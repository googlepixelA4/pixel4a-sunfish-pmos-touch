#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Build the sunfish DTB from U-Boot's own device tree plus the fragments.
#
# usage: dts/build.sh path/to/u-boot-sm7150-google-sunfish.img [OUTDIR]
# needs: python3, dtc (package device-tree-compiler)
#
# Output: OUTDIR/sm7150-google-sunfish-pmos.dtb and a property-level diff
# against U-Boot's tree (OUTDIR/diff-vs-uboot.txt).

set -eu

IMG=${1:?usage: $0 u-boot-sm7150-google-sunfish.img [OUTDIR]}
OUT=${2:-out}
HERE=$(cd "$(dirname "$0")" && pwd)

# Tested U-Boot image (sm7150-mainline/u-boot release 2025-12-02) and result.
UBOOT_SHA256=bc5ad12ae235aaf9150c86b7981c0ee495520483529412548e0c5b7cd26859b9
DTB_SHA256=c397d5cc7edd2e02613b1b86cb107e40918522e2c4b4413d94c5931081576fb5

mkdir -p "$OUT"
cp "$HERE"/0*.dts "$HERE"/sunfish-pmos.dts "$OUT"/

if [ "$(sha256sum "$IMG" | cut -d' ' -f1)" != "$UBOOT_SHA256" ]; then
	echo "WARNING: U-Boot image differs from the tested one; review the result." >&2
fi

python3 "$HERE"/extract-uboot-dtb.py "$IMG" "$OUT"/uboot.dtb
dtc -q -I dtb -O dts -s -o "$OUT"/uboot.dts "$OUT"/uboot.dtb
(cd "$OUT" && dtc -q -I dts -O dtb -o sm7150-google-sunfish-pmos.dtb sunfish-pmos.dts)

python3 "$HERE"/fdtcmp.py "$OUT"/uboot.dtb "$OUT"/sm7150-google-sunfish-pmos.dtb \
	> "$OUT"/diff-vs-uboot.txt

sum=$(sha256sum "$OUT"/sm7150-google-sunfish-pmos.dtb | cut -d' ' -f1)
echo "built $OUT/sm7150-google-sunfish-pmos.dtb"
echo "sha256 $sum"
if [ "$sum" = "$DTB_SHA256" ]; then
	echo "matches the tested DTB"
else
	echo "does NOT match the tested DTB ($DTB_SHA256); check $OUT/diff-vs-uboot.txt" >&2
fi
