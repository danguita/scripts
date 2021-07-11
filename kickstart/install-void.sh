#!/usr/bin/env bash
#
# Script to install my main production system (Void Linux).
#
# Author: David Anguita <david@davidanguita.name>
#
# Run me with:
#
# # ./install-void.sh

set -e

# Creating a bootable drive:
#
# - Download latest iso from: https://alpha.de.repo.voidlinux.org/live/current/
# - # dd if=void-live-x86_64-<version>.iso of=/dev/sdX && sync
#
# Running this script:
#
# - Log in as root.
# - # xbps-install -Sy xbps
# - # xbps-install -Sy wget
# - # wget http://l.davidanguita.name/install-void.sh -O install.sh
# - # chmod +x install.sh
# - # ./install.sh
#
# Post-installation notes:
# - You may need to start the DHCP client service to enable networking right
#   before running the kickstart script:
#   $ sudo ln -s /etc/sv/dhcpcd /var/service/
# - Once your Internet connection is ready, run the kickstart script and follow
#   instructions:
#   $ ./kickstart.sh

# -- Configuration. Set values carefully.

# Block device in which the system will be installed on.
device=/dev/sda # It typically is `/dev/nvme0n1` in NVMe drives.

# See https://docs.voidlinux.org/installation/live-images/partitions.html#swap-partitions.
swap_partition_size=2G

# Kernel version the system will boot on.
# https://github.com/void-linux/void-packages/blob/b0d6286bc93e1490451b0b66fc842f4fcf9308d0/srcpkgs/linux/template#L3
kernel_version=linux5.12

# Time zone in `zoneinfo` format.
time_zone=Europe/Madrid

# Locale.
lang=en_US.UTF-8

# Hostname.
hostname=void

# Initial user. Will be created automatically with `sudo` privileges.
user=david

# XBPS repo to download the base packages from. Default should be good.
xbps_repo_url=https://alpha.de.repo.voidlinux.org/current

# Kickstart script. Can be left blank.
kickstart_script_url=http://l.davidanguita.name/kickstart-void.sh

# Do not change these values unless you know what you're doing.
boot_partition="${device}1" # Change it to "${device}p1" in NVMe drives.
root_partition="${device}2" # Change it to "${device}p2" in NVMe drives.

# -- End of Configuration.

say() {
  printf "\n[$(date --iso-8601=seconds)] %s\n" "$1"
}

confirm() {
  while true; do
    read -r -p "$1 (y/[n]): " answer
    case $answer in
      [Yy]* ) return 0; break;;
      [Nn]* ) return 1; break;;
      "" ) return 1; break;;
      * ) echo "Please answer yes or no.";;
    esac
  done
}

chroot_run() {
  chroot /mnt "$@"
}

# This is assumming you're using a EFI system. Legacy BIOS systems are not
# supported in this script yet.
say "Setting up partitions"
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${device}
  g # create GPT partition table
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk
  +512M # Assign 512 MB to the EFI system partition
  t # change partition type
  1 # select EFI System type
  n # new partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

say "Setting up file systems"
cryptsetup luksFormat ${root_partition}
cryptsetup luksOpen ${root_partition} crypt

pvcreate /dev/mapper/crypt
vgcreate vg /dev/mapper/crypt
lvcreate -L ${swap_partition_size} -n swap vg
lvcreate -l 100%FREE -n root vg

# boot partition: FAT32.
mkfs.vfat -F 32 ${boot_partition}

# root partition: EXT4.
mkfs.ext4 /dev/mapper/vg-root

# swap partition.
mkswap /dev/mapper/vg-swap
swapon /dev/mapper/vg-swap

mount /dev/mapper/vg-root /mnt
mkdir -p /mnt/boot
mount ${boot_partition} /mnt/boot

say "Installing packages"
# Authentication mechanism, needed during installation
xbps-install -Sy -R ${xbps_repo_url} pam

# Base system
xbps-install -Sy -R ${xbps_repo_url} -r /mnt \
  base-system lvm2 cryptsetup grub-x86_64-efi sudo

say "Preparing for chroot"
mkdir -p /mnt/{dev,proc,sys}
mount -R /proc /mnt/proc
mount -R /dev /mnt/dev
mount -R /sys /mnt/sys

say "Setting up root user"
passwd -R /mnt root
chown root:root /mnt
chmod 755 /mnt

say "Setting up hostname"
echo ${hostname} > /mnt/etc/hostname

say "Setting up static networking"
echo "127.0.1.1		${hostname}.localdomain	${hostname}" >> /mnt/etc/hosts

say "Setting up time zone"
ln -s /usr/share/zoneinfo/${time_zone} /mnt/etc/localtime

say "Setting up locales"
echo "LANG=${lang}" > /mnt/etc/locale.conf
echo "${lang} UTF-8" >> /mnt/etc/default/libc-locales
xbps-reconfigure -r /mnt -f glibc-locales

say "Setting up mount points"
boot_partition_uuid=$(blkid -o export ${boot_partition} | awk -F'=' '/^UUID/{ print $2 }')

cat <<- EOF | tee /mnt/etc/fstab
tmpfs                   /tmp    tmpfs   defaults,nosuid,nodev   0       0
UUID=${boot_partition_uuid}          /boot   vfat    defaults                0       0
/dev/mapper/vg-root     /       ext4    defaults                0       0
/dev/mapper/vg-swap     none    swap    sw                      0       0
EOF

say "Installing bootloader (grub)"
mkdir -p /mnt/boot/grub
chroot_run grub-mkconfig -o /boot/grub/grub.cfg
chroot_run grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=void --recheck

echo 'GRUB_CMDLINE_LINUX="rd.auto=1"' >> /mnt/etc/default/grub
echo hostonly=true > /mnt/etc/dracut.conf.d/hostonly.conf
xbps-reconfigure -r /mnt -f ${kernel_version}

sed -i.bak -E \
  "/%wheel ALL=\(ALL\) ALL/s/^#[[:space:]]//g" \
  /mnt/etc/sudoers

say "Creating initial user: ${user}"
useradd -R /mnt -m -s /bin/bash -U -G wheel ${user}
passwd -R /mnt ${user}

if [ -n "${kickstart_script_url}" ]; then
  say "Downloading kickstart script to user's home directory"
  wget ${kickstart_script_url} -O /mnt/home/${user}/kickstart.sh
  chroot_run chown ${user}:${user} /home/${user}/kickstart.sh
  chroot_run chmod +x /home/${user}/kickstart.sh
fi

say "Finishing up"
umount -R /mnt

if confirm "All done. Reboot?"; then reboot; fi
