# Summary
UEFI, BTRFS (@, @home, @var), LUKS, Encrypted swap partition + ZRAM, Pulseaudio,
Apparmor, Duplicati, Snapper, Firejail, ClamAV, Separate drive for backups
(duplicati and disk images), NVIDIA driver, Xorg with i3 rice

| :exclamation:  Warning                  |
|-----------------------------------------|
Before proceeding, read the whole thing just to be sure that you caught any
problems which might prop-up durring instalation!

# General scheme
 0. Grab a copy of latest iso, burn it and boot from it
 1. Load keymap (if needed)
 2. Refresh servers with `pacman -Syy`
 3. Partition disks
 4. Format partitions
 5. Mount partitions
 6. Instal base packages with `pacstrap` to /mnt
 7. Generate FSTAB (File Systems TABle)
 8. Chroot in with `arch-chroot /mnt`
 9. Clone instalation scripts from repository
10. Edit to your liking, make executable and run.
11. Apply additional tweaks, reboot
12. Finish instalation

Repositories:  
`https://github.com/mbialoru/arch-install` (public)  
`https://gitlab.sudobash.pl/Saligia/arch-linux` (private)

# Caveats
* On VMs, when SSH'ed in and trying to restore to a previous snapshot which was
taken after `arch-chroot` - there will be a problem with an existing leftover
session of arch-chroot.
* On VMs, make sure that your VM is running on UEFI(EFI) booting (it's usually
available in settings, look for `OVMF`)
* BTRFS is officially under developement. Hovewer with Fedora34 released, it
became a default filesystem for that distro.

RAID on BTRFS with levels 5 and 6 is fatally flawed, the arch-wiki states
as of August 2021. Multi-device setups are possible, albeit a bit tricky. RAID
levels supported are 0, 1, 10, 5 and 6

* With VMs and maybe even some bare metal configurations, GRUB might not work
correctly. To fix this, try following attached commented-out commands in section
about installing GRUB

# Instalation
## Before you start
In this section we get into the live session on arch linux iso, and check if
crucial elements are working correctly

* Check your bios settings

Make sure that you can boot from USB devices, and that UEFI mode is on, there 
might be a requirement to set addidional setting to allow for legacy support for
just the USB to boot correctly.

* Download latest .iso of arch linux https://archlinux.org/download/
* Burn it
* Boot into live session
* Verify network access (check interfaces, ping google DNS, and a domain name)  
    `ip a`  
    `ping 8.8.8.8`  
    `ping google.pl`

This is to make sure that you have internet access and DNS is working correctly

> In case where DHCP has assigned wrong local IP address, try:  
> `ip link set <interface> [up|down]`  
> To bring that interface up/down, you might need to do that a few times.

> If SSH'ing in from another machine, it is necessary to set root password:  
> `echo root:root | chpasswd` or just simply `passwd`  
> Also make sure that `sshd` service is running and that you can actually
> connect as root.

* To verify if you are using UEFI or BIOS execute:  
    `ls /sys/firmware/efi/efivars`

If you can see output with some variables, it means that you are in UEFI(EFI)
mode, if however there was an error or no output, you are most likely in BIOS
mode.

* Check drives availability  
    `lsblk`

Make sure that all of the drives (or at lest the ones that you want to use) are
detected and listed correctly

## Prepare drives
For clean drives writing over old partition tables isn't necessary, however if
you want to destroy any remaining data you might want to write over it, also to
just wipe the header of partiton table run the command and stop it after a short
while:  
    `badblocks -c 10240 -s -w -t random -v /dev/sdX`

