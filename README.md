# Pixel 4a (sunfish) on postmarketOS: touch, reset loop, ADSP crash, battery, suspend

Fixes that make the Google Pixel 4a (4G, codename *sunfish*, SoC SM7150)
usable with the generic postmarketOS `qcom-sm7150` port:

| Problem | Fix here | Result on our unit |
|---|---|---|
| Touchscreen dead (no driver, no DT node) | FTS5 driver series + our patches 0013/0014, touch DT node with panel link | Touch works from the lock screen, 3/3 boots |
| Silent reset loop early in boot | Blacklist the `ipa` driver | 5/5 clean reboots, 0 short boots |
| ADSP restarts every ~10 s (`sar.cc:27 chre_utils fatal`) | SMP2P `sleepstate` entry in the DT | 0 ADSP crashes (was ~12 per 2 min) |
| Battery shows 0 % | Enable the PM6150 fuel gauge + `/battery` node | Percentage shown (voltage-based estimate) |
| Auto-rotation upside down | udev rule: accelerometer mount matrix | Upright phone shows upright; landscape not confirmed |
| Suspend kills the phone (s2idle never returns) | `system-sleep` hook: only WFI while suspended; Bluetooth rfkill-blocked | Suspend + wake by power key and RTC timer work |

> **Caveat.** Tested on **one** Pixel 4a, on **2026-09-28** (suspend: 2026-09-29), with postmarketOS
> edge, systemd and Phosh. Everything here is experimental. Keep a backup
> image of `userdata` you can restore with `fastboot` before you start.

