#
# AERA Recovery Project build configuration for Xiaomi Pad 6 (pipa)
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# These are build-time exports, as opposed to the make-time configuration in
# aera_pipa.mk. Sourced by build/envsetup.sh.
#
FDEVICE="pipa"

aera_get_target_device() {
local chkdev=$(echo "$BASH_SOURCE" | grep -w $FDEVICE)
   if [ -n "$chkdev" ]; then
      AERA_BUILD_DEVICE="$FDEVICE"
   else
      chkdev=$(set | grep BASH_ARGV | grep -w $FDEVICE)
      [ -n "$chkdev" ] && AERA_BUILD_DEVICE="$FDEVICE"
   fi
}

if [ -z "$1" -a -z "$AERA_BUILD_DEVICE" ]; then
   aera_get_target_device
fi

if [ "$1" = "$FDEVICE" -o "$AERA_BUILD_DEVICE" = "$FDEVICE" ]; then
	export LC_ALL="C"

	# pipa is A/B, and Virtual A/B specifically: only one slot has logical
	# partitions in super (verified with lpdump -- there is no system_a), and
	# ro.virtual_ab.enabled=true.
	export AERA_AB_DEVICE=1
	export AERA_VIRTUAL_AB_DEVICE=1

	# Bundled binaries
	export AERA_USE_TAR_BINARY=1
	export AERA_USE_SED_BINARY=1
	export AERA_USE_LZ4_BINARY=1
	export AERA_USE_ZSTD_BINARY=1
	export AERA_USE_DATE_BINARY=1
	export AERA_USE_GREP_BINARY=1
	export AERA_USE_BUSYBOX_BINARY=1
	export AERA_USE_XZ_UTILS=1
	export AERA_USE_FSCK_EROFS_BINARY=1
	export AERA_USE_PATCHELF_BINARY=1

	export AERA_DELETE_AROMAFM=1
	export AERA_VANILLA_BUILD=1
	export AERA_PRODUCT_PREFIX=AERA
	export AERA_BUILD_STATUS=Unofficial
	export AERA_BUILD_TYPE=Beta

	# pipa has a 192 MiB boot partition, so there is room for the installer
	# ZIP and magiskboot-based repacking.
	export AERA_USE_UPDATED_MAGISKBOOT=1
	export AERA_USE_DMSETUP=1
	export AERA_ENABLE_ROOT_MANAGER=1

	export AERA_SETTINGS_ROOT_DIRECTORY=/data/recovery
	export AERA_MISCELLANEOUS_ROOT_DIRECTORY=/sdcard
	export AERA_ALLOW_EARLY_SETTINGS_LOAD=1

	# Xiaomi Pad 6 marketing/model names. pipain is the Indian variant.
	export TARGET_DEVICE_ALT="pipa,pipain,23043RP34G,23043RP34C,23043RP34I"
	export AERA_TARGET_DEVICES="$TARGET_DEVICE_ALT"

	# This is a fresh bring-up at AERA R1.0; no legacy maintainer patch suffix.
	unset AERA_MAINTAINER_PATCH_VERSION
fi
#
