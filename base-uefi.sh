#!/bin/bash

# This script installs base of ArchLinux with UEFI(EFI)

# Setup time
ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
hwclock --systohc
# Setup locale, language and keymap 
sed -i '177s/.//' /etc/locale.gen # Activate en_US.UTF-8 UTF-8
sed -i '390s/.//' /etc/locale.gen # Activate pl_PL.UTF-8 UTF-8
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=pl" >> /etc/vconsole.conf

# Setup hostname
echo "arch" >> /etc/hostname

# Setup /etc/hosts
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 arch.localdomain arch" >> /etc/hosts

# Setup root password
echo root:password | chpasswd

# Install packages
pacman -S grub grub-btrfs efibootmgr networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools base-devel linux-headers avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils cups hplip alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack bash-completion openssh rsync reflector acpi acpi_call tlp virt-manager qemu qemu-arch-extra edk2-ovmf bridge-utils dnsmasq vde2 openbsd-netcat iptables-nft ipset firewalld flatpak sof-firmware nss-mdns acpid os-prober ntfs-3g terminus-font

# Appropriate video drivers
# pacman -S --noconfirm mesa
# pacman -S --noconfirm xf86-video-intel
# pacman -S --noconfirm xf86-video-amdgpu
pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

# Install and configure GRUB (Watch out for os-probber if dualbooting)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# NOTE:
# Adding `--removable` to grub-install command will make it install itself to 
# esp/EFI/BOOT/BOOTX64.EFI allowing to boot even if EFI vars get lost or drive
# gets moved to another computer

# Enable services
systemctl enable NetworkManager     # Network manager for interfaces
systemctl enable sshd               # SSH daemon
systemctl enable avahi-daemon       # mDNS/DNS daemon
systemctl enable reflector.timer    # Periodic mirrors list sorting by speed
systemctl enable fstrim.timer       # Periodic trim for SSD
systemctl enable libvirtd           # Virtualization
systemctl enable firewalld          # Firewall daemon
systemctl enable acpid              # Advanced Configuration & Power Interface
systemctl enable bluetooth          # Bluetooth service
systemctl enable cups.service       # Printer service
systemctl enable tlp                # Laptop Battery management

# NOTE:
# fstrim.timer runs about once a week, If you are using discard=async with
# btrfs, you might find yourself turning this off, beacause that parameter
# allows the SSD drive to reclaim space immediately. Doesn't hurt though.

# Setup user
useradd -m saligia
echo saligia:password | chpasswd
usermod -aG libvirt saligia
echo "saligia ALL=(ALL) ALL" >> /etc/sudoers.d/saligia

# groupadd sudo                         # Add sudo group for sudo privileges
# sed -i '88s/..//' /etc/sudoers        # Allow sudo group to use sudo
# usermod -aG sudo saligia

# NOTE:
# This is a very hacky way, as you should never edit sudoers file w/o visudo

printf "\e[1;32mDone! Type exit, umount -a and reboot.\n\e[0m"