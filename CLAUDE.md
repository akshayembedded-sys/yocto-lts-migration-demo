# Yocto LTS migration demo: Kirkstone → Scarthgap → Wrynose

Public portfolio repo by Akshay P (embedded Linux / Yocto consultant).
Goal: show, with real build and boot logs, what breaks when a small product layer moves
from Yocto 4.0 Kirkstone (end of life April 2026) to 5.0 Scarthgap and 6.0 Wrynose, and how each break is fixed.
Readers are engineering managers at device makers and BSP hiring managers.

## Ground rules
- IMPORTANT: use only public open-source code and official docs. Never ask for, use or reproduce
  code, configs, logs or designs from the author's current or past employers.
- No smart-home features (KNX, Zigbee, Matter, BLE-Mesh, Thread). The demo is a generic
  industrial-style device: a small C daemon, a systemd service, a kernel config fragment, an image.
- Licences: layer metadata MIT; scripts carry `SPDX-License-Identifier` headers.
- Never commit build/, downloads/, sstate-cache/, tmp/, images or logs larger than 1 MB.
  Keep `.gitignore` current. DL_DIR and SSTATE_DIR live outside the repo.
- Every fact written in docs/ must come from the official migration guides
  (https://docs.yoctoproject.org/migration-guides/) or from our own logs. Link the source.

## Layout (target)
- `meta-demo/`: the product layer under test
- `kas/`: one kas file per release (kirkstone.yml, scarthgap.yml, wrynose.yml)
- `docs/MIGRATION_LOG.md`: one entry per break: release, exact error, root cause, fix, source link
- `docs/VERSIONS.md`: exact layer commits per release
- `docs/RESULTS.md`: measured numbers (build time, image size, break count)
- `scripts/`: `build.sh <release>`, `boot-test.sh <release>`
- `logs/`: trimmed evidence logs only

## Builds
- Build each release inside a container whose distro that release supports
  (kas-container or a CROPS poky image). Check the release's supported-host list first.
- Builds are long: run them in tmux (session `build`), write output to `logs/<release>-<date>.log`,
  and poll the log instead of blocking.
- QEMU target: MACHINE=qemuarm64. Boot test: `runqemu nographic` with a timeout, capturing the
  serial output to a file.
- i.MX 91 work (session 5) uses NXP's FRDM-IMX91 Scarthgap BSP. Physical steps (flashing, power,
  boot switches) are done by the human: stop and give exact instructions, then wait for pasted logs.

## Definition of done for any task
- The check passes and you show the evidence: bitbake exit status 0 and the boot log line with the
  login prompt, or the exact command output. Never report success without pasting the evidence lines.
- Small commits, message format `<release>: <change>`.
