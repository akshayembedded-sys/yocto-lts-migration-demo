# PLAN: Yocto LTS migration demo (Kirkstone → Scarthgap → Wrynose)

Status: Session 1 output. Later sessions corrected some commands and facts in it; `git log -p -- PLAN.md`
shows each change. What actually happened is in `docs/MIGRATION_LOG.md` and `docs/RESULTS.md`. Every "predicted break" below cites the
migration-guide section that predicts it. A prediction counts only once our own log confirms it
(sessions 3 and 4). Sources were read on 2026-10-30.

Guide base URL: `https://docs.yoctoproject.org/migration-guides/`, written as `G/` below.

---

## 0. Release facts used by this plan

| Release | Version pinned | Repositories (tag `yocto-X`, commit) | Kernel |
|---|---|---|---|
| Kirkstone | 4.0.35 | poky `yocto-4.0.35` = `93431249a6260da7bd29ee3ca32145d89e5b8259` | linux-yocto 5.15 (5.10 also provided) |
| Scarthgap | 5.0.21 | poky `yocto-5.0.21` = `4fb7016a07507683359ebd620f1951fd5ea44bfa` | linux-yocto 6.6 only |
| Wrynose | 6.0.4 | bitbake (branch `2.18`) `51fd94a67fa17650a9ff623492005972bbc7d26f`; openembedded-core (`wrynose`) `0f03c732a0a2d0506b41b1abe60b3f368b2300dc`; meta-yocto (`wrynose`) `7c25b11156553145fa6b241a2d4f65d94438f804` | linux-yocto 6.18 |

