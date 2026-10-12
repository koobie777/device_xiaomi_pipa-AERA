#!/usr/bin/env bash
# Retrieve kernel crash/console remnants WITHOUT clearing them.
#
# A black screen with no USB enumeration means the kernel either never ran or
# died very early. ramoops/pstore survives a warm reboot, so if the AERA kernel
# panicked there may be a record of it.
#
# READ ONLY. Nothing here deletes a pstore entry -- removing a file from
# /sys/fs/pstore is what frees it in the backend, so we only copy.
echo "===== sudo ====="
if sudo -n true 2>/dev/null; then echo "passwordless sudo OK"; else echo "NO sudo"; exit 1; fi

echo
echo "===== /sys/fs/pstore (live, do not delete) ====="
if sudo test -d /sys/fs/pstore; then
    sudo ls -la /sys/fs/pstore/ 2>&1
else
    echo "  not mounted"
    echo "  --- is the pstore filesystem available at all? ---"
    grep -i pstore /proc/filesystems 2>/dev/null || echo "  no pstore in /proc/filesystems"
    grep -iE 'ramoops|pstore' /proc/mounts 2>/dev/null || echo "  not in /proc/mounts"
fi

echo
echo "===== systemd-pstore archive (where entries get moved to) ====="
if sudo test -d /var/lib/systemd/pstore; then
    sudo find /var/lib/systemd/pstore -type f -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -20
else
    echo "  /var/lib/systemd/pstore absent"
fi
echo "  systemd-pstore service: $(systemctl is-enabled systemd-pstore 2>/dev/null) / $(systemctl is-active systemd-pstore 2>/dev/null)"

echo
echo "===== ramoops reserved region in the device tree? ====="
sudo find /proc/device-tree -iname '*ramoops*' -o -iname '*pstore*' 2>/dev/null | head -5 \
    || echo "  none found"

echo
echo "===== console-ramoops contents (if any) ====="
for f in /sys/fs/pstore/console-ramoops-0 /sys/fs/pstore/console-ramoops \
         /sys/fs/pstore/dmesg-ramoops-0; do
    if sudo test -f "$f"; then
        echo "--- $f (last 60 lines) ---"
        sudo tail -60 "$f" 2>&1
    fi
done

echo
echo "===== any archived pstore text, newest first ====="
newest=$(sudo find /var/lib/systemd/pstore -type f -name '*ramoops*' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
if [ -n "$newest" ]; then
    echo "--- $newest (last 80 lines) ---"
    sudo tail -80 "$newest" 2>&1
else
    echo "  no archived ramoops files"
fi

echo
echo "===== last EOS boot time, to date the entries ====="
who -b 2>/dev/null || uptime -s 2>/dev/null
echo "now: $(date)"
