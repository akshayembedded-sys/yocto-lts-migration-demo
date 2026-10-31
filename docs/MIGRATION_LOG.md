# Migration log

One entry per break, in the order it appeared in our own build logs. Each entry has the release,
the exact error text, the root cause, the fix and the migration-guide link. Warnings are fixed at
their cause; nothing is silenced.

## Scarthgap 5.0.21

Four breaks, all predicted in PLAN.md section 1 (items 14, 8, 11 and 13, in the order they
appeared). The items PLAN.md places in 5.1 or later (1, 2, 4, 6, 9, 10 and 12) did not break here,
as expected: `S = "${WORKDIR}/git"`, `${WORKDIR}/demod.service`, `kernel-fitimage`, `cve-check`
and `debug-tweaks` all still work in 5.0, and the boot test passed with them unchanged. They are
expected to break in session 4. Evidence: `logs/scarthgap-evidence.txt`.

### S1. Layer series not compatible

- **Log:** `logs/scarthgap-20261031-1008.log` (build attempt 1, failed at parse after 62 s)
- **Error:**
  ```
  ERROR: Layer demo is not compatible with the core layer which only supports these series: scarthgap (layer is compatible with kirkstone)
  ```
- **Root cause:** `meta-demo/conf/layer.conf` declares `LAYERSERIES_COMPAT_demo = "kirkstone"`.
  BitBake refuses a layer whose declared series does not include the series of the core layer.
- **Fix:** `LAYERSERIES_COMPAT_demo = "scarthgap"`. The layer now targets Scarthgap only;
  the Kirkstone version stays available at tag `kirkstone-baseline`.
