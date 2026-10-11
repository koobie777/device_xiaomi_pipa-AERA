#
# Copyright (C) 2023 The Android Open Source Project
# Copyright (C) 2023 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#
# AERA Recovery Project device tree for Xiaomi Pad 6 (pipa)
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Recovery configuration uses AERA_* names exclusively; see aera_pipa.mk and
# bootable/recovery/aera_config.mk. AOSP/BOARD/TARGET variables keep their
# upstream names.
#

DEVICE_PATH := device/xiaomi/pipa

# For building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# The recovery backend registers these local Soong plugins outside the
# framework allow-list.
BUILD_BROKEN_PLUGIN_VALIDATION := soong-libaosprecovery_defaults soong-libguitwrp_defaults soong-libminuitwrp_defaults soong-vold_defaults

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := kryo300

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a75

# Power
ENABLE_CPUSETS := true
ENABLE_SCHEDBOOST := true

# Bootloader
PRODUCT_PLATFORM := kona
TARGET_BOOTLOADER_BOARD_NAME := kona
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := true

# Platform - SM8250 (Snapdragon 870), Adreno 650
TARGET_BOARD_PLATFORM := kona
TARGET_BOARD_PLATFORM_GPU := qcom-adreno650
QCOM_BOARD_PLATFORMS += kona

# Kernel
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 3
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)

# Kernel - prebuilt
TARGET_FORCE_PREBUILT_KERNEL := true
ifeq ($(TARGET_FORCE_PREBUILT_KERNEL),true)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
endif

# Kernel dtb
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb

# A/B
BOARD_USES_RECOVERY_AS_BOOT := true
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    odm \
    product \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_boot

# Assert
TARGET_OTA_ASSERT_DEVICE := pipa

# AVB
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# Partitions
# pipa uses a 192 MiB boot partition (verified on device:
# fastboot getvar partition-size:boot_a -> 0xC000000). 128 MiB causes modern
# ramdisks to be rejected or truncated during image creation.
BOARD_BOOTIMAGE_PARTITION_SIZE := 201326592
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296

# Dynamic Partition - super is 8.5 GiB (verified: 0x220000000)
BOARD_SUPER_PARTITION_SIZE := 9126805504
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
# BOARD_QTI_DYNAMIC_PARTITIONS_SIZE = BOARD_SUPER_PARTITION_SIZE - 2MB
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 9124708352
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := system product odm system_ext vendor

# System-as-root is the Android 14+ default. Do not set the removed legacy
# BOARD_BUILD_SYSTEM_ROOT_IMAGE flag: it is rejected.
BOARD_ROOT_EXTRA_FOLDERS := bluetooth dsp firmware persist
BOARD_SUPPRESS_SECURE_ERASE := true

# File systems
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SYSTEMIMAGE_PARTITION_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_COPY_OUT_VENDOR := vendor

# Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_DEFAULT_ROTATION := ROTATION_RIGHT
TARGET_RECOVERY_DEFAULT_TOUCH_ROTATION := ROTATION_RIGHT
TARGET_RECOVERY_QCOM_RTC_FIX := true
TARGET_USES_MKE2FS := true
RECOVERY_SDCARD_ON_DATA := true
BOARD_HAS_NO_REAL_SDCARD := true

# Display
TARGET_SCREEN_DENSITY := 400
TARGET_SCREEN_HEIGHT := 2880
TARGET_SCREEN_WIDTH := 1800

# Security patch is pinned far in the future so Keymaster never answers
# KEY_REQUIRES_UPGRADE for an existing key blob. PLATFORM_VERSION is supplied
# by the selected release config and must not be overridden here.
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# --- AERA: crypto -----------------------------------------------------------
AERA_INCLUDE_CRYPTO := true
AERA_INCLUDE_CRYPTO_FBE := true
AERA_INCLUDE_FBE_METADATA_DECRYPT := true
AERA_USE_FSCRYPT_POLICY := 2

# --- AERA: display ----------------------------------------------------------
AERA_THEME := portrait_hdpi
AERA_UI_ADAPTIVE_RESOLUTION := true
AERA_FRAMERATE := 120
AERA_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
AERA_MAX_BRIGHTNESS := 2047
AERA_DEFAULT_BRIGHTNESS := 200
AERA_NO_SCREEN_BLANK := true

