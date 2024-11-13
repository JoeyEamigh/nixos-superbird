#!/usr/bin/env bash
export PATH=/bin

mkdir -p /tmp
mkfifo /tmp/superbird-init.log.fifo
logOutFd=8 && logErrFd=9
eval "exec $logOutFd>&1 $logErrFd>&2"
tee -i /proc/self/fd/"$logOutFd" </tmp/superbird-init.log.fifo | while read -r line; do
  if test -n "$line"; then
    echo "<4>init: $line" >/dev/kmsg
  fi
done &
exec >/tmp/superbird-init.log.fifo 2>&1

in_qemu=false
kernel_mods=(vfat btrfs g_ether)

emmc_path=/dev/mmcblk2
emmc_part_1=/dev/mmcblk2p1
emmc_part_2=/dev/mmcblk2p2

boot_part_start=4MiB
boot_part_end=36MiB

data_part_start=156MiB
data_part_end=3727MiB

info() {
  echo ">>> $*"
}

fail() {
  info
  info "Something Went Badly"
  info
}

trap 'fail' 0

network_routes() {
  info
  info "Setup Network Routes"
  info

  info "sleeping for 10 seconds so you can get network connected..."
  sleep 10

  info "attempting to add default route in..."
  info "3"
  sleep 1
  info "2"
  sleep 1
  info "1"
  sleep 1

  info "attempting to add default route..."
  ip address add dev usb0 172.16.42.2/24
  ip link set usb0 up
  sleep 3s
  ip route add default via 172.16.42.1 dev usb0

  info "network routes set!"
}

export_log() {
  info
  info "Export Log"
  info

  info "sleeping for 180 seconds..."
  sleep 180

  info "attempting to mount bootfs..."
  mkdir -p /mnt/boot || info "failed to create /mnt/boot!!!"
  mount "$emmc_part_1" /mnt/boot || info "failed to mount /boot!!!"
  cp -r /run/log/journal /mnt/boot || info "failed to copy journal!!!"
  sync

  info "copied journal log to bootfs!"
}

partition() {
  info
  info "Running Superbird Installer"
  info

  info "restoring decrypted dtb..."
  dd if=/superbird/decrypted.dtb of="$emmc_path" bs=256K seek=160 conv=notrunc || info "failed to restore decrypted dtb!!!"
  dd if=/superbird/decrypted.dtb of="$emmc_path" bs=256K seek=161 conv=notrunc || info "failed to restore decrypted dtb!!!"
  sync
  info "done restoring decrypted dtb!"

  if [ "$in_qemu" = false ]; then
    info "restoring partition snapshot..."
    /superbird/ampart-v1.4-aarch64-static "$emmc_path" --mode eclone bootloader:0B:4M:0 reserved:36M:64M:0 cache:108M:0B:0 env:116M:8M:0 fip_a:132M:4M:0 fip_b:144M:4M:0 data:156M:-1:4 || info "failed to restore partition snapshot (this is probably not an issue)"
    info "done restoring partition snapshot!"
  else
    info "running in qemu, not restoring partition snapshot"
  fi

  info "erasing partitions..."
  parted -s "$emmc_path" mktable msdos || info "failed to make msdos partition table!!!"
  parted -s "$emmc_path" mkpart primary fat32 "$boot_part_start" "$boot_part_end" || info "failed to make bootfs!!!"
  parted -s "$emmc_path" mkpart primary btrfs "$data_part_start" "$data_part_end" || info "failed to make btrfs!!!"
  info "partitions erased!"

  info "restoring bootloader..."
  dd if=/superbird/bootloader.img of="$emmc_path" conv=fsync,notrunc bs=1 count=444 || info "failed to restore bootloader!!!"
  dd if=/superbird/bootloader.img of="$emmc_path" conv=fsync,notrunc bs=512 skip=1 seek=1 || info "failed to restore bootloader!!!"
  sync
  info "done restoring bootloader!"

  info "formatting partitions..."
  mkfs.fat -F 16 "$emmc_part_1" || info "failed to format bootfs!!!"
  mkfs.btrfs -f -L superbird "$emmc_part_2" || info "failed to format btrfs!!!"
  info "partitions formatted!"

  info "copying needed files..."
  mkdir -p /mnt/boot || info "failed to create /mnt/boot!!!"
  mount "$emmc_part_1" /mnt/boot || info "failed to mount /boot!!!"
  cp /superbird/Image /mnt/boot || info "failed to copy kerenl image!!!"
  cp /superbird/superbird.dtb /mnt/boot || info "failed to copy superbird.dtb!!!"
  cp /superbird/bootargs.txt /mnt/boot || info "failed to copy bootargs!!!"
  sync
  info "needed files copied!"

  if [ "$in_qemu" = true ]; then
    info "in qemu - copying rootfs to new partition"

    mkdir -p /mnt/rootfs

    dd if=/dev/vdb status=progress of=/dev/vda2

    info "in qemu - done!"
  fi
}

