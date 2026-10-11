#!/usr/bin/env bash
# Cross-check our pipa device tree against the AERA sources that actually
# synced, to catch mistakes before burning a build.
ROOT="$HOME/android/AERA_16.0"
cd "$ROOT" 2>/dev/null || { echo "no tree"; exit 1; }

echo "=== 1. Soong plugin names AERA actually registers ==="
# BoardConfig sets BUILD_BROKEN_PLUGIN_VALIDATION with a hardcoded list. If
# AERA's plugin names differ from the ones inherited from the OrangeFox tree,
# the build fails on plugin validation.
grep -rhoE 'pluginFor\("[^"]+"\)|RegisterModuleType|soong-[a-z0-9_]+' \
    bootable/recovery/*.go bootable/recovery/**/*.go 2>/dev/null | sort -u | head -20 \
    || echo "  (no .go files found at that depth)"
echo "  --- names referenced in build/soong allow-list ---"
grep -rn 'BUILD_BROKEN_PLUGIN_VALIDATION' build/make/core/*.mk 2>/dev/null | head -3

echo
echo "=== 2. Which AERA_* names does aera_config.mk know? ==="
# Any AERA_* we set that is NOT in this list is silently ignored.
grep -oE 'aera-map-config,[A-Z0-9_]+' bootable/recovery/aera_config.mk 2>/dev/null \
    | sed 's/aera-map-config,/AERA_/' | sort -u > /tmp/aera_known.txt
grep -oE '^\s*(ALLOW_EARLY_SETTINGS_LOAD|[A-Z0-9_]+) \\$' bootable/recovery/aera_config.mk 2>/dev/null \
    | tr -d ' \\' | sed 's/^/AERA_/' | sort -u >> /tmp/aera_known.txt
sort -u /tmp/aera_known.txt -o /tmp/aera_known.txt
echo "  aera_config.mk knows $(wc -l < /tmp/aera_known.txt) AERA_* names"

echo
echo "=== 3. AERA_* we set that aera_config.mk does NOT map ==="
if [ -d device/xiaomi/pipa ]; then
    grep -rhoE '^\s*(export )?AERA_[A-Z0-9_]+' device/xiaomi/pipa/*.mk device/xiaomi/pipa/*.sh 2>/dev/null \
        | sed 's/^[[:space:]]*//;s/^export //' | sort -u > /tmp/aera_ours.txt
    echo "  we set $(wc -l < /tmp/aera_ours.txt) AERA_* names"
    echo "  --- not found in aera_config.mk (may be soong-only or build-time, verify) ---"
    comm -23 /tmp/aera_ours.txt /tmp/aera_known.txt | sed 's/^/    /'
else
    echo "  device tree not placed yet -- rerun after sync"
fi

echo
echo "=== 4. Soong-only AERA vars (from vendor/recovery) ==="
grep -oE 'AERA_[A-Z0-9_]+' vendor/recovery/aera_soong_config.mk 2>/dev/null | sort -u | sed 's/^/    /'

echo
echo "=== 5. Does the lunch product resolve? ==="
if [ -f device/xiaomi/pipa/AndroidProducts.mk ]; then
    grep -E 'twrp_pipa|PRODUCT_MAKEFILES' device/xiaomi/pipa/AndroidProducts.mk | sed 's/^/    /'
else
    echo "  device tree not placed yet"
fi