- **Guide:** [4.2: LAYERSERIES_COMPAT for custom layers](https://docs.yoctoproject.org/migration-guides/migration-4.2.html#layerseries-compat-for-custom-layers-and-devtool-workspace)

### S2. Dangling kernel bbappend

- **Log:** `logs/scarthgap-20261031-1009.log` (attempt 2, failed at parse after 26 s)
- **Error:**
  ```
  ERROR: No recipes in default available for:
  /build/../repo/meta-demo/recipes-kernel/linux/linux-yocto_5.15.bbappend
  ```
- **Root cause:** the bbappend's file name pins kernel version 5.15. Scarthgap's poky ships only
  `meta/recipes-kernel/linux/linux-yocto_6.6.bb` (checked in our checkout), so the append matches
  no recipe.
- **Fix:** rename it to `linux-yocto_%.bbappend`. The config fragment `demo.cfg` only sets generic
  options (`CONFIG_SOFT_WATCHDOG`, `CONFIG_IKCONFIG_PROC`), so it does not depend on the kernel
  version. Setting `BB_DANGLINGAPPENDS_WARNONLY` would only hide the error, and 5.2 removes it.
- **Guide:** [4.3: Removed recipes (linux-yocto 5.15)](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#removed-recipes);
  [5.0: Removed recipes](https://docs.yoctoproject.org/migration-guides/migration-5.0.html#removed-recipes)

### S3. systemd skipped: missing `usrmerge`

- **Log:** attempt 3, failed at parse after 4 s (`BUILD_EXIT=2`). The file `logs/scarthgap-20261031-1010.log`
  was overwritten by attempt 4, which started in the same minute; `build.sh` now adds seconds to
  the log name. The error lines below were copied from attempt 3's output before that happened.
- **Error:**
  ```
  ERROR: Nothing PROVIDES 'systemd' (but /build/../repo/meta-demo/recipes-demo/demod/demod_git.bb DEPENDS on or otherwise requires it)
  systemd was skipped: missing required distro feature 'usrmerge' (not in DISTRO_FEATURES)
  ERROR: Required build target 'demo-image' has no buildable providers.
  Missing or unbuildable dependency chain was: ['demo-image', 'demod', 'systemd']
  ```
- **Root cause:** Scarthgap's `systemd` recipe has `REQUIRED_DISTRO_FEATURES += "usrmerge"`.
  `demo.conf` enabled systemd by hand (`DISTRO_FEATURES:append = " systemd"` plus three
  `VIRTUAL-RUNTIME`/backfill lines) instead of using `INIT_MANAGER`, so it never picked up the
  new requirement. Scarthgap's `meta/conf/distro/include/init-manager-systemd.inc` sets
  `DISTRO_FEATURES:append = " systemd usrmerge"` and the same runtime variables.
- **Fix:** replace the four hand-rolled lines with `INIT_MANAGER = "systemd"`. Adding only
  `usrmerge` would also build, but it keeps the hand-rolled copy, which drifts from oe-core again
  in 6.0 (PLAN.md item 11).
- **Guide:** [4.3: systemd changes](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#systemd-changes)

### S4. `build.sh` cannot find the image: `.rootfs` in link names

- **Log:** `logs/scarthgap-20261031-1010.log` (attempt 4: bitbake succeeded, the script failed)
- **Error:**
  ```
  NOTE: Tasks Summary: Attempted 5735 tasks of which 0 didn't need to be rerun and all succeeded.
  BUILD_EXIT=0
  IMAGE_FILE=not found: /home/akshay-p/yocto-builds/scarthgap/build/tmp/deploy/images/qemuarm64/demo-image-qemuarm64.ext4
  ```
- **Root cause:** since 4.3, `IMAGE_LINK_NAME` includes `IMAGE_NAME_SUFFIX` (`.rootfs`), so the
  deploy link is now `demo-image-qemuarm64.rootfs.ext4`. `build.sh` hard-coded the Kirkstone
  link name.
- **Fix:** `build.sh` asks bitbake for the name
  (`bitbake-getvar --value -r demo-image IMAGE_LINK_NAME`, which prints `demo-image-qemuarm64.rootfs`)
  instead of guessing a pattern, so it works on every release.
- **Guide:** [4.3: Output file naming changes](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#output-file-naming-changes)

## Wrynose 6.0.4

Wrynose has no Poky repository. `kas/wrynose.yml` checks out `bitbake` (branch 2.18),
`openembedded-core` and `meta-yocto` separately, and kas 5.5 is used because its Debian 13 image
is on the Wrynose supported-host list (PLAN.md section 3).

Ten breaks. Eight were predicted in PLAN.md: W1 (item 14), W2 (10), W3 (9), W4 (6), W5 (12),
W6 (1), W7 (4), W8 (2). Two were not: W9 (qemu images are now `.ext4.zst`) and W10 (an upstream
regression in `sbom-cve-check.bbclass`, carried as a patch). There are also two tooling notes
that are not breaks. Items that did **not** break, as expected: 5 (`SRCPV` is still defined),
7 (`inherit systemd` and `SYSTEMD_SERVICE` still work; the service runs), and the 6.0 follow-ons
of item 11 (`DISTRO_FEATURES_BACKFILL_CONSIDERED`, `systemd-compat-units`): they did not appear,
because S3 replaced the hand-rolled lines with `INIT_MANAGER`. Item 3 was dropped in session 2.
Since `meta-demo` on `main` now declares `LAYERSERIES_COMPAT_demo = "wrynose"`, the Kirkstone and
Scarthgap builds are reproduced from the tags `kirkstone-baseline` and `scarthgap-migrated`.
Evidence: `logs/wrynose-evidence.txt`.

### Tooling note (not a layer break): deprecated kas value

- **Log:** `logs/wrynose-20261031-113727.log` (attempt 1)
- **Warning:**
  ```
  WARNING  - Use of deprecated value "excluded" for repo "bitbake", layer ".". Replace with "disabled".
  ```
- **Root cause:** PLAN.md used `.: excluded` to stop kas adding the bitbake checkout as a layer.
  kas 5.5 names that value `disabled`.
- **Fix:** `.: disabled` in `kas/wrynose.yml`. Only the Wrynose file uses this key, and only
  kas 5.5 reads it.

### W1. Layer series not compatible

- **Log:** `logs/wrynose-20261031-113727.log` (attempt 1, failed at parse after 156 s, most of it the
  three git clones)
- **Error:**
  ```
  ERROR: Layer demo is not compatible with the core layer which only supports these series: wrynose (layer is compatible with scarthgap)
  ```
- **Root cause:** same as S1: `LAYERSERIES_COMPAT_demo = "scarthgap"`.
- **Fix:** `LAYERSERIES_COMPAT_demo = "wrynose"`. The Scarthgap version stays at tag `scarthgap-migrated`.
- **Guide:** [4.2: LAYERSERIES_COMPAT for custom layers](https://docs.yoctoproject.org/migration-guides/migration-4.2.html#layerseries-compat-for-custom-layers-and-devtool-workspace)

### W2. `cve-check` class removed

- **Log:** `logs/wrynose-20261031-114029.log` (attempt 2, failed at parse after 2 s)
- **Error:**
  ```
  ERROR: Unable to parse /work/bitbake/lib/bb/parse/parse_py/BBHandler.py
  bb.parse.ParseError: ParseError in configuration INHERITs: Could not inherit file classes/cve-check.bbclass
  ```
- **Root cause:** `demo.conf` has `INHERIT += "cve-check"`. Wrynose removes the class; CVE scanning
  is now done by `sbom-cve-check` on the SPDX output, enabled by the configuration fragment
  `meta/conf/fragments/yocto/sbom-cve-check.conf` (it sets `INHERIT += "create-spdx"` and
  `IMAGE_CLASSES:append = " sbom-cve-check"`).
- **Fix:** drop the `INHERIT` line from `demo.conf` and add
  `OE_FRAGMENTS += "core/yocto/sbom-cve-check"` to the `local_conf_header` in `kas/wrynose.yml`.
  It cannot go in `demo.conf`: in Wrynose `bitbake.conf` the `addfragments` line comes after
  `local.conf` and `toolcfg.conf` but before the distro conf is included, so a distro-level
  `OE_FRAGMENTS` is read too late. `bitbake-config-build enable-fragment` writes the same line to
  `toolcfg.conf`.
- **Guide:** [6.0: cve-check class removed](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#cve-check-class-removed)

### W3. `kernel-fitimage` class removed

- **Log:** `logs/wrynose-20261031-114109.log` (attempt 3, failed at parse after 13 s)
- **Error:**
  ```
  ERROR: ParseError at /build/../work/openembedded-core/meta/classes-recipe/kernel.bbclass:185: Could not inherit file classes/kernel-fitimage.bbclass
  ```
- **Root cause:** `demo.conf` adds `kernel-fitimage` to `KERNEL_CLASSES` (which `kernel.bbclass`
  inherits) and sets `KERNEL_IMAGETYPE = "fitImage"`. Since 5.3 the kernel recipe no longer builds
  the FIT: the separate recipe `meta/recipes-kernel/linux/linux-yocto-fitimage.bb`
  (`inherit kernel-fit-image`) does, from artifacts the kernel deploys through
  `kernel-fit-extra-artifacts` (`kernel-fit-image.bbclass` line 221:
  `do_compile[depends] += "virtual/kernel:do_deploy"`).
- **Fix:** in `demo.conf`, `KERNEL_CLASSES += "kernel-fit-extra-artifacts"` and
  `KERNEL_DEPLOY_DEPEND = "linux-yocto-fitimage:do_deploy"` (the image's `do_build` depends on it,
  per `image.bbclass` line 150). The `KERNEL_IMAGETYPE`, `KERNEL_IMAGETYPES += "Image"` and
  `QB_DEFAULT_KERNEL = "Image"` lines are removed: they only existed because `KERNEL_IMAGETYPE`
  was `fitImage`, and qemuarm64 already sets `KERNEL_IMAGETYPE = "Image"`, which `qemuboot.bbclass`
  uses as the default kernel. `UBOOT_LOADADDRESS`/`UBOOT_ENTRYPOINT` stay; `kernel-fit-image`
  still reads them.
- **Guide:** [5.3: fitImage no longer supported for KERNEL_IMAGETYPE](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#fitimage-no-longer-supported-for-kernel-imagetype);
  [5.3: Removed classes](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#removed-classes)

### Configuration note (not a layer break): hash equivalence database location

- **Log:** `logs/wrynose-20261031-114109.log` (attempt 3)
- **Warning:**
  ```
  WARNING: Sstate directory is shared between several builds (it is set via SSTATE_DIR to /sstate),
  but hash equivalency database is inside this particular build directory /build.
  This will prevent sstate reuse, and it is recommended to set the location for the database to a common path
  via BB_HASHSERVE_DB_DIR, for example:
  BB_HASHSERVE_DB_DIR = "${SSTATE_DIR}"
  ```
- **Root cause:** a new check in Wrynose `sanity.bbclass` (line 1052). Our `SSTATE_DIR` is
  shared by design (`scripts/common.sh`), while the database stayed in each build dir. The
  Scarthgap log has no such warning.
- **Fix:** `BB_HASHSERVE_DB_DIR = "${SSTATE_DIR}"` in the `local_conf_header` of
  `kas/wrynose.yml`, as the warning recommends.

### W4. No whitespace around `=`

- **Log:** `logs/wrynose-20261031-114225.log` (attempt 4)
- **Warning:**
  ```
  WARNING: /build/../repo/meta-demo/recipes-demo/demod/demod_git.bb: /build/../repo/meta-demo/recipes-demo/demod/demod_git.bb:21 has a lack of whitespace around the assignment: 'EXTRA_OEMAKE="PREFIX=${prefix}"'
  ```
- **Root cause:** line 21 of `demod_git.bb` is written `EXTRA_OEMAKE="..."`. Since 5.3 BitBake
  warns about assignments with no spaces around the operator.
- **Fix:** `EXTRA_OEMAKE = "PREFIX=${prefix}"`.
- **Guide:** [5.3: Space around equal assignment](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#space-around-equal-assignment)

### W5. `debug-tweaks` is not a valid image feature

- **Log:** `logs/wrynose-20261031-114225.log` (attempt 4, failed at parse after 15 s)
- **Error:**
  ```
  ERROR: Nothing PROVIDES 'demo-image'
  demo-image was skipped: 'debug-tweaks' in IMAGE_FEATURES (added via EXTRA_IMAGE_FEATURES) is not a valid image feature. Valid features: allow-empty-password allow-root-login ... empty-root-password ... post-install-logging ...
  ```
- **Root cause:** `demo-image.bb` adds `debug-tweaks`, which 5.2 removed. It was there only so the
  boot test can log in as root without a password, but putting it in the image recipe also put an
  empty root password into the product image.
- **Fix:** remove it from `demo-image.bb` and enable oe-core's
  `core/yocto/root-login-with-empty-password` fragment in `kas/wrynose.yml`. That fragment sets
  `EXTRA_IMAGE_FEATURES += "allow-empty-password empty-root-password allow-root-login"` for this
  test build only. This differs from PLAN.md item 12, which listed the four replacement features
  for the recipe: the fragment fixes the cause (a test setting in the product recipe) instead of
  renaming it. `post-install-logging`, the fourth part of the old `debug-tweaks`, is not needed by
  the boot test and is left out.
- **Guide:** [5.2: debug-tweaks removed from IMAGE_FEATURES](https://docs.yoctoproject.org/migration-guides/migration-5.2.html#debug-tweaks-removed-from-image-features)

### W6. `S = "${WORKDIR}/git"` is fatal

- **Log:** `logs/wrynose-20261031-114314.log` (attempt 5: the full build started, with empty sstate,
  and stopped after 834 s: `Attempted 1493 tasks of which 0 didn't need to be rerun and 1 failed`)
- **Error:**
  ```
  ERROR: demod-1.0+git-r0 do_unpack: Recipes that set S = "${WORKDIR}/git" or S = "${UNPACKDIR}/git" should remove that assignment, as S set by bitbake.conf in oe-core now works.
  ERROR: Task (/build/../repo/meta-demo/recipes-demo/demod/demod_git.bb:do_unpack) failed with exit code '1'
  ```
- **Root cause:** `demod_git.bb` sets `S = "${WORKDIR}/git"`, which `insane.bbclass` (line 1446)
  now rejects. Wrynose `bitbake.conf` sets `S = "${UNPACKDIR}/${BP}"` and
  `BB_GIT_DEFAULT_DESTSUFFIX = "${BP}"`. Deleting the line alone is not enough for this recipe:
  with `subpath=demod`, the git fetcher's default destsuffix is the subpath's basename
  (`bitbake/lib/bb/fetch2/git.py` line 670), and the recipe also forced `destsuffix=git`, a
  workaround for the same Kirkstone behaviour.
- **Fix:** delete the `S` line and change `destsuffix=git` to `destsuffix=${BP}`, so the source
  unpacks where the default `S` points.
- **Guide:** [5.3: S = ${WORKDIR}/git and S = ${UNPACKDIR}/git should be removed](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#s-workdir-git-and-s-unpackdir-git-should-be-removed);
  [5.1: General notes](https://docs.yoctoproject.org/migration-guides/migration-5.1.html#general-notes)

### W7. pkg-config does not find the target `libsystemd`

- **Log:** `logs/wrynose-20261031-115723.log` (attempt 6, failed after 3962 s:
  `Attempted 5540 tasks of which 1490 didn't need to be rerun and 1 failed`)
- **Error** (from the `do_compile` log printed in the build log):
  ```
  Package libsystemd was not found in the pkg-config search path.
  Perhaps you should add the directory containing `libsystemd.pc'
  to the PKG_CONFIG_PATH environment variable
  Package 'libsystemd' not found
  .../aarch64-poky-linux-ld: /usr/src/debug/demod/1.0+git/demod.c:65:(.text.startup+0x100): undefined reference to `sd_notify'
  ERROR: demod-1.0+git-r0 do_compile: oe_runmake failed
  ```
- **Root cause:** the recipe had `DEPENDS = "systemd pkgconfig-native"` with no `inherit pkgconfig`.
  That worked up to Scarthgap because the pkg-config variables were exported globally. In Wrynose
  only `meta/classes-recipe/pkgconfig.bbclass` exports `PKG_CONFIG_LIBDIR` and
  `PKG_CONFIG_SYSROOT_DIR`, so the Makefile's `pkg-config --cflags --libs libsystemd` found nothing
  and the link failed. `pkgconfig-native` still resolved, because the `pkgconf` recipe has
  `PROVIDES += "pkgconfig"`.
- **Fix:** `inherit pkgconfig systemd` and `DEPENDS = "systemd"`. The class adds `pkgconf-native`
  itself.
- **Guide:** [6.0: pkgconfig-related variables are no longer automatically exported](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#ref-classes-pkgconfig-related-variables-are-no-longer-automatically-exported);
  [6.0: Removed recipes](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#removed-recipes)

### W8. `${WORKDIR}/demod.service` not found in `do_install`

- **Log:** `logs/wrynose-20261031-130409.log` (attempt 7, failed after 97 s; `do_compile` now passes)
- **Error:**
  ```
  | install -D -m 0755 demod /build/tmp/work/cortexa57-poky-linux/demod/1.0+git/image/usr/bin/demod
  | install: cannot stat '/build/tmp/work/cortexa57-poky-linux/demod/1.0+git/demod.service': No such file or directory
  ERROR: Task (/build/../repo/meta-demo/recipes-demo/demod/demod_git.bb:do_install) failed with exit code '1'
  ```
- **Root cause:** `file://` sources are unpacked into `${UNPACKDIR}` (Wrynose `bitbake.conf`:
  `UNPACKDIR ??= "${WORKDIR}/sources"`), not into `${WORKDIR}`. `do_install` still read
  `${WORKDIR}/demod.service`. Scarthgap unpacked into `${WORKDIR}`, which is why it built there.
- **Fix:** `install -m 0644 ${UNPACKDIR}/demod.service ...`.
- **Guide:** [5.1: WORKDIR references in recipes](https://docs.yoctoproject.org/migration-guides/migration-5.1.html#workdir-references-in-recipes)

### W9. Rootfs is now `.ext4.zst`: runqemu refuses it, `build.sh` cannot find it (not predicted)

- **Logs:** `logs/wrynose-20261031-130601.log` (attempt 8: bitbake succeeded, the script failed) and
  `logs/wrynose-boot-20261031-1315.log` (first boot test)
- **Errors:**
  ```
  NOTE: Tasks Summary: Attempted 5773 tasks of which 5552 didn't need to be rerun and all succeeded.
  BUILD_EXIT=0
  IMAGE_FILE=not found: /home/akshay-p/yocto-builds/wrynose/build/tmp/deploy/images/qemuarm64/demo-image-qemuarm64.rootfs.ext4
  ```
  ```
  runqemu - ERROR - .zst images are only supported with snapshot mode. You can either use the "snapshot" option or use an uncompressed image.
  BOOT_TEST_EXIT=1
  ```
- **Root cause:** oe-core commit `aa5f60d1fc` ("bitbake/conf: Default to zstd compressed image
  output") changed `meta/conf/machine/include/qemu.inc` to `IMAGE_FSTYPES += "tar.zst ext4.zst"`
  and `qemuboot.bbclass` to `QB_DEFAULT_FSTYPE ?= "ext4.zst"`. `scripts/runqemu` only decompresses a
  `.zst` rootfs in snapshot mode. Our scripts assumed `.ext4`. PLAN.md did not predict this: the
  change is in the 5.3 release notes, not in a migration guide.
- **Fix:** the boot test runs `runqemu qemuarm64 nographic slirp snapshot` (the Wrynose Quick Build
  also uses `runqemu snapshot`); a test boot does not need to keep its writes. `build.sh` asks
  bitbake for `QB_DEFAULT_FSTYPE` as well as `IMAGE_LINK_NAME`, and for a `.zst` image also prints
  `IMAGE_UNCOMPRESSED_BYTES`, so sizes stay comparable with the older releases. The upstream
  default image types are kept.
- **Source:** [5.3 release notes: default IMAGE_FSTYPES is now tar.zst](https://docs.yoctoproject.org/migration-guides/release-notes-5.3.html#new-features-enhancements-in-yocto-ver);
  [oe-core commit aa5f60d1fc](https://git.openembedded.org/openembedded-core/commit/?id=aa5f60d1fcb716a2b2174dffcaf35442bff1f1fb);
  [Wrynose Quick Build](https://docs.yoctoproject.org/wrynose/brief-yoctoprojectqs/index.html)

### W10. `do_sbom_cve_check` reads an SBOM that was never written (upstream regression, not a layer break)

- **Log:** `logs/wrynose-20261031-131741.log` (attempt 9, a rebuild from sstate after W9)
- **Error** (from the task log):
  ```
  ERROR: demo-image-1.0-r0 do_sbom_cve_check: sbom-cve-check failed: ...
  sbom-cve-check: error: [Errno 2] No such file or directory: '/build/tmp/deploy/images/qemuarm64/demo-image-qemuarm64.rootfs-20261031074746.spdx.json'
  ```
  The deploy dir only had `demo-image-qemuarm64.rootfs-20261031073605.spdx.json`.
- **Root cause:** `meta/classes-recipe/sbom-cve-check.bbclass` line 17 builds the path from
  `${IMAGE_NAME}`, which carries `DATETIME` (excluded from task signatures in
  `image-artifact-names.bbclass` line 13). The `core/yocto/sbom-cve-check` fragment sets the two CVE
  database recipes to `AUTOREV`, so when their upstream repositories move, `do_sbom_cve_check`
  reruns while `do_create_image_sbom_spdx` does not, and the new timestamp does not match the SBOM
  on disk. Every later run picks a new timestamp, so the failure repeats until the image is
  rebuilt. The line came from commit `b9f060ea6d` ("sbom-cve-check: Fix breakage with empty
  IMAGE_LINK_NAME"), cherry-picked to wrynose, which replaced `${IMAGE_LINK_NAME}` with
  `${IMAGE_NAME}`. Upstream master and wrynose still had this line on 2026-10-31.
- **Fix:** `patches/openembedded-core/0001-sbom-cve-check-read-the-SBOM-through-IMAGE_LINK_NAME.patch`,
  applied by kas (`patches:` in `kas/wrynose.yml`). It reads the SBOM through `IMAGE_LINK_NAME`
  when that is set and keeps `IMAGE_NAME` for the empty-link case that `b9f060ea6d` fixed. With the
  patch, attempt 11 (`logs/wrynose-20261031-132534.log`) reran `do_sbom_cve_check` on its own and
  succeeded. The patch is not sent upstream yet.
- **Source:** our logs; [oe-core commit b9f060ea6d](https://git.openembedded.org/openembedded-core/commit/?id=b9f060ea6d54cc419df9ff5f8822a3536934606f);
  [6.0: cve-check class removed](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#cve-check-class-removed)
