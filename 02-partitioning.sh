#!/bin/bash

# ------------------------------------------------------------------------
# Configure Host
# ------------------------------------------------------------------------

echo -e "\nFormatting disk...\n$HR"
# disk prep
sgdisk -Z /dev/sda # zap all on disk
sgdisk -a 2048 -o /dev/sda # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+200M /dev/sda    # partition 1 (UEFI BOOT)       200MB
sgdisk -n 2:0:0 /dev/sda        # partition 3, (LUKS)            rest

# set partition types
sgdisk -t 1:ef00 /dev/sda
sgdisk -t 2:8300 /dev/sda

# label partitions
sgdisk -c 1:"UEFI Boot" /dev/sda
sgdisk -c 2:"cryptlvm" /dev/sda

# Create encrypted partitions
# This creates one partions for root, modify if /home or other partitions should be on separate partitions
print -r $PASSWORD | cryptsetup luksFormat /dev/disk/by-partlabel/cryptlvm
print -r $PASSWORD | cryptsetup open /dev/disk/by-partlabel/cryptlvm lvm
pvcreate $INSTALL_DEV
vgcreate storage $INSTALL_DEV
lvcreate --size 15G storage --name root
lvcreate --size  4G storage --name swap
lvcreate -l +100%FREE storage --name home

INSTALL_DEV="/dev/mapper/storage-system"

# mkfs filesystems
echo -e "\nCreating Filesystems...\n$HR"
mkfs.vfat -F32 /dev/sda1
#mkfs.ext2 /dev/sda2                             # REMOVE THIS
#mkswap /dev/sda2                                # REMOVE THIS
#mkfs.ext4 /dev/sda3
#mkfs.ntfs /dev/sda3

# mkfs lvm
mkfs.ext4 /dev/mapper/storage-root
#mkfs.ext4 /dev/mapper/vg0-swap                 # NOT NEEDED
mkfs.ext4 /dev/mapper/storage-home
mkswap -L swap /dev/mapper/storage-swap
swapon -d -L swap

### MOUNT

# mount target
umount -R /mnt
mount /dev/storage/root /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir -p /mnt/home
mount /dev/storage/home /mnt/home
