#!/bin/bash

timedatectl set-ntp true

echo Choose the drive you would like to install arch on:
fdisk -l | grep 'Disk /'
read -p 'Drive: ' drive
clear
echo Choose the partitions you want arch to install on:
fdisk -l /dev/sd$drive

read -p 'EFI Partition: ' efi_part
read -p 'Main Partition: ' main_part
read -p 'Swap Partition: ' swap_part

mkfs.ext4 /dev/sd$drive$main_part
mkswap /dev/sd$drive$swap_part

mount /dev/sd$drive$main_part /mnt

pacstrap /mnt base base-devel linux linux-firmware efibootmgr grub nano git dhcpcd dhclient networkmanager man-db man-pages texinfo bash sudo openssh parted wget

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

ln -sf /usr/share/zoneinfo/US/Pacific /etc/localtime
hwclock --systohc

echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf

clear
read -p 'Computer Name: ' pc_name
echo $pc_name >> /etc/hostname
echo '127.0.0.1	'$pc_name >> /etc/hosts
echo '::1		'$pc_name >> /etc/hosts
echo '127.0.1.1	'$pc_name`.localdomain	'$pc_name

read -p 'Would you like to edit GRUB before making config? (y/n) ' grub_edit_confirm

if [ "$grub_edit_confirm" == "y" ]; then
	nano /etc/default/grub
fi

mkdir /efi
mount /dev/sd$drive$efi_part /efi

grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

echo 'done!'
