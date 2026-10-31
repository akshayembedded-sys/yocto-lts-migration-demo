# SPDX-License-Identifier: MIT
SUMMARY = "Demo industrial-style monitoring daemon"
DESCRIPTION = "Small C daemon that reports its health to systemd with sd_notify, \
               used to show what breaks when a product layer moves between Yocto LTS releases."
HOMEPAGE = "https://github.com/akshayembedded-sys/yocto-lts-migration-demo"
BUGTRACKER = "https://github.com/akshayembedded-sys/yocto-lts-migration-demo/issues"
SECTION = "base"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9c633c79505e835759fe0b16e394b263"

DEPENDS = "systemd"

PV = "1.0+git${SRCPV}"

# The daemon source lives in this repo; kas-container mounts it at /repo
SRC_URI = "git:///repo;protocol=file;branch=main;subpath=demod;destsuffix=${BP} \
           file://demod.service \
          "
SRCREV = "88d409fc9687fd9022ca34c871cb47cc4c21baee"

inherit pkgconfig systemd

SYSTEMD_SERVICE:${PN} = "demod.service"

EXTRA_OEMAKE = "PREFIX=${prefix}"

do_install() {
    oe_runmake install DESTDIR=${D}
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/demod.service ${D}${systemd_system_unitdir}/
}
