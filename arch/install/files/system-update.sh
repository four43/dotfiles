#!/bin/bash
# System update with pre-flight checks and interactive confirmation.
#
# Design notes:
#   - Never use --noconfirm: silent updates hide breakage until the reboot.
#   - Refresh archlinux-keyring BEFORE the full upgrade. Stale keys are the
#     #1 cause of "invalid or corrupted package (PGP signature)" failures.
#   - Show pending updates via `checkupdates` first so a huge/risky upgrade
#     can be deferred. `checkupdates` uses a separate sync DB, so it does
#     NOT create the partial-upgrade footgun that `pacman -Sy && pacman -S`
#     would.
#   - Only ever `pacman -Syu` (full sync + upgrade). NEVER `pacman -Sy pkg`.
#     Partial upgrades are the source of most "why did qt/glibc break my
#     system" incidents.
#   - Do NOT prune the pacman cache. Keeping /var/cache/pacman/pkg populated
#     is what makes per-package rollback via `downgrade` possible.
#   - Warn about .pacnew / .pacsave files: unmerged config changes are a
#     common source of post-update breakage.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "$@" >&2; }
info() { log "${GREEN}[INFO]${NC} $*"; }
warn() { log "${YELLOW}[WARN]${NC} $*"; }
err()  { log "${RED}[ERROR]${NC} $*"; }
step() { log; log "${BLUE}==>${NC} $*"; }

confirm() {
	local message="$1" response
	while true; do
		echo -en "${YELLOW}[CONFIRM]${NC} $message (y/n): " >&2
		read -r response
		case "$response" in
		[yY]|[yY][eE][sS]) return 0 ;;
		[nN]|[nN][oO])     return 1 ;;
		*) echo "Please answer yes or no." >&2 ;;
		esac
	done
}

log "=== System Update ==="
log "Running kernel: $(uname -r)"

# --- Pre-flight: keyring first, in its own transaction -----------------------
step "[1/6] Refreshing archlinux-keyring"
# Doing this before -Syu avoids the classic "invalid PGP signature" failure
# when keys have rotated since the last update.
sudo pacman -Sy --needed --noconfirm archlinux-keyring

# --- Pre-flight: show what's about to change ---------------------------------
step "[2/6] Pending updates"
if command -v checkupdates >/dev/null 2>&1; then
	# checkupdates uses a separate sync DB in /tmp, so this does NOT poison
	# the real DB (which would create the partial-upgrade trap).
	pending=$(checkupdates || true)
	if [ -z "$pending" ]; then
		info "System is already up to date. Nothing to do for pacman."
	else
		log "$pending"
		log
		# Flag known high-risk packages so the user pays attention.
		echo "$pending" | grep -E '^(linux|linux-lts|nvidia|nvidia-open|nvidia-open-dkms|nvidia-utils|systemd|glibc|grub|mkinitcpio|qt[56]-base) ' \
			&& warn "^^ high-impact packages present (kernel/driver/init/boot/qt/glibc)." \
			|| true
		log
		confirm "Proceed with pacman -Syu?" || { info "Aborted by user."; exit 0; }
	fi
else
	warn "checkupdates not found (install pacman-contrib). Skipping preview."
	confirm "Proceed anyway?" || exit 1
fi

# --- Snapshot ---------------------------------------------------------------
# Design notes on timeshift's exit code:
#   Empirically, `timeshift --create --scripted` returns 0 when nothing else is
#   going on, but returns non-zero when the auto-remove pass emits retention
#   warnings like "Maximum backups exceeded for backup level 'daily'" — even
#   when the snapshot itself was saved successfully.
#
#   Since a rollback safety-net is the entire point of this step, we can't
#   just ignore the exit code (real failures must abort the update). We also
#   can't trust it (spurious non-zeros must not abort). So we key off the
#   "Snapshot saved successfully" line in the output, which is emitted by
#   Main.vala's create_snapshot only after the subvolume + info.json are
#   both on disk. If that line is present, the snapshot exists; otherwise
#   we abort.
step "[3/6] Pre-update timeshift snapshot"
if ! command -v timeshift >/dev/null 2>&1; then
	warn "timeshift not installed — no snapshot. Continuing without a rollback safety net."
