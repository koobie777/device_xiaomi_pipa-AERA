# AERA Recovery — Xiaomi Pad 6 (pipa)

AERA Recovery Project device tree for the Xiaomi Pad 6, codename `pipa`
(SM8250 / Snapdragon 870, Adreno 650).

**Status: untested bring-up.** This tree has not been built or booted yet. Boot
it with `fastboot boot` before flashing anything.

## Build

```bash
mkdir -p ~/android/AERA_16.0 && cd ~/android/AERA_16.0
repo init -u https://github.com/AERA-Recovery/android_manifest.git -b aera-16.0
repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc)

git clone -b aera-16.0 \
    https://github.com/koobie777/device_xiaomi_pipa-AERA.git \
    device/xiaomi/pipa

source build/envsetup.sh
lunch twrp_pipa-bp2a-eng
mka adbd recoveryimage
```

Output lands in `out/target/product/pipa/`.

The manifest README says AERA's projects are in a private org requiring an SSH
key. That is **stale** — the repos are public and the HTTPS clone above works
anonymously.

## Where this came from

Derived from [`mengguizzz/twrp_device_xiaomi_pipa`](https://github.com/mengguizzz/twrp_device_xiaomi_pipa),
a real TWRP 16.0 pipa tree, rather than from the existing
`device_xiaomi_pipa-AERA` repo — that one is an OrangeFox tree with an
`aera_pipa.mk` written as a *product* makefile (`PRODUCT_NAME := aera_pipa`),
which is not how AERA trees work. In AERA, `aera_<device>.mk` holds `AERA_*`
configuration and is inherited from `device.mk`; the product makefile stays
`twrp_<device>.mk`.

## What changed from the TWRP base

**Configuration moved to the `AERA_*` namespace.** AERA device trees set
`AERA_*` only; `bootable/recovery/aera_config.mk` translates those to the
backend's internal `TW_*`/`OF_*` flags. Setting the internal names directly
bypasses that layer. AOSP `BOARD_*`/`TARGET_*`/`PRODUCT_*` variables keep their
upstream names.

**Added** `aera_pipa.mk` (theme geometry, partition behaviour, decryption),
`vendorsetup.sh` AERA exports, the `recovery-ui2.enabled` marker for AERA's
native UI, and the `device.mk` inherit.

**Dropped the ColorOS 17 property rewrite.** The base tree rewrote
`ro.build.version.release` to `17` and the security patches to `2026-09-01`,
because it targeted a ported ColorOS 17 (Android 17) ROM. Keymaster stores
`os_version`/`os_patchlevel` in the key blobs it creates, so a recovery
claiming the wrong Android version gets `KEY_REQUIRES_UPGRADE` back from the TA
and **cannot decrypt `/data`**. This tree targets Android 16 ROMs such as
LineageOS 23, which a recovery built from the `aera-16.0` manifest already
reports correctly. The `twrp.drm.direct_scanout=0` override is kept — that one
is a real performance fix on this panel (~4 fps without it), unrelated to
ColorOS.

**Boot control left on HIDL.** `AERA_USE_AIDL_BOOT_CONTROL := 0`, because
`device.mk` builds the HIDL passthrough impl
(`android.hardware.boot@1.1-impl-qti.recovery`, `bootctrl.kona.recovery`),
which is the verified configuration. The vendor does ship
`android.hardware.boot-service.qti`, but recovery uses the passthrough path.
Switching this on requires moving `device.mk` to the AIDL packages too.

**Omitted dodge's AERA extras.** The reference OnePlus 13 tree carries
`aera-audio-bridge`, `aera-audio-service`, an Adreno `egl_probe` and a
`security/` OTA directory. Those are device-specific; recovery does not need
them to boot, decrypt or flash. Add pipa equivalents later if audio in recovery
is wanted.

## Device values verified on hardware

Read off the device with `fastboot getvar` and `sgdisk`, not copied:

| | |
|---|---|
| Platform | `kona` (SM8250), Adreno 650 |
| `boot_a`/`boot_b` | 192 MiB (`0xC000000`) |
| `super` | 8.5 GiB (`0x220000000`) |
| `/data` | f2fs under metadata encryption (dm-default-key) |
| A/B | **Virtual A/B** — `lpdump` shows only `_b` logical partitions; no `system_a` |
| Recovery | recovery-as-boot; there is no separate `recovery` partition |

## Known uncertainties

- `AERA_STATUS_H := 145` is scaled from the reference tree (120 at 2376 px) and
  needs tuning on-device.
- `AERA_ENABLE_WLAN := 0` until `AERA_LOAD_VENDOR_MODULES` is populated with
  pipa's touch/wifi modules and verified.
- Repack tools / resetprop are disabled: the upstream Magisk prebuilt's legacy
  `Android.mk` is rejected by the A16 Soong scanner.
- `AERA_FRAMERATE := 120` follows the base tree, though the panel is 144 Hz.
