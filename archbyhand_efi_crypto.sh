#!/bin/bash

# This script is designed to be run in conjunction with a UEFI boot using Archboot intall media.

# prereqs:
# --------------------
# EFI "BIOS" set to boot *only* from EFI
# successful EFI boot of Archboot USB
# mount /dev/sdb1 /src

set -o nounset

# ------------------------------------------------------------------------
# Host specific configuration
# ------------------------------------------------------------------------
# this whole script needs to be customized, particularly disk partitions
# and configuration, but this section contains global variables that
# are used during the system configuration phase for convenience
HOSTNAME=tau
USERNAME=es

# ------------------------------------------------------------------------
# Globals
# ------------------------------------------------------------------------
# We don't need to set these here but they are used repeatedly throughout
# so it makes sense to reuse them and allow an easy, one-time change if we
# need to alter values such as the install target mount point.

INSTALL_TARGET="/install"
HR="--------------------------------------------------------------------------------"
PACMAN="pacman --noconfirm --config /tmp/pacman.conf"
TARGET_PACMAN="pacman --noconfirm --config /tmp/pacman.conf -r ${INSTALL_TARGET}"
CHROOT_PACMAN="pacman --noconfirm --cachedir /var/cache/pacman/pkg --config /tmp/pacman.conf -r ${INSTALL_TARGET}"
FILE_URL="file:///packages/core-$(uname -m)/pkg"
FTP_URL='ftp://mirrors.kernel.org/archlinux/$repo/os/$arch'
HTTP_URL='http://mirrors.kernel.org/archlinux/$repo/os/$arch'

# ------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------
# I've avoided using functions in this script as they aren't required and
# I think it's more of a learning tool if you see the step-by-step 
# procedures even with minor duplciations along the way, but I feel that
# these functions clarify the particular steps of setting values in config
# files.

SetValue () { 
# EXAMPLE: SetValue VARIABLENAME '\"Quoted Value\"' /file/path
VALUENAME="$1" NEWVALUE="$2" FILEPATH="$3"
sed -i "s+^#\?\(${VALUENAME}\)=.*$+\1=${NEWVALUE}+" "${FILEPATH}"
}

CommentOutValue () {
VALUENAME="$1" FILEPATH="$2"
sed -i "s/^\(${VALUENAME}.*\)$/#\1/" "${FILEPATH}"
}

UncommentValue () {
VALUENAME="$1" FILEPATH="$2"
sed -i "s/^#\(${VALUENAME}.*\)$/\1/" "${FILEPATH}"
}

# ------------------------------------------------------------------------
# Initialize
# ------------------------------------------------------------------------
# Warn the user about impending doom, set up the network on eth0, mount
# the squashfs images (Archboot does this normally, we're just filling in
# the gaps resulting from the fact that we're doing a simple scripted
# install). We also create a temporary pacman.conf that looks for packages
# locally first before sourcing them from the network. It would be better
# to do either *all* local or *all* network but we can't for two reasons.
#     1. The Archboot installation image might have an out of date kernel
#	 (currently the case) which results in problems when chrooting
#	 into the install mount point to modprobe efivars. So we use the
#	 package snapshot on the Archboot media to ensure our kernel is
#	 the same as the one we booted with.
#     2. Ideally we'd source all local then, but some critical items,
#	 notably grub2-efi variants, aren't yet on the Archboot media.

# Warn
# ------------------------------------------------------------------------
timer=9
timer=1
echo -n "This procedure will completely format /dev/sda. Please cancel with ctrl-c to cancel within $timer seconds..."
while [[ $timer -gt 0 ]]
do
	sleep 1
	let timer-=1
	echo -en "$timer seconds..."
done

echo "STARTING"

# Get Network
# ------------------------------------------------------------------------
echo -n "Waiting for network address.."
dhcpcd -p eth0
echo -n "Network address acquired."

# Mount packages squashfs images
# ------------------------------------------------------------------------
umount "/packages/core-$(uname -m)"
umount "/packages/core-any"
rm -rf "/packages/core-$(uname -m)"
rm -rf "/packages/core-any"

mkdir -p "/packages/core-$(uname -m)"
mkdir -p "/packages/core-any"

