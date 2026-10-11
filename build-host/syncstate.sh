#!/usr/bin/env bash
# Is the sync genuinely alive? The progress line is rewritten with carriage
# returns so it never flushes as new lines and always looks frozen.
ROOT="$HOME/android/AERA_16.0"
CLANG="$ROOT/.repo/projects/prebuilts/clang/host/linux-x86.git/objects/pack"

echo "=== any repo / git / fetch processes ==="
ps -eo pid,etime,cmd --no-headers | grep -E 'repo|git' | grep -v 'grep' | head -12 \
    || echo "  none"

echo
echo "=== clang temp pack (the one remaining project) ==="
ls -la "$CLANG" 2>/dev/null | tail -4 || echo "  no pack dir"

echo
echo "=== pack size, sampled twice 20s apart ==="
a=$(du -sb "$CLANG" 2>/dev/null | cut -f1); echo "  t0: ${a:-0} bytes"
sleep 20
b=$(du -sb "$CLANG" 2>/dev/null | cut -f1); echo "  t1: ${b:-0} bytes"
if [ -n "${a:-}" ] && [ -n "${b:-}" ] && [ "$b" -gt "$a" ]; then
    echo "  GROWING (+$(( (b - a) / 1024 / 1024 )) MiB in 20s) -- still downloading"
else
    echo "  NOT GROWING -- fetch is stalled or finished"
fi

echo
echo "=== device tree marker ==="
[ -f "$ROOT/device/xiaomi/pipa/aera_pipa.mk" ] && echo "  PLACED" || echo "  not placed"

echo
echo "=== project count checked out ==="
ls -d "$ROOT"/.repo/projects/*/ 2>/dev/null | wc -l | awk '{print "  " $1 " project dirs"}'
du -sh "$ROOT" 2>/dev/null | awk '{print "  tree " $1}'