else
	# Prune old "pre-update" snapshots FIRST (keep 5 most recent). Doing this
	# before create reduces the number of ondemand-with-comment snapshots
	# lying around, which are the ones auto-remove refuses to touch.
	old_snapshots=$(sudo timeshift --list --scripted 2>/dev/null \
		| grep -E "^\s*>" \
		| grep "pre-update" \
		| awk '{print $2}' \
		| head -n -5) || old_snapshots=""
	if [ -n "$old_snapshots" ]; then
		while IFS= read -r snap; do
			if sudo timeshift --delete --snapshot "$snap" --scripted >/dev/null 2>&1; then
				info "  pruned old pre-update snapshot: $snap"
			else
				warn "  failed to prune $snap (continuing)"
			fi
		done <<<"$old_snapshots"
	fi

	# Create the snapshot. Capture output so we can detect success from the
	# "saved successfully" marker regardless of timeshift's exit code.
	ts_out=$(mktemp)
	trap 'rm -f "$ts_out"' EXIT
	set +e
	sudo timeshift --create \
		--comments "pre-update (kernel: $(uname -r))" \
		--scripted 2>&1 | tee "$ts_out"
	ts_exit=${PIPESTATUS[0]}
	set -e

	if grep -qE "(BTRFS|RSYNC) Snapshot saved successfully" "$ts_out"; then
		if [ "$ts_exit" -ne 0 ]; then
			warn "timeshift exited $ts_exit (likely from a retention warning after"
			warn "the snapshot was already saved). Snapshot IS on disk — continuing."
		fi
	else
		err "No 'Snapshot saved successfully' line in timeshift output (exit $ts_exit)."
		err "Snapshot creation failed. Aborting update — refuse to upgrade without a rollback safety net."
		exit 1
	fi

	warn "Timeshift snapshots exclude /boot (ESP is FAT32) — a rollback"
	warn "combined with a removed kernel will leave you unbootable. If"
	warn "linux-lts is installed, you have a fallback. Otherwise: reconsider."
fi

# --- Upgrade ----------------------------------------------------------------
step "[4/6] pacman -Syu"
# Interactive. User reviews the plan and answers 'y' themselves.
sudo pacman -Syu

step "[5/6] AUR (yay)"
if command -v yay >/dev/null 2>&1; then
	# yay handles its own confirmation. Do NOT pass --noconfirm.
	yay -Syu --devel
else
	info "yay not installed — skipping AUR."
fi

# --- Post-update: flatpak ---------------------------------------------------
step "[6/6] Flatpak"
if command -v flatpak >/dev/null 2>&1; then
	flatpak update
	flatpak uninstall --unused
else
	info "flatpak not installed — skipping."
fi

# --- Post-update: warn about drift ------------------------------------------
log
step "Post-update checks"

# .pacnew / .pacsave files = unmerged config drift, common breakage source.
if command -v pacdiff >/dev/null 2>&1; then
	pacnew=$(sudo find /etc /usr -name '*.pacnew' -o -name '*.pacsave' 2>/dev/null || true)
	if [ -n "$pacnew" ]; then
		warn "Unmerged config files present:"
		log "$pacnew"
		warn "Review with: sudo DIFFPROG=nvim pacdiff"
	else
		info "No .pacnew / .pacsave files."
	fi
else
	warn "pacdiff not found (install pacman-contrib) — skipping config drift check."
fi

# Kernel upgraded without reboot? Modules for the running kernel may have
# been removed on disk, which breaks module loading (VPN, DKMS, etc.) until
# reboot.
running_kernel=$(uname -r)
if [ ! -d "/usr/lib/modules/$running_kernel" ]; then
	warn "Running kernel $running_kernel no longer has modules on disk."
	warn "REBOOT SOON. Loading a module (nvidia, vboxdrv, wireguard, etc.) will fail until then."
fi

log
log "=== System update complete ==="
