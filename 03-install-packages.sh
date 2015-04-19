#!/bin/bash

# ------------------------------------------------------------------------
# Install base, necessary utilities
# ------------------------------------------------------------------------

mkdir -p ${INSTALL_TARGET}/var/lib/pacman
pacman --config /tmp/pacman.conf -r ${INSTALL_TARGET} -Sy
pacman --config /tmp/pacman.conf -r ${INSTALL_TARGET} -Su base
# curl could be installed later but we want it ready for rankmirrors
pacman --config /tmp/pacman.conf -r ${INSTALL_TARGET} -S curl zsh grub efibootmgr
#pacman --config /tmp/pacman.conf -r ${INSTALL_TARGET} -R grub
#rm -rf ${INSTALL_TARGET}/boot/grub
#pacman --config /tmp/pacman.conf -r ${INSTALL_TARGET} -S grub2-efi-x86_64
