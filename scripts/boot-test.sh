#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Boot demo-image in runqemu (nographic, slirp) inside kas-container, log in,
# check the daemon and power off. The serial console goes to logs/.
# Usage: scripts/boot-test.sh <kirkstone|scarthgap|wrynose> [timeout-seconds]
set -euo pipefail

# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
setup_release "${1:-}"
TIMEOUT="${2:-900}"

LOG="$REPO_DIR/logs/$RELEASE-boot-$(date +%Y%m%d-%H%M).log"

cd "$REPO_DIR"
set +e
"$KAS_CONTAINER" shell "$KAS_FILE" -c \
	"python3 /repo/scripts/qemu-drive.py --timeout $TIMEOUT --out /build/boot-console.log"
status=$?
set -e

cp "$KAS_BUILD_DIR/boot-console.log" "$LOG" 2>/dev/null || true
echo "BOOT_TEST_EXIT=$status"
echo "console log: $LOG"
exit "$status"
