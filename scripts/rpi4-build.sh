#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Build demo-image for a Raspberry Pi 4 (64-bit) on Wrynose: kas/wrynose.yml plus the
# kas/wrynose-rpi4.yml overlay, in the same kas 5.5 container as the QEMU build.
# Usage: scripts/rpi4-build.sh
# Output: logs/rpi4-wrynose-<ts>.log; images in ~/yocto-builds/rpi4/build/tmp/deploy/images/raspberrypi4-64
set -euo pipefail

# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
setup_release wrynose
# own work and build dirs, so the QEMU build is left alone; downloads and sstate stay shared
export KAS_WORK_DIR="$BUILDS_DIR/rpi4/work"
export KAS_BUILD_DIR="$BUILDS_DIR/rpi4/build"
mkdir -p "$KAS_WORK_DIR" "$KAS_BUILD_DIR"
KAS_FILES="kas/wrynose.yml:kas/wrynose-rpi4.yml"
DEPLOY_DIR="$KAS_BUILD_DIR/tmp/deploy/images/raspberrypi4-64"

LOG="$REPO_DIR/logs/rpi4-wrynose-$(date +%Y%m%d-%H%M%S).log"
echo "logging to $LOG"

cd "$REPO_DIR"
start=$(date +%s)
set +e
# bitbake runs under `kas shell`, not `kas build`: kas build reads bitbake's output line by line
# with a 64 KiB limit, and the linux-raspberrypi CVE warning line is longer (docs/RPI4-WRYNOSE.md, R1)
"$KAS_CONTAINER" shell "$KAS_FILES" -c "bitbake demo-image" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e
end=$(date +%s)

{
	echo "BUILD_RELEASE=wrynose MACHINE=raspberrypi4-64"
	echo "BUILD_EXIT=$status"
	echo "BUILD_SECONDS=$((end - start))"
} | tee -a "$LOG"

[ "$status" -eq 0 ] || exit "$status"

# list the SD card image and its block map
for f in "$DEPLOY_DIR"/demo-image-raspberrypi4-64.rootfs.wic*; do
	[ -e "$f" ] && echo "IMAGE_FILE=$(readlink -f "$f") $(stat -L -c %s "$f")" | tee -a "$LOG"
done
