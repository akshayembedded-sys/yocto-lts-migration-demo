# SPDX-License-Identifier: MIT
SUMMARY = "Demo product image with the demod daemon"
LICENSE = "MIT"

IMAGE_INSTALL = "packagegroup-core-boot demod ${CORE_IMAGE_EXTRA_INSTALL}"

# Root login for the boot test comes from the core/yocto/root-login-with-empty-password
# fragment in kas/wrynose.yml, so the product image itself has no empty root password.

inherit core-image
