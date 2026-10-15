### Install DenOS on a disk

DenOS 0.1 is an experimental Debian-based live desktop for amd64 PCs and virtual
machines. Its terminal installer can create an installed system on an entire
spare disk. It supports legacy BIOS and UEFI using the removable-media fallback
boot path. Secure Boot must be disabled. Test the ISO and installed system in a
virtual machine before using physical hardware.

**Installation erases the selected disk. The installed filesystem is not
encrypted.** Back up your files first. DenOS 0.1 has no partition editor, dual-boot
mode, encrypted installation, or automatic migration. The minimum disk size is
20 GiB. No swap partition is created. Reformatting is not a secure overwrite of
old data; dispose of or sanitize previously sensitive disks separately.

Boot the live ISO, open a terminal, and inspect the plan first:

```sh
sudo denos-install --dry-run
```

Choose an unused whole disk from the displayed `lsblk` list, for example
`/dev/vda` in a virtual machine. Dry run checks the live image, disk, and chosen
account name, then prints its plan without writing or mounting anything.

To install, run:

```sh
sudo denos-install
```

The installer displays the disk path, size, model, and serial number. It requires
the exact phrase `ERASE /dev/DEVICE`, using the displayed canonical device path,
before making changes. It rejects mounted disks, active swap or mapped devices,
and disks containing the running system or live medium. You must create a login
password; live auto-login and general passwordless sudo are removed, and root
login is locked. Only the three fixed Privacy Center status/online/offline
commands remain available without a password. The desktop defaults remain dark.
Networking starts disabled until you explicitly connect.

The installed disk receives a GPT partition table, a BIOS boot partition, a
512 MiB EFI system partition, and an ext4 root partition. The installer copies
the live SquashFS image, writes UUID-based mounts, generates boot files, and
installs GRUB for BIOS and UEFI. UEFI installation uses `EFI/BOOT/BOOTX64.EFI`
without changing firmware NVRAM entries. Firmware support for this fallback path
varies; select the installed disk in your firmware boot menu if needed.

When installation finishes, shut down, detach the ISO or live USB, and boot the
installed disk. If interrupted after the erase confirmation, assume that the
target disk contains a partial installation; rerun the installer to start over.
Do not disconnect a disk if the installer reports an unmount failure. Reboot the
live system first.

The live ISO must include `bash`, `coreutils`, `findutils`, `grep`, `sed`, `gawk`
or `mawk`, `util-linux`, `mount`, `udev`, `parted`, `dosfstools`, `e2fsprogs`,
`squashfs-tools`, `passwd`, `sudo`, `grub2-common`, `grub-pc-bin`,
`grub-efi-amd64-bin`, `initramfs-tools`, and `linux-image-amd64`.
