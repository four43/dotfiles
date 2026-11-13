#!/bin/bash
# Amazon Linux 2023 system update with pre-flight checks and interactive
# confirmation. AL2023 counterpart of arch/install/files/system-update.sh.
#
# Design notes:
#   - AL2023 uses deterministic, versioned repos: each host is locked to one
#     release, and a plain `dnf upgrade` stays on it. Moving forward means
#     `dnf upgrade --releasever=<version>`. We pin the exact version reported
#     by `dnf check-release-update` (not `latest`) so the preview and the
#     real transaction resolve against the same repo snapshot.
#   - Never use -y: the transaction plan is reviewed by a human.
#   - Preview with --assumeno first and flag high-impact packages (kernel,
#     glibc, systemd, ssh, docker) so a risky upgrade can be deferred.
#   - Warn before docker/containerd upgrades: the daemon restarts and running
#     containers stop.
#   - Rollback for userspace is `sudo dnf history undo last`. Kernels are
#     install-only, so the previous kernel stays in GRUB as a fallback.
#   - Warn about .rpmnew / .rpmsave files: unmerged config changes are a
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

if ! grep -q '^Amazon Linux release 2023' /etc/amazon-linux-release 2>/dev/null; then
	err "Not Amazon Linux 2023 (/etc/amazon-linux-release). Refusing to run."
	exit 1
fi

current=$(rpm -q --qf '%{VERSION}' system-release)

log "=== Amazon Linux 2023 System Update ==="
log "Current release: $current"
log "Running kernel:  $(uname -r)"

# --- Pick target release ------------------------------------------------------
step "[1/4] Checking for newer releases"
# Prints one "Version <x>:" block per newer release and nothing when current.
target=$(dnf check-release-update 2>&1 \
	| sed -nE 's/^[[:space:]]*Version ([0-9.]+):.*/\1/p' \
	| sort -V | tail -n1)
if [ -z "$target" ]; then
	target=$current
	info "Already on the latest release. Checking for updates within $current."
else
	info "Latest release: $target"
	info "Release notes:  https://docs.aws.amazon.com/linux/al2023/release-notes/relnotes-$target.html"
fi

# --- Preview ------------------------------------------------------------------
step "[2/4] Pending changes"
preview=$(sudo dnf upgrade --refresh --releasever="$target" --assumeno 2>&1 || true)
if grep -q '^Nothing to do' <<<"$preview"; then
	info "System is already up to date. Nothing to do."
	exit 0
fi
log "$preview"
log

high_impact=$(grep -E '^ (kernel[0-9.]*|glibc|systemd|openssh-server|openssl-libs|docker-ce|containerd\.io|grub2-[a-z0-9-]+) ' <<<"$preview" || true)
if [ -n "$high_impact" ]; then
	log "$high_impact"
	warn "^^ high-impact packages present (kernel/glibc/init/ssh/boot/docker)."
fi

if grep -qE '^ (docker-ce|containerd\.io) ' <<<"$preview" && command -v docker >/dev/null 2>&1; then
	running=$(docker ps --format '{{.Names}}' 2>/dev/null || true)
	if [ -n "$running" ]; then
		warn "Docker will restart. These running containers will stop:"
		log "$running"
	fi
fi
log

if [ "$target" = "$current" ]; then prompt="Apply updates on $current?"; else prompt="Upgrade $current -> $target?"; fi
confirm "$prompt" || { info "Aborted by user."; exit 0; }

# --- Upgrade ------------------------------------------------------------------
step "[3/4] dnf upgrade --releasever=$target"
# Interactive. User reviews the plan and answers 'y' themselves.
sudo dnf upgrade --releasever="$target"

# --- Post-update checks -------------------------------------------------------
step "[4/4] Post-update checks"
info "Release now: $(rpm -q --qf '%{VERSION}' system-release)"
info "Boot kernel: $(sudo grubby --default-kernel)"
info "Undo userspace changes with: sudo dnf history undo last"

# .rpmnew / .rpmsave files = unmerged config drift, common breakage source.
rpmnew=$(sudo find /etc /usr \( -name '*.rpmnew' -o -name '*.rpmsave' \) 2>/dev/null || true)
if [ -n "$rpmnew" ]; then
	warn "Unmerged config files present:"
	log "$rpmnew"
else
	info "No .rpmnew / .rpmsave files."
fi

# needs-restarting -r exits 1 when a reboot is required (kernel, glibc, ...).
if command -v needs-restarting >/dev/null 2>&1; then
	if ! needs-restarting -r >/dev/null 2>&1; then
		warn "REBOOT REQUIRED to load the new kernel / core libraries: sudo reboot"
	else
		info "No reboot required."
	fi
else
	warn "needs-restarting not found (install dnf-utils) — skipping reboot check."
fi

log
log "=== System update complete ==="
