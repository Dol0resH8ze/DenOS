DenOS 0.1 — First Light
Your space. Your rules.

DenOS is a real bootable amd64 Linux desktop, based on Debian 13 (trixie),
with Xfce, a dark Arc theme, native DenOS Privacy Center, Firefox ESR,
Thunar file manager, Mousepad editor, and a terminal.

THIS IS AN EXPERIMENTAL FIRST RELEASE
Test in a virtual machine before installing on a computer.
The custom DenOS installer and privacy integration have not been independently
security audited. This is not an anonymity system or a replacement for Tails.

BOOT
Use a 64-bit Intel/AMD virtual machine with 4 GB RAM recommended and a 24 GB
virtual disk if installing. Attach DenOS-0.1-amd64.iso as the optical drive.
BIOS and UEFI are supported; Secure Boot must be disabled for this unsigned ISO.
Select the default GRUB entry to boot the desktop. The live account is:
  username: den
  password: denos
Live mode auto-signs in and grants passwordless sudo. It is for trying DenOS;
do not treat its shared public password as protection for sensitive sessions.

For USB: write the ISO to a spare USB drive using an image-writing tool.
Writing an image replaces the contents of the chosen USB drive. DenOS does
not write or install anything to internal disks just by booting the desktop.
Some firmware may require legacy/CSM mode; hardware has not been fully tested.

PRIVACY DEFAULTS
- Networking starts disabled at every boot, including installed-system boots.
- An nftables firewall blocks outbound traffic while offline. When online,
  outbound traffic is allowed and unsolicited inbound traffic is blocked;
  ICMP, DHCP replies, loopback, and established connections are exceptions.
- Open Privacy Center > Network access to deliberately enable internet access.
  Then use the panel network icon for Wi-Fi. Disabling access blocks traffic.
- Firefox telemetry and studies are disabled by policy. Strict tracking
  protection and always-private browsing are defaults. Private browsing does
  not hide your IP or make you anonymous. Bookmarks/downloads can persist.
- DenOS itself has no analytics service. Included third-party applications
  can make normal service/update requests once networking is enabled.
- Live sessions use a temporary RAM overlay and ignore persistence volumes.
  No swap partition is configured or explicitly enabled. Files you choose to
  save to a mounted drive remain on that drive. RAM is not securely scrubbed.
- Shell command history and GTK recent-file lists are disabled by default.
- System logs use volatile storage. Audio capture is muted at login only;
  apps can unmute it. Camera drivers are not disabled.
- No encrypted disk, VPN, Tor routing, or secure-erase guarantee is supplied.

INSTALL
Open Install DenOS from the welcome app or applications menu. The installer
supports one entire disk only: no dual boot and no automatic disk encryption.
It needs at least 20 GiB and erases the whole disk you choose. It rejects the
live-media disk, mounted disks, active swap, and mapped RAID/LVM devices.
You must type the exact ERASE /dev/... phrase shown before writes begin.
It creates BIOS boot + EFI + ext4 root partitions, copies the original
read-only image, asks for a new account password, removes live autologin and
general passwordless sudo, and installs BIOS/UEFI GRUB. Root login is locked.
The installed admin account can use the three fixed Privacy Center network
commands without an extra password; other sudo actions require your password.
After installation, shut down, remove the live ISO/USB and boot the disk.
The installed desktop stores files persistently on UNENCRYPTED disk.

Check the plan without writing:
  sudo denos-install --dry-run

UPDATES AND LIMITATIONS
Debian's signed repositories remain configured. Enable networking, then:
  sudo apt update
  sudo apt full-upgrade
DenOS customizations have no separate automatic update service.
The ISO includes Debian main only. Proprietary Wi-Fi/GPU firmware is not
included. Use Ethernet or supported virtual hardware first. Keyboard is US;
change it in Xfce Settings. CPU architecture is amd64, not ARM or Apple Silicon.

SOURCE AND REBUILD
The accompanying DenOS-source.zip contains the customization source, installer,
package manifest and Linux build scripts. Use an amd64 Debian-compatible
build host as root, with enough space (about 8 GB plus downloaded packages):
  bash base/install-build-tools.sh
  bash base/bootstrap.sh
  bash customize.sh
  bash package-iso.sh /absolute/path/DenOS-0.1-amd64.iso
The build root defaults to /tmp/denos-build on the Linux filesystem. Override
DENOS_BUILD_ROOT if needed. Windows users can build under WSL; keep the rootfs
on WSL's Linux filesystem to retain Unix ownership and symlinks.
The scripts use current trixie repositories, so later rebuilds may update
package versions rather than produce byte-identical images. See NOTICE.md.

Created for you as DenOS. Debian, Linux, Xfce and Firefox are separate projects;
this remix is not an official release or endorsement by those projects.
