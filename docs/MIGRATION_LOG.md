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
