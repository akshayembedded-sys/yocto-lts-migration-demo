# Migrating a Yocto layer from Kirkstone to Wrynose: what actually breaks

Yocto 4.0 Kirkstone is now end of life ([Yocto releases](https://wiki.yoctoproject.org/wiki/Releases)). If your product still builds on it, the next LTS releases
are 5.0 Scarthgap and 6.0 Wrynose. I wanted to know what that move costs for an ordinary product
layer, so I built one and measured it, without guessing from release notes.

The layer, `meta-demo`, is deliberately ordinary. It has:

- a small C daemon that reports to systemd through `sd_notify`, with its service file;
- a kernel config fragment;
- a FIT kernel image;
- CVE scanning;
- an image recipe.

It was written in a typical Kirkstone style. The target is QEMU `qemuarm64`, and each release builds in
a container whose distro that release supports. Before any build, I wrote down the breaks I expected
from the official migration guides. Then I built, fixed one error at a time, and recorded each one with
its log file. Everything below comes from those logs and the guides. The repository has the full
entries and the evidence: `docs/MIGRATION_LOG.md` has each error, root cause, fix and guide link.

## Kirkstone to Scarthgap: four breaks, all predicted

Scarthgap was the easy step. It took four fixes, and the guides predicted every one.

**The layer series** ([4.2](https://docs.yoctoproject.org/migration-guides/migration-4.2.html#layerseries-compat-for-custom-layers-and-devtool-workspace)). The first error is always the same:
`Layer demo is not compatible with the core layer which only supports these series: scarthgap`.
`LAYERSERIES_COMPAT` names the releases a layer claims to support, and BitBake refuses anything else.
The fix is one line.

**A version-pinned bbappend** ([4.3](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#removed-recipes)). `linux-yocto_5.15.bbappend` no longer matched any recipe, because
Scarthgap's poky ships only `linux-yocto_6.6`. The build stopped with `No recipes in default available for`
the append. The fragment it adds only sets generic options, so the fix was to rename it to
`linux-yocto_%.bbappend`. Setting `BB_DANGLINGAPPENDS_WARNONLY` would only have hidden the error.

**systemd and usrmerge** ([4.3](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#systemd-changes)). This one is instructive. The distro enabled systemd by hand: it appended it
to `DISTRO_FEATURES` and set the runtime variables itself. In Scarthgap the systemd recipe requires the
`usrmerge` distro feature, and it was simply skipped:
`systemd was skipped: missing required distro feature 'usrmerge'`.
Adding `usrmerge` would have built, but the hand-written copy would keep drifting from oe-core.
`INIT_MANAGER = "systemd"` pulls in oe-core's own include, which already sets both features.
The lesson: whatever you copied from oe-core is what breaks.

**Output names** ([4.3](https://docs.yoctoproject.org/migration-guides/migration-4.3.html#output-file-naming-changes)). Since 4.3, `IMAGE_LINK_NAME` includes `.rootfs`, so my build script, which had the
Kirkstone file name hard-coded, could not find the image. The script now asks BitBake with
`bitbake-getvar` instead of guessing. That choice paid off again in Wrynose.

## Scarthgap to Wrynose: ten breaks, two not predicted

Wrynose changes more. It has no Poky repository ([5.3](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#the-poky-repository-master-branch-is-no-longer-updated)): BitBake, openembedded-core and meta-yocto are
separate checkouts. It took ten fixes, and eight of them were in the guides.

**Removed classes** ([6.0](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#cve-check-class-removed), [5.3](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#fitimage-no-longer-supported-for-kernel-imagetype)). The `cve-check` class is gone. Scanning is now done by `sbom-cve-check` on the SPDX
output, and it is enabled through a configuration fragment, `core/yocto/sbom-cve-check`. The detail that
cost time: fragments are processed before the distro configuration is read, so setting `OE_FRAGMENTS`
in a distro file has no effect. It belongs in `local.conf` or `toolcfg.conf`, which is where
`bitbake-config-build enable-fragment` writes it. The `kernel-fitimage` class is also gone. A separate
recipe, `linux-yocto-fitimage`, builds the FIT from artifacts the kernel deploys, and the kernel itself
goes back to a plain image.

**Recipe hygiene that is now enforced** ([5.1](https://docs.yoctoproject.org/migration-guides/migration-5.1.html#workdir-references-in-recipes), [5.2](https://docs.yoctoproject.org/migration-guides/migration-5.2.html#debug-tweaks-removed-from-image-features), [5.3](https://docs.yoctoproject.org/migration-guides/migration-5.3.html#s-workdir-git-and-s-unpackdir-git-should-be-removed)). Several things that used to work are now errors:

- `S = "${WORKDIR}/git"` is fatal. oe-core's default `S` now points into `UNPACKDIR`.
- `file://` sources unpack into `${UNPACKDIR}`, not `${WORKDIR}`, so `do_install` could not find the
  service file.
- `EXTRA_OEMAKE="..."` with no spaces around `=` produces a warning.
- `debug-tweaks` no longer exists. I did not swap in the four replacement features. Instead I moved root
  login out of the image recipe and into the oe-core fragment `core/yocto/root-login-with-empty-password`,
  enabled only in the test build. The old setup had been putting an empty root password into the
  product image.

The `S` error needed more than deleting one line. The recipe fetches a subdirectory of a git repo, and
with `subpath=` set the fetcher's default destination is the subdirectory's name. So the source also had
to be unpacked to `${BP}`, which is where the new default `S` points.

**pkg-config** ([6.0](https://docs.yoctoproject.org/migration-guides/migration-6.0.html#ref-classes-pkgconfig-related-variables-are-no-longer-automatically-exported)). The daemon compiled but failed to link:
`Package libsystemd was not found in the pkg-config search path` and
`undefined reference to 'sd_notify'`. In Wrynose the pkg-config variables are exported only by
`pkgconfig.bbclass`. The recipe had `pkgconfig-native` in `DEPENDS` and never inherited the class.
It worked up to Scarthgap only because those variables used to be exported globally. `inherit pkgconfig` fixed it.

**The two the guides did not predict.**

- **Compressed QEMU images.** QEMU images are now `.ext4.zst`. runqemu refused to boot one:
  `.zst images are only supported with snapshot mode`. This is in the [5.3 release notes](https://docs.yoctoproject.org/migration-guides/release-notes-5.3.html#new-features-enhancements-in-yocto-ver),
  not in a migration guide. The boot test now runs in snapshot mode, and the build script asks BitBake for the
  image type as well as the name.
- **An upstream regression.** A backported fix ([oe-core b9f060ea6d](https://git.openembedded.org/openembedded-core/commit/?id=b9f060ea6d54cc419df9ff5f8822a3536934606f)) made `sbom-cve-check` build the SBOM path from
  `IMAGE_NAME`, which contains a timestamp that is not part of task signatures. The fragment sets the
  CVE database recipes to `AUTOREV`. So when those databases moved upstream, the check reran on its own
  and looked for an SBOM file name with a new timestamp that did not exist. The build passed the first
  time and failed on a later rebuild. I carry a small oe-core patch, applied by kas, that reads the
  SBOM through `IMAGE_LINK_NAME`.

## What it cost

All builds ran on the same host, a 32-CPU machine:

| Release | Time | Tasks | Image (uncompressed, MiB) | Breaks |
|---|---|---|---|---|
| Kirkstone | 9765 s | 4171 | 101.2 | 0 |
| Scarthgap | 3446 s | 5735 | 133.1 | 4 |
| Wrynose | about 5471 s, summed over attempts | 5773 | 153.9 | 10 |

The times are not strictly comparable, because the later builds reused downloads. The image grew at
each step. I did not measure why, so I am not claiming a cause.

## What I would tell a team planning this

1. **Read the 4.1–6.0 migration guides before the first build.** They predicted 12 of the 14 breaks.
2. **Expect a few surprises.** Read the release notes too, and budget time for an upstream bug.
3. **Do not copy oe-core into your layer.** Hand-written systemd setup and hard-coded file names broke;
   `INIT_MANAGER` and `bitbake-getvar` did not.
4. **Keep test settings out of product recipes.** Wrynose's configuration fragments make that easy.
5. **Tag each release before you move on.** The layer can only target one series at a time, so the
   tags are the only way to rebuild the old versions.

Wrynose also brings `bitbake-setup`, the official alternative to kas ([Quick Build](https://docs.yoctoproject.org/wrynose/brief-yoctoprojectqs/index.html)). I built the same image with it
once. One thing to know: its default `poky-wrynose` configuration follows branch heads, not the release
tag. So if you need a reproducible build, record the revisions it writes out.
