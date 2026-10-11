#!/usr/bin/env bash
# Build AERA Recovery for pipa.
#
# Logs everything to build.log, then surfaces the parts that matter, because a
# failing Soong/ninja run buries the real cause under thousands of lines.
#
# Usage:
#   bash build-aera.sh              # lunch + mka adbd recoveryimage
#   TARGET=bootimage bash build-aera.sh
set -uo pipefail

ROOT="$HOME/android/AERA_16.0"
LUNCH="${LUNCH:-twrp_pipa-bp2a-eng}"
TARGET="${TARGET:-recoveryimage}"
LOG="$ROOT/build.log"

cd "$ROOT" || { echo "FATAL: $ROOT missing -- run sync-aera.sh first"; exit 1; }

if [ ! -f device/xiaomi/pipa/aera_pipa.mk ]; then
    echo "FATAL: device/xiaomi/pipa not in place -- sync-aera.sh did not finish"
    exit 1
fi

# Soong spawns a lot of file-watching and parallel jobs.
ulimit -n 65536 2>/dev/null || true
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export LC_ALL=C
# Keep the build off the Windows filesystem entirely.
export TMPDIR="$ROOT/.tmp"
mkdir -p "$TMPDIR"

echo "### Environment"
echo "  root    $ROOT"
echo "  lunch   $LUNCH"
echo "  target  $TARGET"
echo "  cores   $(nproc)"
echo "  log     $LOG"
echo

set +u   # envsetup.sh references unset vars
# shellcheck disable=SC1091
source build/envsetup.sh >/dev/null 2>&1
set -u

echo "### lunch $LUNCH"
if ! lunch "$LUNCH" 2>&1 | tee "$LOG" | tail -25; then
    echo
    echo "### lunch FAILED -- available choices:"
    grep -A20 'COMMON_LUNCH_CHOICES' device/xiaomi/pipa/AndroidProducts.mk 2>/dev/null || true
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
    echo "Test it WITHOUT flashing:"
    echo "  fastboot boot out/target/product/pipa/recovery.img"
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