modprobe -q loop
modprobe -q squashfs
mount -o ro,loop -t squashfs "/src/packages/archboot_packages_$(uname -m).squashfs" "/packages/core-$(uname -m)"
mount -o ro,loop -t squashfs "/src/packages/archboot_packages_any.squashfs" "/packages/core-any"

# Create temporary pacman.conf file
# ------------------------------------------------------------------------
cat << PACMANEOF > /tmp/pacman.conf
[options]
Architecture = auto
CacheDir = ${INSTALL_TARGET}/var/cache/pacman/pkg
CacheDir = /packages/core-$(uname -m)/pkg
CacheDir = /packages/core-any/pkg

[core]
Server = ${FILE_URL}
Server = ${FTP_URL}
Server = ${HTTP_URL}

[extra]
Server = ${FILE_URL}
Server = ${FTP_URL}
Server = ${HTTP_URL}

# Uncomment to enable pacman -Sy yaourt
# (in this script we're doing this in the Post Install step below)
#[archlinuxfr]
#Server = http://repo.archlinux.fr/\$arch
PACMANEOF

# Prepare pacman
# ------------------------------------------------------------------------
[[ ! -d "${INSTALL_TARGET}/var/cache/pacman/pkg" ]] && mkdir -m 755 -p "${INSTALL_TARGET}/var/cache/pacman/pkg"
[[ ! -d "${INSTALL_TARGET}/var/lib/pacman" ]] && mkdir -m 755 -p "${INSTALL_TARGET}/var/lib/pacman"
${PACMAN} -Sy
${TARGET_PACMAN} -Sy

# Install prereqs from network (not on archboot media)
# ------------------------------------------------------------------------
echo -e "\nInstalling prereqs...\n$HR"
UncommentValue S /etc/pacman.d/mirrorlist # Uncomment all Server lines
${PACMAN} --noconfirm -Sy gptfdisk btrfs-progs-unstable

# ------------------------------------------------------------------------
# Configure Host
# ------------------------------------------------------------------------
# Here we create three partitions:
# 1. efi and /boot (one partition does double duty)
# 2. swap
# 3. our encrypted root
# Note that all of these are on a GUID partition table scheme. This proves
# to be quite clean and simple since we're not doing anything with MBR
# boot partitions and the like.

echo -e "\nFormatting disk...\n$HR"

# disk prep
sgdisk -Z /dev/sda # zap all on disk
sgdisk -a 2048 -o /dev/sda # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+200M /dev/sda # partition 1 (UEFI BOOT), default start block, 200MB
sgdisk -n 2:0:+4G /dev/sda # partition 2 (SWAP), default start block, 200MB
sgdisk -n 3:0:0 /dev/sda # partition 3, (LUKS), default start, remaining space

# set partition types
sgdisk -t 1:ef00 /dev/sda
sgdisk -t 2:8200 /dev/sda
sgdisk -t 3:8300 /dev/sda

# label partitions
sgdisk -c 1:"UEFI Boot" /dev/sda
sgdisk -c 2:"Swap" /dev/sda
sgdisk -c 3:"LUKS" /dev/sda

# format LUKS on root
cryptsetup --cipher=aes-xts-plain --verify-passphrase --key-size=512 luksFormat /dev/sda3
cryptsetup luksOpen /dev/sda3 root

# NOTE: make sure to add dm_crypt and aes_i586 to MODULES in rc.conf
# NOTE2: actually this isn't required since we're mounting an encrypted root and grub2/initramfs handles this before we even get to rc.conf

# make filesystems
echo -e "\nCreating Filesystems...\n$HR"
mkfs.vfat /dev/sda1
# following swap related commands not used now that we're encrypting our swap partition
#mkswap /dev/sda2
#swapon /dev/sda2
#mkfs.ext4 /dev/sda3 # this is where we'd create an unencrypted root partition, but we're using luks instead
mkfs.ext4 /dev/mapper/root

# mount target
mkdir ${INSTALL_TARGET}
#mount /dev/sda3 ${INSTALL_TARGET} # this is where we'd mount the unencrypted root partition
mount /dev/mapper/root ${INSTALL_TARGET}
mkdir ${INSTALL_TARGET}/boot
mount -t vfat /dev/sda1 ${INSTALL_TARGET}/boot

# ------------------------------------------------------------------------
# Install base, necessary utilities
# ------------------------------------------------------------------------
# note: curl could be installed later but we want it ready for rankmirrors

