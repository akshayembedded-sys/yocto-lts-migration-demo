# Yocto LTS migration demo: Kirkstone → Scarthgap → Wrynose

## The problem

Yocto 4.0 Kirkstone is end of life ([Yocto releases](https://wiki.yoctoproject.org/wiki/Releases)).
Products still built on it get no more security fixes from the Yocto Project. The two current LTS
releases are 5.0 Scarthgap (to April 2028) and 6.0 Wrynose (to April 2030). This repo takes a
small product layer, `meta-demo`, from Kirkstone to Scarthgap to Wrynose, and records what broke at
each step. The layer has a C daemon with a systemd service, a kernel config fragment, a FIT kernel,
CVE scanning and an image. Every break is backed by our own build log and a link to the official
migration guide. `PLAN.md` predicted the breaks before any build ran: 8 of the 10 Wrynose breaks were
predicted, and all 4 Scarthgap breaks.

## Hardware and exact versions

| | |
|---|---|
| Build host | Ubuntu 24.04.5, 32 CPUs, 62 GiB RAM, Docker. Every build runs in a container whose distro the release supports |
| Kirkstone | poky `yocto-4.0.35` (`93431249a6`), kas 4.8.2 (Debian 12.11), linux-yocto 5.15.201 |
| Scarthgap | poky `yocto-5.0.21` (`4fb7016a07`), kas 4.8.2 (Debian 12.11), linux-yocto 6.6.151 |
| Wrynose | bitbake / openembedded-core / meta-yocto `yocto-6.0.4`, kas 5.5 (Debian 13.6), linux-yocto 6.18.52, plus one oe-core patch (W10) |
| Target | QEMU `qemuarm64` for all three releases |
| Board | NXP FRDM-IMX91, NXP BSP 6.6.36-2.1.0 (Scarthgap) + `meta-imx-frdm` `imx-frdm-4.0`, MACHINE `imx91-11x11-lpddr4-frdm` ([docs/IMX91.md](docs/IMX91.md)) |

All commits, container digests and `DISTRO_FEATURES` are listed in [docs/VERSIONS.md](docs/VERSIONS.md).

## Reproduce

You need Docker and git. Budget tens of GB of disk per build ([docs/RESULTS.md](docs/RESULTS.md)).
Caches go to `~/yocto-cache` and builds to `~/yocto-builds`. Run long builds in tmux. `main` holds the
Wrynose layer. The other releases build from their tags.

| Release | One command |
|---|---|
| Kirkstone | `git checkout kirkstone-baseline && scripts/build.sh kirkstone && scripts/boot-test.sh kirkstone` |
| Scarthgap | `git checkout scarthgap-migrated && scripts/build.sh scarthgap && scripts/boot-test.sh scarthgap` |
| Wrynose (kas) | `git checkout main && scripts/build.sh wrynose && scripts/boot-test.sh wrynose` |
| Wrynose (bitbake-setup) | `scripts/bitbake-setup-build.sh` ([docs/BITBAKE-SETUP.md](docs/BITBAKE-SETUP.md)) |
| FRDM-IMX91 | `scripts/imx91-build.sh sync && EULA=1 scripts/imx91-build.sh build`. Read and accept NXP's licence first (see below) |

`build.sh` prints `BUILD_EXIT` and the image size. `boot-test.sh` boots the image in `runqemu`, logs in,
checks that `demod` is `active (running)` and prints `BOOT_TEST_EXIT`. The serial console goes to `logs/`.

## Every break

| # | Release | Symptom | Fix | Guide |
|---|---|---|---|---|
| S1 | Scarthgap | `Layer demo is not compatible with the core layer` | `LAYERSERIES_COMPAT_demo = "scarthgap"` | [4.2](https://docs.yoctoproject.org/migration-guides/migration-4.2.html#layerseries-compat-for-custom-layers-and-devtool-workspace) |
| S2 | Scarthgap | `No recipes ... for linux-yocto_5.15.bbappend` | rename to `linux-yocto_%.bbappend` | [4.3](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#removed-recipes) |
| S3 | Scarthgap | `systemd was skipped: missing required distro feature 'usrmerge'` | hand-written systemd lines → `INIT_MANAGER = "systemd"` | [4.3](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#systemd-changes) |
| S4 | Scarthgap | `build.sh` cannot find the image (`.rootfs` in link names) | ask bitbake for `IMAGE_LINK_NAME` | [4.3](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#output-file-naming-changes) |
| W1 | Wrynose | `Layer demo is not compatible with the core layer` | `LAYERSERIES_COMPAT_demo = "wrynose"` | [4.2](https://docs.yoctoproject.org/migration-guides/migration-4.2.html#layerseries-compat-for-custom-layers-and-devtool-workspace) |
| W2 | Wrynose | `Could not inherit file classes/cve-check.bbclass` | `core/yocto/sbom-cve-check` configuration fragment | [6.0](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#cve-check-class-removed) |
| W3 | Wrynose | `Could not inherit file classes/kernel-fitimage.bbclass` | FIT from `linux-yocto-fitimage` + `kernel-fit-extra-artifacts` | [5.3](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#fitimage-no-longer-supported-for-kernel-imagetype) |
| W4 | Wrynose | `lack of whitespace around the assignment` | `EXTRA_OEMAKE = "..."` | [5.3](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#space-around-equal-assignment) |
| W5 | Wrynose | `'debug-tweaks' ... is not a valid image feature` | `core/yocto/root-login-with-empty-password` fragment, test builds only | [5.2](https://docs.yoctoproject.org/migration-guides/migration-5.2.html#debug-tweaks-removed-from-image-features) |
| W6 | Wrynose | `Recipes that set S = "${WORKDIR}/git" ... should remove that assignment` | drop `S`, `destsuffix=${BP}` | [5.3](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#s-workdir-git-and-s-unpackdir-git-should-be-removed) |
| W7 | Wrynose | `Package libsystemd was not found`, `undefined reference to 'sd_notify'` | `inherit pkgconfig` | [6.0](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#ref-classes-pkgconfig-related-variables-are-no-longer-automatically-exported) |
| W8 | Wrynose | `install: cannot stat '.../demod.service'` | `${UNPACKDIR}/demod.service` | [5.1](https://docs.yoctoproject.org/migration-guides/migration-5.1.html#workdir-references-in-recipes) |
| W9 | Wrynose | `.zst images are only supported with snapshot mode` (not predicted) | `runqemu ... snapshot`, image type read from bitbake | [5.3 notes](https://docs.yoctoproject.org/migration-guides/release-notes-5.3.html#new-features-enhancements-in-yocto-ver) |
| W10 | Wrynose | `do_sbom_cve_check`: `No such file or directory: ...spdx.json` (not predicted; upstream regression) | oe-core patch in `patches/`, applied by kas | [oe-core b9f060ea6d](https://git.openembedded.org/openembedded-core/commit/?id=b9f060ea6d54cc419df9ff5f8822a3536934606f) |

Each entry in [docs/MIGRATION_LOG.md](docs/MIGRATION_LOG.md) has the full error text, the root cause and the log file.

## Measured results

From [docs/RESULTS.md](docs/RESULTS.md). The trimmed evidence is in `logs/*-evidence.txt`. All three tags
and `main` were also rebuilt and boot-tested from a clean clone with `scripts/verify-refs.sh`, reusing
sstate, to prove that the committed content builds (`logs/verify-evidence.txt`).

| Release | Build time | Tasks | Image size | Breaks | Boot test |
|---|---|---|---|---|---|
| Kirkstone 4.0.35 | 9765 s, empty sstate | 4171 | 106,166,272 B ext4 | 0 (baseline) | pass |
| Scarthgap 5.0.21 | 3446 s, empty sstate, downloads shared | 5735 | 139,569,152 B ext4 | 4 | pass, kernel 6.6.151 |
| Wrynose 6.0.4 | about 5471 s, summed over attempts | 5773 | 161,427,456 B ext4 (about 36.3 MB `.ext4.zst`; varies by a few hundred bytes per build) | 10 | pass, kernel 6.18.52 |
| FRDM-IMX91 (Scarthgap BSP) | 4090 s, empty sstate | 5015 | 309,748,736 B wic (43,924,056 B `.wic.zst`) | n/a | board boot pending |

## Known limits

- The build times are not strictly comparable: the later builds reused the downloads, and the Wrynose time is the sum of several attempts (see RESULTS.md).
- The FRDM-IMX91 boot result is not recorded yet. The image is built; the serial log from the board is still to come.
- The W10 fix is a local oe-core patch. It has not been sent upstream.
- `bitbake-setup`'s `poky-wrynose` config tracks branch heads, so that build used newer revisions (kernel 6.18.54) than the pinned kas build.
- On the board, the kernel is NXP's `linux-imx`, so the `linux-yocto` watchdog fragment is not applied there.
- The FRDM-IMX91 run did not use the shared caches or `rm_work` because of a script bug, now fixed but not re-run (see docs/IMX91.md).
- The Kirkstone and Scarthgap tags, and the board image built from the Scarthgap tag, allow root login with an empty password (`debug-tweaks`). From Wrynose on, that comes only from a fragment in the test build. These are test images, not product images.
- CI (GitHub Actions) only lints: shellcheck on `scripts/`, oelint-adv on `meta-demo`. Full builds are too large for hosted runners and run locally.

## Licence

The layer, scripts and docs are MIT ([LICENSE](LICENSE)). This repo contains no NXP files.
`scripts/imx91-build.sh` fetches NXP's BSP from NXP's public repositories. That BSP is covered by NXP's
licence (`sources/meta-imx/LICENSE.txt` after the sync), and its build step accepts that licence, so
read it and accept it yourself before you run `EULA=1`.