What was tested how is listed under [Testing status](#testing-status).

Not covered (still broken or untouched): audio, charging status
(charge/discharge state), mobile data via IPA. Auto-rotation is fixed but
only checked upright; see [Known issues](#known-issues).

## Credits

This work stands on other people's reverse engineering:

- **David Heidelberg** (with Petr Hodina): the STM FTS5 touchscreen driver
  series, *Input: support for STM FTS5* v4,
  [lore](https://lore.kernel.org/lkml/20260409-stmfts5-v4-0-64fe62027db5@ixit.cz/).
- **miromraz**: Pixel 4a touch patches
  ([pixel4a-stmfts5-mainline](https://github.com/miromraz/pixel4a-stmfts5-mainline)),
  the kernel tree [miromraz/linux](https://github.com/miromraz/linux)
  (branch `sunfish-venus-v7.2`) and the
  **Mobian port** [mobian-pixel4a-port](https://github.com/miromraz/mobian-pixel4a-port).
  From the Mobian port come: the DRM panel-follower approach for touch, the
  IPA reset diagnosis (`docs/internals.md`), the ADSP `sleepstate` fix
  (commit [ff5dc4c](https://github.com/miromraz/mobian-pixel4a-port/commit/ff5dc4cd12d92204dc0ac0750a4e21993831b465))
  and the battery description.
- [sm7150-mainline](https://github.com/sm7150-mainline) (kernel and U-Boot)
  and the postmarketOS `qcom-sm7150` port.

## Tested setup

- Device: Pixel 4a 4G (sunfish), bootloader unlocked.
- postmarketOS edge, device `qcom-sm7150`, UI Phosh, service manager systemd.
- Boot chain: Android bootloader → U-Boot
  (`u-boot-sm7150-google-sunfish.img` from sm7150-mainline/u-boot, release
  2025-12-02, sha256 `bc5ad12ae235aaf9150c86b7981c0ee495520483529412548e0c5b7cd26859b9`)
  → systemd-boot → kernel. Root filesystem on `userdata`.
- Kernel: pmaports `linux-postmarketos-qcom-sm7150` 7.1_rc3 (pmaports commit
  `fb0bfa97aa`), rebuilt as `7.1_rc3-r2` with the patches below.

By default the pmOS boot entry has no `devicetree` line, so the kernel runs
on **U-Boot's own device tree**. The DTB here is U-Boot's tree plus small
fragments, so the only differences from what the phone already boots are the
fixes. (The kernel's own `sm7150-google-sunfish.dtb` was not tested with
these fixes.)

## Testing status

On the phone (one unit, 2026-09-28):

- Kernel `7.1_rc3-r2`, built with pmbootstrap from the APKBUILD in `aport/`
  and our own copies of the same 14 patches.
- The DTB, byte-identical to what `dts/build.sh` produces (same sha256),
  installed under a different file name.
- `system/etc/modprobe.d/*`, `stmfts-guard` and its unit (since then only
  comments and an SPDX line were added). `system/etc/deviceinfo` differs from
  the tested one only in the DTB file name.
- Rotation (2026-09-28): the udev rule (the file here differs from the
  tested one only in its comments).
- Suspend (2026-09-29): the `system-sleep` hook (the file here differs from
  the tested one only in its comments) and `rfkill block bluetooth`.

The repository's scripts, run end-to-end on the build machine:

- `scripts/fetch-patches.sh`: fetched the series with b4 from lore and
  miromraz's patch from GitHub. The 14 files applied to the official
  7.1_rc3 source in APKBUILD order, and the resulting `stmfts.c` is
  identical to the tested r2. **Not run:** `pmbootstrap checksum` and a
  kernel build from these fetched files.
- `dts/build.sh` (with dtc 1.7.0): run with the tested U-Boot image; the
  output matches the tested DTB byte for byte.

Not run as written:

- Step 4 install commands (file name `sm7150-google-sunfish-pmos.dtb`, the
  repo's `/etc/deviceinfo`): on the phone the same DTB had another name.
- Rollback: the kernel downgrade (r2 → r0 file) was tested in a throwaway
  apk root with apk-tools 3.0.8, not on the phone; the other rollback steps
  were not exercised.

## Repository layout

```
patches/kernel/   0013 and 0014, our kernel patches (GPL-2.0)
aport/            modified APKBUILD, its diff, and the one-line config diff
scripts/          fetch-patches.sh: collects all 14 patches for the aport
dts/              DT fragments against U-Boot's tree, build script, diffs
system/           files for the phone: modprobe.d, stmfts-guard, deviceinfo,
                  system-sleep hook (suspend), udev rule (rotation)
```

## Kernel

The package is the official `linux-postmarketos-qcom-sm7150` with:

| # | Patch | Author |
|---|---|---|
| 0001–0011 | *Input: support for STM FTS5* v4 (11 patches) | David Heidelberg, Petr Hodina |
| 0012 | *Input: stmfts - poll for CONTROLLER_READY event in stmfts5_configure* | miromraz (pixel4a-stmfts5-mainline, `patches/0001`) |
| 0013 | *Input: stmfts - include linux/gpio/consumer.h* (build fix: the series uses gpiod without the header) | this repo |
| 0014 | *Input: stmfts - power in-cell touch as a DRM panel follower* | this repo, approach from the Mobian port |

and `CONFIG_TOUCHSCREEN_STMFTS=m` (`aport/config.diff`), `pkgrel=2`.

Patch 0014:

- With a `panel` phandle in the DT, the chip is powered in the panel's
  `panel_prepared()` callback and powered off in `panel_unpreparing()`,
  instead of at probe. Without the phandle, probe powers it as before.
- The IRQ is disabled again when configuration fails after enabling it, and
  enable/disable stay balanced across failed and repeated power-ons.
- A failed power-on no longer switches off `vdd`/`avdd`: on this phone they
  are the OLED panel's rails (l13a, l7c). The chip is held in reset instead;
  the supplies are released only in power-off.
- Power state has its own lock (the IRQ thread takes the driver mutex while
  power-on waits for it). FTS4 and FTS5 support is otherwise unchanged.

## Step by step

Commands marked `$` run on your build machine, `phone$` on the phone over
SSH. `<phone>` is the phone's address, `user` the phone's user name.

### 0. Before you start

- The phone runs postmarketOS `qcom-sm7150` with U-Boot (see the pmOS wiki).
- You have SSH access and `pmbootstrap` set up for this device.
- You have a `userdata` backup image you can restore with
  `fastboot flash userdata <image>`.

### 1. Stop the early reset loop (IPA)

```
$ scp system/etc/modprobe.d/blacklist-ipa.conf user@<phone>:
phone$ sudo install -m 644 blacklist-ipa.conf /etc/modprobe.d/blacklist-ipa.conf
phone$ sudo reboot
phone$ lsmod | grep -w ipa          # expect nothing
```

This costs mobile data through IPA.

### 2. Build the kernel

```
$ A="$(pmbootstrap config aports)/device/community/linux-postmarketos-qcom-sm7150"
$ scripts/fetch-patches.sh /tmp/sunfish-patches      # needs b4, git, curl
$ cp /tmp/sunfish-patches/*.patch "$A"/
$ cp aport/APKBUILD "$A"/APKBUILD
$ (cd "$A" && patch -p1 < "$OLDPWD"/aport/config.diff)
$ pmbootstrap checksum linux-postmarketos-qcom-sm7150
$ pmbootstrap build linux-postmarketos-qcom-sm7150 --force
```

`aport/APKBUILD.diff` shows the APKBUILD changes against pmaports
`fb0bfa97aa`. If your pmaports has moved on, apply that diff by hand instead
of copying the file. `pmbootstrap checksum` is needed because the fetched
patch files are not byte-identical to ours.

The package ends up in
`$(pmbootstrap config work)/packages/edge/aarch64/linux-postmarketos-qcom-sm7150-7.1_rc3-r2.apk`.

### 3. Build the DTB

```
$ dts/build.sh u-boot-sm7150-google-sunfish.img out    # needs python3, dtc
```

`build.sh` extracts U-Boot's DTB from the image, decompiles it, adds the
fragments `dts/00-*.dts` … `dts/04-*.dts` and compiles
`out/sm7150-google-sunfish-pmos.dtb`. With the tested U-Boot image the result
has sha256 `c397d5cc7edd2e02613b1b86cb107e40918522e2c4b4413d94c5931081576fb5`,
byte-identical to the DTB we tested.

The fragments (each is a readable diff against U-Boot's tree):

| File | What |
|---|---|
| `00-dtc-roundtrip-fix.dts` | No functional change: keeps two regulator values that `dtc` would corrupt when recompiling |
| `01-touch.dts` | Touch node on i2c7 @ 0x49, pin states, PM6150 GPIO 4 load switch |
| `02-panel-link-reset-pin.dts` | `panel` phandle (for patch 0014) and reset pin `bias-disable` |
| `03-adsp-sleepstate.dts` | `/smp2p-adsp/sleepstate-out`: stops the ADSP crash loop |
| `04-battery-gauge.dts` | `/battery` node and the PM6150 QG fuel gauge enabled |

`dts/diff-vs-uboot.txt` lists every changed property (38 added, 1 changed:
the gauge's `status`); `dts/diff-vs-uboot.dts.diff` is the same as a
decompiled unified diff.

### 4. Install on the phone

Order matters: the DTB, `/etc/deviceinfo` and the stmfts blacklist go in
**before** the kernel, so the kernel install writes the right boot entry and
udev never loads the touch driver on its own.

```
$ scp out/sm7150-google-sunfish-pmos.dtb system/etc/deviceinfo \
      system/etc/modprobe.d/blacklist-stmfts.conf \
      system/usr/local/sbin/stmfts-guard \
      system/etc/systemd/system/stmfts-guard.service \
      "$(pmbootstrap config work)"/packages/edge/aarch64/linux-postmarketos-qcom-sm7150-7.1_rc3-r2.apk \
      user@<phone>:

phone$ sudo install -m 644 sm7150-google-sunfish-pmos.dtb /boot/dtbs/qcom/
phone$ cat /etc/deviceinfo 2>/dev/null    # should not exist yet; if it does, merge by hand
phone$ sudo install -m 644 deviceinfo /etc/deviceinfo
phone$ sudo install -m 644 blacklist-stmfts.conf /etc/modprobe.d/
phone$ sudo install -m 755 stmfts-guard /usr/local/sbin/stmfts-guard
phone$ sudo install -m 644 stmfts-guard.service /etc/systemd/system/
phone$ sudo systemctl daemon-reload
phone$ sudo systemctl enable stmfts-guard.service

phone$ sudo cp /boot/loader/entries/pmos.conf /home/user/pmos.conf.bak
phone$ sudo apk add --allow-untrusted linux-postmarketos-qcom-sm7150-7.1_rc3-r2.apk
phone$ sudo cat /boot/loader/entries/pmos.conf
```

The last command must show `devicetree sm7150-google-sunfish-pmos.dtb`.
`--allow-untrusted` is needed because the package is signed with your build
machine's key.

Keep `apk upgrade` from replacing the kernel: installing from a file already
pins the exact package in `/etc/apk/world` (an entry like
`linux-postmarketos-qcom-sm7150><Q1…`). We used a version pin instead; edit
`/etc/apk/world` so the kernel line reads:

```
linux-postmarketos-qcom-sm7150=7.1_rc3-r2
```

Then reboot the phone.

### 5. Check

```
phone$ uname -v                                    # starts with #3 (r2 package)
phone$ sudo grep -c 'st,stmfts5' /sys/firmware/fdt # 1: our DTB is live
phone$ lsmod | grep stmfts                         # loaded by stmfts-guard
phone$ cat /var/lib/stmfts-guard/history           # "survived 60s; marker cleared"
phone$ sudo dmesg | grep -c "crash detected in adsp"   # 0
phone$ ls /sys/class/power_supply/                 # a battery supply next to tcpm-source-psy-…
phone$ upower -d | grep -E 'percentage|state'
```

## stmfts-guard

Touch now loads safely at boot, but a touch driver that resets the phone at
boot is a loop you can't break over SSH. `stmfts-guard` (a systemd service
that runs before `sysinit.target`) is the safety net:

1. If `/var/lib/stmfts-guard/attempt` exists, the previous load attempt did not
   survive: **skip loading** and log it. The phone boots without touch.
2. Otherwise write the marker, `sync`, `modprobe --ignore-install stmfts`.
3. Remove the marker 60 s after a successful load. A clean shutdown within
   the 60 s also removes it; a hard reset does not.

Re-arm after a skip: `sudo rm /var/lib/stmfts-guard/attempt`.
History: `/var/lib/stmfts-guard/history`.

Blind spots: a crash more than 60 s after loading is not caught; a shutdown
while `modprobe` itself is still running leaves the marker (one skipped boot).

## Suspend / s2idle

Without a fix, every suspend kills the phone: the journal ends at
`PM: suspend entry (s2idle)`, the phone goes dark, and a short press of the
power key starts a fresh boot. `pstore` is empty afterwards.

What we found (one unit, 2026-09-29, kernel `7.1_rc3-r2`):

| Test | cpuidle states allowed while suspended | Result |
|---|---|---|
| A | WFI only (state1 and state2 disabled) | Suspend held, woke on the power key, no reboot |
| B | WFI + state1 (per-CPU power collapse; state2 disabled) | Phone died, fresh boot |

So per-CPU power collapse during s2idle is enough; the cluster idle states
are not needed for it. The root cause is unknown. The power key's interrupt
path (PMIC arbiter → PDC pin 1 → GIC) was checked in the running DT, in the
sm7150-mainline `sm7150.dtsi` and in U-Boot's tree: all three route it through
the PDC, so a missing wake route is not the explanation.

**Workaround:** `system/usr/lib/systemd/system-sleep/cpuidle-s2idle-wfi-only`.
On `pre` it records which cpuidle states are enabled on every CPU and
disables all of them except WFI; on `post` it restores them. While awake, all idle states stay
available. The cost is more drain while suspended (WFI only, no power
collapse); not measured yet.

```
phone$ sudo install -m 0755 cpuidle-s2idle-wfi-only /usr/lib/systemd/system-sleep/
```

**Bluetooth can wake it at once.** In some boots every suspend came back
after 0.8 s with no wakeup source recorded. With `rfkill block bluetooth` the
same suspend held. (The Bluetooth UART, `88c000.serial`, is a wakeup source.)
Why only some boots are affected is unknown. We keep Bluetooth blocked;
systemd-rfkill restores the block at every boot.

```
phone$ sudo rfkill block bluetooth
```

With both in place: suspends of 2 to 47 min, wake by the power key and by
the RTC (a systemd timer with `WakeSystem=true` woke the phone after 5 min;
Wi-Fi was back 9 s later), and the normal idle suspend afterwards. The line
`dwc3-qcom-legacy ...: port-1 HS-PHY not in L2` appears on every resume, good
or bad; it is not related.

## Known issues

- **Auto-rotation: fixed upright, landscape not confirmed.** Auto-rotation in
  Phosh works since the sleepstate fix (a side effect of the ADSP no longer
  restarting), but without a mount matrix the screen turned the wrong way.
  `system/etc/udev/rules.d/81-libssc-google-sunfish.rules` sets
  `ACCEL_MOUNT_MATRIX` on `/dev/fastrpc-*` (180 degrees about Z, as for most
  libssc phones in pmaports). Tested 2026-09-28: upright now reads `normal`
  and the screen is right side up. Landscape was not confirmed: the screen
  stayed in portrait in that test. If landscape turns the wrong way, the other
  candidate is `1, 0, 0; 0, -1, 0; 0, 0, 1` (only y negated).

  ```
  phone$ sudo install -D -m 644 81-libssc-google-sunfish.rules /etc/udev/rules.d/81-libssc-google-sunfish.rules
  phone$ sudo udevadm control --reload
  phone$ sudo udevadm trigger --action=change --subsystem-match=misc --sysname-match='fastrpc-*'
  phone$ sudo systemctl restart iio-sensor-proxy
  phone$ monitor-sensor     # upright should read "normal"
  ```
- **Battery percentage is rough** and the charge state shows as unknown; see
  [Battery](#why-each-fix) below.

## Rollback

Each part can be undone on its own:

| Undo | How |
|---|---|
| Touch loader | `sudo systemctl disable stmfts-guard.service` (blacklist keeps the driver out) |
| DTB | `sudo rm /etc/deviceinfo && sudo mkinitfs` → boot entry without `devicetree`, U-Boot's tree again; reboot |
| Kernel | See [Kernel rollback](#kernel-rollback) below |
| IPA blacklist | `sudo rm /etc/modprobe.d/blacklist-ipa.conf`, reboot (the resets come back) |
| Rotation rule | `sudo rm /etc/udev/rules.d/81-libssc-google-sunfish.rules`, reboot (rotation is upside down again) |
| Suspend hook | `sudo rm /usr/lib/systemd/system-sleep/cpuidle-s2idle-wfi-only`; suspend kills the phone again, so also `sudo systemctl mask suspend.target sleep.target` |
| Bluetooth block | `sudo rfkill unblock bluetooth` (instant wake-ups may come back) |
| Everything | `fastboot flash userdata <backup image>` |

### Kernel rollback

1. Remove the kernel pin: edit `/etc/apk/world` so the kernel line is just
   `linux-postmarketos-qcom-sm7150` (drop `=7.1_rc3-r2` or `><Q1…`).
2. Install the official package file (`linux-postmarketos-qcom-sm7150-7.1_rc3-r0.apk`
   from the postmarketOS mirror):

   ```
   phone$ sudo apk add --allow-untrusted linux-postmarketos-qcom-sm7150-7.1_rc3-r0.apk
   ```

   `--allow-untrusted` is still needed for the **official** file: installed
   by itself (not through the repository index), apk checks the package's own
   signature, and that key is not among the phone's apk keys. Without the
   flag apk-tools 3.0.8 refuses it with `UNTRUSTED signature`.
3. Installing a file pins it again (`><Q1…`). Once online, return to the
   repository kernel: `sudo apk add linux-postmarketos-qcom-sm7150`.

In our test (apk-tools 3.0.8, throwaway root) the file install also replaced
an `=7.1_rc3-r2` pin by itself; step 1 makes the intent explicit either way.

`mkinitfs` (and every kernel install) re-runs boot-deploy, which rewrites
`/boot/loader/entries/*.conf` from scratch. A `devicetree` line added by hand
is lost; use `/etc/deviceinfo` as above.

## Why each fix

**Reset loop (IPA).** Early boots died with a silent reset: no panic, no
watchdog message in the logs. `pstore` (ramoops) was empty after every
reset, and also after clean reboots, so it gave no information here. The
journal is misleading here: short boots appear to end at journald's flush,
because later entries never reached the disk. The Mobian port traced the same
loop with a USB-serial console to the IPA driver; blocking it gave 5/5 clean
reboots.

**Touch.** Loading `stmfts` during boot (kernel r1, without 0014) put the phone
into a continuous reset loop; with the driver blacklisted it booted, and
loading the driver by hand after boot worked. Powering the chip at probe,
independent of the panel that shares its rails, is the difference; the Mobian
driver instead follows the panel. Patch 0014 plus the `panel` link does the
same, and the driver now loads at boot (~11 s) with touch working at the lock
screen.

**ADSP crash loop.** The ADSP sensor firmware expects an AP-side SMP2P entry
named `sleepstate`. Without it CHRE kills `sensor_process` about every 10 s:

```
PDM: service 'sensor_process' crash: 'EF:sensor_process:0x1:rcinit_worker:0xf6:sar.cc:27:chr'
remoteproc remoteproc1: crash detected in adsp: type fatal error
```

Adding the node (Mobian commit ff5dc4c) stopped it. Mainline `smp2p.c`
creates the entry from the node; no extra driver is needed. As a side
effect, auto-rotation started working once the ADSP stopped restarting; it
was upside down until the udev rule (see [Known issues](#known-issues)).

**Battery.** The kernel already has the PM6150 fuel-gauge driver (`qcom_qg`,
built as a module), but U-Boot's tree leaves the gauge disabled and has no
battery node, so there was no battery supply at all. `qcom_qg` only reads
from the PMIC; the percentage is a straight line between the battery's
minimum and maximum design voltage (3.30–4.45 V), so it is rough and reads
high while charging. The charge state stays "unknown".

**Battery option B (not applied, unverified).** The Mobian port also enables
the PM6150 charger (`charger@1000`, driver `qcom_smbx`; it needs two extra
ADC channels in U-Boot's tree) and links the gauge to it. That would give a
charger supply and, with a one-line change to `qcom_qg`, a charging/discharging
state. We did **not** apply it: `qcom_smbx` reprograms charging when it loads
(float voltage from the battery node, 4.45 V; fast-charge current 1.95 A), and
we have not verified those values against the battery's specifications.

## Dead ends (so you can skip them)

- **The miromraz pmaports fork** (`device-google-sunfish` plus its kernel):
  with today's tooling it needed several fixes to build (flash target
  `cache` does not exist on the 4a, a pmbootstrap crash, a file name
  `abuild` rejects, conflicts with `device-qcom-sm7150`). Once built, it
  bootlooped early in boot, with U-Boot's tree and with its own
  DTB. We did not find the cause and switched to the official package plus
  patches. In hindsight (unconfirmed): its kernel ships `stmfts` as a module
  that powers the chip at probe, and its own DTB has the touch node without a
  `panel` link, so with its DTB it likely hit the same boot-time loop as our
  r1. That cannot explain the boots on U-Boot's tree, which has no touch
  node; IPA was not blocked at the time, so those were probably the IPA
  resets.
- **The watchdog theory.** U-Boot contains Qualcomm watchdog code and
  `qcom_wdt` is a module that loads late, so a bootloader-armed watchdog
  biting before Linux takes it over looked plausible for the reset loop.
  It was not the cause: the loop was IPA (the Mobian port reached the same
  conclusion).
- **Loading stmfts at boot on r1.** Without patch 0014 the driver powers and
  configures the chip at probe; at boot that meant a continuous reset loop
  (12+ minutes until restored by fastboot). A delayed load (45 s after boot)
  worked as a stopgap; 0014 made the early load safe.

Smaller traps:

- Decompiling and recompiling U-Boot's DTB with `dtc` corrupts two regulator
  values (they print as strings). `00-dtc-roundtrip-fix.dts` handles it;
  compare DTBs property by property (`dts/fdtcmp.py`), not only as text.
- U-Boot's DTB has no `__symbols__`, so there are no labels to reference;
  the fragments use node paths.

## License

`patches/kernel/0013-*.patch` and `0014-*.patch` are GPL-2.0-only, like the
kernel code they change. The rest of this repository (DT fragments, scripts,
configuration) is also offered under GPL-2.0-only; see `LICENSE`. Patches
fetched by `scripts/fetch-patches.sh` keep their authors' terms.
