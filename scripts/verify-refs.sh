#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Build and boot-test git refs from a fresh clone of this repo, so the logs belong to committed
# content, not to a working tree. Each clone uses that ref's own scripts and kas file. The
# release's build dir and the shared caches are reused, so unchanged tasks come from sstate.
# Usage: scripts/verify-refs.sh <ref>:<release> [...]
#   e.g. scripts/verify-refs.sh kirkstone-baseline:kirkstone scarthgap-migrated:scarthgap main:wrynose
# Output: logs/verify-<ref>-<ts>.log, plus the clone's build and boot logs copied as logs/verify-<ref>-*.log
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY_DIR="${YOCTO_BUILDS_DIR:-$HOME/yocto-builds}/verify"
mkdir -p "$VERIFY_DIR" "$REPO_DIR/logs"
[ $# -gt 0 ] || {
	echo "usage: $0 <ref>:<release> [...]" >&2
	exit 2
}

rc=0
for pair in "$@"; do
	ref=${pair%%:*}
	rel=${pair##*:}
	clone="$VERIFY_DIR/$ref"
	rm -rf "$clone"
	git clone -q "$REPO_DIR" "$clone"
	git -C "$clone" checkout -q "$ref"
	summary="$REPO_DIR/logs/verify-$ref-$(date +%Y%m%d-%H%M%S).log"
	{
		echo "VERIFY_REF=$ref VERIFY_COMMIT=$(git -C "$clone" rev-parse HEAD) VERIFY_DIRTY_FILES=$(git -C "$clone" status --porcelain | wc -l)"
		(cd "$clone" && scripts/build.sh "$rel")
		echo "VERIFY_BUILD_RC=$?"
		(cd "$clone" && scripts/boot-test.sh "$rel")
		echo "VERIFY_BOOT_RC=$?"
		# shellcheck disable=SC2016 # expanded by the clone's own shell, after common.sh is sourced
		(cd "$clone" && bash -c '. scripts/common.sh; setup_release "$1"; "$KAS_CONTAINER" shell "$KAS_FILE" -c "echo DISTRO_FEATURES=\$(bitbake-getvar --value DISTRO_FEATURES)"' _ "$rel" 2>/dev/null | grep '^DISTRO_FEATURES=')
	} 2>&1 | tee "$summary"
	grep -q '^VERIFY_BUILD_RC=0' "$summary" && grep -q '^VERIFY_BOOT_RC=0' "$summary" || rc=1
	for f in "$clone"/logs/*.log; do
		[ -e "$f" ] && cp "$f" "$REPO_DIR/logs/verify-$ref-$(basename "$f")"
	done
done
exit "$rc"
