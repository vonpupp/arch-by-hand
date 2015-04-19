#!/bin/bash

# ------------------------------------------------------------------------
# mount proc, sys, dev in install root
# ------------------------------------------------------------------------

mount -t proc proc ${INSTALL_TARGET}/proc
mount -t sysfs sys ${INSTALL_TARGET}/sys
mount -o bind /dev ${INSTALL_TARGET}/dev

# we have to remount /boot from inside the chroot
umount ${INSTALL_TARGET}/boot

# OK

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

# install and configure grub2
# ------------------------------------------------------------------------
# did this above
#${CHROOT_PACMAN} -Sy
#${CHROOT_PACMAN} -R grub
#rm -rf /boot/grub
#${CHROOT_PACMAN} -S grub2-efi-x86_64

# you can be surprisingly sloppy with the root value you give grub2 as a kernel option and
# even omit the cryptdevice altogether, though it will wag a finger at you for using
# a deprecated syntax, so we're using the correct form here
# NOTE: take out i915.modeset=1 unless you are on intel graphics
#SetValue GRUB_CMDLINE_LINUX '\\"cryptdevice=/dev/sda3:root add_efi_memmap i915.modeset=1 i915.i915_enable_rc6=1 i915.i915_enable_fbc=1 i915.lvds_downclock=1 pcie_aspm=force quiet\\"' /etc/default/grub
SetValue GRUB_CMDLINE_LINUX '\\"cryptdevice=/dev/sda3:root add_efi_memmap pcie_aspm=force quiet\\"' /etc/default/grub

# set output to graphical
SetValue GRUB_TERMINAL_OUTPUT gfxterm /etc/default/grub
SetValue GRUB_GFXMODE 960x600x32,auto /etc/default/grub
SetValue GRUB_GFXPAYLOAD_LINUX keep /etc/default/grub # comment out this value if text only mode

# install the actual grub2. Note that despite our --boot-directory option we will still need to move
# the grub directory to /boot/grub during grub-mkconfig operations until grub2 gets patched (see below)
# grub_efi_x86_64-install --bootloader-id=grub --no-floppy --recheck
grub-install --target=x86_64-efi --root-directory=/boot --boot-directory=/boot/efi --bootloader-id=grub --no-floppy --recheck

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
