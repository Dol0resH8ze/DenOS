#!/usr/bin/env bash
# Apply DenOS customizations to a completed isolated rootfs; no host disks touched.
set -Eeuo pipefail
export LC_ALL=C.UTF-8
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ROOT="${DENOS_BUILD_ROOT:-/tmp/denos-build}"
ROOTFS="$BUILD_ROOT/rootfs"
[[ $EUID == 0 && -f "$BUILD_ROOT/base-complete" && -f "$ROOTFS/etc/debian_version" ]] || { echo 'A completed base rootfs and root are required.' >&2; exit 1; }
python3 "$BASE/configure-overlay.py"
cp -a "$BASE/overlay/." "$ROOTFS/"
# Windows-hosted source files do not retain restrictive Unix modes. Normalize
# only the overlay paths after copying to the Linux rootfs.
python3 - "$BASE/overlay" "$ROOTFS" <<'PY'
import os
import pathlib
import sys
source, target = map(pathlib.Path, sys.argv[1:])
for directory, dirs, files in os.walk(source):
    relative = pathlib.Path(directory).relative_to(source)
    for item in [target / relative] + [target / relative / name for name in files]:
        if not item.is_symlink():
            os.chown(item, 0, 0)
            os.chmod(item, 0o755 if item.is_dir() else 0o644)
PY
chmod 0755 "$ROOTFS/usr/local/bin/denos-hub" "$ROOTFS/usr/local/bin/denos-session" "$ROOTFS/usr/local/sbin/denos-control" "$ROOTFS/usr/local/sbin/denos-install"
chmod 0440 "$ROOTFS/etc/sudoers.d/denos-live" "$ROOTFS/etc/sudoers.d/denos-control"
cp "$BASE/README.txt" "$ROOTFS/usr/share/denos/README.txt"
cat > "$ROOTFS/etc/os-release" <<'EOF'
PRETTY_NAME="DenOS 0.1 (First Light)"
NAME="DenOS"
VERSION_ID="0.1"
VERSION="0.1 (First Light)"
ID=denos
ID_LIKE=debian
DEBIAN_VERSION_FULL=13
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
EOF
printf 'denos\n' > "$ROOTFS/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 denos\n::1 localhost ip6-localhost ip6-loopback\n' > "$ROOTFS/etc/hosts"
printf 'LANG=C.UTF-8\n' > "$ROOTFS/etc/default/locale"
printf 'DenOS 0.1 · First Light\nDebian-based experimental desktop\n' > "$ROOTFS/etc/issue"
printf 'DenOS 0.1 — Your space. Your rules.\nLive account: den / denos. Live session has passwordless sudo.\nNetworking starts disabled. Enable it in the Privacy Center.\n' > "$ROOTFS/etc/motd"
if ! chroot "$ROOTFS" id den >/dev/null 2>&1; then
  chroot "$ROOTFS" useradd --create-home --uid 1000 --user-group --shell /bin/bash --comment 'DenOS live session' den
fi
for group in sudo audio video plugdev netdev cdrom render; do
  if chroot "$ROOTFS" getent group "$group" >/dev/null; then chroot "$ROOTFS" usermod --append --groups "$group" den; fi
done
printf 'den:denos\n' | chroot "$ROOTFS" chpasswd
chroot "$ROOTFS" passwd --lock root
cp -a "$ROOTFS/etc/skel/." "$ROOTFS/home/den/"
chroot "$ROOTFS" chown -R den:den /home/den
chroot "$ROOTFS" visudo --check
systemctl --root="$ROOTFS" enable lightdm.service NetworkManager.service nftables.service denos-offline.service
systemctl --root="$ROOTFS" set-default graphical.target
# Keep the build host resolver and identity out of the image.
rm -f "$ROOTFS/etc/resolv.conf"
ln -s /run/NetworkManager/resolv.conf "$ROOTFS/etc/resolv.conf"
rm -f "$ROOTFS/etc/machine-id" "$ROOTFS/var/lib/dbus/machine-id" "$ROOTFS/var/lib/systemd/random-seed"
: > "$ROOTFS/etc/machine-id"
ln -s /etc/machine-id "$ROOTFS/var/lib/dbus/machine-id"
mkdir -p "$ROOTFS/var/lib/NetworkManager"
printf '[main]\nNetworkingEnabled=false\nWirelessEnabled=false\nWWANEnabled=false\n' > "$ROOTFS/var/lib/NetworkManager/NetworkManager.state"
chmod 0600 "$ROOTFS/var/lib/NetworkManager/NetworkManager.state"
chroot "$ROOTFS" apt-get clean
find "$ROOTFS/var/log" -type f ! -name denos-base-packages.tsv -exec truncate -s 0 {} +
find "$ROOTFS/tmp" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
chroot "$ROOTFS" python3 -m py_compile /usr/local/bin/denos-hub /usr/local/sbin/denos-control
chroot "$ROOTFS" bash -n /usr/local/sbin/denos-install
chroot "$ROOTFS" dpkg --audit
date -u +%FT%TZ > "$BUILD_ROOT/custom-complete"
echo 'DenOS customization complete.'