# --- AERA: filesystem -------------------------------------------------------
AERA_INCLUDE_NTFS_3G := true

# --- AERA: tools ------------------------------------------------------------
AERA_INCLUDE_FASTBOOTD := true
AERA_INCLUDE_LPDUMP := true
AERA_INCLUDE_LPTOOLS := true
AERA_USE_TOOLBOX := true
# Repack tools pull in a Magisk prebuilt whose legacy Android.mk is rejected by
# the A16 Soong scanner. Not needed to boot recovery or decrypt data; enable
# once that prebuilt is fixed.
# AERA_INCLUDE_REPACKTOOLS := true
# AERA_INCLUDE_RESETPROP := true
# AERA_INCLUDE_LIBRESETPROP := true

# --- AERA: input / haptics --------------------------------------------------
AERA_INPUT_BLACKLIST := hbtp_vm
AERA_NO_HAPTICS := true

# --- AERA: other ------------------------------------------------------------
AERA_DEVICE_VERSION := 16.0
AERA_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone1/temp"
AERA_BATTERY_SYSFS_WAIT_SECONDS := 5
AERA_BACKUP_EXCLUSIONS := /data/adb/ap,/data/adb/ksu
AERA_EXCLUDE_APEX := true
AERA_EXCLUDE_DEFAULT_USB_INIT := true
AERA_EXTRA_LANGUAGES := true
AERA_DEFAULT_LANGUAGE := en
AERA_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true

# --- AERA: debug ------------------------------------------------------------
AERA_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true

# ---- recovery image property overrides -------------------------------------
# twrp.drm.direct_scanout=0
#   The DRM scanout buffer is write-combined and the gGL renderer does
#   read-modify-write alpha blending, so drawing straight into the scanout
#   buffer reads uncached memory for every blended pixel. Measured on this
#   panel while scrolling a file list: ~4 fps (~213 ms CPU per frame). With
#   direct scanout disabled recovery draws into a cached buffer and copies only
#   the damage into the scanout buffer (write-only).
#
# NOTE: the TWRP tree this was derived from also rewrote
# ro.build.version.release to 17 and the security patches to 2026-09-01, for a
# ported ColorOS 17 (Android 17) ROM. That is deliberately NOT carried over.
# Keymaster stores os_version/os_patchlevel in the key blobs it creates, so
# claiming the wrong Android version makes the TA answer KEY_REQUIRES_UPGRADE
# and /data cannot be decrypted. This tree targets Android 16 ROMs
# (e.g. LineageOS 23), which a recovery built from the aera-16.0 manifest
# already reports correctly. Re-add an override only to match a ROM that
# reports something different.
BOARD_RECOVERY_IMAGE_PREPARE = $(hide) sed -i \
    -e 's|^twrp.drm.direct_scanout=.*|twrp.drm.direct_scanout=0|' \
    $(TARGET_RECOVERY_ROOT_OUT)/prop.default; \
    grep -q '^twrp.drm.direct_scanout=' $(TARGET_RECOVERY_ROOT_OUT)/prop.default || echo 'twrp.drm.direct_scanout=0' >> $(TARGET_RECOVERY_ROOT_OUT)/prop.default

# ---------------------------------------------------------------------------
# Boot image cmdline: do NOT bake twrpfastboot=1 into the shipped image.
#
# This tree is built with BOARD_USES_RECOVERY_AS_BOOT := true, so the boot
# image is both the recovery ramdisk and the normal boot image. First-stage
# init hands off to the installed system when the bootloader passes
# androidboot.force_normal_boot=1 (every normal boot), so the flashed image
# still boots the ROM, and `adb reboot recovery` enters recovery.
#
# The cmdline flag twrpfastboot=1 disables that handoff. It is only wanted for
# a temporary image used with `fastboot boot` - baked into a flashed image the
# device would always start into recovery. Generate that variant with:
#
#     python3 device/xiaomi/pipa/tools/make_fbboot_image.py
#
# (BOARD_KERNEL_CMDLINE cannot be used here anyway: build/make/core/Makefile
# only appends --cmdline when BOARD_USES_RECOVERY_AS_BOOT is not true.)
