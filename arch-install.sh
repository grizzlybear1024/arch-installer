#!/bin/bash


timedatectl set-ntp true
drive_letter=s
efi_vars=/sys/firmware/efi/efivars
total_mem=$(cat /proc/meminfo | grep MemTotal: | cut -d " " -f 8)
if find "efi_vars" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then #IF SYSTEM IS UEFI
    efi = 1
else
    efi = 0
fi
clear

echo '======================'
echo '  DISK SETUP'
echo '======================'
echo ''


if [ "$efi" -eq "1" ]; then #IF SYSTEM IS UEFI
    echo 'SYSTEM IS UEFI'
else
    echo 'SYSTEM IS NOT UEFI'
fi

echo 'Choose the drive you would like to install arch on:'
echo ''
fdisk -l
read -p 'Drive (enter the lowercase letter after /dev/'${drive_letter}'d, for example a for /dev/'${drive_letter}'da: ' drive

read -p 'Would you like to automatically set up the partitions (WARNING: THIS WILL WIPE ALL DATA FROM THE DRIVE) (y/n)' auto_drive_setup

if [ "$auto_drive_setup" == "y" ]; then
    read -p 'ARE YOU SURE YOU WANT TO WIPE ALL DATA FROM /dev/'${drive_letter}'d'$drive'? (y/n) ' wipe_confirm
    
    if [ "$wipe_confirm" == "y" ]; then
        if [ "$efi" -eq "1" ]; then #IF SYSTEM IS UEFI
            sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/${drive_letter}d$drive
    g # clear the in memory partition table
    n # new partition
    p # primary partition
    1 # partition number 1
    # default - start at beginning of disk 
    +500M # EFI boot parttion
    n # new partition
    p # primary partition
    2 # partion number 2
    # default, start immediately after preceding partition
    -${total_mem}K # default, extend partition to end of disk -RAM
    n # new partition
    p # primary partition
    3 # partion number 1
    # default, start immediately after preceding partition
    # end of drive
    w # write the partition table
EOF
            efi_drive = $drive
            efi_part = 1
            main_part = 2
            swap_part = 3
        else #IF SYSTEM IS NOT UEFI
            sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/${drive_letter}d$drive
    o # clear the in memory partition table
    n # new partition
    p # primary partition
    1 # partion number 1
    # default, start immediately after preceding partition
    -${total_mem}K # default, extend partition to end of disk -RAM
    n # new partition
    p # primary partition
    2 # partion number 1
    # default, start immediately after preceding partition
    # end of drive
    w # write the partition table and save to disk
EOF
        main_part = 1
        swap_part = 2
        fi
    fi
else
    if [ "$efi" -eq "1" ]; then #IF SYSTEM IS UEFI
        read -p 'Would you like to manually edit the partition table of the drive? (y/n) ' drive_edit_confirm

        if [ "$drive_edit_confirm" == "y" ]; then
                clear
                fdisk /dev/${drive_letter}d$drive
        fi
        echo Choose the partitions you want arch to install on:
        fdisk -l /dev/${drive_letter}d$drive

        read -p 'Main Partition: ' main_part
        read -p 'Swap Partition: ' swap_part

        read -p 'Is the EFI Partition on another drive? (y/n)' efi_another_drive

        if [ "$efi_another_drive" == "y" ]; then
            fdisk -l
            read -p "EFI Drive: " efi_drive
        else
            efi_drive=$drive
        fi

        read -p 'EFI Partition: ' efi_part
    else #IF SYSTEM IS NOT UEFI
        efi = 0
        read -p 'Would you like to manually edit the partition table of the drive? (y/n) ' drive_edit_confirm

        if [ "$drive_edit_confirm" == "y" ]; then
                clear
                fdisk /dev/${drive_letter}d$drive
        fi
    fi
fi
clear

echo '======================'
echo '  PACKAGE INSTALL'
echo '======================'


mount /dev/${drive_letter}d$drive$main_part /mnt

pacstrap /mnt base base-devel linux linux-firmware efibootmgr grub nano git dhcpcd dhclient networkmanager man-db man-pages texinfo bash sudo openssh parted reflector ntfs-3g os-prober wget

genfstab -U /mnt >> /mnt/etc/fstab

read -p 'Would you like to review the file system table? (y/n) ' review_fstab

