#!/usr/bin/env bash
# Unprivileged diagnostics from inside EndeavourOS on the pipa tablet.
# Piped in over ssh and run with bash, because the login shell is fish.
echo "===== identity ====="
uname -a
echo "hostname: $(cat /etc/hostname 2>/dev/null)"

echo
echo "===== kernel cmdline (shows root=, boot=, slot) ====="
cat /proc/cmdline

echo
echo "===== booted via UEFI? ====="
if [ -d /sys/firmware/efi ]; then
    echo "yes -- /sys/firmware/efi present (Mu-Silicium UEFI chain)"
    echo "fw platform size: $(cat /sys/firmware/efi/fw_platform_size 2>/dev/null)"
else
    echo "NO -- not an EFI boot"
fi

echo
echo "===== block devices ====="
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT 2>/dev/null | head -60

echo
echo "===== mounts of interest ====="
mount | grep -E ' / | /boot| /efi' || true

echo
echo "===== rootfs usage (did the 128 GiB resize hold?) ====="
df -h / /boot /boot/efi 2>/dev/null

echo
echo "===== /boot contents ====="
ls -la /boot 2>/dev/null | head -25

echo
echo "===== /boot/efi (ESP in rawdump) ====="
ls -laR /boot/efi 2>/dev/null | head -40 || echo "  not mounted or unreadable"

echo
echo "===== partlabels present (is linux/cust/rawdump intact?) ====="
for p in /dev/disk/by-partlabel/*; do
    [ -e "$p" ] || continue
    printf '%-22s -> %s\n' "${p##*/}" "$(readlink -f "$p")"
done 2>/dev/null | grep -iE 'linux|cust|rawdump|userdata|boot_|dtbo|vbmeta|super' || echo "  no by-partlabel dir"

echo
echo "===== filesystem labels ====="
ls -la /dev/disk/by-label/ 2>/dev/null | tail -12

echo
echo "===== A/B slot tooling available? ====="
for t in qbootctl bootctl efibootmgr sgdisk parted; do
    if command -v "$t" >/dev/null 2>&1; then echo "have $t"; else echo "no   $t"; fi
done

echo
echo "===== device packages installed ====="
pacman -Q linux-pipa pipa-grub-config pipa-sensors hexagonrpc iio-sensor-proxy-pipa pipa-dracut 2>/dev/null || echo "  (some not installed)"

echo
echo "===== can we sudo without a password? ====="
if sudo -n true 2>/dev/null; then
    echo "yes -- passwordless sudo available"
else
    echo "NO -- privileged checks (raw partition reads, sgdisk) are unavailable"
fi
