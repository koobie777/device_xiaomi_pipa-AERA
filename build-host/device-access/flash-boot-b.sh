#!/usr/bin/env bash
# Write the AERA image to boot_b and verify it, from inside EOS over ssh.
#
# Rationale: `fastboot boot` of a header-v3 image gave a black screen with no
# USB. A v3 boot image carries no DTB -- the DTB lives in vendor_boot -- and
# the bootloader only pairs them on a normal boot, not necessarily for
# `fastboot boot`. Writing to boot_b exercises the real path, with
# vendor_boot_b + dtbo_b supplying the DTB exactly as InfinityX does.
#
# Reversible: backups/boot_b.img is a verified full-partition copy.
#
# Stage 1 (default): write + verify, change nothing else.
# Stage 2 (SET_SLOT=1): also set slot b active.
set -o pipefail

KEY="$HOME/.ssh/pipa_ed25519"
HOST=koobie777@192.168.40.86
SSHO=(-i "$KEY" -o StrictHostKeyChecking=no -o BatchMode=yes)
IMG=/mnt/c/Users/CJ/pipa-eos/aera/out/AERA-R1.0-Beta-Unofficial-pipa.img
BACKUP=/mnt/c/Users/CJ/pipa-eos/aera/backups/boot_b.img
SET_SLOT="${SET_SLOT:-0}"

die() { echo "FATAL: $*" >&2; exit 1; }

[ -s "$IMG" ] || die "image missing: $IMG"
[ -s "$BACKUP" ] || die "refusing to write without a backup of boot_b"

echo "===== preflight ====="
want=$(sha256sum "$IMG" | cut -d' ' -f1)
echo "  image      $(stat -c %s "$IMG") bytes"
echo "  sha256     $want"
echo "  backup     $(stat -c %s "$BACKUP") bytes ($(sha256sum "$BACKUP" | cut -c1-16)...)"

# The partition is 192 MiB and the image is exactly partition-sized, so a
# full-partition read-back must equal the file byte for byte.
psize=$(ssh "${SSHO[@]}" "$HOST" "sudo blockdev --getsize64 /dev/disk/by-partlabel/boot_b") \
    || die "cannot read boot_b size"
echo "  boot_b     $psize bytes"
[ "$psize" = "$(stat -c %s "$IMG")" ] || die "size mismatch: image vs boot_b"

echo
echo "===== qbootctl: usage and current state ====="
ssh "${SSHO[@]}" "$HOST" "sudo qbootctl --help 2>&1 | head -12; echo '--- status ---'; sudo qbootctl 2>&1 | head -10"

echo
echo "===== copying image to tablet ====="
scp "${SSHO[@]}" "$IMG" "$HOST:/tmp/aera.img" >/dev/null || die "scp failed"
got=$(ssh "${SSHO[@]}" "$HOST" "sha256sum /tmp/aera.img | cut -d' ' -f1")
echo "  on tablet  $got"
[ "$got" = "$want" ] || die "hash mismatch after copy"
echo "  transfer verified"

echo
echo "===== writing to boot_b ====="
ssh "${SSHO[@]}" "$HOST" "sudo dd if=/tmp/aera.img of=/dev/disk/by-partlabel/boot_b bs=1M conv=fsync status=none && sync && echo write-ok" \
    || die "dd failed"

echo
echo "===== verifying boot_b read-back ====="
rb=$(ssh "${SSHO[@]}" "$HOST" "sudo dd if=/dev/disk/by-partlabel/boot_b bs=1M status=none | sha256sum | cut -d' ' -f1")
echo "  boot_b now $rb"
if [ "$rb" = "$want" ]; then
    echo "  VERIFIED -- boot_b byte-for-byte matches the built AERA image"
else
    echo "  MISMATCH -- restoring the backup now"
    scp "${SSHO[@]}" "$BACKUP" "$HOST:/tmp/boot_b_restore.img" >/dev/null
    ssh "${SSHO[@]}" "$HOST" "sudo dd if=/tmp/boot_b_restore.img of=/dev/disk/by-partlabel/boot_b bs=1M conv=fsync status=none && sync && echo restored"
    die "write did not verify; boot_b restored from backup"
fi

ssh "${SSHO[@]}" "$HOST" "rm -f /tmp/aera.img"

if [ "$SET_SLOT" != "1" ]; then
    echo
    echo "Stage 1 complete. boot_b holds AERA; the active slot is UNCHANGED."
    echo "Run again with SET_SLOT=1 to switch to slot b."
    exit 0
fi

echo
echo "===== setting slot b active ====="
ssh "${SSHO[@]}" "$HOST" "sudo qbootctl -s b 2>&1 || sudo qbootctl --set-active=b 2>&1; echo '--- after ---'; sudo qbootctl 2>&1 | head -10"

echo
echo "Done. Reboot the tablet to boot AERA from slot b."
echo "If it fails: Volume Down + Power -> fastboot, then 'fastboot set_active a'."
