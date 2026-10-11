#!/usr/bin/env bash
# Sync the AERA Recovery aera-16.0 manifest and drop our pipa tree in place.
#
# The manifest README says AERA's projects live in a private org needing an SSH
# key. That is stale: the repos are public, so init over HTTPS anonymously.
set -euo pipefail

ROOT="$HOME/android/AERA_16.0"
export PATH="$HOME/bin:$PATH"

mkdir -p "$ROOT"
cd "$ROOT"

if [ ! -d .repo ]; then
    echo "### repo init (aera-16.0)"
    repo init -u https://github.com/AERA-Recovery/android_manifest.git \
        -b aera-16.0 --depth=1
else
    echo "### .repo already exists, skipping init"
fi

echo
echo "### repo sync -- this is the long part"
date
# -c         only the current branch
# --no-tags  skip tag objects
# --depth=1  came from init; keeps the tree far smaller than full history
repo sync -c --force-sync --no-clone-bundle --no-tags -j"$(nproc)"
date

echo
echo "### Placing the pipa device tree"
rm -rf device/xiaomi/pipa
mkdir -p device/xiaomi
git clone -b aera-16.0 \
    https://github.com/koobie777/device_xiaomi_pipa-AERA.git \
    device/xiaomi/pipa

echo
echo "### Sanity checks"
test -f build/envsetup.sh && echo "ok   build/envsetup.sh" || echo "MISS build/envsetup.sh"
test -f bootable/recovery/aera_config.mk && echo "ok   bootable/recovery/aera_config.mk" \
    || echo "MISS bootable/recovery/aera_config.mk  <- AERA core did not sync"
test -f vendor/twrp/config/common.mk && echo "ok   vendor/twrp/config/common.mk" \
    || echo "MISS vendor/twrp/config/common.mk"
test -f vendor/recovery/aera_soong_config.mk && echo "ok   vendor/recovery/aera_soong_config.mk" \
    || echo "MISS vendor/recovery/aera_soong_config.mk"
test -f device/xiaomi/pipa/aera_pipa.mk && echo "ok   device/xiaomi/pipa/aera_pipa.mk" \
    || echo "MISS device/xiaomi/pipa"
test -f device/xiaomi/pipa/prebuilt/kernel && echo "ok   prebuilt kernel" || echo "MISS prebuilt kernel"

echo
echo "### Tree size"
du -sh "$ROOT" 2>/dev/null | awk '{print "total  " $1}'
df -h / | awk 'NR==2 {print "free   " $4}'

echo
echo "### Done. Next:"
echo "  cd $ROOT"
echo "  source build/envsetup.sh"
echo "  lunch twrp_pipa-bp2a-eng"
echo "  mka adbd recoveryimage"
