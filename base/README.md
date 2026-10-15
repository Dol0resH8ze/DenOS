# DenOS base system

The base is Debian 13 (trixie), amd64. Packages are obtained from official
Debian repositories and verified through Debian's archive signing keys.

On an amd64 Debian-compatible Linux host, run:

```sh
sudo bash install-build-tools.sh
sudo bash bootstrap.sh
```

The default build location is `/tmp/denos-build`; set `DENOS_BUILD_ROOT` to
an absolute path to change it. The root filesystem must reside on a Linux
filesystem that preserves ownership, permissions, device nodes, and symlinks.
When building under WSL, do not put the root filesystem under `/mnt/c`.

`packages.txt` lists direct package requests. Dependencies are resolved by
APT with recommends disabled. Exact installed versions are written to
`rootfs/var/log/denos-base-packages.tsv`. This is a repeatable build recipe,
not a bit-for-bit reproducible image: repositories receive security updates.

The scripts create a root filesystem and install build tools. They do not
partition or format host disks. The branding, privacy configuration, live
user, installer, and ISO packaging are applied in later build stages.

The image includes Debian main only. Some computers need proprietary Wi-Fi
or graphics firmware, which is not included in this first build. Ethernet,
supported open hardware, and virtual machines are the initial targets.
