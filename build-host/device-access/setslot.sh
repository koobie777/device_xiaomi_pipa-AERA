#!/usr/bin/env bash
# Set the active A/B slot from inside EOS. Takes 'a' or 'b'.
#
# Switching to b means the next boot loads boot_b (now AERA) paired with
# vendor_boot_b + dtbo_b -- the normal path, which is what `fastboot boot`
# probably failed to assemble.
#
# Getting back from a non-booting slot needs physical access:
#   Volume Down + Power -> fastboot, then `fastboot set_active a`.
SLOT="${1:-}"
case "$SLOT" in
    a|b) ;;
    *) echo "usage: setslot.sh a|b"; exit 2 ;;
esac

echo "===== before ====="
sudo qbootctl 2>&1 | grep -vE "cmdline arg|Unable to read boot slot"

echo
echo "===== setting active slot to $SLOT ====="
sudo qbootctl -s "$SLOT" 2>&1 | grep -vE "cmdline arg|Unable to read boot slot"

echo
echo "===== after ====="
sudo qbootctl 2>&1 | grep -vE "cmdline arg|Unable to read boot slot"

echo
echo "===== what boot_b holds (sanity) ====="
echo -n "boot_b sha256: "
sudo dd if=/dev/disk/by-partlabel/boot_b bs=1M status=none | sha256sum | cut -d' ' -f1
echo "expected AERA: f30d437091c67def7212cf8521b36d94ed668972bcf84aff3feea1c06fac37dc"
