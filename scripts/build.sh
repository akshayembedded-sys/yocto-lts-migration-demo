#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Build demo-image for one release inside kas-container.
# Usage: scripts/build.sh <kirkstone|scarthgap|wrynose>
set -euo pipefail

# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
setup_release "${1:-}"

LOG="$REPO_DIR/logs/$RELEASE-$(date +%Y%m%d-%H%M%S).log"
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

# ask bitbake for the link name; it gained ".rootfs" in 4.3 (MIGRATION_LOG.md S4)
LINK_NAME=$("$KAS_CONTAINER" shell "$KAS_FILE" \
	-c "bitbake-getvar --value -r demo-image IMAGE_LINK_NAME" 2>/dev/null | tail -1)
IMAGE="$DEPLOY_DIR/$LINK_NAME.ext4"
if [ -e "$IMAGE" ]; then
	echo "IMAGE_FILE=$(readlink -f "$IMAGE")" | tee -a "$LOG"
	echo "IMAGE_SIZE_BYTES=$(stat -L -c %s "$IMAGE")" | tee -a "$LOG"
else
	echo "IMAGE_FILE=not found: $IMAGE" | tee -a "$LOG"
	exit 1
fi
