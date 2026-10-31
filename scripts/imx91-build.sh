#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Build demo-image for the FRDM-IMX91 board on NXP's Scarthgap BSP (imx-6.6.36-2.1.0 plus
# meta-imx-frdm imx-frdm-4.0), following meta-imx-frdm's README. Runs in the kas 4.8.2
# image (Debian 12, a Scarthgap supported host). Steps and results: docs/IMX91.md.
# Usage: scripts/imx91-build.sh sync            # repo init + sync, clone meta-imx-frdm
#        EULA=1 scripts/imx91-build.sh build    # only after you have read and accepted NXP's EULA
set -euo pipefail

# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
setup_release scarthgap

PHASE="${1:-}"
case "$PHASE" in
sync | build) ;;
*)
	echo "usage: $0 sync|build" >&2
	exit 2
	;;
esac
if [ "$PHASE" = build ] && [ "${EULA:-}" != 1 ]; then
	echo "the build step accepts NXP's EULA ($BUILDS_DIR/imx91/sources/meta-imx/LICENSE.txt, shown by imx-setup-release.sh); read it, then run with EULA=1" >&2
	exit 2
fi

MANIFEST_BRANCH=imx-linux-scarthgap
MANIFEST=imx-6.6.36-2.1.0.xml
FRDM_TAG=imx-frdm-4.0
MACHINE=imx91-11x11-lpddr4-frdm
DISTRO=fsl-imx-xwayland
# the layer as it was after the Scarthgap migration; main has moved on to Wrynose
LAYER_TAG=scarthgap-migrated
export MANIFEST_BRANCH MANIFEST FRDM_TAG MACHINE DISTRO

TOP="$BUILDS_DIR/imx91"
mkdir -p "$TOP/home"
LOG="$REPO_DIR/logs/imx91-$PHASE-$(date +%Y%m%d-%H%M%S).log"
echo "logging to $LOG"

if [ "$PHASE" = build ]; then
	rm -rf "$TOP/meta-demo"
	git -C "$REPO_DIR" archive "$LAYER_TAG" meta-demo | tar -x -C "$TOP"
fi

# ssh (called by repo) and some build tools need a passwd entry for the host uid
docker run --rm --entrypoint cat "ghcr.io/siemens/kas/kas:$KAS_VERSION" /etc/passwd >"$TOP/passwd"
echo "builder:x:$(id -u):$(id -g)::/top/home:/bin/bash" >>"$TOP/passwd"

start=$(date +%s)
set +e
# same pattern as bitbake-setup-build.sh: bash as the host user, HOME inside the top dir
docker run --rm --user "$(id -u):$(id -g)" --entrypoint bash \
	-e HOME=/top/home -e USER=builder -e LANG=en_US.UTF-8 \
	-e PHASE="$PHASE" -e EULA="${EULA:-}" -e MANIFEST_BRANCH -e MANIFEST -e FRDM_TAG \
	-e MACHINE -e DISTRO \
	-v "$TOP/passwd:/etc/passwd:ro" \
	-v "$REPO_DIR:/repo:ro" -v "$TOP:/top" \
	-v "$DL_DIR:/downloads" -v "$SSTATE_DIR:/sstate" \
	"ghcr.io/siemens/kas/kas:$KAS_VERSION" -c '
set -ex
cd /top
git config --global user.name builder
git config --global user.email builder@localhost
git config --global color.ui false
if [ "$PHASE" = sync ]; then
	mkdir -p bin
	curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o bin/repo
	chmod +x bin/repo
	export PATH="/top/bin:$PATH"
	repo init -u https://github.com/nxp-imx/imx-manifest -b "$MANIFEST_BRANCH" -m "$MANIFEST"
	repo sync -j8
	rm -rf sources/meta-imx-frdm
	git clone -q https://github.com/nxp-imx-support/meta-imx-frdm.git sources/meta-imx-frdm
	git -C sources/meta-imx-frdm checkout -q "$FRDM_TAG"
	repo forall -c "echo LAYER_REV \$REPO_PATH \$(git rev-parse HEAD)"
	echo "LAYER_REV sources/meta-imx-frdm $(git -C sources/meta-imx-frdm rev-parse HEAD) $FRDM_TAG"
	exit 0
fi
# the setup scripts need an existing build dir name and expect to run from the top dir
set +u
MACHINE=$MACHINE DISTRO=$DISTRO EULA=$EULA . sources/meta-imx-frdm/tools/imx-frdm-setup.sh -b build-frdm-imx91
set -u
grep -q meta-demo conf/bblayers.conf || echo "BBLAYERS += \"/top/meta-demo\"" >> conf/bblayers.conf
# a marker of our own: the NXP local.conf already has a DL_DIR ?= line
grep -q "^# meta-demo build settings" conf/local.conf || cat >> conf/local.conf <<EOF
# meta-demo build settings
DL_DIR = "/downloads"
SSTATE_DIR = "/sstate"
INHERIT += "rm_work"
RM_WORK_EXCLUDE += "demod"
EOF
bitbake-layers show-layers
bitbake-getvar --value MACHINE
bitbake-getvar --value DISTRO
bitbake-getvar --value INIT_MANAGER
bitbake-getvar --value IMAGE_FSTYPES
bitbake demo-image
ls -l tmp/deploy/images/$MACHINE/ | grep -E "demo-image.*wic|imx-boot"
' 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e
end=$(date +%s)
{
	echo "IMX91_PHASE=$PHASE"
	echo "IMX91_EXIT=$status"
	echo "IMX91_SECONDS=$((end - start))"
} | tee -a "$LOG"
exit "$status"
