# SPDX-License-Identifier: MIT
# Only for the demo distro, so the layer changes nothing for other distros
FILESEXTRAPATHS:prepend:demo := "${THISDIR}/files:"

SRC_URI:append:demo = " file://demo.cfg"
