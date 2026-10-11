#!/usr/bin/env bash
# Build AERA Recovery for pipa.
#
# Logs everything to build.log, then surfaces the parts that matter, because a
# failing Soong/ninja run buries the real cause under thousands of lines.
#
# Usage:
#   bash build-aera.sh              # lunch + mka adbd bootimage
#
# No `set -u` anywhere in this script: envsetup.sh and the lunch/mka functions
# it defines read unset variables freely (e.g. BUILD_VAR_CACHE_READY at
# envsetup.sh:117), so nounset makes lunch fail instantly. Defaults are given
# explicitly below instead.
set -o pipefail

ROOT="$HOME/android/AERA_16.0"
LUNCH="${LUNCH:-twrp_pipa-bp2a-eng}"
TARGET="${TARGET:-bootimage}"
LOG="$ROOT/build.log"

cd "$ROOT" || { echo "FATAL: $ROOT missing -- run sync-aera.sh first"; exit 1; }

# The lunch string is product-release-variant (e.g. twrp_pipa-bp2a-eng).
# Product names use underscores, so splitting on '-' is unambiguous.
#
# Pin all three explicitly rather than trusting them to survive. If they are
# missing when mka re-runs dumpvars, the failures are silent and misleading:
#   - no TARGET_RELEASE -> falls back to trunk_staging, which this manifest
#     does not ship, and release-config panics with "Missing config
#     trunk_staging"
#   - no TARGET_PRODUCT -> falls back to aosp_arm64 and happily builds the
#     WRONG PRODUCT, generating out/soong/build.aosp_arm64.ninja with no error
#     at all. Check the ninja filename if a build looks suspiciously generic.
case "$LUNCH" in
    *-*-*)
        export TARGET_PRODUCT="${LUNCH%%-*}"
        _rest="${LUNCH#*-}"
        export TARGET_RELEASE="${_rest%-*}"
        export TARGET_BUILD_VARIANT="${_rest##*-}"
        ;;
    *)
        echo "FATAL: LUNCH must be product-release-variant, got '$LUNCH'"
        exit 1
        ;;
esac

if [ ! -f device/xiaomi/pipa/aera_pipa.mk ]; then
    echo "FATAL: device/xiaomi/pipa not in place -- sync-aera.sh did not finish"
    exit 1
fi

# Soong spawns a lot of file-watching and parallel jobs.
ulimit -n 65536 2>/dev/null || true
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export LC_ALL=C
# Android's sandbox mounts the source tree and home read-only. Cache and
# temporary files must live under out/, which is explicitly writable.
export CCACHE_DIR="$ROOT/out/.ccache"
export CCACHE_TEMPDIR="$CCACHE_DIR/tmp"
export TMPDIR="$ROOT/out/.tmp"
mkdir -p "$TMPDIR" "$CCACHE_TEMPDIR"
"$CCACHE_EXEC" --max-size=50G >/dev/null
# Persist the temp path too: ninja filters environment variables, while
# ccache always reads the config inside CCACHE_DIR.
"$CCACHE_EXEC" --set-config="temporary_dir=$CCACHE_TEMPDIR"

echo "### Environment"
echo "  root    $ROOT"
echo "  lunch   $LUNCH"
echo "  product $TARGET_PRODUCT"
echo "  release $TARGET_RELEASE"
echo "  variant $TARGET_BUILD_VARIANT"
echo "  target  $TARGET"
echo "  cores   $(nproc)"
echo "  log     $LOG"
echo

# shellcheck disable=SC1091
source build/envsetup.sh >/dev/null 2>&1

echo "### lunch $LUNCH"
# Do NOT pipe lunch. It is a shell function, so `lunch ... | tee` runs it in a
# subshell and every variable it exports -- TARGET_PRODUCT, TARGET_RELEASE,
# TARGET_BUILD_VARIANT -- is discarded when that subshell exits. mka then
# re-runs dumpvars with nothing set and AOSP falls back to the trunk_staging
# release config (release_config.mk:267), which this manifest does not ship,
# so release-config panics with "Missing config trunk_staging".
#
# Redirect to a file instead, which keeps lunch in this shell. (tail -25 on a
# pipe also withheld all output until lunch finished, making a slow first
# dumpvars look like a hang.)
if ! lunch "$LUNCH" >"$LOG" 2>&1; then
    echo
    echo "### lunch FAILED"
    tail -30 "$LOG"
    echo
    echo "### available choices:"
    grep -A20 'COMMON_LUNCH_CHOICES' device/xiaomi/pipa/AndroidProducts.mk 2>/dev/null || true
    exit 1
fi
tail -22 "$LOG"
echo "  TARGET_PRODUCT=${TARGET_PRODUCT:-<unset>} TARGET_RELEASE=${TARGET_RELEASE:-<unset>} TARGET_BUILD_VARIANT=${TARGET_BUILD_VARIANT:-<unset>}"

if [ "${TARGET_PRODUCT:-}" != "twrp_pipa" ]; then
    echo "FATAL: TARGET_PRODUCT is '${TARGET_PRODUCT:-<unset>}', expected twrp_pipa."
    echo "       lunch did not take effect -- refusing to build the wrong product."
    exit 1
fi

echo
echo "### Building: mka adbd $TARGET"
date
# mka is a function from envsetup.sh, so it must run in this shell.
mka adbd "$TARGET" 2>&1 | tee -a "$LOG"
rc=${PIPESTATUS[0]}
date

echo
if [ "$rc" -eq 0 ]; then
    echo "### BUILD OK"
    ls -lh out/target/product/pipa/*.img 2>/dev/null || echo "(no .img found -- check the log)"
    echo
    echo "Create the temporary-boot image, then test it WITHOUT flashing:"
    echo "  python3 device/xiaomi/pipa/tools/make_fbboot_image.py"
    echo "  fastboot boot out/target/product/pipa/boot-fbboot.img"
    echo
    echo "WARNING: slot a currently holds EndeavourOS. Never flash recovery to"
    echo "boot_a. Target boot_b only, and only after fastboot boot works."
else
    echo "### BUILD FAILED (exit $rc)"
    echo
    echo "--- first 40 error/failure lines ---"
    grep -nE '(^| )(FAILED|error:|Error:|ERROR:|fatal error|ninja: build stopped|No rule to make target|cannot find|unknown target)' \
        "$LOG" | head -40
    echo
    echo "--- last 60 lines of the log ---"
    tail -60 "$LOG"
    echo
    echo "Full log: $LOG"
fi
exit "$rc"