- Commits come from `git ls-remote '<repo>' 'refs/tags/yocto-X^{}'` on 2026-10-30. Session 2 copies them into `docs/VERSIONS.md`.
- Kernel versions come from the `meta/recipes-kernel/linux/` listing on each branch. 6.0 ships 6.18 (see the [6.0 release notes](https://docs.yoctoproject.org/migration-guides/release-notes-6.0.html#new-features-enhancements-in-yocto-ver)).
- Wrynose bitbake branch `2.18`: see [6.0 release notes, Repositories](https://docs.yoctoproject.org/migration-guides/release-notes-6.0.html#repositories-downloads-for-yocto-yocto-ver).
- Kirkstone end of life: sourced in session 6 to the [Yocto releases page](https://wiki.yoctoproject.org/wiki/Releases), which lists Kirkstone as "EOL" without a date; README.md and docs/ARTICLE.md cite it that way (corrected).

---

## 1. meta-demo for Kirkstone, written in Kirkstone-era style

Layout (created in session 2, not now):

```
meta-demo/
  conf/layer.conf                      LAYERSERIES_COMPAT_demo = "kirkstone"
  conf/distro/demo.conf                require conf/distro/poky.conf + the items below
  recipes-demo/demod/demod_git.bb      C daemon, git-fetched
  recipes-demo/demod/files/demod.service
  recipes-kernel/linux/linux-yocto_5.15.bbappend
  recipes-kernel/linux/files/demo.cfg  kernel config fragment
  recipes-core/images/demo-image.bb
demod/                                 daemon source (C + Makefile), MIT, in this repo
```

**Daemon source (decision, flag it if you disagree).** The repo was private while it was
built, so the recipe cannot fetch from GitHub without credentials inside the container. The
daemon source lives in `demod/` in this repo. The recipe fetches it with the real git fetcher:
`git:///repo;protocol=file;subpath=demod` (kas-container mounts the repo at `/repo`), with a
pinned `SRCREV`. This still uses `S = "${WORKDIR}/git"` and the git fetcher's branch rules, so the
breaks are real. Once the repo is public, the URL can switch to `https://github.com/...`.

**Daemon behaviour.** `demod` is a small industrial-style daemon. It reads `/proc/loadavg` and
uptime every N seconds, logs to the journal and reports readiness with `sd_notify()` (from
`libsystemd`, found through `pkg-config`). The unit is `Type=notify` with `WatchdogSec=`. There are
no smart-home protocols.

### Items and the breaks they are designed to show

| # | Kirkstone-era code (deliberate) | Predicted break | Release | Guide section |
|---|---|---|---|---|
| 1 | `demod_git.bb`: `S = "${WORKDIR}/git"` | Fatal: `Recipes that set S = "${WORKDIR}/git" ... should remove that assignment` (text found in Wrynose `insane.bbclass`). Fix: delete the line, because the default `S` is `${UNPACKDIR}/${BP}` | 6.0 (introduced 5.3; still works in 5.0 and 5.1) | [5.3: S = ${WORKDIR}/git ... should be removed](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#s-workdir-git-and-s-unpackdir-git-should-be-removed); [5.1 General notes](https://docs.yoctoproject.org/migration-guides/migration-5.1.html#general-notes) |
| 2 | `demod_git.bb`: `install -m 0644 ${WORKDIR}/demod.service ...` | `do_install` cannot find the file, because `file://` sources now unpack to `${UNPACKDIR}` (`WORKDIR/sources` in Wrynose `bitbake.conf`; corrected). Fix: `${UNPACKDIR}/demod.service` | 6.0 (introduced 5.1) | [5.1: WORKDIR references in recipes](https://docs.yoctoproject.org/migration-guides/migration-5.1.html#workdir-references-in-recipes) |
| 3 | ~~`SRC_URI` with no `branch=`~~ **Dropped in session 2.** With no `branch=`, the Kirkstone fetcher (bitbake 2.0 `fetch2/git.py`) warns, uses `master`, then requires `SRCREV` to be on `master`. This repo only has `main`, so the fetch would fail on Kirkstone itself. The recipe sets `branch=main` from the start, so this break cannot occur | n/a (5.2 rule) | [5.2: Branch parameter now required](https://docs.yoctoproject.org/migration-guides/migration-5.2.html#git-fetcher-branch-parameter-now-required-in-src-uri) |
| 4 | `demod_git.bb`: `DEPENDS = "systemd pkgconfig-native"` with no `inherit pkgconfig`; the Makefile calls `pkg-config --cflags --libs libsystemd` | `PKG_CONFIG_PATH`/`PKG_CONFIG_SYSROOT_DIR` are no longer exported globally, so pkg-config does not find the target `libsystemd`, and the `pkgconfig` recipe is replaced by `pkgconf`. Fix: `inherit pkgconfig`, drop `pkgconfig-native` | 6.0 | [6.0: pkgconfig variables no longer exported](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#ref-classes-pkgconfig-related-variables-are-no-longer-automatically-exported); [6.0 Removed recipes (pkgconfig)](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#removed-recipes) |
| 5 | `demod_git.bb`: `PV = "1.0+git${SRCPV}"` | No break expected: `SRCPV` is still defined as `""` in Wrynose `bitbake.conf`. Clean-up only, recorded as "no break" | 5.0 / 6.0 | [4.3: Versioning changes](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#versioning-changes) |
| 6 | `demod_git.bb`: one assignment written `EXTRA_OEMAKE="..."` (no spaces) | Warning `lack of whitespace around the assignment`. Fix the root cause by adding spaces, not by hiding the warning | 6.0 (introduced 5.3) | [5.3: Space around equal assignment](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#space-around-equal-assignment) |
| 7 | `demod.service` installed with `inherit systemd`, `SYSTEMD_SERVICE:${PN}` | Expected to keep working (control item). Watch for the `Also=` packaging change | 6.0 (5.2) | [5.2: systemd changes](https://docs.yoctoproject.org/migration-guides/migration-5.2.html#systemd-changes) |
| 8 | `linux-yocto_5.15.bbappend` (version-pinned name), adding `file://demo.cfg` (softdog watchdog plus a few generic options) | Scarthgap has only `linux-yocto_6.6.bb`, so parsing fails with a dangling-bbappend error. Fix: rename to `linux-yocto_%.bbappend`. A `BB_DANGLINGAPPENDS_WARNONLY` workaround is not allowed: it silences the error, and 5.2 removes it anyway | 5.0 | [4.3 Removed recipes (linux-yocto 5.15)](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#removed-recipes); [5.0 Removed recipes (6.1)](https://docs.yoctoproject.org/migration-guides/migration-5.0.html#removed-recipes); [5.2 Removed variables](https://docs.yoctoproject.org/migration-guides/migration-5.2.html#removed-variables) |
| 9 | `demo.conf`: `KERNEL_IMAGETYPE = "fitImage"`, `KERNEL_CLASSES += "kernel-fitimage"`, `UBOOT_LOADADDRESS = "0x40080000"`, `UBOOT_ENTRYPOINT = "0x40080000"`, `QB_DEFAULT_KERNEL = "Image"` (see the note below) | The `kernel-fitimage` class is removed and `fitImage` is no longer valid for `KERNEL_IMAGETYPE`. Fix: drop both, add `KERNEL_CLASSES += "kernel-fit-extra-artifacts"`, build `linux-yocto-fitimage` and set `KERNEL_DEPLOY_DEPEND = "linux-yocto-fitimage:do_deploy"` | 6.0 (introduced 5.3) | [5.3: fitImage no longer supported for KERNEL_IMAGETYPE](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#fitimage-no-longer-supported-for-kernel-imagetype); [5.3 Removed classes](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#removed-classes) |
| 10 | `demo.conf`: `INHERIT += "cve-check"` | The class is gone. Fix: `OE_FRAGMENTS += "core/yocto/sbom-cve-check"`. The output changes to `.sbom-cve-check.yocto.json` and `.spdx.json` | 6.0 | [6.0: cve-check class removed](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#cve-check-class-removed) |
| 11 | `demo.conf`: hand-rolled systemd setup, as in many Kirkstone BSPs: `DISTRO_FEATURES:append = " systemd"`, `DISTRO_FEATURES_BACKFILL_CONSIDERED += "sysvinit"`, `VIRTUAL-RUNTIME_init_manager = "systemd"`, `VIRTUAL-RUNTIME_initscripts = "systemd-compat-units"` (instead of `INIT_MANAGER`) | Scarthgap's systemd recipe has `REQUIRED_DISTRO_FEATURES += "usrmerge"`, so systemd is skipped and the image fails. Root-cause fix: `INIT_MANAGER = "systemd"`, whose include adds `usrmerge`. If we chose the minimal fix (just adding `usrmerge`), Wrynose would then fail on the renamed `DISTRO_FEATURES_BACKFILL_CONSIDERED` and the dropped `systemd-compat-units`. With the root-cause fix, those should not appear, and the log will show which happened | 5.0 (from 4.3); 6.0 follow-ons | [4.3: systemd changes](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#systemd-changes); [6.0: DISTRO_FEATURES/MACHINE_FEATURES defaults](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#changes-in-how-default-distro-features-and-machine-features-are-provided); [6.0: SysVinit compat dropped](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#support-for-sysvinit-compatibility-in-systemd-was-dropped) |
| 12 | `demo-image.bb`: `inherit core-image`, `IMAGE_INSTALL += "demod"`, `EXTRA_IMAGE_FEATURES += "debug-tweaks"` (needed so the boot test can log in as root) | `debug-tweaks` is no longer a valid image feature. Fix: `allow-empty-password allow-root-login empty-root-password post-install-logging` | 6.0 (introduced 5.2) | [5.2: debug-tweaks removed](https://docs.yoctoproject.org/migration-guides/migration-5.2.html#debug-tweaks-removed-from-image-features) |
| 13 | `scripts/build.sh` measures `demo-image-qemuarm64.ext4` | Image names gain `.rootfs`, so the script cannot find the file. Fix: read the name from the build, not a hard-coded pattern | 5.0 (from 4.3) | [4.3: Output file naming changes](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#output-file-naming-changes) |
| 14 | `conf/layer.conf`: `LAYERSERIES_COMPAT_demo = "kirkstone"` | Layer is not compatible with `scarthgap` or `wrynose`. Fix: set the real series, never `LAYERSERIES_CORENAMES` | 5.0, 6.0 | [4.2: LAYERSERIES_COMPAT](https://docs.yoctoproject.org/migration-guides/migration-4.2.html#layerseries-compat-for-custom-layers-and-devtool-workspace) |

**Expected changes that are not breaks** (record them in RESULTS.md as measured, not as breaks):
- Wrynose turns on `multiarch opengl ptest vulkan wayland` by default ([6.0](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#changes-to-the-list-of-distro-features-enabled-by-default)). This affects build time and image size. Whether to opt out through `DISTRO_FEATURES_OPTED_OUT` is a session 4 decision, logged with numbers.
- The Poky motd warning in 5.0 ([5.0](https://docs.yoctoproject.org/migration-guides/migration-5.0.html#motd-message-when-using-distro-poky)) does not apply, because we use our own `demo` distro.

**Note on FIT plus QEMU (item 9).** qemuarm64 boots with `-kernel` directly. There is no U-Boot in
the runqemu flow, so a FIT image cannot be booted there. The Kirkstone class picks `Image` as the
replacement type for arm64 (`get_fit_replacement_type` in kirkstone `kernel-fitimage.bbclass`).
Session 2 must confirm that `Image` is still deployed for runqemu and verify the FIT with
`dumpimage -l`. Booting the FIT is a known limit and goes in the README. The addresses already use
the `0x` form, so the 5.2 [UBOOT_ENTRYPOINT change](https://docs.yoctoproject.org/migration-guides/migration-5.2.html#uboot-entrypoint-changes)
should not bite, and the plan does not fake it.

**Considered and left out** (guide items that our layer does not use, so they cannot honestly break):
patch Upstream-Status QA ([4.2](https://docs.yoctoproject.org/migration-guides/migration-4.2.html#patch-qa-checks), [4.3](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#layername-override-implications)) because the layer carries no recipe patches (the one oe-core patch, W10, came later and is applied by kas, not by a recipe);
`CVE_CHECK_IGNORE` → `CVE_STATUS` ([4.3](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#deprecated-variables)) because inventing a CVE ID would be fabricated;
WIC file location ([6.0](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#wic-kickstart-files-to-be-moved-under-files-wic)) because we have no WKS files;
multiple git revisions per URL ([5.2](https://docs.yoctoproject.org/migration-guides/migration-5.2.html#git-fetcher-support-for-multiple-revisions-per-url-removed)).

---

## 2. kas files

Shared settings for all three: `machine: qemuarm64`, `distro: demo`, target `demo-image`. `DL_DIR`
and `SSTATE_DIR` come from the environment (kas-container forwards both), and the build and work
dirs sit outside the repo. Pins use `branch` plus `commit` (kas format 14, which both kas 4.8.2
and 5.5 understand).

### kas/kirkstone.yml
```yaml
header:
  version: 14
machine: qemuarm64
distro: demo
target: demo-image
repos:
  meta-demo:                     # this repo, mounted at /repo
    layers:
      meta-demo:
  poky:
    url: https://git.yoctoproject.org/poky
    branch: kirkstone
    commit: 93431249a6260da7bd29ee3ca32145d89e5b8259   # yocto-4.0.35
    layers:
      meta:
      meta-poky:
      meta-yocto-bsp:
local_conf_header:
  demo: |
    INHERIT += "rm_work"
    RM_WORK_EXCLUDE += "demod"
```

### kas/scarthgap.yml
This is the same file with `branch: scarthgap` and `commit: 4fb7016a07507683359ebd620f1951fd5ea44bfa` (yocto-5.0.21).

### kas/wrynose.yml: separate repositories, no Poky
Per [5.3: The Poky repository master branch is no longer updated](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#the-poky-repository-master-branch-is-no-longer-updated)
and [Setting Up the Poky Reference Distro Manually](https://docs.yoctoproject.org/wrynose/dev-manual/poky-manual-setup.html):
```yaml
header:
  version: 14
machine: qemuarm64
distro: demo
target: demo-image
repos:
  meta-demo:
    layers:
      meta-demo:
  bitbake:
    url: https://git.openembedded.org/bitbake
    branch: "2.18"
    commit: 51fd94a67fa17650a9ff623492005972bbc7d26f   # yocto-6.0.4
    layers:
      .: excluded
  openembedded-core:
    url: https://git.openembedded.org/openembedded-core
    branch: wrynose
    commit: 0f03c732a0a2d0506b41b1abe60b3f368b2300dc   # yocto-6.0.4
    layers:
      meta:
  meta-yocto:
    url: https://git.yoctoproject.org/meta-yocto
    branch: wrynose
    commit: 7c25b11156553145fa6b241a2d4f65d94438f804   # yocto-6.0.4
    layers:
      meta-poky:
      meta-yocto-bsp:
```
To verify in session 4: kas finds `oe-init-build-env` in `openembedded-core`, and that script
finds BitBake in the sibling `bitbake` checkout.

### The same Wrynose build with bitbake-setup (official tool)
From the [Wrynose Quick Build](https://docs.yoctoproject.org/wrynose/brief-yoctoprojectqs/index.html#install-and-use-bitbake-setup):
```bash
# session 4: the kas image has no python3-venv, so bitbake-setup runs from a bitbake checkout
git clone -b 2.18 https://git.openembedded.org/bitbake && export PATH="$PWD/bitbake/bin:$PATH"
bitbake-setup init --non-interactive poky-wrynose poky distro/poky machine/qemuarm64
source <top-dir>/bitbake-builds/poky-wrynose/build/init-build-env
bitbake-layers add-layer /path/to/repo/meta-demo
# distro/demo replaces the built-in distro/poky fragment (confirmed in session 4)
bitbake-config-build enable-fragment distro/demo
bitbake-config-build enable-fragment core/yocto/sbom-cve-check
bitbake-config-build enable-fragment core/yocto/root-login-with-empty-password
bitbake demo-image
```
bitbake-setup exists only for 5.3 and later, so Kirkstone and Scarthgap have no equivalent; their
kas files are the reference. The commands above are the core of what worked in session 4. The full sequence, with the BitBake
pin, the `bitbake-setup settings` commands and the `local.conf` additions, is in `docs/BITBAKE-SETUP.md`.

---

## 3. Containers, checked against each supported-host list

Host: Ubuntu 24.04.5, 32 CPUs, 62 GB RAM, 1.5 TB free, Docker 29.8.2. Ubuntu 24.04 is on all three
lists, but builds still run in containers as CLAUDE.md requires.

| Release | Container | Base OS | On the supported list? |
|---|---|---|---|
| Kirkstone | `ghcr.io/siemens/kas/kas:4.8.2` via `kas-container` 4.8.2 | Debian 12 (bookworm-slim, from the kas 4.8.2 Dockerfile) | Yes: [Kirkstone 4.0.35 list](https://docs.yoctoproject.org/kirkstone/ref-manual/system-requirements.html#supported-linux-distributions) includes Debian 12 |
| Scarthgap | `ghcr.io/siemens/kas/kas:4.8.2` | Debian 12 | Yes: [Scarthgap 5.0.21 list](https://docs.yoctoproject.org/scarthgap/ref-manual/system-requirements.html#supported-linux-distributions) includes Debian 12 |
| Wrynose | `ghcr.io/siemens/kas/kas:5.5` via `kas-container` 5.5 | Debian 13 (trixie-slim, kas 5.x) | Yes: [Wrynose 6.0.4 list](https://docs.yoctoproject.org/wrynose/ref-manual/system-requirements.html#supported-linux-distributions) includes Debian 13. Python 3.13 meets the 3.9 minimum ([6.0 release notes](https://docs.yoctoproject.org/migration-guides/release-notes-6.0.html#new-features-enhancements-in-yocto-ver)) |

kas 5.x (Debian 13) must not be used for Kirkstone or Scarthgap, because Debian 13 is not on
either list. `scripts/build.sh` picks the kas-container version by release, and both versions are
pinned in `docs/VERSIONS.md`. A fallback for all three is CROPS `crops/poky:ubuntu-22.04`, since
22.04 is on all three lists.

---

## 4. Checks per session, and disk estimate

| Session | Check (the evidence to paste) |
|---|---|
| 2 Kirkstone | `kas-container build` exit 0. `runqemu nographic` log shows `qemuarm64 login:`. Captured `systemctl status demod` shows `active (running)`. `dumpimage -l fitImage` lists the kernel. The cve-check report file exists. Image size and build time are taken from the log. Commit and tag `kirkstone-baseline` |
| 3 Scarthgap | Each break: exact error from our log, then a MIGRATION_LOG entry (release, error, root cause, fix, link). Final: exit 0, login line, `active (running)`. RESULTS.md: time, size, break count. Tag `scarthgap-migrated` |
| 4 Wrynose | Same loop. Items 1, 2, 3, 4, 9, 10, 12 confirmed from our own log or recorded as "did not occur". bitbake-setup run once, with its output in `docs/BITBAKE-SETUP.md`. `.sbom-cve-check.yocto.json` exists. Tag `wrynose-migrated` |
| 5 i.MX 91 | NXP repo sync on `imx-linux-scarthgap` / `imx-6.6.36-2.1.0.xml` works. MACHINE choice explained. Image built. You flash it. Your serial log shows login and `demod` running. No NXP or EULA files committed |
| 6 Publish | shellcheck and oelint-adv CI green. Review subagent reports no gaps |

**Disk estimate** (an estimate, not measured; session 2 to 4 replace it with `du -sh` numbers in RESULTS.md):

| Item | Per release | Total for 3 |
|---|---|---|
| DL_DIR (shared; little overlap because versions differ; the kernel git clone is the largest item) | 8–15 GB | 25–40 GB |
| SSTATE_DIR (shared, separate per release) | 8–15 GB | 25–45 GB |
| TMPDIR with `rm_work` (without it: 50–70 GB each) | 20–30 GB | 60–90 GB |
| kas work dirs (layer clones) | 1–2 GB | 3–6 GB |
| **Total** | | **about 115–180 GB** (1.5 TB free on the host) |

Paths outside the repo: `~/yocto-cache/{downloads,sstate}`, `~/yocto-builds/<release>/` for
the build and work dirs. `.gitignore` also blocks `build/ downloads/ sstate-cache/ tmp/`.

---

## 5. Open points for you to confirm before session 2

1. The daemon source goes in this repo and is fetched with `protocol=file` (section 1). The
   alternative is a separate public `demod` repo.
2. ~~Deliberate warning debt from the missing `branch=`~~: dropped, see item 3.
3. Item 11: take the root-cause fix (`INIT_MANAGER`) in Scarthgap, which means the 6.0 BACKFILL
   rename probably never appears.
