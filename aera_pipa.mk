#
# AERA Recovery Project configuration for Xiaomi Pad 6 (pipa)
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# AERA device trees configure the recovery through AERA_* names only.
# bootable/recovery/aera_config.mk translates these to the backend's internal
# flags, so never set TW_*/OF_* here -- the translation layer owns those.
#
# Inherited from device.mk.
#

# --- Maintainer / build identity -------------------------------------------
AERA_MAINTAINER := koobie777
AERA_DEVICE_VERSION := Xiaomi_Pad_6

# --- Display ----------------------------------------------------------------
# pipa is 1800x2880 at density 400, driven in recovery with ROTATION_RIGHT.
# STATUS_H is scaled from the reference tree (120 at 2376) and is a starting
# point -- tune it on-device if the status bar sits wrong.
AERA_SCREEN_H := 2880
AERA_STATUS_H := 145
AERA_STATUS_INDENT_LEFT := 30
AERA_STATUS_INDENT_RIGHT := 30
AERA_STATUS_ICONS_ALIGN := center
# No notch or cutout on this panel.
AERA_HIDE_NOTCH := 0
AERA_OPTIONS_LIST_NUM := 6
# This panel has no notification LED.
AERA_USE_GREEN_LED := 0

# --- Partition / filesystem behaviour ---------------------------------------
AERA_ENABLE_ALL_PARTITION_TOOLS := 1
AERA_WORKAROUND_BACKUP_BUG := 1
# /data on pipa is f2fs under metadata encryption (dm-default-key).
AERA_FORCE_DATA_FORMAT_F2FS := 1
AERA_UNBIND_SDCARD_F2FS := 1
AERA_WIPE_METADATA_AFTER_DATAFORMAT := 1
# BOARD_QTI_DYNAMIC_PARTITIONS_SIZE for pipa's 8.5 GiB super.
AERA_DYNAMIC_FULL_SIZE := 9124708352
AERA_DISPLAY_FORMAT_FILESYSTEMS_DEBUG_INFO := 1

# --- Boot control -----------------------------------------------------------
# device.mk builds the HIDL passthrough impl (android.hardware.boot@1.1-impl-qti
# .recovery + bootctrl.kona.recovery), which is the configuration verified on
# this device. Do not switch this on without also moving device.mk to the AIDL
# packages -- the vendor does ship android.hardware.boot-service.qti, but
# recovery here uses the passthrough path, not the vendor service.
AERA_USE_AIDL_BOOT_CONTROL := 0
# The kernel and dtb are prebuilts in this tree; nothing is compiled.
AERA_FORCE_PREBUILT_KERNEL := 1
# pipa is recovery-as-boot: there is no separate `recovery` partition, so the
# AB-device-with-recovery-partition path must stay off.
AERA_AB_DEVICE_WITH_RECOVERY_PARTITION := 0

# --- Decryption -------------------------------------------------------------
AERA_NO_RELOAD_AFTER_DECRYPTION := 1
AERA_NO_TREBLE_COMPATIBILITY_CHECK := 1

# --- Misc -------------------------------------------------------------------
AERA_ENABLE_FRP_ADDON := 1
AERA_USE_LZ4_COMPRESSION := 1
# WLAN needs the vendor touch/wifi modules loaded in recovery; left off until
# AERA_LOAD_VENDOR_MODULES is populated and verified on this device.
AERA_ENABLE_WLAN := 0
