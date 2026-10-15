#!/usr/bin/env bash
# Package a completed DenOS rootfs into a BIOS + UEFI hybrid ISO.
set -Eeuo pipefail
BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ROOT="${DENOS_BUILD_ROOT:-/tmp/denos-build}"
ROOTFS="$BUILD_ROOT/rootfs"
ISO_DIR="$BUILD_ROOT/iso"
OUTPUT="${1:-$BUILD_ROOT/DenOS-0.1-amd64.iso}"
[[ $EUID == 0 && -f "$BUILD_ROOT/custom-complete" ]] || { echo 'Run customize.sh as root first.' >&2; exit 1; }
if findmnt --raw --noheadings --output TARGET | grep -Fq "$ROOTFS/"; then
  echo 'Unmount all chroot bind mounts before packaging.' >&2; exit 1
fi
mkdir -p "$ISO_DIR/live" "$ISO_DIR/boot/grub" "$(dirname -- "$OUTPUT")"
kernel=$(find "$ROOTFS/boot" -maxdepth 1 -name 'vmlinuz-*-amd64' | sort -V | tail -n 1)
[[ -n "$kernel" ]]
version=${kernel##*/vmlinuz-}
cp "$kernel" "$ISO_DIR/live/vmlinuz"
cp "$ROOTFS/boot/initrd.img-$version" "$ISO_DIR/live/initrd.img"
mksquashfs "$ROOTFS" "$ISO_DIR/live/filesystem.squashfs" -noappend -comp zstd -Xcompression-level 15 -b 1M -processors 4 -no-progress
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5
insmod all_video
set gfxmode=1280x800,1024x768,auto
set gfxpayload=keep
terminal_output gfxterm
set color_normal=light-gray/black
set color_highlight=black/light-cyan

menuentry "DenOS 0.1 — Try the dark desktop" {
    linux /live/vmlinuz boot=live components username=den hostname=denos locales=C.UTF-8 keyboard-layouts=us nopersistence noeject quiet
    initrd /live/initrd.img
}
menuentry "DenOS 0.1 — Basic graphics (compatibility)" {
    linux /live/vmlinuz boot=live components username=den hostname=denos locales=C.UTF-8 keyboard-layouts=us nopersistence noeject nomodeset quiet
    initrd /live/initrd.img
}
menuentry "DenOS 0.1 — Diagnostic / serial console" {
    linux /live/vmlinuz boot=live components username=den hostname=denos locales=C.UTF-8 keyboard-layouts=us nopersistence noeject console=tty0 console=ttyS0,115200n8
    initrd /live/initrd.img
}
EOF
cp "$BASE/README.txt" "$ISO_DIR/README.txt"
cp "$BASE/NOTICE.md" "$ISO_DIR/NOTICE.md"
chroot "$ROOTFS" dpkg-query -W -f='${binary:Package}\t${Version}\n' > "$ISO_DIR/live/packages.tsv"
grub-mkrescue --product-name=DenOS --product-version=0.1 -volid DENOS_01 -o "$OUTPUT" "$ISO_DIR"
sha256sum "$OUTPUT" > "$OUTPUT.sha256"
xorriso -indev "$OUTPUT" -report_el_torito plain -report_system_area plain > "$BUILD_ROOT/iso-boot-report.txt" 2>&1
echo "DenOS ISO ready: $OUTPUT"