mkdir -p ${INSTALL_TARGET}/var/lib/pacman
${TARGET_PACMAN} -Sy
${TARGET_PACMAN} -Su base
${TARGET_PACMAN} -S curl
${TARGET_PACMAN} -R grub
rm -rf ${INSTALL_TARGET}/boot/grub
${TARGET_PACMAN} -S grub2-efi-x86_64

# ------------------------------------------------------------------------
# Configure new system
# ------------------------------------------------------------------------

SetValue HOSTNAME ${HOSTNAME} ${INSTALL_TARGET}/etc/rc.conf
sed -i "s/^\(127\.0\.0\.1.*\)$/\1 ${HOSTNAME}/" ${INSTALL_TARGET}/etc/hosts
SetValue CONSOLEFONT Lat2-Terminus16 ${INSTALL_TARGET}/etc/rc.conf
SetValue interface eth0 ${INSTALL_TARGET}/etc/rc.conf

# ------------------------------------------------------------------------
# write fstab
# ------------------------------------------------------------------------
# You can use UUID's or whatever you want here, of course. This is just
# the simplest approach and as long as your drives aren't changing values
# randomly it should work fine.

cat > ${INSTALL_TARGET}/etc/fstab <<FSTAB_EOF
# 
# /etc/fstab: static file system information
#
# <file system>		<dir>	<type>	<options>		<dump>	<pass>
tmpfs			/tmp	tmpfs	nodev,nosuid		0	0
/dev/sda1		/boot	vfat	defaults		0	0 
/dev/mapper/cryptswap	none	swap	defaults		0	0 
/dev/mapper/root	/ 	ext4	defaults,noatime	0	1 
FSTAB_EOF

# ------------------------------------------------------------------------
# write crypttab
# ------------------------------------------------------------------------
# encrypted swap (random passphrase on boot)

echo cryptswap /dev/sda2 SWAP "-c aes-xts-plain -h whirlpool -s 512" >> ${INSTALL_TARGET}/etc/crypttab

# ------------------------------------------------------------------------
# copy configs we want to carry over to target from install environment
# ------------------------------------------------------------------------

mv ${INSTALL_TARGET}/etc/resolv.conf ${INSTALL_TARGET}/etc/resolv.conf.orig
cp /etc/resolv.conf ${INSTALL_TARGET}/etc/resolv.conf

mkdir -p ${INSTALL_TARGET}/tmp
cp /tmp/pacman.conf ${INSTALL_TARGET}/tmp/pacman.conf

# ------------------------------------------------------------------------
# mount proc, sys, dev in install root
# ------------------------------------------------------------------------

mount -t proc proc ${INSTALL_TARGET}/proc
mount -t sysfs sys ${INSTALL_TARGET}/sys
mount -o bind /dev ${INSTALL_TARGET}/dev

# we have to remount /boot from inside the chroot
umount ${INSTALL_TARGET}/boot

# ------------------------------------------------------------------------
# Create install_efi script (to be run *after* chroot /install)
# ------------------------------------------------------------------------

touch ${INSTALL_TARGET}/install_efi
chmod a+x ${INSTALL_TARGET}/install_efi
cat > ${INSTALL_TARGET}/install_efi <<EFI_EOF

# functions (these could be a library, but why overcomplicate things
# ------------------------------------------------------------------------
SetValue () { VALUENAME="\$1" NEWVALUE="\$2" FILEPATH="\$3"; sed -i "s+^#\?\(\${VALUENAME}\)=.*\$+\1=\${NEWVALUE}+" "\${FILEPATH}"; }
CommentOutValue () { VALUENAME="\$1" FILEPATH="\$2"; sed -i "s/^\(\${VALUENAME}.*\)\$/#\1/" "\${FILEPATH}"; }
UncommentValue () { VALUENAME="\$1" FILEPATH="\$2"; sed -i "s/^#\(\${VALUENAME}.*\)\$/\1/" "\${FILEPATH}"; }

# remount here or grub et al gets confused
# ------------------------------------------------------------------------
mount -t vfat /dev/sda1 /boot

