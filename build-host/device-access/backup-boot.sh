#!/usr/bin/env bash
# Back up the Android-slot boot chain from inside EOS, then inspect it.
#
# READ ONLY on the device. Having root in EOS means we can both preserve
# InfinityX's boot images (so flashing AERA to boot_b becomes reversible) and
# examine the vendor_boot/dtbo that a v3 boot image depends on for its DTB.
set -o pipefail

OUT=/mnt/c/Users/CJ/pipa-eos/aera/backups
SSH="ssh -i $HOME/.ssh/pipa_ed25519 -o StrictHostKeyChecking=no -o BatchMode=yes koobie777@192.168.40.86"

mkdir -p "$OUT"

echo "===== pulling partitions (read-only dd over ssh) ====="
for p in boot_a boot_b vendor_boot_b dtbo_a dtbo_b; do
    f="$OUT/$p.img"
    if [ -s "$f" ]; then
        echo "  $p already saved ($(stat -c %s "$f") bytes)"
        continue
    fi
    echo -n "  $p ... "
    if $SSH "sudo dd if=/dev/disk/by-partlabel/$p bs=1M status=none" > "$f" 2>/dev/null; then
        echo "$(stat -c %s "$f") bytes"
    else
        echo "FAILED"
        rm -f "$f"
    fi
done

echo
echo "===== sha256 ====="
(cd "$OUT" && sha256sum *.img 2>/dev/null)

echo
echo "===== Android boot header of each image ====="
for p in boot_a boot_b vendor_boot_b; do
    f="$OUT/$p.img"
    [ -s "$f" ] || continue
    magic=$(head -c 8 "$f" | tr -d '\0')
    # Android boot header v3: magic[8], kernel_size, ramdisk_size, os_version,
    # header_size, reserved[4], header_version, cmdline[1536]
    ver=$(od -An -tu4 -j 40 -N 4 "$f" 2>/dev/null | tr -d ' ')
    printf '%-16s magic=[%-8s] header_version=%s\n' "$p" "$magic" "$ver"
done

echo
echo "===== kernel version strings found in each boot image ====="
for p in boot_a boot_b; do
    f="$OUT/$p.img"
    [ -s "$f" ] || continue
    v=$(strings -a "$f" 2>/dev/null | grep -m2 -oE 'Linux version [0-9][^ ]*( [^ ]+)?' | head -2 | tr '\n' ' ')
    printf '%-10s %s\n' "$p" "${v:-<none found>}"
done

echo
echo "===== does boot_b currently hold AERA, InfinityX recovery, or UEFI? ====="
for p in boot_a boot_b; do
    f="$OUT/$p.img"
    [ -s "$f" ] || continue
    echo "--- $p ---"
    strings -a "$f" 2>/dev/null | grep -m6 -iE 'aera|orangefox|twrp|infinity|lineage|Mu-Silicium|EDK II|UEFI' | sort -u | head -6 \
        || echo "  no recognisable product strings"
done

echo
echo "===== dtbo contents ====="
for p in dtbo_a dtbo_b; do
    f="$OUT/$p.img"
    [ -s "$f" ] || continue
    magic=$(od -An -tx1 -N 4 "$f" 2>/dev/null | tr -d ' ')
    nz=$(tr -d '\0' < "$f" | wc -c)
    printf '%-9s first4=%s nonzero_bytes=%s\n' "$p" "$magic" "$nz"
done
echo "  (dtbo table magic is d7b7ab1e; all-zero means erased)"
