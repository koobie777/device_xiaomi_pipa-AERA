#!/usr/bin/env bash
# Compare our AERA boot image against the InfinityX image that the bootloader
# is known to accept, and against what a v3 image needs to actually boot.
#
# Prime suspect for "black screen, no USB" after `fastboot boot`:
# an Android boot header v3 image carries NO DTB -- the DTB lives in
# vendor_boot. `fastboot boot` uploads only the image you hand it, so if the
# bootloader does not merge the on-device vendor_boot, the kernel starts with
# no device tree and dies before any console or USB comes up.
B=/mnt/c/Users/CJ/pipa-eos/aera/backups
O=/mnt/c/Users/CJ/pipa-eos/aera/out
BL=/mnt/c/Users/CJ/pipa-eos/aera/builds

hdr() {
    local f="$1" name="$2"
    [ -s "$f" ] || { printf '%-34s MISSING\n' "$name"; return; }
    local magic kver ksz rsz hv
    magic=$(head -c 8 "$f" | tr -d '\0')
    # boot_img_hdr_v3: magic[8] kernel_size ramdisk_size os_version header_size
    #                  reserved[4]*4 header_version cmdline[1536]
    ksz=$(od -An -tu4 -j 8  -N 4 "$f" | tr -d ' ')
    rsz=$(od -An -tu4 -j 12 -N 4 "$f" | tr -d ' ')
    hv=$(od -An -tu4 -j 40 -N 4 "$f" | tr -d ' ')
    printf '%-34s magic=[%-8s] hdr_v=%-3s kernel=%-10s ramdisk=%-10s size=%s\n' \
        "$name" "$magic" "$hv" "$ksz" "$rsz" "$(stat -c %s "$f")"
}

echo "===== headers ====="
hdr "$B/boot_b.img" "boot_b (InfinityX, boots)"
hdr "$B/boot_a.img" "boot_a (Mu-Silicium UEFI)"
for f in "$O"/*.img; do [ -s "$f" ] && hdr "$f" "built: $(basename "$f")"; done
if [ -d "$BL" ]; then
    find "$BL" -name '*.img' 2>/dev/null | while read -r f; do
        hdr "$f" "built: ${f#$BL/}"
    done
fi

echo
echo "===== embedded DTB? (flattened device tree magic d00dfeed) ====="
for f in "$B/boot_b.img" "$B/vendor_boot_b.img" "$O"/*.img; do
    [ -s "$f" ] || continue
    n=$(grep -c $'\xd0\x0d\xfe\xed' "$f" 2>/dev/null || echo 0)
    off=$(grep -abo $'\xd0\x0d\xfe\xed' "$f" 2>/dev/null | head -1 | cut -d: -f1)
    printf '%-40s fdt_magic_hits=%-5s first_offset=%s\n' "$(basename "$f")" "$n" "${off:-none}"
done

echo
echo "===== kernel version in each built image ====="
for f in "$O"/*.img; do
    [ -s "$f" ] || continue
    v=$(strings -a "$f" | grep -m1 -oE 'Linux version [0-9][^ ]*')
    printf '%-40s %s\n' "$(basename "$f")" "${v:-<none>}"
done

echo
echo "===== cmdline embedded in each image (v3 cmdline is at offset 44) ====="
for f in "$B/boot_b.img" "$O"/*.img; do
    [ -s "$f" ] || continue
    c=$(dd if="$f" bs=1 skip=44 count=200 status=none 2>/dev/null | tr -d '\0')
    printf '%-40s [%s]\n' "$(basename "$f")" "$c"
done
