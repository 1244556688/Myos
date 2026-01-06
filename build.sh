#!/bin/bash
set -e
set -x

WORKDIR=$(pwd)
BUILD_DIR=$WORKDIR/build
ISO_DIR=$WORKDIR/iso

# 清理舊檔
rm -rf "$BUILD_DIR" "$ISO_DIR"
mkdir -p "$BUILD_DIR" "$ISO_DIR"

# 1. debootstrap
debootstrap --arch=amd64 bookworm "$BUILD_DIR" http://deb.debian.org/debian/

# 掛載必要系統
mount --bind /dev "$BUILD_DIR/dev"
mount -t proc /proc "$BUILD_DIR/proc"
mount -t sysfs /sys "$BUILD_DIR/sys"

# 2. chroot 設定系統 + 安裝 kernel
cat > "$BUILD_DIR/root/setup.sh" <<'EOF'
#!/bin/bash
set -e

apt-get update

apt-get install -y \
  linux-image-amd64 \
  live-boot \
  systemd-sysv \
  lxde-core \
  lightdm \
  sudo \
  locales

locale-gen en_US.UTF-8
echo "myos" > /etc/hostname

useradd -m -s /bin/bash myuser
echo 'myuser:password' | chpasswd
usermod -aG sudo myuser

cat > /etc/lightdm/lightdm.conf <<EOL
[Seat:*]
autologin-user=myuser
EOL

update-initramfs -c -k all

rm -f /root/setup.sh
EOF

chmod +x "$BUILD_DIR/root/setup.sh"
chroot "$BUILD_DIR" /root/setup.sh

# 卸載
umount "$BUILD_DIR/dev"
umount "$BUILD_DIR/proc"
umount "$BUILD_DIR/sys"

# 3. squashfs
mkdir -p "$ISO_DIR/live"
mksquashfs "$BUILD_DIR" "$ISO_DIR/live/filesystem.squashfs" -e boot

# 4. 複製 kernel / initrd（現在一定存在）
cp "$BUILD_DIR"/boot/vmlinuz-* "$ISO_DIR/live/vmlinuz"
cp "$BUILD_DIR"/boot/initrd.img-* "$ISO_DIR/live/initrd.img"

# 5. GRUB
mkdir -p "$ISO_DIR/boot/grub"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0

menuentry "MyOS Live (LXDE)" {
    linux /live/vmlinuz boot=live quiet
    initrd /live/initrd.img
}
EOF

# 6. ISO
grub-mkrescue -o myos.iso "$ISO_DIR"

echo "=== ✅ Build finished: myos.iso ==="
