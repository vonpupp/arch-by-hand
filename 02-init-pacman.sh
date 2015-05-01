#!/bin/bash

# ------------------------------------------------------------------------
# Mount NFS Cache
# ------------------------------------------------------------------------
mkdir -p /packages/core-$(uname -m)/pkg
mount -t -o nolock nfs $NFS_SERVER:/share/cache/arch/core-$(uname -m)/pkg /packages/core-$(uname -m)/pkg

# Mount packages squashfs images
# ------------------------------------------------------------------------
#umount "/packages/core-$(uname -m)"
#umount "/packages/core-any"
#rm -rf "/packages/core-$(uname -m)"
#rm -rf "/packages/core-any"
#
#mkdir -p "/packages/core-$(uname -m)"
#mkdir -p "/packages/core-any"
#
#modprobe -q loop
#modprobe -q squashfs
#mount -o ro,loop -t squashfs "/src/packages/archboot_packages_$(uname -m).squashfs" "/packages/core-$(uname -m)"
#mount -o ro,loop -t squashfs "/src/packages/archboot_packages_any.squashfs" "/packages/core-any"

# ------------------------------------------------------------------------
# Create temporary pacman.conf file
# ------------------------------------------------------------------------
cat << PACMANEOF > /tmp/pacman.conf
[options]
Architecture = auto
CacheDir = ${INSTALL_TARGET}/var/cache/pacman/pkg
CacheDir = /packages/core-$(uname -m)/pkg
#CacheDir = /packages/core-$(uname -m)/pkg
#CacheDir = /packages/core-any/pkg

[core]
Server = ${FILE_URL}
Server = ${HTTP_URL}
Server = ${FTP_URL}

[extra]
Server = ${FILE_URL}
Server = ${HTTP_URL}
Server = ${FTP_URL}

PACMANEOF
#!/bin/bash

# ------------------------------------------------------------------------
# Prepare pacman
# ------------------------------------------------------------------------
[[ ! -d "${INSTALL_TARGET}/var/cache/pacman/pkg" ]] && mkdir -m 755 -p "${INSTALL_TARGET}/var/cache/pacman/pkg"
[[ ! -d "${INSTALL_TARGET}/var/lib/pacman" ]] && mkdir -m 755 -p "${INSTALL_TARGET}/var/lib/pacman"
#${PACMAN} -Sy
#${TARGET_PACMAN} -Sy
pacman-key --refresh-keys
pacman --config /tmp/pacman.conf -Sy
pacman --config /tmp/pacman.conf -r ${INSTALL_TARGET} -Sy

# Install prereqs from network (not on archboot media)
# ------------------------------------------------------------------------
echo -e "\nInstalling prereqs...\n$HR"
#sed -i "s/^#S/S/" /etc/pacman.d/mirrorlist # Uncomment all Server lines
UncommentValue S /etc/pacman.d/mirrorlist # Uncomment all Server lines
#${PACMAN} --noconfirm -Sy gptfdisk btrfs-progs-unstable
pacman --config /tmp/pacman.conf -r ${INSTALL_TARGET} -Sy gptfdisk btrfs-progs-unstable
