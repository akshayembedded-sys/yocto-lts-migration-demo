#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Build demo-image for one release inside kas-container.
# Usage: scripts/build.sh <kirkstone|scarthgap|wrynose>
set -euo pipefail

# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
setup_release "${1:-}"

LOG="$REPO_DIR/logs/$RELEASE-$(date +%Y%m%d-%H%M).log"
echo "logging to $LOG"

cd "$REPO_DIR"
start=$(date +%s)
set +e
"$KAS_CONTAINER" build "$KAS_FILE" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e
end=$(date +%s)

{
	echo "BUILD_RELEASE=$RELEASE"
	echo "BUILD_EXIT=$status"
	echo "BUILD_SECONDS=$((end - start))"
} | tee -a "$LOG"

[ "$status" -eq 0 ] || exit "$status"

IMAGE="$DEPLOY_DIR/demo-image-qemuarm64.ext4"
if [ -e "$IMAGE" ]; then
	echo "IMAGE_FILE=$(readlink -f "$IMAGE")" | tee -a "$LOG"
	echo "IMAGE_SIZE_BYTES=$(stat -L -c %s "$IMAGE")" | tee -a "$LOG"
else
	echo "IMAGE_FILE=not found: $IMAGE" | tee -a "$LOG"
	exit 1
fi
