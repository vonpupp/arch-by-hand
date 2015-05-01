#!/bin/bash

HOSTNAME=vm
USERNAME=afu
PASSWORD="1234"

# ------------------------------------------------------------------------

AURHELPER=packer
INSTALL_TARGET="/mnt"
HR="--------------------------------------------------------------------------------"
PACMAN="pacman --config /tmp/pacman.conf"
TARGET_PACMAN="pacman --config /tmp/pacman.conf -r ${INSTALL_TARGET}"
CHROOT_PACMAN="pacman --cachedir /var/cache/pacman/pkg --config /tmp/pacman.conf -r ${INSTALL_TARGET}"
FILE_URL="file:///packages/core-$(uname -m)/pkg"
FTP_URL='ftp://archlinux.c3sl.ufpr.br/archlinux/$repo/os/$arch'
HTTP_URL='http://archlinux.c3sl.ufpr.br/$repo/os/$arch'
DISK_DEV="/dev/sda"
INSTALL_DEV="/dev/mapper/lvm"

# ------------------------------------------------------------------------

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
