#!/system/bin/sh
# Read-only observations after a RAM boot of AERA on pipa.
# This script does not mount, decrypt, format, flash, reboot, change slots,
# set properties, or write device files. Redirect its stdout on the host.
# Example (host shell; do not upload the script to /data):
#   adb shell -T sh < observe-recovery.sh > recovery-observations.txt

section() {
    printf '\n===== %s =====\n' "$1"
}

run_if_present() {
    if command -v "$1" >/dev/null 2>&1; then
        "$@" 2>&1
    else
        printf 'Unavailable command: %s\n' "$1"
    fi
}

section 'Identity and boot mode'
run_if_present id
run_if_present uname -a
for property_name in \
    ro.product.device ro.product.model ro.hardware \
    ro.boot.slot_suffix ro.boot.slot ro.bootmode ro.boot.bootreason \
    ro.boot.force_normal_boot ro.build.version.release \
    ro.build.version.sdk ro.build.version.security_patch \
    ro.vendor.build.security_patch ro.bootimage.build.version.security_patch \
    ro.virtual_ab.enabled ro.boot.dynamic_partitions \
    ro.crypto.state ro.crypto.type twrp.drm.direct_scanout \
    sys.usb.config sys.usb.state sys.usb.configfs sys.usb.ffs.ready \
    init.svc.adbd init.svc.recovery init.svc.logd \
    init.svc.vendor.qseecomd init.svc.keymaster-4-0 init.svc.gatekeeper-1-0
do
    printf '%s=%s\n' "$property_name" "$(getprop "$property_name")"
done
for kernel_file in /proc/cmdline /proc/bootconfig; do
    if [ -r "$kernel_file" ]; then
        printf '\n%s\n' "$kernel_file"
        cat "$kernel_file"
    fi
done

section 'Recovery and supporting processes'
if command -v ps >/dev/null 2>&1; then
    ps -A 2>&1 | grep -E '(^USER|recovery|adbd|keymaster|gatekeeper|qseecomd|health|logd)' || true
fi

section 'Native UI marker and installed binaries'
for artifact_path in \
    /system/etc/recovery-ui2.enabled /etc/recovery-ui2.enabled \
    /system/bin/recovery /system/bin/adbd /sbin/adbd \
    /system/bin/aera /system/bin/aera-browser-jail \
    /system/bin/aera-audio-null-bridge /system/bin/lpdump \
    /system/bin/magiskboot /sbin/magiskboot \
    /vendor/bin/qseecomd \
    /vendor/bin/hw/android.hardware.keymaster@4.0-service-qti \
    /vendor/bin/hw/android.hardware.gatekeeper@1.0-service-qti
do
    ls -ld "$artifact_path" 2>&1
done
if [ -r /system/etc/recovery-ui2.enabled ]; then
    cat /system/etc/recovery-ui2.enabled
fi

section 'Recovery partition configuration'
for config_path in /system/etc/recovery.fstab /system/etc/twrp.flags; do
    if [ -r "$config_path" ]; then
        printf '\n%s\n' "$config_path"
        cat "$config_path"
    fi
done

section 'Existing mounts and mapper nodes (no mount requests)'
cat /proc/mounts
ls -l /dev/block/mapper 2>&1
for block_name in boot_a boot_b dtbo_a dtbo_b vendor_boot_a vendor_boot_b \
    userdata metadata super linux cust rawdump
do
    ls -l "/dev/block/by-name/$block_name" 2>&1
done
run_if_present lpdump

section 'Display and input inventory'
if [ -r /proc/bus/input/devices ]; then
    cat /proc/bus/input/devices
fi
ls -l /dev/dri /dev/input /sys/class/backlight 2>&1
for panel_path in \
    /sys/class/backlight/panel0-backlight/brightness \
    /sys/class/backlight/panel0-backlight/max_brightness
do
    if [ -r "$panel_path" ]; then
        printf '%s=' "$panel_path"
        cat "$panel_path"
    fi
done

section 'Recent recovery log (includes observed decryption state)'
if [ -r /tmp/recovery.log ]; then
    tail -n 350 /tmp/recovery.log
else
    printf '/tmp/recovery.log is unavailable\n'
fi

section 'Recent Android log buffers'
run_if_present logcat -d -b all -t 300

section 'Recent kernel messages'
if command -v dmesg >/dev/null 2>&1; then
    dmesg 2>&1 | tail -n 200
fi

section 'End of observations; no device state changes requested'
