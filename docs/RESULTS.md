# Measured results

All numbers come from our own logs. The trimmed evidence for each release is in `logs/<release>-evidence.txt`.
Host: Ubuntu 24.04.5, 32 CPUs, 62 GB RAM. Builds start from empty DL_DIR and SSTATE_DIR unless noted.

| Release | Build time (from scratch) | Tasks | `demo-image` ext4 size | Warnings | Breaks fixed | Boot test |
|---|---|---|---|---|---|---|
| Kirkstone 4.0.35 (baseline) | 9765 s (2 h 43 min) | 4171 | 106,166,272 bytes (101.2 MiB) | 63: 51 cve-check unpatched CVEs, 12 upstream fetches served from mirrors, 0 from meta-demo | 0 (baseline) | pass: login prompt, `demod` active (running) |

The 51 cve-check warnings are the Kirkstone `cve-check` class reporting unpatched CVEs in the
4.0.35 recipes. They are the expected output of a scan on an end-of-life release, not a fault in
the build. The full report is `demo-image-qemuarm64.cve` in the deploy dir (20.9 MB, not committed).
