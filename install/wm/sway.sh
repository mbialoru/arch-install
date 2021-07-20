#!/bin/bash

# This script installs sway window manager with wayland display server

# Set the clock to network time synchronization and set RTC from system time
sudo timedatectl set-ntp true
sudo hwclock --systohc

# Refresh available mirrors list and repositories
sudo reflector --latest 200 --protocol http,https --country 'Poland' --age 12 --sort rate --connection-timeout 2 --save /etc/pacman.d/mirrorlist
sudo pacman -Syy

# Install AUR helper package
cd /tmp
git clone https://aur.archlinux.org/paru.git
cd paru;makepkg -si --noconfirm


# Install sway packages
sudo pacman -S --noconfirm wayland xorg-xwayland xorg-xlsclients qt5-wayland glfw-wayland sway alacritty waybar wofi

# Install font packages
sudo pacman -S --noconfirm dina-font tamsyn-font bdf-unifont ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid gnu-free-fonts ttf-ibm-plex ttf-liberation ttf-linux-libertine noto-fonts ttf-roboto tex-gyre-fonts ttf-ubuntu-font-family ttf-anonymous-pro ttf-cascadia-code ttf-fantasque-sans-mono ttf-fira-mono ttf-hack ttf-fira-code ttf-inconsolata ttf-jetbrains-mono ttf-monofur adobe-source-code-pro-fonts cantarell-fonts inter-font ttf-opensans gentium-plus-font ttf-junicode adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts noto-fonts-cjk noto-fonts-emoji

# Use sample config as starting base
mkdir -p ~/.config/sway
cp /etc/sway/config ~/.config/sway

printf "\e[1;32mDone!\n\e[0m"