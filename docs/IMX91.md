# meta-demo on the FRDM-IMX91 board (NXP Scarthgap BSP)

This page records how `demo-image` was built for NXP's FRDM-IMX91 board with NXP's i.MX Linux BSP
6.6.36-2.1.0 (Yocto 5.0 Scarthgap). The setup follows the
[meta-imx-frdm README](https://github.com/nxp-imx-support/meta-imx-frdm/tree/lf-6.6.36-2.1.0) and NXP's
[Getting Started with FRDM-IMX91](https://www.nxp.com/document/guide/getting-started-with-frdm-imx91:GS-FRDM-IMX91).
Script: `scripts/imx91-build.sh`. Trimmed evidence: `logs/imx91-evidence.txt`; machine lists, the quoted machine comment, `POKY_INIT_MANAGER`,
the device tree file and the `.wks` layout are in `logs/source-facts-evidence.txt`.

Nothing from NXP is in this repo: no firmware, no images, no EULA flag. The NXP BSP is covered by
NXP's licence (`sources/meta-imx/LICENSE.txt` after the sync). The build step accepts it, so read it
and accept it yourself before you run that step.

## Sources

`scripts/imx91-build.sh sync` runs, inside the kas 4.8.2 container (Debian 12, a Scarthgap host):

```bash
repo init -u https://github.com/nxp-imx/imx-manifest -b imx-linux-scarthgap -m imx-6.6.36-2.1.0.xml
repo sync
git clone https://github.com/nxp-imx-support/meta-imx-frdm.git sources/meta-imx-frdm
git -C sources/meta-imx-frdm checkout imx-frdm-4.0
```

The 6.6.36-2.1.0 manifest itself has no FRDM machine for the i.MX 91: meta-imx at
`rel_imx_6.6.36_2.1.0` ships only `imx91-11x11-lpddr4-evk`, `imx91-9x9-lpddr4-qsb` and `imx91evk`. The board
support comes from NXP's separate `meta-imx-frdm` layer. Its README pins it to this release. Tag
`imx-frdm-4.0` is the head of its only branch, `lf-6.6.36-2.1.0` (`0391d7457a9f`). The revisions of all
17 repos are in `logs/imx91-evidence.txt`. These include poky `f43f393ef024` and meta-imx `92ad51ef3cc7`.

## MACHINE: `imx91-11x11-lpddr4-frdm`

meta-imx-frdm lists four i.MX 91 machines in its `meta-imx-bsp` layer:

| Machine | What it is |
|---|---|
| `imx91-11x11-lpddr4-frdm` | **Chosen.** The FRDM-IMX91 board: device tree `imx91-11x11-frdm`, U-Boot `imx91_11x11_frdm`, LPDDR4 training firmware |
| `imx91frdm` | Wrapper: `require conf/machine/imx91-11x11-lpddr4-frdm.conf`. The README uses it, but its own comment says "For most users, the dedicated machine imx91-11x11-lpddr4-frdm.conf should be used for simplicity." |
| `imx91-11x11-lpddr4-frdm-imx91s`, `imx91frdmimx91s` | The FRDM-IMX91S, a different board |

The built U-Boot's default device tree is `CONFIG_DEFAULT_FDT_FILE="imx91-11x11-frdm.dtb"`. That
file is in the deploy dir.

## DISTRO and layer

- **DISTRO `fsl-imx-xwayland`**, the distro the README and NXP's guide use. It sets
  `POKY_INIT_MANAGER = "systemd"`, and the build confirmed `INIT_MANAGER` = `systemd`, which `demod.service`
  needs. Our own `demo` distro is not used here. At the Scarthgap tag it builds the kernel as a FIT image
  (`KERNEL_IMAGETYPE = "fitImage"`), and we did not try that with the board's U-Boot. NXP's tested distro
  keeps the BSP's own kernel and boot setup.
- **meta-demo from tag `scarthgap-migrated`**. `main` holds the Wrynose version of the layer, so the
  script exports the tagged copy with `git archive`. `demod` is fetched from this repo, mounted read-only.
- The SOFT_WATCHDOG config fragment is in `linux-yocto_%.bbappend`. The board kernel is `linux-imx`, so
  the fragment is not applied on the board.

## Build

`EULA=1 scripts/imx91-build.sh build` runs `imx-frdm-setup.sh -b build-frdm-imx91` with the MACHINE and
DISTRO above. It adds `/top/meta-demo` to `bblayers.conf` and runs `bitbake demo-image`.

```
NOTE: Tasks Summary: Attempted 5015 tasks of which 6 didn't need to be rerun and all succeeded.
Summary: There were 33 WARNING messages.
IMX91_EXIT=0
IMX91_SECONDS=4090
```

- Image: `demo-image-imx91-11x11-lpddr4-frdm.rootfs.wic.zst`, 43,924,056 bytes, 309,748,736 bytes
  uncompressed. It holds the boot image (`imx-boot`), kernel, device trees and rootfs.
- The image manifest has `demod 1.0+git0+88d409fc96`, `systemd 1:255.4` and `packagegroup-core-boot`.
- Warnings: 32 upstream fetches served from mirrors and 1 `linux-imx` QA warning. None of them come from meta-demo.

**Known mistake in this run.** The script was meant to add shared `DL_DIR` and `SSTATE_DIR` and
`rm_work` to `local.conf`. Its guard checked for a `^DL_DIR` line, and NXP's `local.conf` already has
`DL_DIR ?= "${BSPDIR}/downloads/"`, so the block was skipped. The run therefore used NXP's default
cache dirs and kept all work dirs. That is why `build/tmp` is 67 G (`tmp/work` 64 G). The guard now
looks for a marker line of our own. A rebuild has not tested the fix yet.

## Flashing and boot

These steps are from NXP's [Getting Started with FRDM-IMX91](https://www.nxp.com/document/guide/getting-started-with-frdm-imx91:GS-FRDM-IMX91):

- SD-card boot is SW1-4..SW1-1 = `0 0 1 1` ("USDHC2 4-bit SD3.0"). The default is `0 0 1 0`, eMMC.
- The console is the debug USB-C port `P16` at 115200 8N1. The first of the two serial ports is the
  Cortex-A55 console. Power goes to `P1`.

The image is written to the card with `zstdcat <image>.wic.zst | sudo dd of=/dev/sdX bs=1M conv=fsync`,
after `lsblk` before and after inserting the card has confirmed which device is the card.

## Result on the board

Pending: the serial console log from the board.
