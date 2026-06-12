#!/bin/bash
# yay-hack-check.sh
#
# The AUR is undergoing a supply-chain attack in which old/abandoned packages
# have been hijacked and poisoned with malware. The Arch community is tracking
# the affected package names in a shared list. This script pulls that list and
# checks it against the packages installed on this system.
#
# Exit codes:
#   0  no infected packages installed
#   1  error (could not fetch list, missing dependencies, etc.)
#   2  one or more infected packages ARE installed
#
# Usage:
#   ./yay-hack-check.sh            # fetch the published list and check
#   ./yay-hack-check.sh FILE       # check against a local copy of the list
#   LIST_URL=... ./yay-hack-check.sh   # override the source URL

set -euo pipefail

# Source of the infected-package list. The "/download" suffix returns the raw
# text of the published HedgeDoc note rather than the rendered HTML page.
LIST_URL="${LIST_URL:-https://md.archlinux.org/s/SxbqukK6IA/download}"

# Colorize output only when writing to a terminal.
if [[ -t 1 ]]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

die() { echo "${RED}error:${RESET} $*" >&2; exit 1; }

command -v pacman >/dev/null || die "pacman not found — this script is for Arch-based systems."

# Acquire the list of infected package names, one per line.
list_file="$(mktemp)"
trap 'rm -f "$list_file"' EXIT

if [[ $# -ge 1 ]]; then
    [[ -r "$1" ]] || die "cannot read list file: $1"
    cp "$1" "$list_file"
    echo "Using local list: $1"
else
    echo "Fetching infected-package list from:"
    echo "  $LIST_URL"
    if command -v curl >/dev/null; then
        curl -fsSL "$LIST_URL" -o "$list_file" || die "failed to download the list (curl)."
    elif command -v wget >/dev/null; then
        wget -qO "$list_file" "$LIST_URL" || die "failed to download the list (wget)."
    else
        die "neither curl nor wget is available to fetch the list."
    fi
fi

# Normalize: keep only valid package-name lines, strip whitespace/CRs, dedupe.
infected="$(mktemp)"
trap 'rm -f "$list_file" "$infected"' EXIT
tr -d '\r' < "$list_file" \
    | sed 's/[[:space:]]*$//' \
    | grep -E '^[a-zA-Z0-9._+-]+$' \
    | sort -u > "$infected"

infected_count=$(wc -l < "$infected")
[[ "$infected_count" -gt 0 ]] || die "the fetched list contained no package names — refusing to report a false all-clear."
echo "Loaded ${BOLD}${infected_count}${RESET} known-infected package names."
echo

# Compare against everything installed. The attack targets AUR packages, but we
# check ALL installed packages (-Qq) rather than only foreign ones (-Qm) so a
# poisoned package is still caught even if pacman no longer tags it as foreign.
matches="$(comm -12 <(pacman -Qq | sort -u) "$infected")"

if [[ -z "$matches" ]]; then
    echo "${GREEN}✓ Clean.${RESET} None of the ${infected_count} infected packages are installed."
    exit 0
fi

match_count=$(printf '%s\n' "$matches" | grep -c .)
echo "${RED}${BOLD}⚠ WARNING:${RESET} ${RED}${match_count} infected package(s) installed:${RESET}"
echo
# Show the installed version alongside each match for context.
while IFS= read -r pkg; do
    ver="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')"
    foreign=""
    pacman -Qmq 2>/dev/null | grep -qxF "$pkg" && foreign=" ${YELLOW}(AUR)${RESET}"
    echo "  ${RED}•${RESET} ${pkg} ${ver}${foreign}"
done <<< "$matches"
echo
echo "${YELLOW}Recommended:${RESET} remove these packages (e.g. 'sudo pacman -Rns <pkg>'),"
echo "then audit your system. Do NOT reinstall from the AUR until the package is known clean."
exit 2