# mkinitcpio
# ------------------------------------------------------------------------
# NOTE: intel_agp drm and i915 for intel graphics
SetValue MODULES '\\"dm_mod dm_crypt aes_x86_64 ext2 ext4 vfat intel_agp drm i915\\"' /etc/mkinitcpio.conf
SetValue HOOKS '\\"base udev pata scsi sata usb usbinput keymap consolefont encrypt filesystems\\"' /etc/mkinitcpio.conf
mkinitcpio -p linux

# locale-gen
# ------------------------------------------------------------------------
UncommentValue en_US /etc/locale.gen
locale-gen

# kernel modules for EFI install
# ------------------------------------------------------------------------
modprobe efivars
modprobe dm-mod

# configure grub2
# ------------------------------------------------------------------------
# grub2 installed above, natch

# you can be surprisingly sloppy with the root value you give grub2 as a kernel option and
# even omit the cryptdevice altogether, though it will wag a finger at you for using
# a deprecated syntax, so we're using the correct form here
# NOTE: take out i915.modeset=1 unless you are on intel graphics
SetValue GRUB_CMDLINE_LINUX '\\"cryptdevice=/dev/sda3:root add_efi_memmap i915.modeset=1\\"' /etc/default/grub

# set output to graphical
SetValue GRUB_TERMINAL_OUTPUT gfxterm /etc/default/grub
SetValue GRUB_GFXMODE 960x600x32,auto /etc/default/grub
SetValue GRUB_GFXPAYLOAD_LINUX keep /etc/default/grub # comment out this value if text only mode

# install the actual grub2. Note that despite our --boot-directory option we will still need to move
# the grub directory to /boot/grub during grub-mkconfig operations until grub2 gets patched (see below)
grub_efi_x86_64-install --bootloader-id=grub --no-floppy --recheck

# create our EFI boot entry
efibootmgr --create --gpt --disk /dev/sda --part 1 --write-signature --label "ARCH LINUX" --loader "\\\\grub\\\\grub.efi"

# copy font for grub2
cp /usr/share/grub/unicode.pf2 /boot/grub

# generate config file
grub-mkconfig -o /boot/grub/grub.cfg

exit
EFI_EOF

# ------------------------------------------------------------------------
# Install EFI using script inside chroot
# ------------------------------------------------------------------------

chroot ${INSTALL_TARGET} /install_efi
rm ${INSTALL_TARGET}/install_efi

# ------------------------------------------------------------------------
# Post install steps
# ------------------------------------------------------------------------
# anything you want to do post install. run the script automatically or
# manually

touch ${INSTALL_TARGET}/post_install
chmod a+x ${INSTALL_TARGET}/post_install
cat > ${INSTALL_TARGET}/post_install <<POST_EOF
set -o errexit
set -o nounset
# root password
echo -e "${HR}\\nNew root user password\\n${HR}"
passwd

# add user
echo -e "${HR}\\nNew non-root user password (username:${USERNAME})\\n${HR}"
useradd -m -g users -G audio,lp,optical,storage,video,games,power,scanner,network -s /bin/bash ${USERNAME}
passwd ${USERNAME}

# configure the network

# mirror ranking
echo -e "${HR}\\nRanking Mirrors (this will take a while)\\n${HR}"
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.all
sed -i "s/#S/S/" /etc/pacman.d/mirrorlist.all
rankmirrors -n 5 /etc/pacman.d/mirrorlist.all > /etc/pacman.d/mirrorlist

# temporary fix for locale.sh update conflict
mv /etc/profile.d/locale.sh /etc/profile.d/locale.sh.preupdate || true

# yaourt repo (add to target pacman, not tmp pacman.conf, for ongoing use)
echo -e "\\n[archlinuxfr]\\nServer = http://repo.archlinux.fr/\\\$arch" >> /etc/pacman.conf

# additional groups and utilities
pacman --noconfirm -Syu base-devel mesa mesa-demos xorg xfce4 yaourt
pacman --noconfirm -S chromium flashplugin

# sudo

# sound

# video

# x

# fonts

# environment/wm/etc.

# misc apps
POST_EOF

# ------------------------------------------------------------------------
# Post install in chroot
# ------------------------------------------------------------------------

# manually:
echo "chroot ${INSTALL_TARGET} and run /post_install"

# or automatically:
#chroot /install /post_install
#rm /install/post_install


# ------------------------------------------------------------------------
# NOTES/TODO
# ------------------------------------------------------------------------