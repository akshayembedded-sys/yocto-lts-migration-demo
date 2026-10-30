# SPDX-License-Identifier: MIT
SUMMARY = "Demo product image with the demod daemon"
LICENSE = "MIT"

IMAGE_INSTALL = "packagegroup-core-boot demod ${CORE_IMAGE_EXTRA_INSTALL}"

# Root login without a password, so the boot test can log in
EXTRA_IMAGE_FEATURES += "debug-tweaks"

inherit core-image
