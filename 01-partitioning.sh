#!/bin/bash

set -o nounset

source vars.sh
#umount -R /mnt
#partprobe

# ------------------------------------------------------------------------
# Partitioning
# ------------------------------------------------------------------------

echo -e "\nFormatting disk...\n$HR"
# disk prep
sgdisk -Z $DISK_DEV             # zap all on disk
sgdisk -a 2048 -o $DISK_DEV     # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+200M $DISK_DEV   # partition 1 (UEFI BOOT)       200MB
sgdisk -n 2:0:0 $DISK_DEV       # partition 3, (LUKS)            rest

# set partition types
sgdisk -t 1:ef00 $DISK_DEV
sgdisk -t 2:8300 $DISK_DEV

# label partitions
sgdisk -c 1:"UEFI Boot" $DISK_DEV
sgdisk -c 2:"cryptlvm" $DISK_DEV

# ------------------------------------------------------------------------
# LUKS
# ------------------------------------------------------------------------
# Create encrypted partitions
# This creates one partions for root, modify if /home or other partitions should be on separate partitions
echo -e "\nCreating encrypted partition...\n$HR"
echo -e $PASSWORD | cryptsetup luksFormat /dev/disk/by-partlabel/cryptlvm
sleep 2
echo -e $PASSWORD | cryptsetup luksOpen /dev/disk/by-partlabel/cryptlvm lvm
#echo -e $PASSWORD | cryptsetup open /dev/disk/by-partlabel/cryptlvm lvm

# ------------------------------------------------------------------------
# LVM
# ------------------------------------------------------------------------
echo -e "\nCreating logical volumes...\n$HR"
pvcreate $INSTALL_DEV
vgcreate storage $INSTALL_DEV
lvcreate --size 15G storage --name root
lvcreate --size  4G storage --name swap
lvcreate -l +100%FREE storage --name home

# ------------------------------------------------------------------------
# FORMAT
# ------------------------------------------------------------------------
echo -e "\nFormating partitions...\n$HR"
mkfs.vfat -F32 /dev/sda1
mkfs.ext4 /dev/mapper/storage-root
mkfs.ext4 /dev/mapper/storage-home
mkswap -L swap /dev/mapper/storage-swap
swapon -d -L swap

# ------------------------------------------------------------------------
# MOUNT
# ------------------------------------------------------------------------
echo -e "\nMounting partitions...\n$HR"
mount /dev/storage/root /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir -p /mnt/home
mount /dev/storage/home /mnt/home
