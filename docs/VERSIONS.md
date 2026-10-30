# Exact versions per release

Each value below was read from our own checkout or build. The commands that produced them are
listed under each table.

## Kirkstone (Yocto 4.0.35)

| Component | Value |
|---|---|
| poky | `kirkstone` @ `93431249a6260da7bd29ee3ca32145d89e5b8259` (tag `yocto-4.0.35`) |
| Layers used | `meta`, `meta-poky`, `meta-yocto-bsp` (from poky), `meta-demo` (this repo) |
| linux-yocto | `5.15.201` (`PREFERRED_VERSION_linux-yocto = "5.15%"`), SRCREV machine `b75d71b7f2`, meta `8634ca1dd8` |
| demod SRCREV | `88d409fc9687fd9022ca34c871cb47cc4c21baee` (this repo, `demod/`) |
| kas / kas-container | 4.8.2, script sha256 `b6973af0ca87da02defc4637479af4d0c01dc9a3f29b44842c5db99f9f498d2c` |
| Container image | `ghcr.io/siemens/kas/kas@sha256:fd0000890ccf7c8091239e1df9aa46af7721b6e4d992be0ce3d178d17ffcebff` |
| Container distro | Debian 12.11, which is on the [Kirkstone supported list](https://docs.yoctoproject.org/kirkstone/ref-manual/system-requirements.html#supported-linux-distributions) |
| Build host | Ubuntu 24.04.5, 32 CPUs, 62 GB RAM, Docker 29.8.2 |

Sources: `kas-container dump kas/kirkstone.yml` (poky checkout),
`bitbake -e virtual/kernel | grep ^PV=`, `docker image inspect`, `/etc/debian_version` inside the image.
