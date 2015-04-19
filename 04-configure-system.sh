#!/bin/bash

# ------------------------------------------------------------------------
# Configure new system
# ------------------------------------------------------------------------
SetValue HOSTNAME ${HOSTNAME} ${INSTALL_TARGET}/etc/rc.conf
sed -i "s/^\(127\.0\.0\.1.*\)$/\1 ${HOSTNAME}/" ${INSTALL_TARGET}/etc/hosts
SetValue CONSOLEFONT Lat2-Terminus16 ${INSTALL_TARGET}/etc/rc.conf
#following replaced due to netcfg
#SetValue interface eth0 ${INSTALL_TARGET}/etc/rc.conf

# ------------------------------------------------------------------------
# write fstab
# ------------------------------------------------------------------------
# You can use UUID's or whatever you want here, of course. This is just
# the simplest approach and as long as your drives aren't changing values
# randomly it should work fine.


genfstab -L -p ${INSTALL_TARGET} > ${INSTALL_TARGET}/etc/fstab
genfstab -U -p ${INSTALL_TARGET} > ${INSTALL_TARGET}/etc/fstab.uuid

#cat > ${INSTALL_TARGET}/etc/fstab <<FSTAB_EOF
##
## /etc/fstab: static file system information
##
## <file system>		<dir>	<type>	<options>		<dump>	<pass>
#tmpfs			/tmp	tmpfs	nodev,nosuid		0	0
#/dev/sda1		/boot	vfat	defaults		0	0
#/dev/mapper/cryptswap	none	swap	defaults		0	0
#/dev/mapper/root	/ 	ext4	defaults,noatime	0	1
#FSTAB_EOF

# ------------------------------------------------------------------------
# write crypttab
# ------------------------------------------------------------------------
# encrypted swap (random passphrase on boot)
#echo cryptswap /dev/sda2 SWAP "-c aes-xts-plain -h whirlpool -s 512" >> ${INSTALL_TARGET}/etc/crypttab
echo cryptswap /dev/mapper/storage-swap "-c aes-xts-plain -h whirlpool -s 512" >> ${INSTALL_TARGET}/etc/crypttab

# ------------------------------------------------------------------------
# copy configs we want to carry over to target from install environment
# ------------------------------------------------------------------------

mv ${INSTALL_TARGET}/etc/resolv.conf ${INSTALL_TARGET}/etc/resolv.conf.orig
cp /etc/resolv.conf ${INSTALL_TARGET}/etc/resolv.conf

mkdir -p ${INSTALL_TARGET}/tmp
cp /tmp/pacman.conf ${INSTALL_TARGET}/tmp/pacman.conf
