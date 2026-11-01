# Building demo-image on Wrynose with bitbake-setup

The main Wrynose build uses kas (`kas/wrynose.yml`). This page records one build of the same image with
`bitbake-setup`, the setup tool that comes with BitBake from 5.3 on
([5.3 release notes](https://docs.yoctoproject.org/migration-guides/release-notes-5.3.html);
[Wrynose Quick Build](https://docs.yoctoproject.org/wrynose/brief-yoctoprojectqs/index.html#install-and-use-bitbake-setup)).
Everything here comes from one run on 2026-10-31: `scripts/bitbake-setup-build.sh`, full log
`logs/bitbake-setup-20261031-133501.log` (local only), trimmed evidence in `logs/bitbake-setup-evidence.txt`.
The oe-core line check and the kas entrypoint lines are in `logs/source-facts-evidence.txt`.

Result: `BITBAKE_SETUP_EXIT=0`, `NOTE: Tasks Summary: Attempted 5773 tasks of which 1151 didn't need to be rerun and all succeeded.`

## Commands that worked

The commands run inside the kas 5.5 image (Debian 13), as the host user, with `/top` as the work dir:

```bash
git clone -b 2.18 https://git.openembedded.org/bitbake bitbake
git -C bitbake checkout 51fd94a67fa17650a9ff623492005972bbc7d26f   # yocto-6.0.4, as in kas/wrynose.yml
export PATH="$PWD/bitbake/bin:$PATH"
bitbake-setup settings set --global default top-dir-prefix /top
bitbake-setup settings set --global default dl-dir /downloads
bitbake-setup init --non-interactive poky-wrynose poky distro/poky machine/qemuarm64
. /top/bitbake-builds/poky-wrynose/build/init-build-env
bitbake-layers add-layer /repo/meta-demo
bitbake-config-build enable-fragment distro/demo
bitbake-config-build enable-fragment core/yocto/sbom-cve-check
bitbake-config-build enable-fragment core/yocto/root-login-with-empty-password
cat >> conf/local.conf <<'EOF'
SSTATE_DIR = "/sstate"
BB_HASHSERVE_DB_DIR = "${SSTATE_DIR}"
INHERIT += "rm_work"
EOF
bitbake demo-image
```

`bitbake-config-build list-fragments` then showed:

```
Enabled built-in fragments:
machine/qemuarm64	Sets MACHINE = "qemuarm64"
distro/demo	Sets DISTRO = "demo"
```

and `conf/toolcfg.conf` held
`OE_FRAGMENTS += "machine/qemuarm64 distro/demo core/yocto/sbom-cve-check core/yocto/root-login-with-empty-password"`.
`bitbake-getvar --value DISTRO` printed `demo`.

## Where this differs from the PLAN.md sketch

| PLAN.md | What happened | Why |
|---|---|---|
| `python3 -m venv` + `pip install bitbake-setup` | Run `bitbake-setup` from a BitBake checkout instead | The kas image has no `python3-venv`: `The virtual environment was not created successfully because ensurepip is not available.` The Quick Build page offers the BitBake checkout as the other way to get the tool. |
| `disable-fragment distro/poky`, then `DISTRO = "demo"` in local.conf | `enable-fragment distro/demo` alone | `distro/<name>` is a built-in fragment. Enabling `distro/demo` replaced `distro/poky` in `OE_FRAGMENTS`, as the `init` output says: "enable additional fragments or replace built-in ones (e.g. machine/<name> or distro/<name> ...)". |
| (not in the sketch) | `enable-fragment core/yocto/root-login-with-empty-password` | Same as kas/wrynose.yml, which replaces `debug-tweaks` (MIGRATION_LOG.md W5). |
| `<setup-dir>` | `/top/bitbake-builds/poky-wrynose` | `bitbake-setup` puts setups under `<top-dir-prefix>/bitbake-builds` (`NOTE: Bitbake-setup is using /top/bitbake-builds as top directory.`). |

The kas image's entrypoint runs only kas commands when it maps the user, so the script calls
`bash` directly as the host user (`--entrypoint bash --user $(id -u):$(id -g)`) with `HOME` inside `/top`.

## Layer revisions: newer than 6.0.4

The `poky-wrynose` config in BitBake's `default-registry` tracks branch heads (`"rev": "wrynose"`),
not a release tag. `init` therefore fetched whatever was on the branches that day. It recorded the
result in `config/sources-fixed-revisions.json`:

| Repo | Branch | Revision | `git describe` |
|---|---|---|---|
| bitbake | 2.18 | `6e260eb6ab1631607ea414d9ff8ede1155faa5d9` | yocto-6.0.4-1-g6e260eb6a |
| openembedded-core | wrynose | `ae5a301091f5b0574ea7444aab40b309b6d9f3f2` | yocto-6.0.4-82-gae5a301091 |
| meta-yocto | wrynose | `79b6d87030178bed0088ad3b00aa6dfbabac37c4` | yocto-6.0.4-1-g79b6d870 |
| yocto-docs | wrynose | `197ed05f4f157432e7fcab63ced8df1249217366` | yocto-6.0.4-6-g197ed05f4 |

The kas build is pinned to the 6.0.4 tags (docs/VERSIONS.md). The two builds therefore differ: here the
kernel is `linux-yocto-6.18.54+git`, while the kas build has 6.18.52. To pin a bitbake-setup build
to a release, you need a config file with fixed revisions. A later `bitbake-setup init` can also
reuse the `sources-fixed-revisions.json` above. We did not try either option in this session.

## The W10 patch is not applied here

kas applies `patches/openembedded-core/0001-...` to oe-core. bitbake-setup has no patch step, so this build
used oe-core unpatched. oe-core `ae5a301091` still has the line we patch
(`sbom_path = d.expand("${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.spdx.json")`). The build passed because
`do_sbom_cve_check` ran in the same build as the SBOM, so the timestamp in both names matched.
The failure in MIGRATION_LOG.md W10 shows up only when `do_sbom_cve_check` reruns alone in a later build.
`demo-image-qemuarm64.rootfs.sbom-cve-check.yocto.json` is in the deploy dir.

## Numbers

| | bitbake-setup run |
|---|---|
| Time | 4375 s (1 h 13 min), including clone and `init` |
| sstate | `Wanted 2904 Local 906 Mirrors 0 Missed 1998`: `SSTATE_DIR` is shared with the kas build, so 31 % was reused. Not a from-scratch time. |
| Tasks | 5773, all succeeded |
| `ext4.zst` | 36,317,685 bytes (kas build: 36,321,026) |
| Warnings | 14: 13 sbom-cve-check unpatched CVEs, 1 upstream fetch served from a mirror |
| Boot test | not run for this build. The boot test is done on the kas build (docs/RESULTS.md). |
