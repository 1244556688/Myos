#!/bin/bash
set -e
set -x

WORKDIR=$(pwd)
BUILD_DIR=$WORKDIR/build
ISO_DIR=$WORKDIR/iso

# 清理舊檔
rm -rf $BUILD_DIR $ISO_DIR
mkdir -p $BUILD_DIR $ISO_DIR

# 1. debootstrap 安裝基本系統
debootstrap --variant=minbase bookworm $BUILD_DIR http://deb.debian.org/debian/

# 2. chroot 裡安裝桌面環境
cat > $BUILD_DIR/root/setup.sh <<'EOF'
#!/bin/bash
set -e
apt-get update
apt-get install -y lxde-core lightdm sudo locales
locale-gen en_US.UTF-8
echo "myos" > /etc/hostname

# 建一個普通使用者 myuser，密碼是 password
useradd -m -s /bin/bash myuser
echo 'myuser:password' | chpasswd
usermod -aG sudo myuser

# 設定 LightDM 自動登入
cat > /etc/lightdm/lightdm.conf <<EOL
[SeatDefaults]
autologin-user=myuser
EOL

rm -rf /root/setup.sh
EOF

chmod +x $BUILD_DIR/root/setup.sh
chroot $BUILD_DIR /root/setup.sh

# 3. 製作 squashfs
mkdir -p $ISO_DIR/live
mksquashfs $BUILD_DIR $ISO_DIR/live/filesystem.squashfs -e boot

# 4. 複製 kernel 與 initrd
cp $BUILD_DIR/boot/vmlinuz* $ISO_DIR/live/vmlinuz
cp $BUILD_DIR/boot/initrd.img* $ISO_DIR/live/initrd.img

# 5. 製作 grub 配置檔
mkdir -p $ISO_DIR/boot/grub
cat > $ISO_DIR/boot/grub/grub.cfg <<EOF
set timeout=5
set default=0

menuentry "MyOS Live (LXDE)" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}
EOF

# 6. 製作 ISO
grub-mkrescue -o myos.iso $ISO_DIR

echo "=== Build finished: myos.iso ==="
