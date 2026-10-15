#!/usr/bin/env bash
# DenOS amd64 base system. Run as root on an amd64 Debian-compatible Linux host.
# This creates an isolated root filesystem; it never partitions a host disk.
set -Eeuo pipefail

BUILD_ROOT="${DENOS_BUILD_ROOT:-/tmp/denos-build}"
ROOTFS="$BUILD_ROOT/rootfs"
MIRROR="${DENOS_DEBIAN_MIRROR:-http://deb.debian.org/debian}"
SUITE="${DENOS_DEBIAN_SUITE:-trixie}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

[[ $EUID -eq 0 ]] || { echo 'Run this script as root.' >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo 'An amd64 build host is required.' >&2; exit 1; }
[[ "$BUILD_ROOT" = /* && "$BUILD_ROOT" != / ]] || { echo 'Use an absolute build directory.' >&2; exit 1; }
command -v debootstrap >/dev/null
mkdir -p "$BUILD_ROOT"
exec > >(tee -a "$BUILD_ROOT/base-build.log") 2>&1

if [[ ! -f "$ROOTFS/etc/debian_version" ]]; then
    debootstrap --arch=amd64 --variant=minbase --include=ca-certificates,systemd-sysv \
        "$SUITE" "$ROOTFS" "$MIRROR"
fi

mkdir -p "$ROOTFS"/{proc,sys,dev,run}
cleanup() {
    for point in dev/pts dev sys proc; do
        mountpoint -q "$ROOTFS/$point" && umount -R "$ROOTFS/$point" || true
    done
}
trap cleanup EXIT
mountpoint -q "$ROOTFS/proc" || mount -t proc proc "$ROOTFS/proc"
mountpoint -q "$ROOTFS/sys" || mount --rbind /sys "$ROOTFS/sys"
mount --make-rslave "$ROOTFS/sys"
mountpoint -q "$ROOTFS/dev" || mount --rbind /dev "$ROOTFS/dev"
mount --make-rslave "$ROOTFS/dev"
cp -L /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

cat > "$ROOTFS/etc/apt/sources.list" <<EOF
deb https://deb.debian.org/debian $SUITE main
deb https://deb.debian.org/debian $SUITE-updates main
deb https://security.debian.org/debian-security $SUITE-security main
EOF
printf '#!/bin/sh\nexit 101\n' > "$ROOTFS/usr/sbin/policy-rc.d"
chmod 0755 "$ROOTFS/usr/sbin/policy-rc.d"
cp "$SCRIPT_DIR/packages.txt" "$ROOTFS/tmp/denos-packages.txt"
chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 /bin/bash -eux <<'CHROOT'
apt-get update
mapfile -t packages < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' /tmp/denos-packages.txt)
apt-get install -y --no-install-recommends "${packages[@]}"
dpkg --audit
dpkg-query -W -f='${binary:Package}\t${Version}\n' > /var/log/denos-base-packages.tsv
CHROOT
rm -f "$ROOTFS/tmp/denos-packages.txt" "$ROOTFS/usr/sbin/policy-rc.d"
date -u +%FT%TZ > "$BUILD_ROOT/base-complete"
echo "DenOS base ready: $ROOTFS"