postflash() {
  info
  info "Runnig Superbird Postflash"
  info

  info "mounting rootfs"
  mkdir -p /mnt/rootfs || info "failed make mount directory!!!"
  mount -o compress=zstd,noatime "$emmc_part_2" /mnt/rootfs || info "failed to mount rootfs!!"
  info "mounting rootfs!"

  info "expanding btrfs filesystem"
  btrfs filesystem resize max /mnt/rootfs || info "failed to expand filesystem!!!"
  info "done expanding btrfs filesystem!"
}

init_net() {
  info
  info "Initializing Network"
  info

  info "messing with systemd a bit..."
  rm -rf /etc/systemd/system/default.target
  rm -rf /etc/systemd/system/initrd.target.requires

  info "messing with sshd a bit..."
  cat >/etc/ssh/sshd_config <<EOF
UsePAM no
Port 22

PasswordAuthentication yes
PermitEmptyPasswords yes
PermitRootLogin yes

HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

LogLevel INFO

UseDNS no
EOF
  chown root:root /etc/ssh/ssh_host_rsa_key
  chown root:root /etc/ssh/ssh_host_ed25519_key
  chmod 0600 /etc/ssh/ssh_host_rsa_key
  chmod 0600 /etc/ssh/ssh_host_ed25519_key

  info "messing with systemd a bit more..."
  cat >/etc/systemd/system/initrd.target <<EOF
[Unit]
Description=Superbird Initrd Target
OnFailure=emergency.target
OnFailureJobMode=replace-irreversibly
AssertPathExists=/etc/initrd-release
Requires=basic.target debug-shell.service sshd.service
After=basic.target rescue.service rescue.target debug-shell.service
AllowIsolate=yes
EOF
  ln -s /etc/systemd/system/initrd.target /etc/systemd/system/default.target

  info "handing off to systemd in..."
  info "3"
  sleep 1
  info "2"
  sleep 1
  info "1"
  sleep 1

  exec /init
}

info
info "Superbird Installer Init"
info

info "creating required directories"

mkdir -p /proc /dev /sys
mount -t proc proc -o nosuid,nodev,noexec /proc
mount -t devtmpfs none -o nosuid /dev
mount -t sysfs sysfs -o nosuid,nodev,noexec /sys

info "loading kernel modules: "
for mod in "${kernel_mods[@]}"; do
  info "loading module $mod..."
  modprobe -v "$mod"
done

# shellcheck disable=SC2013
for o in $(cat /proc/cmdline); do
  case $o in
  superbird.qemu)
    in_qemu=true

    emmc_path=/dev/vda
    emmc_part_1=/dev/vda1
    emmc_part_2=/dev/vda2

    boot_part_start=4MiB
    boot_part_end=128MiB
    ;;
  superbird.exportlog)
    export_log &
    ;;
  superbird.net)
    network_routes &
    init_net
    ;;
  superbird.partition)
    partition
    ;;
  superbird.install)
    partition
    network_routes &
    init_net
    ;;
  superbird.postflash)
    postflash
    ;;
  esac
done

info "purposely hanging on console"

exec 1>&"$logOutFd" 2>&"$logErrFd"
exec {logOutFd}>&- {logErrFd}>&-

exec /bin/bash
