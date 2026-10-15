#!/usr/bin/env bash
# Build prerequisites only; use on an amd64 Debian-compatible Linux host.
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin \
    mtools qemu-system-x86 qemu-utils ca-certificates
