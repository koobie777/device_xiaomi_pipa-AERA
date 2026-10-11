#!/usr/bin/env python3
"""Synthetic regression checks; never requires or writes a device image."""

import contextlib
import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location(
    "make_fbboot_image", Path(__file__).with_name("make_fbboot_image.py"))
FBBOOT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FBBOOT)

PAGE_SIZE = 4096
KERNEL = bytes(range(256)) * 24 + b"kernel-tail"
RAMDISK = bytes(reversed(range(256))) * 35 + b"ramdisk-tail"
SIGNATURE = b"signature" * 64


def padded(payload):
    return payload + b"\xa5" * (-len(payload) % PAGE_SIZE)


def boot_image(version, cmdline=b"", signature=SIGNATURE):
    header = bytearray(PAGE_SIZE)
    header[:8] = FBBOOT.MAGIC
    struct.pack_into("<4I", header, 8, len(KERNEL), len(RAMDISK),
                     0x12345678, 1580 if version == 3 else 1584)
    header[0x18:0x28] = b"reserved-bytes!!"
    struct.pack_into("<I", header, 0x28, version)
    header[FBBOOT.CMDLINE_OFFSET:FBBOOT.CMDLINE_OFFSET + len(cmdline)] = cmdline
    if version == 4:
        struct.pack_into("<I", header, 1580, len(signature))
    return (bytes(header) + padded(KERNEL) + padded(RAMDISK)
            + (padded(signature) if version == 4 else b""))


class FbbootImageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.src = Path(self.temporary.name) / "boot.img"
        self.dst = Path(self.temporary.name) / "boot-fbboot.img"

    def patch(self, original):
        self.src.write_bytes(original)
        with contextlib.redirect_stdout(io.StringIO()):
            FBBOOT.patch(str(self.src), str(self.dst))
        self.assertEqual(self.src.read_bytes(), original)
        return self.dst.read_bytes()

    def reject(self, original, message):
        self.src.write_bytes(original)
        self.dst.unlink(missing_ok=True)
        with self.assertRaisesRegex(SystemExit, message):
            with contextlib.redirect_stdout(io.StringIO()):
                FBBOOT.patch(str(self.src), str(self.dst))
        self.assertEqual(self.src.read_bytes(), original)
        self.assertFalse(self.dst.exists())

    def assert_preserved(self, original, modified):
        start = FBBOOT.CMDLINE_OFFSET
        end = start + FBBOOT.CMDLINE_SIZE
        self.assertEqual(len(modified), len(original))
        self.assertEqual(modified[:start], original[:start])
        self.assertEqual(modified[end:], original[end:])
        kernel_start = PAGE_SIZE
        ramdisk_start = PAGE_SIZE + len(padded(KERNEL))
        self.assertEqual(modified[kernel_start:kernel_start + len(KERNEL)], KERNEL)
        self.assertEqual(modified[ramdisk_start:ramdisk_start + len(RAMDISK)], RAMDISK)

    def test_v3_v4_short_and_long_cmdlines_preserve_payload(self):
        for version in (3, 4):
            for cmdline in (b"", b"console=ttyMSM0 androidboot.hardware=qcom",
                            b"x=" + b"x" * 1022,
                            b"x" * (FBBOOT.CMDLINE_SIZE - len(FBBOOT.FLAG) - 2)):
                with self.subTest(version=version, cmdline_length=len(cmdline)):
                    original = boot_image(version, cmdline)
                    modified = self.patch(original)
                    self.assert_preserved(original, modified)
                    expected = FBBOOT.FLAG + (b" " + cmdline if cmdline else b"")
                    field = modified[FBBOOT.CMDLINE_OFFSET:
                                     FBBOOT.CMDLINE_OFFSET + FBBOOT.CMDLINE_SIZE]
                    self.assertEqual(field, expected + b"\0" *
                                     (FBBOOT.CMDLINE_SIZE - len(expected)))

    def test_idempotent(self):
        for version in (3, 4):
            with self.subTest(version=version):
                modified = self.patch(boot_image(version, b"x=" + b"x" * 1000))
                self.assertEqual(self.patch(modified), modified)

    def test_existing_flag_preserves_full_size_cmdline(self):
        cmdline = FBBOOT.FLAG + b" " + b"x" * (1535 - len(FBBOOT.FLAG) - 1)
        for version in (3, 4):
            with self.subTest(version=version):
                original = boot_image(version, cmdline)
                self.assertEqual(self.patch(original), original)

    def test_partial_flag_is_not_an_existing_token(self):
        cmdline = b"twrpfastboot=10 other=twrpfastboot=1"
        modified = self.patch(boot_image(4, cmdline))
        field = modified[44:1580].split(b"\0", 1)[0]
        self.assertEqual(field, FBBOOT.FLAG + b" " + cmdline)

    def test_overflow_rejected_without_writing_output(self):
        for version in (3, 4):
            for length in (1535 - len(FBBOOT.FLAG), 1535, 1536):
                with self.subTest(version=version, length=length):
                    self.reject(boot_image(version, b"x" * length), "would not fit")

    def test_invalid_magic(self):
        image = bytearray(boot_image(3))
        image[:8] = b"INVALID!"
        self.reject(bytes(image), "not an Android boot image")

    def test_unsupported_header_versions(self):
        for version in (0, 1, 2, 5, 0xFFFFFFFF):
            with self.subTest(version=version):
                image = bytearray(boot_image(3))
                struct.pack_into("<I", image, 0x28, version)
                self.reject(bytes(image), "only boot header v3/v4")

    def test_incorrect_header_sizes(self):
        for version in (3, 4):
            for header_size in (0, 44, 1579, 1580 if version == 4 else 1584, 4096):
                with self.subTest(version=version, header_size=header_size):
                    image = bytearray(boot_image(version))
                    struct.pack_into("<I", image, 0x14, header_size)
                    self.reject(bytes(image), "invalid boot header size")

    def test_truncated_headers(self):
        for version in (3, 4):
            lengths = (0, 7, 43, 1579) + ((1583,) if version == 4 else ())
            for length in lengths:
                with self.subTest(version=version, length=length):
                    self.reject(boot_image(version)[:length],
                                "not an Android boot image|invalid boot header size")

    def test_truncated_kernel_or_ramdisk_rejected(self):
        for version in (3, 4):
            ramdisk_start = PAGE_SIZE + len(padded(KERNEL))
            payload_end = ramdisk_start + len(padded(RAMDISK))
            for length in (1580 if version == 3 else 1584, PAGE_SIZE,
                           PAGE_SIZE + len(KERNEL) - 1,
                           ramdisk_start + len(RAMDISK) - 1, payload_end - 1):
                with self.subTest(version=version, length=length):
                    self.reject(boot_image(version)[:length], "truncated|incomplete|too short")

    def test_v4_without_signature(self):
        original = boot_image(4, b"console=ttyMSM0", signature=b"")
        self.assert_preserved(original, self.patch(original))

    def test_truncated_v4_signature_rejected(self):
        payload_end = PAGE_SIZE + len(padded(KERNEL)) + len(padded(RAMDISK))
        for signature in (SIGNATURE, b"x" * PAGE_SIZE, b"x" * (PAGE_SIZE + 1)):
            image = boot_image(4, signature=signature)
            for length in (payload_end, payload_end + len(signature) - 1,
                           len(image) - 1):
                with self.subTest(signature_length=len(signature), length=length):
                    self.reject(image[:length], "truncated|incomplete|too short")


if __name__ == "__main__":
    unittest.main()
