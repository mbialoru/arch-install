#!/bin/bash

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo reflector -c Poland -a 12 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syy

# Main packages
sudo pacman -S --noconfirm wayland xorg-xwayland xorg-xlsclients qt5-wayland
glfw-wayland sway alacritty waybar wofi
