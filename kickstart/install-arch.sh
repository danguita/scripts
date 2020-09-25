#!/usr/bin/env bash
#
# Script to install my main production system (Arch Linux).
#
# Author: David Anguita <david@davidanguita.name>
#
# Run me with:
#
# # ./install-arch.sh

set -e

# Creating a bootable drive:
#
# - Download latest iso from: https://www.archlinux.org/download/
# - # dd if=archlinux-<version>-x86_64.iso of=/dev/sdX && sync
#
# Running this script:
#
# - Log in as root.
# - # pacman -Sy wget
# - # wget http://l.davidanguita.name/install-arch.sh -O install.sh
# - # chmod +x install.sh
# - # ./install.sh
#
# Post-installation notes:
# - You may need to enable the DHCP client service to enable networking right
#   before running the kickstart script:
#   $ sudo systemctl enable dhcpcd
# - Once your Internet connection is ready, run the kickstart script and follow
#   instructions:
#   $ ./kickstart.sh

# -- Configuration. Set values carefully.

# Block device in which the system will be installed on.
device=/dev/sda # It typically is `/dev/nvme0n1` in NVMe drives.

swap_partition_size=2G

# Time zone in `zoneinfo` format.
time_zone=Europe/Madrid

# Locale.
lang=en_US.UTF-8

# Hostname.
hostname=arch

# Initial user. Will be created automatically with `sudo` privileges.
user=david

# Kickstart script. Can be left blank.
kickstart_script_url=http://l.davidanguita.name/kickstart-arch.sh

# Do not change these values unless you know what you're doing.
boot_partition="${device}1" # i.e. `/dev/sda1`
root_partition="${device}2" # i.e. `/dev/sda2`

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
  arch-chroot /mnt "$@"
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
mkfs.vfat ${boot_partition}

# root partition: EXT4.
mkfs.ext4 /dev/mapper/vg-root

# swap partition.
mkswap /dev/mapper/vg-swap
swapon /dev/mapper/vg-swap

mount /dev/mapper/vg-root /mnt
mkdir -p /mnt/boot
mount ${boot_partition} /mnt/boot

say "Installing base system"
pacstrap /mnt base linux linux-firmware intel-ucode lvm2 grub efibootmgr

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
hwclock --systohc

say "Setting up locales"
echo "LANG=${lang}" > /mnt/etc/locale.conf
echo "${lang} UTF-8" >> /mnt/etc/locale.gen
chroot_run locale-gen

say "Setting up mount points"
genfstab -U /mnt >> /mnt/etc/fstab

say "Creating initial ramdisk"
echo "HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)" >> /mnt/etc/mkinitcpio.conf
chroot_run mkinitcpio -P

say "Installing bootloader (grub)"
root_partition_uuid=$(blkid -o export ${root_partition} | awk -F'=' '/^UUID/{ print $2 }')

echo "GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${root_partition_uuid}:crypt root=/dev/mapper/vg-root\"" >> /mnt/etc/default/grub
echo 'GRUB_PRELOAD_MODULES="part_gpt part_msdos lvm"' >> /mnt/etc/default/grub

mkdir -p /mnt/boot/grub
chroot_run grub-mkconfig -o /boot/grub/grub.cfg
chroot_run grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch --recheck

say "Installing sudo"
pacstrap /mnt sudo

sed -i.bak -E \
  "/%wheel ALL=\(ALL\) ALL/s/^#[[:space:]]//g" \
  /mnt/etc/sudoers

say "Installing dhcp client"
pacstrap /mnt dhcpcd

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
