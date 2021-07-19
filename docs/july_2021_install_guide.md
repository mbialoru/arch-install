# Features
EFI, BTRFS, LUKS, Swap partition + ZRAM, Pipeline, Wayland.

# General scheme
 0. Grab a copy of iso and boot from it
 1. Load keymap (if needed)
 2. Refresh servers `pacman -Syy`
 3. Partition disks
 4. Format partitions
 5. Mount partitions
 6. Instal base packages with `pacstrap` to /mnt
 7. Generate FSTAB (File Systems TABle)
 8. Chroot in with `arch-chroot /mnt`
 9. Clone instalation scripts from https://gitlab.sudobash.pl/pub/arch-install
10. Edit to your liking, make executable and run.
11. Apply additional tweaks, reboot
12. Finish instalation

# Caveats
* On VMs, when SSH'ed in and trying to restore to a previous snapshot which was taken after `arch-chroot` - there will be a problem with an existing leftover session of arch-chroot.
* On VMs, make sure that your VM is running on UEFI(EFI) booting (it's usually available in settings, look for `OVMF`)
* Keep in mind that wayland doesn't play very nicely with nvidia just yet, installing this system with DE like KDE might lead to some weird graphical glithes and other issues.
* BTRFS is officially under developement. Hovewer with Fedora34 released it became a default filesystem for that distro.
* With VMs and maybe even some bare metal configurations, GRUB might not work correctly. To fix this, try following attached commented-out commands in section about GRUB

# Installation procedure
## Before you start
* Download latest .iso of arch linux https://archlinux.org/download/
* Boot into live session
* Verify network access (report interfaces, ping google DNS)  
	`ip a`  
	`ping 8.8.8.8`  
	`ping sudobash.pl`

> In case where DHCP has assigned wrong local IP address, try:  
> `ip link set <interface> [up|down]`  
> To bring that interface down/up, you might need to do that a few times.

> If SSH'ing in from another machine, it is necessary to set root password:  
> `echo root:root | chpasswd` or just simply `passwd`  
> Also make sure that `sshd` service is running and that you can actually connect as root.

* To verify if you are using UEFI or BIOS execute:  
	`ls /sys/firmware/efi/efivars`

> If you can see output with some variables, it means that you are in UEFI(EFI) mode, if however there was an error or no output, you are most likely in BIOS mode.

* Check drives availability  
	`lsblk`

## Partition drives and format
* For clean drives writing over old partition tables isn't necessary, however of you want to destroy any remaining data you might want to overwrite it, also to just wipe the header of partiton table run the command and stop it after a short while:  
	`badblocks -c 10240 -s -w -t random -v /dev/sdX`
* When the drive is ready, we are going to partition it with gdisk  
	`gdisk /dev/sdX`
* When inside a new partition table will most likely be created. We need to create few partitions:
	1. EFI (code ef00) ~ 200M
	2. GRUB ~ 600M
	3. SWAP (code 8200) - System RAM size + .5G should be good
	4. BTRFS - rest of the disk (remember about ssd over-provisioning)

> GRUB partition is optional, if ommiting it, adjust the EFI size to 600M and mount it directly to /boot/efi

* Write changes to disks and check if it's okay  
	`lsblk`

* Create LUKS volume and open it, we call it here **luksloop**  
	`cryptsetup luksFormat --cipher aes-xts-plain64 --key-size 256 --hash sha256 --use-random /dev/sda4`  
	`cryptsetup luksOpen /dev/sda4 luksloop`

* Now we need to format our partitions (pay attention to swap):
	1. `mkfs.vfat /dev/sdX1` 			  Format EFI partition to FAT32
	2. `mkfs.ext4 /dev/sdX2`  			  Format GRUB partition to EXT4
	3. `mkswap /dev/sdX3` 	 			  Create swap
	4. `mkfs.btrfs /dev/mapper/luksloop` Format root partition to BTRFS

> You might want to set labels for new partitions with `e2label`

* Mount the encrypted root file system  
	`mount -o noatime,compress=lzo,discard,ssd,defaults,space_cache /dev/mapper/luksloop /mnt`

> Used mount options:
> * **noatime** - Do not update inode access times, allows for faster access.
> * **compress=lzo** - faster compression algoritm than zlib or zstd
> * **discard=async** - good for SSDs as it enables them to reclaim freed space.
> * **ssd** - explicitly points to an SSD beeing used, optional because btrfs should detect that automatically.
> * **space_cache** - enables v1 free space cache, improves performance when reading block group free space into memory
> * **default** - [rw, suid, dev, exec, auto, nouser, async] in one parameter

* Create subvolumes
```bash
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @var
cd ; umount /mnt
```

> Naming convention used here with `@` in name is a standard naming convention used in Debian, Ubuntu and few other distros. It also allows `Timeshift` to work correctly.

* Mount created subvolumes and create required directories
```bash
mount -o noatime,compress=lzo,discard,ssd,defaults,space_cache,subvol=@ /dev/mapper/luksloop /mnt
mkdir /mnt/{home,var,boot}
mount -o noatime,compress=lzo,discard,ssd,defaults,space_cache,subvol=@home /dev/mapper/luksloop /mnt/home
mount -o noatime,compress=lzo,discard,ssd,defaults,space_cache,subvol=@var /dev/mapper/luksloop /mnt/var
sync
```

* Mount remaining non-btrfs partitions and set swap
```bash
mount /dev/sdX2 /mnt/boot
mkdir /mnt/boot/efi
mount /dev/sdX1 /mnt/boot/efi
swapon /dev/sdX3 -p 0
swapon -a ; swapon -s
```

> `swapon -a ; swapon -s` is here to activate swap on all available devices (in this case it's just one) and notify about the status of swap

## Begin the actual installation
* With `pacstrap` install needed packages  
	`pacstrap /mnt base base-devel linux linux-firmware vim git intel-ucode btrfs-progs`

> If you are using AMD CPU, use `amd-ucode` instead

* Generate FSTAB  
	`genfstab -p -U /mnt >> /mnt/etc/fstab`

* chroot into your freshly installed arch linux  
	`arch-chroot /mnt`

* Check root file system and fstab  
	`ls;cat /etc/fstab`

* Download instalation scripts  
	`cd /tmp;git clone https://gitlab.sudobash.pl/pub/arch-install`

* Modify the script to your preferences
	`vim arch-install/base.sh`

* Make it executable and run it

* After script finishes, we need to apply changes to mkinitcpio.conf
In `/etc/mkinitcpio.conf` within `HOOKS` section add `encrypt` between `filesystems` and `block` or use this command:
```bash
sed -i 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS="base\ udev\ autodetect\ modconf\ block\ encrypt\ filesystems\ keyboard\ fsck"/' /etc/mkinitcpio.conf
```
If you use Nvidia/AMD/Intel graphics card you might want to add `nvidia` `amdgpu` or `i915` in `MODULES` section

Also since we are using BTRFS, in `MODULES` you should add `btrfs` and in `BINARIES` `/usr/bin/btrfs`

Don't forget to apply changes with `mkinitcpio -p linux`

* Apply changes to GRUB boot loader (for LUKS parameters)
```bash
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=\/dev\/sda4:luksloop\ root=\/dev\/mapper\/luksloop\ rootflags=subvol=@\ quiet"/' /etc/default/grub
```

* Regenerate grub.cfg
```bash
grub-mkconfig -o /boot/grub/grub.cfg
# grub-mkconfig -o /boot/efi/EFI/GRUB/grub.cfg
# mkdir /boot/efi/EFI/BOOT
# cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
```

* Restart
```bash
sync
exit
umount -a
reboot
```

| Note 								      |
|-----------------------------------------|
If after rebooting you see a valid GRUB screen with `Arch Linux` as an option to boot, choose it and input your LUKS password. If after that you will see the prompt to login - Congratulations, your installation of Arch linux was successful. However if not, you might want to check with your UEFI(EFI) configuration or take a look at the `Caveats` section

# Post-Install
After successful instalation, you might want to back up the disk with `dd` or some other backup method just in case something goes wrong (or make a snapshot if it's a virtual machine) Now onto the last few remaining steps.

## Enable ZRAM
* First install package `zramd` from AUR (or use a helper)
* Edit /etc/default/zramd to set parameters of ZRAM
* Enable zramd.service
	`systemctl enable --now zramd.service`
* Check with `lsblk` and `swapon -a ; swapon -s`

## Encrypt Swap
https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption

If you want to encrypt swap, you need to uncomment the line beggining with `swap` in `/etc/crypttab` and add device as desired.

| :exclamation:  Attention			      |
|-----------------------------------------|
Order of devices in simple naming convention might change on boot, thus naming your encrypted swap partition the simple way (/dev/sdX#) might open up a possibility of wiping the same partition in a wrong drive. To circumvent this, you can a persistent name. To do this check the device id with `find -L /dev/disk -samefile /dev/sdX#` it will return persistent names, place it (or one of them if there are more - preferably one that has 'by-id') in `/etc/crypttab` under `device` column.

| :exclamation:  Attention			      |
|-----------------------------------------|
Encrypting swap with a random password every time will render it useless after pc shutdown, this also means that hybernation will **NOT** be available