# Measured results

All numbers come from our own logs. The trimmed evidence for each release is in `logs/<release>-evidence.txt`.
Host: Ubuntu 24.04.5, 32 CPUs, 62 GB RAM. Builds start from empty DL_DIR and SSTATE_DIR unless noted.

| Release | Build time (from scratch) | Tasks | `demo-image` ext4 size | Warnings | Breaks fixed | Boot test |
|---|---|---|---|---|---|---|
| Kirkstone 4.0.35 (baseline) | 9765 s (2 h 43 min) | 4171 | 106,166,272 bytes (101.2 MiB) | 63: 51 cve-check unpatched CVEs, 12 upstream fetches served from mirrors, 0 from meta-demo | 0 (baseline) | pass: login prompt, `demod` active (running) |
| Scarthgap 5.0.21 | 3446 s (57 min), empty sstate; DL_DIR shared with Kirkstone (see note) | 5735 | 139,569,152 bytes (133.1 MiB) | 29: 23 cve-check unpatched CVEs, 6 upstream fetches served from mirrors, 0 from meta-demo | 4 (S1–S4 in MIGRATION_LOG.md) | pass: login prompt, `demod` active (running), kernel 6.6.151 |
| Wrynose 6.0.4 | about 5471 s (1 h 31 min) summed over attempts 5–8, not one clean run (see note); DL_DIR shared | 5773 | `ext4.zst` 36,321,026 bytes; uncompressed 161,427,456 bytes (153.9 MiB) | 15: all sbom-cve-check unpatched CVEs, 0 from meta-demo (final run) | 10 (W1–W10 in MIGRATION_LOG.md; 8 predicted, 2 not) | pass: login prompt, `demod` active (running), kernel 6.18.52 |

The 51 cve-check warnings are the Kirkstone `cve-check` class reporting unpatched CVEs in the
4.0.35 recipes. They are the expected output of a scan on an end-of-life release, not a fault in
the build. The full report is `demo-image-qemuarm64.cve` in the deploy dir (20.9 MB, not committed).

**Scarthgap notes.** The build log shows `Sstate summary: Wanted 2423 Local 0 Mirrors 0 Missed 2423`,
so every task was built from source. `DL_DIR` was not empty: it held the Kirkstone downloads, so
sources whose versions did not change were not fetched again. The build time is therefore not
directly comparable with the Kirkstone row, which started with an empty `DL_DIR` as well.
The image grew by 33,402,880 bytes (+31.5%) over Kirkstone. This page records the size only; the
cause was not measured (no buildhistory in these builds), so none is claimed here.
The FIT image is still built by the `kernel-fitimage` class (AArch64, load/entry `0x40080000`), and
cve-check still writes `demo-image-qemuarm64.rootfs.cve` (25.9 MB, not committed).

**Wrynose notes.** No single from-scratch build was timed. Attempt 5 started with
`Sstate summary: Wanted 2904 Local 0 Mirrors 0 Missed 2904` and stopped at W6 after 834 s; attempts
6, 7 and 8 continued from its sstate (3962 s, 97 s, 578 s). The sum, 5471 s, is the cost of
building Wrynose from source on this host plus the restarts, so it is an approximation. `DL_DIR`
held the Kirkstone and Scarthgap downloads.
The rootfs is now deployed as `ext4.zst` (MIGRATION_LOG.md W9), so `build.sh` reports both sizes.
Uncompressed, the image grew by 21,858,304 bytes (+15.7%) over Scarthgap. As with Scarthgap, the
cause was not measured, so none is claimed.
`DISTRO_FEATURES` compared with Scarthgap (`bitbake-getvar --value DISTRO_FEATURES`): added
`pulseaudio gobject-introspection-data ldconfig`; dropped `pcmcia usbgadget usbhost`. PLAN.md
expected `multiarch opengl ptest vulkan wayland` to be new in 6.0, but our Scarthgap build already
had all five, because the demo distro requires `poky.conf`. We kept the Wrynose defaults and did
not opt anything out, so the size and time above include them.
CVE output is now `demo-image-qemuarm64.rootfs.sbom-cve-check.yocto.json` (34.3 MB, not committed).

## Disk use after all three builds

Measured with `du -sh` on 2026-10-31, after session 4 (`rm_work` is on for all builds):

| Path | Size |
|---|---|
| `~/yocto-cache/downloads` (DL_DIR, shared) | 21 G |
| `~/yocto-cache/sstate` (SSTATE_DIR, shared) | 12 G |
| Kirkstone `build/tmp` | 7.2 G |
| Scarthgap `build/tmp` | 13 G |
| Wrynose `build/tmp` | 26 G |
| kas work dirs (layer clones), all three | 0.9 G |
| **Total** | **about 80 G** (PLAN.md estimated 115–180 G) |
