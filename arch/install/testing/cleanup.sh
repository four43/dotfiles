#!/bin/bash
# Teardown the test VM and any orphan libvirt state.
# Safe to run any time — every step is best-effort and idempotent.
set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

VIRSH="virsh -c qemu:///system"

# Names this script knows about:
#   - "arch-install-test" — current virt-install setup
#   - "testing_default"   — legacy name from the vagrant-libvirt era
FOUND_ANY=0
for VM_NAME in arch-install-test testing_default; do
	if $VIRSH dominfo "$VM_NAME" >/dev/null 2>&1; then
		FOUND_ANY=1
		STATE=$($VIRSH domstate "$VM_NAME" 2>/dev/null || echo "unknown")
		info "Domain $VM_NAME found (state: $STATE) — tearing down..."
		# destroy is harmless on stopped/paused domains
		$VIRSH destroy "$VM_NAME" >/dev/null 2>&1 || true
		$VIRSH undefine --nvram --remove-all-storage "$VM_NAME" >/dev/null 2>&1 \
			|| $VIRSH undefine --nvram "$VM_NAME" >/dev/null 2>&1 \
			|| warn "could not undefine $VM_NAME"
	fi

	# Volume names left over from vagrant-libvirt (e.g. testing_default-vdb.qcow2).
	mapfile -t VOLS < <($VIRSH vol-list default 2>/dev/null \
		| awk -v n="$VM_NAME" 'NR>2 && $1 ~ "^"n {print $1}')
	for vol in "${VOLS[@]}"; do
		[[ -z $vol ]] && continue
		info "Deleting orphan volume $vol from pool default..."
		$VIRSH vol-delete --pool default "$vol" >/dev/null 2>&1 \
			|| warn "could not delete $vol"
	done
done

# Legacy NVRAM file from the vagrant Vagrantfile (hardcoded path).
LEGACY_NVRAM="/var/lib/libvirt/qemu/nvram/arch-live_VARS.fd"
if [[ -e $LEGACY_NVRAM ]]; then
	info "Removing legacy NVRAM file $LEGACY_NVRAM..."
	sudo rm -f "$LEGACY_NVRAM"
fi

if [[ $FOUND_ANY -eq 0 ]]; then
	info "Nothing to clean — no matching libvirt domains found."
else
	info "Cleanup complete."
fi
