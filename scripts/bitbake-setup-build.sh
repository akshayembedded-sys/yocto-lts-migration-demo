#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Build demo-image on Wrynose with the official bitbake-setup tool instead of kas,
# following the Wrynose Quick Build (bitbake-setup run from a bitbake checkout). Runs inside the same kas 5.5 image
# (Debian 13) that scripts/build.sh uses. Output: docs/BITBAKE-SETUP.md.
# Usage: scripts/bitbake-setup-build.sh
set -euo pipefail

# shellcheck source=scripts/common.sh
. "$(dirname "$0")/common.sh"
setup_release wrynose

TOP="$BUILDS_DIR/bitbake-setup"
mkdir -p "$TOP"
LOG="$REPO_DIR/logs/bitbake-setup-$(date +%Y%m%d-%H%M%S).log"
echo "logging to $LOG"

start=$(date +%s)
set +e
# the image entrypoint only runs kas commands for a mapped user, so call bash
# directly as the host user, with HOME inside the mounted top dir
mkdir -p "$TOP/home"
docker run --rm --user "$(id -u):$(id -g)" --entrypoint bash \
	-e HOME=/top/home -e USER=builder -e LANG=en_US.UTF-8 \
	-v "$REPO_DIR:/repo:ro" -v "$TOP:/top" \
	-v "$DL_DIR:/downloads" -v "$SSTATE_DIR:/sstate" \
	ghcr.io/siemens/kas/kas:5.5 -c '
set -ex
cd /top
# the kas image has no python3-venv, so use the Quick Build alternative:
# bitbake-setup straight from a bitbake checkout, pinned as in kas/wrynose.yml
rm -rf bitbake && git clone -q -b 2.18 https://git.openembedded.org/bitbake bitbake
git -C bitbake checkout -q 51fd94a67fa17650a9ff623492005972bbc7d26f
echo "BITBAKE_SETUP_FROM $(git -C bitbake describe --tags) $(git -C bitbake rev-parse HEAD)"
export PATH="/top/bitbake/bin:$PATH"
bitbake-setup settings set --global default top-dir-prefix /top
bitbake-setup settings set --global default dl-dir /downloads
bitbake-setup settings list
rm -rf /top/bitbake-builds/poky-wrynose
bitbake-setup init --non-interactive poky-wrynose poky distro/poky machine/qemuarm64
set +u
. /top/bitbake-builds/poky-wrynose/build/init-build-env
set -u
for l in /top/bitbake-builds/poky-wrynose/layers/*; do
	[ -d "$l/.git" ] && echo "LAYER_REV $(basename "$l") $(git -C "$l" describe --tags --always) $(git -C "$l" rev-parse HEAD)"
done
bitbake-layers add-layer /repo/meta-demo
bitbake-config-build enable-fragment distro/demo
bitbake-config-build enable-fragment core/yocto/sbom-cve-check
bitbake-config-build enable-fragment core/yocto/root-login-with-empty-password
cat >> conf/local.conf <<EOF
SSTATE_DIR = "/sstate"
BB_HASHSERVE_DB_DIR = "\${SSTATE_DIR}"
INHERIT += "rm_work"
EOF
bitbake-config-build list-fragments
cat conf/toolcfg.conf ../../site.conf
bitbake-getvar --value DISTRO
bitbake demo-image
' 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e
end=$(date +%s)
{
	echo "BITBAKE_SETUP_EXIT=$status"
	echo "BITBAKE_SETUP_SECONDS=$((end - start))"
} | tee -a "$LOG"
exit "$status"
