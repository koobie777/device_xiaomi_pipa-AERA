#!/usr/bin/env bash
# Why does the build ask for trunk_staging when only ap2a..bp2a exist?
cd "$HOME/android/AERA_16.0" || exit 1

echo "=== release configs present ==="
ls build/release/release_configs/ 2>/dev/null | tr '\n' ' '; echo

echo
echo "=== is trunk_staging defined anywhere? ==="
find build/release -name 'trunk_staging*' 2>/dev/null | head -5 || true
grep -rl 'trunk_staging' build/release/ 2>/dev/null | head -5 || echo "  not in build/release"

echo
echo "=== what does lunch export? ==="
source build/envsetup.sh >/dev/null 2>&1
lunch twrp_pipa-bp2a-eng >/dev/null 2>&1
echo "  TARGET_PRODUCT       = ${TARGET_PRODUCT:-<unset>}"
echo "  TARGET_RELEASE       = ${TARGET_RELEASE:-<unset>}"
echo "  TARGET_BUILD_VARIANT = ${TARGET_BUILD_VARIANT:-<unset>}"

echo
echo "=== default when unset (build/make/core/release_config.mk) ==="
grep -n 'trunk_staging\|TARGET_RELEASE' build/make/core/release_config.mk 2>/dev/null | head -12

echo
echo "=== does an explicit TARGET_RELEASE fix dumpvars? ==="
if TARGET_RELEASE=bp2a build/soong/soong_ui.bash --dumpvar-mode TARGET_RELEASE 2>/dev/null; then
    echo "  dumpvars OK with TARGET_RELEASE=bp2a"
else
    echo "  still failing with bp2a -- try another config"
fi