if [ "$review_fstab" == "y" ]; then
        nano /mnt/etc/fstab
        clear
	read -p 'Is the swap partition missing from the fs table? (y/n) ' add_swap
	if [ "$add_swap" == "y" ]; then
		fdisk -l /dev/${drive_letter}d$drive
		read -p 'Enter the swap partition: ' swap_part
		echo '' >> /mnt/fstab
		swap_drive_uuid=$(blkid -s UUID -o value /dev/${drive_letter}d$drive$swap_part)
		printf "%s" "UUID=" "$swap_drive_uuid"  " none" " swap" " defaults" " 0" " 0" >> /mnt/etc/fstab
	fi
fi

clear

echo '======================'
echo '  TIME / LOCALES'
echo '======================'


echo 'Set system time zone'
arch-chroot /mnt ls /usr/share/zoneinfo/
read -p 'Region: ' install_region
arch-chroot /mnt ls /usr/share/zoneinfo/$install_region
read -p 'Time Zone: ' time_zone

arch-chroot /mnt ln -sf /usr/share/zoneinfo/$install_region/$time_zone /etc/localtime
arch-chroot /mnt hwclock --systohc

echo 'en_US.UTF-8 UTF-8' >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo 'LANG=en_US.UTF-8' >> /mnt/etc/locale.conf

clear

echo '======================'
echo '  NETWORK SETUP'
echo '======================'

echo 'Starting and enabling Network Manager...'

arch-chroot /mnt systemctl start NetworkManager
arch-chroot /mnt systemctl enable NetworkManager

read -p 'Computer Name: ' pc_name
echo $pc_name >> /mnt/etc/hostname
echo '127.0.0.1	'$pc_name >> /mnt/etc/hosts
echo '::1		'$pc_name >> /mnt/etc/hosts
echo '127.0.1.1	'$pc_name'.localdomain	'$pc_name >> /mnt/etc/hosts

echo 'Would you like to auto-rank mirrors for improved pacman download speeds? This may take a while (y/n) ' mirrors_confirm

if [ "$mirrors_confirm" == "y" ]; then
    arch-chroot /mnt cp /etc/pacman.d/mirrorlist /etc/pacman.d/backup-mirrorlist
    arch-chroot /mnt reflector --sort rate --save /etc/pacman.d/mirrorlist
fi

echo 'Would you like to edit /etc/pacman.conf to enable 32 bit support? (y/n) ' pacman_conf_confirm

if [ "$pacman_conf_confirm" == "y" ]; then
    arch-chroot /mnt nano /etc/pacman.conf
fi

echo 'Would you like to install an AUR helper (yay) (y/n) ' yay_confirm

if [ "$yay_confirm" == "y" ]; then
    arch-chroot /mnt git clone https://aur.archlinux.org/yay.git
    arch-chroot /mnt cd yay & makepkg -si
    arch-chroot /mnt cd ..
fi

echo 'Are you running on an Intel or AMD Processor? (enter b for both if installing on USB drive) (i/a/b) ' ucode

if [ "$ucode" == "i" ]; then
    arch-chroot /mnt pacman -S intel-ucode --noconfirm
else if [ "$ucode" == "a" ]; then
    arch-chroot /mnt pacman -S amd-ucode --noconfirm
else 
    arch-chroot /mnt pacman -S intel-ucode amd-ucode --noconfirm
fi

arch-chroot /mnt pacman -Syu --noconfirm

clear

echo '======================'
echo '  GRUB SETUP'
echo '======================'


read -p 'Would you like to edit GRUB before making config? (y/n) ' grub_edit_confirm

if [ "$grub_edit_confirm" == "y" ]; then
	arch-chroot /mnt nano /etc/default/grub
	clear
fi

read -p 'Do you have other operating systems installed on your computer? (y/n) ' other_os

if [ "$other_os" == "y" ]; then
	arch-chroot /mnt os-prober
fi

if [ "$efi" -eq "1" ]; then
    arch-chroot /mnt mkdir /efi
    arch-chroot /mnt mount /dev/${drive_letter}d$efi_drive$efi_part /efi

    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
else
    grub-install --target=i386-pc /dev/${drive_letter}d$drive
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
fi
clear

echo '======================'
echo '  USER / PERMS SETUP'
echo '======================'


echo 'Password for root user: '
arch-chroot /mnt passwd

read -p 'sudo Username: ' user__name
arch-chroot /mnt useradd -m -G wheel,audio,video -s /bin/bash $user__name
echo 'Password:'
arch-chroot /mnt passwd $user__name

echo '%wheel ALL=(ALL) ALL' >> /mnt/etc/sudoers
clear

read -p 'Installation and setup has completed. Would you like to reboot or chroot into your system: (r/c) ' reboot_or_chroot

if [ "$reboot_or_chroot" == "c" ]; then
	echo 'Type exit to reboot the system'
        arch-chroot /mnt
fi

reboot
