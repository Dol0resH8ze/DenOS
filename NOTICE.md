# DenOS 0.1 notices

DenOS customization code and artwork are MIT licensed; see LICENSE.
Included operating-system packages retain their original licenses and notices
under `/usr/share/doc` inside the image. DenOS is an independent Debian-based
remix, not an official Debian, Xfce, Mozilla, or Linux project release.

`base/base-packages.tsv` records the installed binary package versions.
Debian source packages are available from Debian's official repositories and
[source archive](https://sources.debian.org/). To retrieve the matching source,
enable `deb-src` entries for Debian trixie, trixie-updates and trixie-security,
run `apt update`, and use `apt source source-package=source-version`. Some binary
versions use a distinct source package version (inspect `apt-cache show`).
Archived versions can be located through [Debian Snapshot](https://snapshot.debian.org/).

Technical references used:

- [Debian Live manual](https://live-team.pages.debian.net/live-manual/html/live-manual.en.html)
- [Debian live-boot](https://manpages.debian.org/trixie/live-boot-doc/live-boot.7.en.html)
- [Debian live-config](https://manpages.debian.org/trixie/live-config-doc/live-config.7.en.html)
- [Mozilla enterprise policy reference](https://firefox-admin-docs.mozilla.org/reference/policies/)
- [GRUB installation](https://manpages.debian.org/trixie/grub2-common/grub-install.8.en.html)
- [QEMU documentation](https://www.qemu.org/docs/master/system/qemu-manpage.html)

Security-related language describes implemented defaults. It is not an
independent audit or a guarantee of anonymity, hardware compatibility, or data
removal. The first release's installed ext4 filesystem is unencrypted.
