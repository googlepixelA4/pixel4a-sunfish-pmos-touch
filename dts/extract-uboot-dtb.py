#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Extract the device tree built into a U-Boot Android boot image.

usage: extract-uboot-dtb.py u-boot-sm7150-google-sunfish.img uboot.dtb

The image's "kernel" is a gzip-compressed U-Boot binary; its DTB is found
by the FDT magic (d00dfeed) in the image. Exactly one DTB is expected.
"""
import struct
import sys

img, out = sys.argv[1], sys.argv[2]
data = open(img, 'rb').read()
if data[:8] != b'ANDROID!':
    sys.exit('not an Android boot image')

found = []
i = 0
while (i := data.find(b'\xd0\x0d\xfe\xed', i)) != -1:
    size = struct.unpack('>I', data[i + 4:i + 8])[0]
    if 1000 < size < 2_000_000 and i + size <= len(data):
        found.append((i, size))
    i += 4

if len(found) != 1:
    sys.exit(f'expected one DTB, found {len(found)}: {found}')
off, size = found[0]
open(out, 'wb').write(data[off:off + size])
print(f'DTB at offset {off:#x}, {size} bytes -> {out}')
