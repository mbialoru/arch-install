#!/bin/bash

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

# Xorg should be installed together with a desired WM/DE
# Optionals are 'bluez bluez-utils cups hplip tlp'

# Install packages
pacman -S grub grub-btrfs efibootmgr networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools base-devel linux-headers avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils cups hplip alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack bash-completion openssh rsync reflector acpi acpi_call tlp virt-manager qemu qemu-arch-extra edk2-ovmf bridge-utils dnsmasq vde2 openbsd-netcat iptables-nft ipset firewalld flatpak sof-firmware nss-mdns acpid os-prober ntfs-3g terminus-font

# Appropriate video drivers
# pacman -S --noconfirm xf86-video-amdgpu
pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

# Install and configure GRUB (Watch out for os-probber if dualbooting)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Enable services
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups.service		# Printer service
systemctl enable sshd				# SSH daemon
systemctl enable avahi-daemon		# mDNS/DNS daemon
systemctl enable tlp				# Laptop Battery management
systemctl enable reflector.timer	# Periodic mirrors list sorting by speed
systemctl enable fstrim.timer		# Periodic trim for SSD
systemctl enable libvirtd			# Virtualization
systemctl enable firewalld
systemctl enable acpid				# Advanced Configuration & Power Interface

# Setup user
useradd -m saligia
echo saligia:password | chpasswd
usermod -aG libvirt saligia
echo "saligia ALL=(ALL) ALL" >> /etc/sudoers.d/saligia

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m\n"