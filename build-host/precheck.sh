#!/usr/bin/env bash
# Pre-validate what the AERA pipa build needs, before the first mka.
ROOT="$HOME/android/AERA_16.0"
cd "$ROOT" 2>/dev/null || { echo "no tree yet"; exit 1; }

echo "=== core build pieces ==="
for f in build/envsetup.sh \
         build/make/core/config.mk \
         bootable/recovery/aera_config.mk \
         vendor/twrp/config/common.mk \
         vendor/recovery/aera_soong_config.mk \
         vendor/recovery/AERA_A16.sh; do
    [ -e "$f" ] && echo "ok   $f" || echo "MISS $f"
done

echo
echo "=== is aera_config.mk actually included by the build? ==="
grep -rn 'aera_config.mk' build/make/core/ bootable/recovery/Android*.mk \
    vendor/twrp/config/ vendor/recovery/ 2>/dev/null | head -10 \
    || echo "  no include found -- check how it gets pulled in"

echo
echo "=== is aera_soong_config.mk included? ==="
grep -rn 'aera_soong_config' build/make/core/ vendor/ 2>/dev/null | head -5 \
    || echo "  no include found"

echo
echo "=== device tree present? ==="
if [ -d device/xiaomi/pipa ]; then
    ls device/xiaomi/pipa | tr '\n' ' '; echo
else
    echo "  device/xiaomi/pipa NOT placed yet (sync still running)"
fi

echo
echo "=== release configs available (for the bp2a lunch suffix) ==="
ls build/release/release_configs/*.textproto 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ' || \
    ls build/release/ 2>/dev/null | head -10
echo

echo "=== does anything still point at an unreachable SSH remote? ==="
grep -rhoE 'git@github\.com:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' .repo/manifests/*.xml 2>/dev/null \
    | sort -u | head -10 || echo "  none found in manifests"

echo
echo "=== repo sync state ==="
if pgrep -f 'repo sync' >/dev/null 2>&1; then echo "  repo sync STILL RUNNING"; else echo "  repo sync not running"; fi
du -sh "$ROOT" 2>/dev/null | awk '{print "  tree " $1}'
