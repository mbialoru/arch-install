# Arch BTRFS | ZRAM + SWAP | PIPEWIRE | WAYLAND

* If ssh'ing in from outside
	* Check ip address if ssh'ing in
		>	ip a

	* In case you need to bring an interface down or up
		> ip link set <interface> [up|down]

	* Set root password
		> passwd

* Verify Boot mode
	> ls /sys/firmware/efi/efivars
	# If displays correctly, then it's UEFI, otherwise its BIOS

* Check drives
	> lsblk

* Partition drives
	> gdisk <device>
		Here create:
			partiton for boot (UEFI code ef00 | BIOS code ef02) ~ 300M
			swap partition (code 8200) ~ ram size + .5G
			partition for BTRFS ~ remember about ssd over-provisioning
		write changes to disk

* Format partitions
	> mkfs.vfat <dev-boot>
	> mkswap <dev-swap> -p 0 (that 0 is important for zram priority)
	> mkfs.btrfs <dev-rootfs>

* Mount root fs into /mnt and enter it
	> mount <dev-rootfs> /mnt;cd /mnt

# Separating var allows to exclude it from snapshots
* Create root, home and var subvolume for btrfs
	> btrfs subvolume create @
	> btrfs subvolume create @home
	> btrfs subvolume create @var

* Go back unmount /mnt and mount created subvolume
	> cd
	> umount /mnt
	# For SSDs add also 'discard=async' (btrfs might do it automatically)
		> mount -o noatime,compress=zstd,space_cache,subvol=@ <dev-rootfs> /mnt

* Create directories in mounted /mnt for home and var
	> mkdir /mnt/{boot,home,var}

* Mount subvolumes to remaining directories in /mnt
	> mount -o noatime,compress=zstd,space_cache,subvol=@home <dev-rootfs> /mnt/home
	> mount -o noatime,compress=zstd,space_cache,subvol=@var <dev-rootfs> /mnt/var
    > mount <dev-boot> /mnt/boot

* After mounting we can begin installing packages
    # If on amd, use 'amd-ucode' instead
    > pacstrap /mnt base linux linux-firmware git vim intel-ucode btrfs-progs

* Generate FSTAB
    > genfstab -U /mnt >> /mnt/etc/fstab

* Change root to /mnt
    > arch-chroot /mnt

* Check rootfs and fstab
    > ls
    > cat /etc/fstab

* System should be ready for the instalation script, pull it from gitlab
    > git clone https://gitlab.sudobash.pl/Saligia/arch-install

* Search though the base.sh and modify it to your case
    > vim /arch-install/base.sh

* Make the base.sh executable
    > chmod +x /arch-install/base.sh

* Run the script
    ./archinstall/base.sh

* If your mkinitcpio.conf needs changes, do those now and recreate initramfs
    # example of GPUs - you might want to set in modules nvidia|amdgpu|i915 for
    nvidia, amd and intel gpus respectively (chose one)
    > mkinitcpio -p linux

* After rebooting, you should be greeted with a grub menu and arch linux option

* Keep in mind that installing gnome might have conflicts with locale set to polish for some reason.