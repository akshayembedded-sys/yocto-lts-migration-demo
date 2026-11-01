# From QEMU to real hardware: demo-image on a Raspberry Pi 4 with Wrynose

This page walks through taking `meta-demo` from the QEMU build to a real board, from scratch, with the
Raspberry Pi 4 (64-bit) as the example. Everything below was run on 2026-11-01. The build passed; the
image has **not** been booted on a Pi yet (see step 8). Evidence: `logs/rpi4-wrynose-evidence.txt`.

## The rule: the board's BSP picks the release

The QEMU builds in this repo (`kas/kirkstone.yml`, `kas/scarthgap.yml`, `kas/wrynose.yml`) use
`MACHINE = "qemuarm64"`. They have no bootloader, firmware or device tree for a real board, so they
cannot be flashed. A real board needs a **BSP layer**, and you can only use a Yocto release that the
BSP supports:

| Board | BSP layer | Newest release it supports | So this repo builds |
|---|---|---|---|
| NXP FRDM-IMX91 | NXP BSP 6.6.36-2.1.0 + `meta-imx-frdm` | Scarthgap | Scarthgap ([IMX91.md](IMX91.md)) |
| Raspberry Pi 4 | [`meta-raspberrypi`](https://git.yoctoproject.org/meta-raspberrypi) | Wrynose (`wrynose` branch, `LAYERSERIES_COMPAT_raspberrypi = "wrynose"`) | Wrynose (this page) |

`meta-demo` itself is ready for Kirkstone, Scarthgap and Wrynose (it has a tag for each), so the BSP
is the limit.

## Step 1: check the BSP supports your release

```bash
git ls-remote --heads https://git.yoctoproject.org/meta-raspberrypi scarthgap wrynose
git clone -b wrynose https://git.yoctoproject.org/meta-raspberrypi
grep -n 'LAYERSERIES_COMPAT\|LAYERDEPENDS' meta-raspberrypi/conf/layer.conf
```

Output on 2026-11-01:

```
12:LAYERSERIES_COMPAT_raspberrypi = "wrynose"
13:LAYERDEPENDS_raspberrypi = "core"
```

- A branch named after the release (`wrynose`) and that release in `LAYERSERIES_COMPAT` mean the layer
  is meant for it. If the layer lists only older releases, bitbake stops with
  `Layer raspberrypi is not compatible with the core layer` (the same check as MIGRATION_LOG.md S1/W1).
- `LAYERDEPENDS` lists the other layers it needs. Here it is only `core` (openembedded-core), which
  `kas/wrynose.yml` already has. Vendor BSPs often need more layers; their README lists them.
- Pin the commit you tested. We used `919588393f41b48cb6c5d832aa35e58a19b6762d` (2026-10-10).

## Step 2: pick the MACHINE

Each file in `meta-raspberrypi/conf/machine/` is one `MACHINE` value. The 64-bit ones end in `-64`, plus
`raspberrypi5` and `raspberrypi-cm5-io-board`:

```
raspberrypi0-2w-64 raspberrypi3-64 raspberrypi4-64 raspberrypi5 raspberrypi-armv8 raspberrypi-cm5-io-board ...
```

We use `raspberrypi4-64`. Its kernel is `linux-raspberrypi` 6.18.33 (from the BSP), not `linux-yocto`.

## Step 3: add the BSP with a kas overlay

Do not copy `kas/wrynose.yml`. kas can stack files, `kas/wrynose.yml:kas/wrynose-rpi4.yml`, and the second file
only says what changes. That is the whole board port:

```yaml
# kas/wrynose-rpi4.yml
header:
  version: 14

machine: raspberrypi4-64            # replaces qemuarm64

repos:
  meta-raspberrypi:                 # the BSP layer, pinned
    url: https://git.yoctoproject.org/meta-raspberrypi
    branch: wrynose
    commit: 919588393f41b48cb6c5d832aa35e58a19b6762d
    layers:
      .:

local_conf_header:
  rpi-serial: |
    ENABLE_UART = "1"               # writes enable_uart=1 into config.txt
```

`ENABLE_UART = "1"` turns on the serial console on the GPIO header. The BSP leaves it empty by default
(`ENABLE_UART ??= ""` in `recipes-bsp/bootfiles/rpi-config_git.bb`); its
[extra-build-config.md](https://git.yoctoproject.org/meta-raspberrypi/tree/docs/extra-build-config.md?h=wrynose)
explains the setting. Everything else (the `demo` distro, the CVE fragment, the W10 patch, the test
login fragment) comes from `kas/wrynose.yml` unchanged.

Without kas, the same thing is: `bitbake-layers add-layer ../meta-raspberrypi` and
`MACHINE = "raspberrypi4-64"` plus `ENABLE_UART = "1"` in `conf/local.conf`. We did not run that way.

## Step 4: build

```bash
scripts/rpi4-build.sh
```

It uses the same kas 5.5 container (Debian 13) as the QEMU Wrynose build, its own dirs under
`~/yocto-builds/rpi4`, and the shared downloads and sstate. Run it in tmux.

### R1: kas crashes on a very long bitbake warning

The first run used `kas build`, like `scripts/build.sh`. It ended with `BUILD_EXIT=1`:

```
ERROR    - Separator is found, but chunk is longer than limit
asyncio.exceptions.LimitOverrunError: Separator is found, but chunk is longer than limit
```

- **What actually happened:** bitbake finished the whole job; its own log says
  `Tasks Summary: Attempted 5500 tasks of which 2293 didn't need to be rerun and all succeeded.`
  Only kas failed, because it could not pass one line through.
- **Root cause:** `kas build` reads bitbake's output line by line through
  `asyncio.create_subprocess_exec` (`kas/libkas.py` line 149 in kas 5.5), and asyncio's default limit for one line is
  64 KiB ([asyncio streams](https://docs.python.org/3/library/asyncio-stream.html#asyncio.StreamReader)).
  The `do_sbom_cve_check` warning for the Pi kernel is one line of 86,276 characters listing 5,389 CVE IDs
  (`linux-raspberrypi-6.18.33+git: Found unpatched CVEs: ...`). On the QEMU build the same line for
  `linux-yocto-6.18.52+git` lists 559 IDs, which fits. We measured the difference; we have not found
  out why the two kernels differ by that much.
- **Fix:** run bitbake under `kas shell -c "bitbake demo-image"` instead of `kas build`. kas then does
  not read bitbake's output. CVE scanning stays on. Second run:

```
NOTE: Tasks Summary: Attempted 5500 tasks of which 5488 didn't need to be rerun and all succeeded.
BUILD_EXIT=0
```

The first run took 2916 s with 1216 of 2788 sstate objects (43 %) reused from the QEMU build, so it is
not a from-scratch time. The build dir used 19 G.

## Step 5: check what you built

In `~/yocto-builds/rpi4/build/tmp/deploy/images/raspberrypi4-64/`:

| File | What it is |
|---|---|
| `demo-image-raspberrypi4-64.rootfs.wic.bz2` (58,568,276 B) | the whole SD card: boot partition + root filesystem |
| `demo-image-raspberrypi4-64.rootfs.wic.bmap` | block map, so `bmaptool` writes only the used blocks |
| `bootfiles/config.txt`, `bootfiles/cmdline.txt` | the Pi firmware's settings; they are in the boot partition |

The image format comes from the BSP (`IMAGE_FSTYPES = "tar.bz2 ext3 wic.bz2 wic.bmap"`), not from
`meta-demo`. Checks from `logs/rpi4-wrynose-evidence.txt`:

```
demod cortexa72 1.0+git0+88d409fc96                         # the daemon is in the image
kernel-image-6.18.33-v8 raspberrypi4_64 ...                 # the Pi kernel
245:enable_uart=1                                           # config.txt
console=serial0,115200 root=/dev/mmcblk0p2 rootfstype=ext4  # cmdline.txt
SERIAL_CONSOLES=115200;ttyS0                                # a login prompt on the serial port
```

The Pi firmware loads the kernel itself (`IMAGE_BOOT_FILES` ends in `Image;kernel8.img`;
`RPI_USE_U_BOOT` is empty), so there is no U-Boot on this card.

## Step 6: flash the SD card

The uncompressed image is 360,710,144 B (344 MiB), so any microSD card of 1 GB or more fits.
Everything on the card will be erased.

1. With the card **not** inserted, run `lsblk` and note the disks.
2. Insert the card and run `lsblk` again. The new disk (for example `sdb` or `mmcblk0`) is the card.
   Check its size matches the card. Writing to the wrong disk destroys its data.
3. Unmount any of its partitions that your desktop mounted, e.g. `sudo umount /dev/sdX1 /dev/sdX2`.
4. Write the image. Either with `bmaptool` (`sudo apt install bmap-tools` on Ubuntu):

   ```bash
   cd ~/yocto-builds/rpi4/build/tmp/deploy/images/raspberrypi4-64
   sudo bmaptool copy demo-image-raspberrypi4-64.rootfs.wic.bz2 /dev/sdX
   ```

   or with `dd`:

   ```bash
   bzcat demo-image-raspberrypi4-64.rootfs.wic.bz2 | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
   ```

5. `sync`, then remove the card.

## Step 7: connect the serial console

You need a 3.3 V USB-to-serial adapter (not 5 V). On the Pi's 40-pin header
([Raspberry Pi GPIO docs](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#gpio)):

| Pi pin | Signal | Adapter |
|---|---|---|
| 6 | GND | GND |
| 8 | GPIO 14 (TXD) | RX |
| 10 | GPIO 15 (RXD) | TX |

Leave the adapter's power pin unconnected. Open the port at 115200 8N1, e.g.
`sudo picocom -b 115200 /dev/ttyUSB0`.

## Step 8: boot and check (not done yet)

Insert the card, then power the Pi through its USB-C port. On the serial console you should get a
login prompt; log in as `root` (empty password, from the test fragment), then:

```bash
systemctl status demod     # expect: active (running)
uname -r                   # expect: 6.18.33-v8
```

**Result: pending.** No Pi has booted this image yet. Paste the serial log to record it here.

## What is different from the QEMU build

- **Kernel fragment not applied.** `meta-demo`'s watchdog fragment is a `linux-yocto_%.bbappend`, so it does not touch
  `linux-raspberrypi`. To apply it on the Pi, add a `linux-raspberrypi_%.bbappend` with the same
  `SRC_URI`. We have not done this.
- **A FIT image is built but not used.** The `demo` distro sets
  `KERNEL_DEPLOY_DEPEND = "linux-yocto-fitimage:do_deploy"` (MIGRATION_LOG.md W3), so the build also
  makes a `fitImage`. The Pi firmware boots `kernel8.img` and ignores it. A product port would make the
  FIT settings machine-specific.
- **No Wi-Fi/Bluetooth firmware.** The machine recommends `linux-firmware-rpidistro-*` packages, and that recipe
  has `LICENSE_FLAGS = "synaptics-killswitch"`. We did not accept that licence, so the image has no
  `linux-firmware` packages (`grep -c '^linux-firmware' ...manifest` gives `0`). If you need Wi-Fi, read the licence notes in
  [ipcompliance.md](https://git.yoctoproject.org/meta-raspberrypi/tree/docs/ipcompliance.md?h=wrynose)
  and decide for yourself before adding `LICENSE_FLAGS_ACCEPTED = "synaptics-killswitch"`.
- **Test login only.** Root login with an empty password comes from
  `core/yocto/root-login-with-empty-password` in `kas/wrynose.yml`. Drop that fragment for anything
  that leaves your desk.

## The same steps for another board

1. Find the BSP layer (vendor or community) and check its branches and `LAYERSERIES_COMPAT` (step 1).
2. Pick the newest release that both the BSP and `meta-demo` support, and check out that tag or `main`.
3. Copy `kas/wrynose-rpi4.yml`, change `machine:`, swap in the BSP repo and any layers its
   `LAYERDEPENDS` lists, and add the BSP's console setting if it needs one.
4. Build, then look in `tmp/deploy/images/<machine>/` for the `.wic*` file. Its format comes from the
   BSP's `IMAGE_FSTYPES`.
5. Flash it the way the BSP documents (SD card for most dev boards; some vendors use their own tool
   for eMMC, such as NXP's `uuu`), set the boot switches, and watch the serial console.
6. Write down anything that breaks, with the log line, as this page does for R1.
