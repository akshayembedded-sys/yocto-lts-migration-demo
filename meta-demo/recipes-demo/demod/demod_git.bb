# SPDX-License-Identifier: MIT
SUMMARY = "Demo industrial-style monitoring daemon"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9c633c79505e835759fe0b16e394b263"

# The daemon source lives in this repo; kas-container mounts it at /repo
SRC_URI = "git:///repo;protocol=file;branch=main;subpath=demod;destsuffix=git \
           file://demod.service \
          "
SRCREV = "88d409fc9687fd9022ca34c871cb47cc4c21baee"

PV = "1.0+git${SRCPV}"
S = "${WORKDIR}/git"

DEPENDS = "systemd pkgconfig-native"

inherit systemd

SYSTEMD_SERVICE:${PN} = "demod.service"

EXTRA_OEMAKE="PREFIX=${prefix}"

do_install() {
	oe_runmake install DESTDIR=${D}
	install -d ${D}${systemd_system_unitdir}
	install -m 0644 ${WORKDIR}/demod.service ${D}${systemd_system_unitdir}/
}
