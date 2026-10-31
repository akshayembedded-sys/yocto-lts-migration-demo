# Exact versions per release

Each value below was read from our own checkout or build. The commands that produced them are
listed under each table. The recorded outputs are in `logs/host-and-tools-evidence.txt` (host, kas,
container images, kernel SRCREVs) and `logs/verify-evidence.txt` (`DISTRO_FEATURES`).

## Kirkstone (Yocto 4.0.35)

| Component | Value |
|---|---|
| poky | `kirkstone` @ `93431249a6260da7bd29ee3ca32145d89e5b8259` (tag `yocto-4.0.35`) |
| Layers used | `meta`, `meta-poky`, `meta-yocto-bsp` (from poky), `meta-demo` (this repo) |
| linux-yocto | `5.15.201` (`PREFERRED_VERSION_linux-yocto = "5.15%"`), SRCREV machine `8634ca1dd8`, meta `b75d71b7f2` |
| demod SRCREV | `88d409fc9687fd9022ca34c871cb47cc4c21baee` (this repo, `demod/`) |
| kas / kas-container | 4.8.2, script sha256 `b6973af0ca87da02defc4637479af4d0c01dc9a3f29b44842c5db99f9f498d2c` |
| Container image | `ghcr.io/siemens/kas/kas@sha256:fd0000890ccf7c8091239e1df9aa46af7721b6e4d992be0ce3d178d17ffcebff` |
| Container distro | Debian 12.11, which is on the [Kirkstone supported list](https://docs.yoctoproject.org/kirkstone/ref-manual/system-requirements.html#supported-linux-distributions) |
| Build host | Ubuntu 24.04.5, 32 CPUs, 62 GiB RAM, Docker 29.8.2 |

Sources: `git describe --tags` in the poky checkout and `grep SRCREV` on the kernel recipe
(`logs/host-and-tools-evidence.txt`); the kernel version is in the fitImage name and the boot log's
`uname` line (`logs/kirkstone-evidence.txt`); `docker image inspect` and `/etc/debian_version` in the image.

## Scarthgap (Yocto 5.0.21)

| Component | Value |
|---|---|
| poky | `scarthgap` @ `4fb7016a07507683359ebd620f1951fd5ea44bfa` (tag `yocto-5.0.21`) |
| Layers used | `meta`, `meta-poky`, `meta-yocto-bsp` (from poky), `meta-demo` (this repo) |
| linux-yocto | `6.6.151` (`linux-yocto_6.6.bb`, the only linux-yocto recipe in this poky), SRCREV machine `b96d2d770c`, meta `dd201eb6ec` |
| demod SRCREV | `88d409fc9687fd9022ca34c871cb47cc4c21baee` (unchanged) |
| kas / kas-container | 4.8.2, script sha256 `b6973af0ca87da02defc4637479af4d0c01dc9a3f29b44842c5db99f9f498d2c` |
| Container image | `ghcr.io/siemens/kas/kas@sha256:fd0000890ccf7c8091239e1df9aa46af7721b6e4d992be0ce3d178d17ffcebff` |
| Container distro | Debian 12.11, which is on the [Scarthgap supported list](https://docs.yoctoproject.org/scarthgap/ref-manual/system-requirements.html#supported-linux-distributions) |
| DISTRO_FEATURES | `acl alsa bluetooth debuginfod ext2 ipv4 ipv6 pcmcia usbgadget usbhost wifi xattr nfs zeroconf pci 3g nfc x11 vfat seccomp opengl ptest multiarch wayland vulkan systemd usrmerge` |
| Build host | same as Kirkstone |

Sources: `git describe --tags` in the poky checkout and `grep SRCREV` on `linux-yocto_6.6.bb`
(`logs/host-and-tools-evidence.txt`); the kernel version from the boot log's `uname` line;
`bitbake-getvar --value DISTRO_FEATURES` (`logs/verify-evidence.txt`).

## Wrynose (Yocto 6.0.4)

| Component | Value |
|---|---|
| bitbake | `2.18` @ `51fd94a67fa17650a9ff623492005972bbc7d26f` (tag `yocto-6.0.4`) |
| openembedded-core | `wrynose` @ `0f03c732a0a2d0506b41b1abe60b3f368b2300dc` (tag `yocto-6.0.4`), plus our patch `patches/openembedded-core/0001-sbom-cve-check-read-the-SBOM-through-IMAGE_LINK_NAME.patch` applied by kas |
| meta-yocto | `wrynose` @ `7c25b11156553145fa6b241a2d4f65d94438f804` (tag `yocto-6.0.4`) |
| Layers used | `meta` (openembedded-core), `meta-poky`, `meta-yocto-bsp` (meta-yocto), `meta-demo` (this repo) |
| linux-yocto | `6.18.52` (`linux-yocto_6.18.bb`), SRCREV machine `364c4b44ab`, meta `2184786cc3`; FIT from `linux-yocto-fitimage.bb` |
| demod SRCREV | `88d409fc9687fd9022ca34c871cb47cc4c21baee` (unchanged) |
| Configuration fragments | `core/yocto/sbom-cve-check`, `core/yocto/root-login-with-empty-password` |
| kas / kas-container | 5.5, script sha256 `7a8186f18d14ec6bec3f8d5188eba7a60f1ef4b5587af15917527588cc7d738a` |
| Container image | `ghcr.io/siemens/kas/kas@sha256:4b210b0be3c887875973c4f4c35470b4ecf3edd2346c9de1bdd33feae5b86e94` |
| Container distro | Debian 13.6, Python 3.13.5, on the [Wrynose supported list](https://docs.yoctoproject.org/wrynose/ref-manual/system-requirements.html#supported-linux-distributions) |
| DISTRO_FEATURES | `systemd usrmerge acl alsa bluetooth debuginfod ext2 ipv4 ipv6 wifi xattr nfs zeroconf pci 3g nfc x11 vfat seccomp pulseaudio gobject-introspection-data ldconfig opengl ptest multiarch wayland vulkan` |
| Build host | same as Kirkstone |

Sources: `git describe --tags` and `git rev-parse HEAD` in each kas checkout, `bitbake-getvar`
as for Scarthgap, `/etc/debian_version` and `python3 --version` in the image.
