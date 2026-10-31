# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Shared settings for build.sh and boot-test.sh. Source it, don't run it.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${YOCTO_CACHE_DIR:-$HOME/yocto-cache}"
BUILDS_DIR="${YOCTO_BUILDS_DIR:-$HOME/yocto-builds}"

# kas-container version per release; its image's distro must be on the
# release's supported-host list (see PLAN.md section 3)
kas_version_for() {
	case "$1" in
	kirkstone | scarthgap) echo "4.8.2" ;; # Debian 12
	wrynose) echo "5.5" ;;                 # Debian 13
	*) return 1 ;;
	esac
}

setup_release() {
	RELEASE="$1"
	KAS_VERSION="$(kas_version_for "$RELEASE")" || {
		echo "unknown release: $RELEASE (kirkstone|scarthgap|wrynose)" >&2
		exit 2
	}
	KAS_FILE="kas/$RELEASE.yml"
	[ -f "$REPO_DIR/$KAS_FILE" ] || {
		echo "missing $KAS_FILE" >&2
		exit 2
	}

	KAS_CONTAINER="$CACHE_DIR/tools/kas-container-$KAS_VERSION"
	if [ ! -x "$KAS_CONTAINER" ]; then
		mkdir -p "$CACHE_DIR/tools"
		curl -fsSL -o "$KAS_CONTAINER" \
			"https://raw.githubusercontent.com/siemens/kas/$KAS_VERSION/kas-container"
		chmod +x "$KAS_CONTAINER"
	fi

	export DL_DIR="$CACHE_DIR/downloads"
	export SSTATE_DIR="$CACHE_DIR/sstate"
	export KAS_WORK_DIR="$BUILDS_DIR/$RELEASE/work"
	export KAS_BUILD_DIR="$BUILDS_DIR/$RELEASE/build"
	mkdir -p "$DL_DIR" "$SSTATE_DIR" "$KAS_WORK_DIR" "$KAS_BUILD_DIR" "$REPO_DIR/logs"

	# shellcheck disable=SC2034 # used by the scripts that source this file
	DEPLOY_DIR="$KAS_BUILD_DIR/tmp/deploy/images/qemuarm64"
}
