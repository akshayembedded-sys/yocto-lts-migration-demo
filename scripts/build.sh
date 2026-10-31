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

# ask bitbake for the image name and the type runqemu boots, instead of
# guessing: the link gained ".rootfs" in 4.3 (MIGRATION_LOG.md S4) and the
# qemu rootfs became ext4.zst in 5.3 (W9)
read -r LINK_NAME FSTYPE < <("$KAS_CONTAINER" shell "$KAS_FILE" \
	-c "echo \$(bitbake-getvar --value -r demo-image IMAGE_LINK_NAME) \$(bitbake-getvar --value -r demo-image QB_DEFAULT_FSTYPE)" \
	2>/dev/null | tail -1)
IMAGE="$DEPLOY_DIR/$LINK_NAME.$FSTYPE"
if [ -e "$IMAGE" ]; then
	echo "IMAGE_FILE=$(readlink -f "$IMAGE")" | tee -a "$LOG"
	echo "IMAGE_SIZE_BYTES=$(stat -L -c %s "$IMAGE")" | tee -a "$LOG"
	case "$FSTYPE" in
	*.zst) echo "IMAGE_UNCOMPRESSED_BYTES=$(zstd -dc <"$IMAGE" | wc -c)" | tee -a "$LOG" ;;
	esac
else
	echo "IMAGE_FILE=not found: $IMAGE" | tee -a "$LOG"
	exit 1
fi
