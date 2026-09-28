#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Compare two DTBs property by property (raw bytes, no decompiling).

usage: fdtcmp.py old.dtb new.dtb
Prints ADDED / REMOVED / CHANGED with the node path and the first bytes.
Exit status 0 always; empty output means identical trees.
"""
import struct
import sys


def parse(path):
    b = open(path, 'rb').read()
    (_, _, off_struct, off_strings, _, _, _, _,
     size_strings, _) = struct.unpack('>10I', b[:40])
    strings = b[off_strings:off_strings + size_strings]
    i, path_parts, props = off_struct, [], {}
    while True:
        token = struct.unpack('>I', b[i:i + 4])[0]
        i += 4
        if token == 1:                          # FDT_BEGIN_NODE
            end = b.index(b'\0', i)
            path_parts.append(b[i:end].decode())
            i = (end + 4) & ~3
        elif token == 2:                        # FDT_END_NODE
            path_parts.pop()
        elif token == 3:                        # FDT_PROP
            length, name_off = struct.unpack('>II', b[i:i + 8])
            i += 8
            name = strings[name_off:strings.index(b'\0', name_off)].decode()
            props['/'.join(path_parts) + ':' + name] = b[i:i + length]
            i = (i + length + 3) & ~3
        elif token == 4:                        # FDT_NOP
            continue
        elif token == 9:                        # FDT_END
            return props


a, b = parse(sys.argv[1]), parse(sys.argv[2])
for key in sorted(set(a) | set(b)):
    if a.get(key) != b.get(key):
        tag = 'ADDED' if key not in a else 'REMOVED' if key not in b else 'CHANGED'
        value = b[key] if key in b else a[key]
        print(tag, key or '/', value[:24].hex(' '))
