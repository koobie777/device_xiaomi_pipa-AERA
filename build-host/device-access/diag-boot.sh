#!/usr/bin/env bash
# Privileged, READ-ONLY inspection of the boot chain on pipa.
# Nothing here writes to any partition.
set -o pipefail

P=/dev/disk/by-partlabel

echo "===== sudo check ====="
if sudo -n true 2>/dev/null; then echo "passwordless sudo OK"; else echo "NO sudo -- aborting"; exit 1; fi

echo
echo "===== qbootctl: slot state ====="
sudo qbootctl 2>&1 | head -20

echo
echo "===== boot image magic per slot ====="
# Android boot images start with "ANDROID!". A UEFI payload will not.
for s in boot_a boot_b; do
    if [ -e "$P/$s" ]; then
        magic=$(sudo dd if="$P/$s" bs=8 count=1 status=none 2>/dev/null | tr -d '\0')
        printf '%-8s magic=[%s]\n' "$s" "$magic"
    else
        printf '%-8s MISSING\n' "$s"
    fi
done

echo
echo "===== full-partition sha256 of each boot slot ====="
# Our built AERA image is exactly 192 MiB (partition-sized), so if it was
# flashed, the whole-partition hash should equal the file's hash:
#   AERA-R1.0-Beta-Unofficial-pipa.img = f30d437091c67def7212cf8521b36d94ed668972bcf84aff3feea1c06fac37dc
for s in boot_a boot_b; do
    [ -e "$P/$s" ] || continue
    h=$(sudo dd if="$P/$s" bs=1M status=none 2>/dev/null | sha256sum | cut -d' ' -f1)
    printf '%-8s %s\n' "$s" "$h"
done

echo
echo "===== dtbo slots (erased or populated?) ====="
for s in dtbo_a dtbo_b; do
    [ -e "$P/$s" ] || continue
    # An erased partition reads as all zeros / all 0xff.
    nz=$(sudo dd if="$P/$s" bs=1M count=4 status=none 2>/dev/null | tr -d '\0' | wc -c)
    h=$(sudo dd if="$P/$s" bs=1M count=4 status=none 2>/dev/null | sha256sum | cut -d' ' -f1 | cut -c1-16)
    printf '%-8s nonzero_bytes_in_first_4MiB=%-10s sha256(4MiB)=%s\n' "$s" "$nz" "$h"
done

echo
echo "===== vbmeta slots ====="
for s in vbmeta_a vbmeta_b; do
    [ -e "$P/$s" ] || continue
    magic=$(sudo dd if="$P/$s" bs=4 count=1 status=none 2>/dev/null | tr -d '\0')
    printf '%-10s magic=[%s]\n' "$s" "$magic"
done

echo
echo "===== GPT health ====="
sudo parted -s /dev/sda unit MiB print 2>&1 | tail -12

echo
echo "===== what GRUB is booting ====="
sudo cat /boot/grub2/grub.cfg 2>/dev/null | grep -E 'menuentry|linux|initrd|devicetree' | head -20 \
    || echo "  (grub.cfg not where expected)"

echo
echo "===== ESP contents ====="
sudo ls -R /boot/efi 2>/dev/null | head -30 || echo "  ESP not mounted"
