# Measured results

All numbers come from our own logs. The trimmed evidence for each release is in `logs/<release>-evidence.txt`.
Host: Ubuntu 24.04.5, 32 CPUs, 62 GB RAM. Builds start from empty DL_DIR and SSTATE_DIR unless noted.

| Release | Build time (from scratch) | Tasks | `demo-image` ext4 size | Warnings | Breaks fixed | Boot test |
|---|---|---|---|---|---|---|
| Kirkstone 4.0.35 (baseline) | 9765 s (2 h 43 min) | 4171 | 106,166,272 bytes (101.2 MiB) | 63: 51 cve-check unpatched CVEs, 12 upstream fetches served from mirrors, 0 from meta-demo | 0 (baseline) | pass: login prompt, `demod` active (running) |
| Scarthgap 5.0.21 | 3446 s (57 min), empty sstate; DL_DIR shared with Kirkstone (see note) | 5735 | 139,569,152 bytes (133.1 MiB) | 29: 23 cve-check unpatched CVEs, 6 upstream fetches served from mirrors, 0 from meta-demo | 4 (S1–S4 in MIGRATION_LOG.md) | pass: login prompt, `demod` active (running), kernel 6.6.151 |

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
