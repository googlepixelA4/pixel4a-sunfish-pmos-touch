#!/bin/sh
# Collect the 14 kernel patches that aport/APKBUILD lists, under the exact
# file names it expects, into an output directory.
#
#   0001-0011  David Heidelberg / Petr Hodina: "Input: support for STM FTS5" v4
#              <20260409-stmfts5-v4-0-64fe62027db5@ixit.cz>   (fetched with b4)
#   0012       miromraz: poll for CONTROLLER_READY (pixel4a-stmfts5-mainline)
#   0013-0014  this repository (patches/kernel/)
#
# Usage: scripts/fetch-patches.sh OUTDIR
# Needs: b4, git, curl.  Offline: set FTS5_MBX=/path/to/v4.mbx (a b4 am mbox).
#
# The files are byte-for-byte what upstream publishes, so they will not match
# the sha512sums in aport/APKBUILD exactly; run
#   pmbootstrap checksum linux-postmarketos-qcom-sm7150
# after copying them into the aport.

set -eu

OUT=${1:?usage: $0 OUTDIR}
HERE=$(cd "$(dirname "$0")/.." && pwd)

FTS5_MSGID=20260409-stmfts5-v4-0-64fe62027db5@ixit.cz
MIROMRAZ_COMMIT=ec78eeecdc7cd0b462921d5cf1965eb8843a9f9c
MIROMRAZ_URL=https://raw.githubusercontent.com/miromraz/pixel4a-stmfts5-mainline/$MIROMRAZ_COMMIT/patches/0001-Input-stmfts-poll-for-CONTROLLER_READY-event-in-stmf.patch

# Names the APKBUILD expects for the v4 series, in series order (1/11..11/11).
FTS5_NAMES="
0001-Input-stmfts-Fix-the-MODULE_LICENSE-string.patch
0002-Input-stmfts-Use-dev-struct-directly.patch
0003-Input-stmfts-Switch-to-devm_regulator_bulk_get_const.patch
0004-Input-stmfts-abstract-reading-information-from-the-f.patch
0005-Input-stmfts-disable-regulators-when-power-on-fails.patch
0006-Input-stmfts-use-client-to-make-future-code-cleaner.patch
0007-dt-bindings-input-touchscreen-st-stmfts-Introduce-re.patch
0008-Input-stmfts-add-optional-reset-GPIO-support.patch
0009-dt-bindings-input-touchscreen-st-stmfts-Introduce-ST.patch
0010-Input-stmfts-support-FTS5.patch
0011-arm64-dts-qcom-sdm845-google-Add-STM-FTS-touchscreen.patch
"

mkdir -p "$OUT"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ -n "${FTS5_MBX:-}" ]; then
	cp "$FTS5_MBX" "$TMP/series.mbx"
else
	(cd "$TMP" && b4 am -o . "$FTS5_MSGID" >/dev/null)
	mv "$TMP"/*.mbx "$TMP/series.mbx"
fi

mkdir "$TMP/split"
n=$(git mailsplit -o"$TMP/split" "$TMP/series.mbx")
if [ "$n" -ne 11 ]; then
	echo "expected 11 patches in the FTS5 v4 mbox, got $n" >&2
	exit 1
fi

i=1
for name in $FTS5_NAMES; do
	src="$TMP/split/$(printf '%04d' "$i")"
	subj=$(sed -n 's/^Subject: //p' "$src" | head -n 1)
	case "$subj" in
	*"$i/11]"*) ;;
	*) echo "patch $i is out of order: $subj" >&2; exit 1 ;;
	esac
	cp "$src" "$OUT/$name"
	i=$((i + 1))
done

curl -fsSL -o "$OUT/0012-Input-stmfts-poll-for-CONTROLLER_READY-event-in-stmf.patch" "$MIROMRAZ_URL"

cp "$HERE"/patches/kernel/0013-*.patch "$HERE"/patches/kernel/0014-*.patch "$OUT/"

ls -1 "$OUT"
echo "Now copy these into the aport and run: pmbootstrap checksum linux-postmarketos-qcom-sm7150"