* Partition with tool of choice (fdisk, gdisk, cfdisk, cgdisk, parted ...)
    1. EFI (code ef00) ~ 200M (For GRUB)
    2. GRUB ~ 600M
    3. SWAP (code 8200) - System RAM size + .5G should be good enough
    4. BTRFS - rest of the disk (remember about ssd over-provisioning)
    5. Other partitions (if you're adding any)

### Additional partitions
I case of this particular instalation additional partitions will be on separate
drives. WD Blue 2TB will house DATA_A and DATA_B both of type EXT4, Seagate 1TB
will house BACKUPS and IMAGES both of type EXT4. Samsung 870 QVO 1TB will house
FAST_A, FAST_B and FAST_BACKUPS subvolumes of BTRFS type
.
### Swap size
There is a heated debate over 'how big my swap should be?' truth to be told,
it's completely up to you. Different concepts are supported by their 
respective userbases (everything from 0.5xRAM to 2xRAM) in my opinion though
twice the ram size is a bit silly, with 32G of it, you allocate 64G. If then you
have a 256G SSD that is like 1/4 of its size, which you probably will never
use. So a good rule of thumb is to set it to system ram size +0.5G - this
makes sure that you will actually be able to suspend the system and isn't too
wasteful. Usually.

* Write changes to disks and check if it's okay  
    `lsblk`

* Create LUKS volume and open it, we call it here **luksloop**  
    `cryptsetup luksFormat --cipher aes-xts-plain64 --key-size 256 --hash sha256
    --use-random /dev/sda4`  
    `cryptsetup luksOpen /dev/sda4 luksloop`

* Now we need to format our partitions (remember about swap):
    1. `mkfs.vfat /dev/sdX1`             Format EFI  partition to FAT32
    2. `mkfs.ext4 /dev/sdX2`             Format GRUB partition to EXT4
    3. `mkswap /dev/sdX3`                Create swap
    4. `mkfs.btrfs /dev/mapper/luksloop` Format root partition to BTRFS
    5.  Other partitions (if you're adding any)

While using CLI tools to partition and format the drives, you might want to add
labels for freshly created partitions. Keep in mind that every partition type
has it's own way of adding labels

* Mount the encrypted root file system  
    `mount -o noatime,compress=lzo,discard,ssd,defaults,space_cache=v1
    /dev/mapper/luksloop /mnt`

Used mount options:
* **noatime** - Do not update inode access times, allows for faster access.
* **compress=lzo** - faster compression algoritm than zlib or zstd
* **discard=async** - good for SSDs as it enables them to reclaim freed space.
* **ssd** - explicitly points to an SSD beeing used, optional because btrfs
should detect that automatically.
* **space_cache=v1** - enables v1 free space cache, improves performance when
reading block group free space into memory
* **defaults** - [rw, suid, dev, exec, auto, nouser, async, relatime] in one
parameter

* Create subvolumes
```bash
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @snapshots
btrfs subvolume create @var_log
cd ; umount /mnt
```

Separate subvolume for snapshots of /, mounted later at /.snapshots allows us to
rollback whole / to a previous snapshot with no issues. Otherwise all that's
left is just booting from snapshot via grub.

Important to note here that btrfs has a limitation that disallows snapshotted
volumes from containing a swap file - that is why this instalation doesn't have
a swapfile and uses swap partiton with zram.

> Naming convention used here with `@` in name is a standard naming convention
> used in Debian, Ubuntu and few other distros. It also allows `Timeshift` to
> work correctly.

* Mount created subvolumes and create required directories
```bash
mount -o noatime,compress=lzo,discard,ssd,defaults,space_cache=v1,subvol=@ /dev/mapper/luksloop /mnt
mkdir /mnt/{home,var,boot,.snapshots}
mount -o noatime,compress=lzo,discard,ssd,defaults,space_cache=v1,subvol=@home /dev/mapper/luksloop /mnt/home
mount -o noatime,compress=lzo,discard,ssd,defaults,space_cache=v1,subvol=@var /dev/mapper/luksloop /mnt/var
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

`swapon -a ; swapon -s` is here to activate swap on all available devices (in
this case it's just one) and notify about the status of swap

## Begin Instalation
At this point the system should have been already checked, drives partitioned,
formatted and mounted. Everything is ready to go.

* With `pacstrap` install needed base packages  
    `pacstrap /mnt base base-devel linux linux-firmware vim git intel-ucode
    btrfs-progs`

> If you are using AMD CPU, use `amd-ucode` instead

* Generate FSTAB  
    `genfstab -p -U /mnt >> /mnt/etc/fstab`

> Use single `>` to replace contents of current fstab file

* chroot into your freshly installed arch linux  
    `arch-chroot /mnt`

* Check root file system and fstab  
    `ls;cat /etc/fstab`

* Download instalation scripts  
    `cd /tmp;git clone <LINK TO REPO - SEE TOP OF THIS FILE>`

* Modify the script to your preferences
    `vim arch-install/base-uefi.sh`

* Make it executable and run it

* After script finishes, we need to apply changes to mkinitcpio.conf
In `/etc/mkinitcpio.conf` within `HOOKS` section add `encrypt` between
`filesystems` and `block` or use this command:
```bash
sed -i 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS="base\ udev\ autodetect\ modconf\ block\ encrypt\ filesystems\ keyboard\ fsck"/' /etc/mkinitcpio.conf
```

If you use Nvidia/AMD/Intel graphics card you might want to add `nvidia`
`amdgpu` or `i915` (or `nouveau` in case of FOSS driver) in `MODULES` section  
Also since we are using BTRFS, in `MODULES` you should add `btrfs` and in
`BINARIES` `/usr/bin/btrfs`  
Don't forget to apply changes with `mkinitcpio -p linux`

* Apply changes to GRUB boot loader (for LUKS parameters)
```bash
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=\/dev\/sda4:luksloop\ root=\/dev\/mapper\/luksloop\ rootflags=subvol=@\ quiet"/' /etc/default/grub
```
* Regenerate grub.cfg `grub-mkconfig -o /boot/grub/grub.cfg`
* Restart
```bash
sync
exit
umount -a
reboot
```

| Note                                    |
|-----------------------------------------|
If after rebooting you see a valid GRUB screen with `Arch Linux` as an option to
boot, choose it and input your LUKS password. If after that you will see the
prompt to login - Congratulations, your installation of Arch linux was
successful. However if not, you might want to check with your UEFI(EFI)
configuration or take a look at the `Caveats` section

# Post-Install
After successful instalation, you might want to back up the disk with clonezilla (included on the arch linux iso) or `dd` or some other backup method just in case something goes wrong (or make a snapshot if it's a virtual machine) Now onto the last few remaining steps.

## Install Snapper
* Install package `snapper`, `snap-pac` and `snap-pac-grub` (aur)
* Create `root` config with `snapper -c root create-config /`


## Enable ZRAM
* First install package `zramd` from AUR (or use a helper)
* Edit /etc/default/zramd to set parameters of ZRAM
* Enable zramd.service
    `systemctl enable --now zramd.service`
* Check with `lsblk` and `swapon -a ; swapon -s`

## Configure AppArmor
Every official arch linux kernel comes with AppArmor support included - it has
been chosen over SELinux - thats opposing to RHEL/Fedora. SELinux attaches
labels which makes it flexible but takes a lot of effort to get it installed and
configured correctly.

* AppArmor is available but disabled by default - to check it's status we can:
    `zgrep CONFIG_LSM= /proc/config.gz`

Now if there isn't `apparmor` within the output - then AA is disabled.

* To enable AppArmor it's necessary to modify `/etc/grub/default` and under
`GRUB_CMDLINE_LINUX_DEFAULT` add `lsm=landlock,lockdown,yama,apparmor,bpf`
* After that rerun the grub-mkconfig
* Install userland tools with `pacman -S apparmor`
* Enable service `systemctl enable --now apparmor`
* Reboot
* Check status with `aa-enabled` and `aa-status`

If you want to make your own profiles - check `Audit Framework`, it's required.

## Configure Duplicati - TODO
Duplicati is free and opensource solution for backups

* Install `duplicati-latest` from AUR

## Install Firejail - TODO

## Configure HDD standby timeout
### hdparm
If your machine has mechanical hard drives that house data partitions which you
do not use a lot and thus generates noise - it is possible to configure timeout
after which HDDs will be put to standby, saving power and making the machine
less noisy.
* Install `hdparm` package - `pacman -S hdparm`
* Locate the drive you want to modify with `lsblk`
* Check it's current settings with `hdparm -I /dev/sdX`

At this point we have basically three values to work with, one is about power
management - APM(Advanced Power Management), second one is just plain spindown
time - after this time drive will spindown, and third is not always available to
all drives - Automatic Acoustic Management, modern drives have an option to slow
down their head movements to generate less noise.

APM (denoted by -B parameteris between 1 and 255 (lower means more aggresive
power conservation), while SD (denoted by -S parameter) is between 1 and 251.
From 1 to 240 it multiplies the number by 5s over that and it counts as a
multitude od 30min.

* To make changes persistent, use `udev` rule. Add to `/etc/udev/rules.d/69-hdpa
rm.rules`
    `ACTION=="add", SUBSYSTEM=="block", KERNEL=="sda", RUN+="/usr/bin/hdparm -B x -S x /dev/sda"`

> To make sure that the right drive gets affected every time, identify drives by
> their serial numbers

### hd-idle
If `hdparm` didn't cut it, or your hard drive doesn't support APM or SD, you can
use `hd-idle` package.

* Install `hd-idle` package
* Edit `/etc/conf.d/hd-idle` and add line
    `HD_IDLE_OPTS="-i 0 -a /dev/sda -i 60 -a /dev/sdb -i 60"`  
This ensures that hard drives sda and sdb will spindown after 1 minute of idling