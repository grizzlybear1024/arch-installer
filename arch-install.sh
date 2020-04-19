#!/bin/bash

timedatectl set-ntp true
clear

echo '======================\n'
echo '  DISK SETUP\n'
echo '======================\n'

echo Choose the drive you would like to install arch on:
fdisk -l | grep 'Disk /'
read -p 'Drive: ' drive

read -p 'Would you like to edit the partition table of the drive? (y/n) ' drive_edit_confirm

if [ "$drive_edit_confirm" == "y" ]; then
        fdisk /dev/sd$drive
fi

echo Choose the partitions you want arch to install on:
fdisk -l /dev/sd$drive

read -p 'Main Partition: ' main_part
read -p 'Swap Partition: ' swap_part

mkfs.ext4 /dev/sd$drive$main_part
mkswap /dev/sd$drive$swap_part

clear

echo

echo '======================\n'
echo '  INTERNET SETUP\n'
echo '======================\n'

read -p 'WiFi or Ethernet? (w/e)' wifi_eth

if [ "$wifi_eth" == "w" ]; then
	wifi-menu
fi
clear

echo '======================\n'
echo '  PACKAGE INSTALL\n'
echo '======================\n'


mount /dev/sd$drive$main_part /mnt

pacstrap /mnt base base-devel linux linux-firmware efibootmgr grub nano git dhcpcd dhclient networkmanager man-db man-pages texinfo bash sudo openssh parted wget

genfstab -U /mnt >> /mnt/etc/fstab

read -p 'Would you like to review the file system table? (y/n) ' review_fstab

if [ "$review_fstab" == "y" ]; then
        nano /mnt/etc/fstab
	echo 'Is the swap partition missing from the fs table? (y/n) ' add_swap
	if [ "$add_swap" == "y" ]; then
		fdisk -l /dev/sd$drive
		read -p 'Enter the swap partition: ' swap_part
		echo '' >> /mnt/fstab
		swap_drive_uuid=$(sudo blkid -s UUID -o value /dev/sd$drive$swap_part)
		printf "%s" "UUID=" "$swap_drive_uuid"  " none" " swap" " defaults" " 0" " 0" >> /mnt/etc/fstab
	fi
fi

clear

echo '======================\n'
echo '  TIME / LOCALES\n'
echo '======================\n'


echo 'Set system time zone'
arch-chroot /mnt ls /usr/share/zoneinfo/
read -p 'Region: ' install_region
arch-chroot /mnt ls /usr/share/zoneinfo/$install_region
read -p 'Time Zone: ' time_zone

arch-chroot /mnt ln -sf /usr/share/zoneinfo/$install_region/$time_zone /etc/localtime
hwclock --systohc

arch-chroot /mnt echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt echo 'LANG=en_US.UTF-8' >> /etc/locale.conf

clear

echo '======================\n'
echo '  NETWORK SETUP\n'
echo '======================\n'

echo 'Starting and enabling Network Manager...'

systemctl start NetworkManager
systemctl enable NetworkManager

if [ "$wifi_eth" == "w" ]; then
	nmcli r wifi on
	echo '\nLog into wifi with NetworkManager'
	echo 'Choose your network'
	nmcli d wifi list
	read -p 'SSID: ' ssid
	read -p -s 'Wifi Password: ' wifi_pass
	nmcli d wifi connect $ssid password $wifi_pass
fi

read -p 'Computer Name: ' pc_name
arch-chroot /mnt echo $pc_name >> /etc/hostname
arch-chroot /mnt echo '127.0.0.1	'$pc_name >> /etc/hosts
arch-chroot /mnt echo '::1		'$pc_name >> /etc/hosts
arch-chroot /mnt echo '127.0.1.1	'$pc_name'.localdomain	'$pc_name >> /etc/hosts

clear

echo '======================\n'
echo '  GRUB SETUP\n'
echo '======================\n'


read -p 'Would you like to edit GRUB before making config? (y/n) ' grub_edit_confirm

if [ "$grub_edit_confirm" == "y" ]; then
	arch-chroot /mnt nano /etc/default/grub
fi


arch-chroot /mnt mkdir /efi
arch-chroot /mnt mount /dev/sd$drive$efi_part /efi

arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo '======================\n'
echo '  USER / PERMS SETUP\n'
echo '======================'


echo 'Password for root user: '
arch-chroot /mnt passwd

read -p 'Non-root Username: ' user__name
arch-chroot /mnt useradd -m -G wheel,audio,video -s /bin/bash $user__name
echo $user__name'\'s Password:'
arch-chroot /mnt passwd $user__name

read -p 'Would you like to edit the sudo file? (y/n) ' sudo_edit_confirm

if [ "$sudo_edit_confirm" == "y" ]; then
        arch-chroot /mnt EDITOR=nano visudo
fi

clear

read -p 'Installation and setup has completed. Would you like to reboot or chroot into your system: (r/c) ' reboot_or_chroot

if [ "$reboot_or_chroot" == "c" ]; then
	echo 'Type \'exit\' to reboot the system'
        arch-chroot /mnt
fi

reboot
