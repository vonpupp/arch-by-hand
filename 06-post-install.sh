#!/bin/bash

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

# functions (these could be a library, but why overcomplicate things
# ------------------------------------------------------------------------
SetValue () { VALUENAME="\$1" NEWVALUE="\$2" FILEPATH="\$3"; sed -i "s+^#\?\(\${VALUENAME}\)=.*\$+\1=\${NEWVALUE}+" "\${FILEPATH}"; }
CommentOutValue () { VALUENAME="\$1" FILEPATH="\$2"; sed -i "s/^\(\${VALUENAME}.*\)\$/#\1/" "\${FILEPATH}"; }
UncommentValue () { VALUENAME="\$1" FILEPATH="\$2"; sed -i "s/^#\(\${VALUENAME}.*\)\$/\1/" "\${FILEPATH}"; }

# root password
# ------------------------------------------------------------------------
echo -e "${HR}\\nNew root user password\\n${HR}"
passwd

# add user
# ------------------------------------------------------------------------
echo -e "${HR}\\nNew non-root user password (username:${USERNAME})\\n${HR}"
groupadd sudo
useradd -m -g users -G audio,lp,optical,storage,video,games,power,scanner,network,sudo,wheel -s /bin/bash ${USERNAME}
passwd ${USERNAME}

# mirror ranking
# ------------------------------------------------------------------------
#echo -e "${HR}\\nRanking Mirrors (this will take a while)\\n${HR}"
#cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
#mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.all
#sed -i "s/#S/S/" /etc/pacman.d/mirrorlist.all
#rankmirrors -n 5 /etc/pacman.d/mirrorlist.all > /etc/pacman.d/mirrorlist

# mirrors - all (quick and dirty alternate to ranking)
# ------------------------------------------------------------------------
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
sed -i "s/#S/S/" /etc/pacman.d/mirrorlist

# temporary fix for locale.sh update conflict
# ------------------------------------------------------------------------
mv /etc/profile.d/locale.sh /etc/profile.d/locale.sh.preupdate || true

# additional groups and utilities
# ------------------------------------------------------------------------
pacman --noconfirm -Syu
pacman --noconfirm -S base-devel

# AUR helper
# ------------------------------------------------------------------------
# Note that the AUR helper must support standard pacman syntax
mkdir -p /tmp/build
cd /tmp/build
wget https://aur.archlinux.org/packages/${AURHELPER}/${AURHELPER}.tar.gz
tar -xzvf ${AURHELPER}.tar.gz
cd ${AURHELPER}
makepkg --asroot -si
cd /tmp

# sudo
# ------------------------------------------------------------------------
pacman --noconfirm -S sudo
cp /etc/sudoers /tmp/sudoers.edit
sed -i "s/#\s*\(%wheel\s*ALL=(ALL)\s*ALL.*$\)/\1/" /tmp/sudoers.edit
sed -i "s/#\s*\(%sudo\s*ALL=(ALL)\s*ALL.*$\)/\1/" /tmp/sudoers.edit
visudo -qcsf /tmp/sudoers.edit && cat /tmp/sudoers.edit > /etc/sudoers

# power
# ------------------------------------------------------------------------
pacman --noconfirm -S acpi acpid acpitool cpufrequtils
${AURHELPER} --noconfirm -S powertop2
sed -i "/^DAEMONS/ s/)/ @acpid)/" /etc/rc.conf
sed -i "/^MODULES/ s/)/ acpi-cpufreq cpufreq_ondemand cpufreq_powersave coretemp)/" /etc/rc.conf
# following requires my acpi handler script
echo "/etc/acpi/handler.sh boot" > /etc/rc.local

# time
# ------------------------------------------------------------------------
pacman --noconfirm -S ntp
sed -i "/^DAEMONS/ s/hwclock /!hwclock @ntpd /" /etc/rc.conf

# wireless (wpa supplicant should already be installed)
# ------------------------------------------------------------------------
pacman --noconfirm -S iw wpa_supplicant rfkill
pacman --noconfirm -S netcfg wpa_actiond ifplugd
mv /etc/wpa_supplicant.conf /etc/wpa_supplicant.conf.orig
echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=network\nupdate_config=1" > /etc/wpa_supplicant.conf
# make sure to copy /etc/network.d/examples/wireless-wpa-config to /etc/network.d/home and edit
sed -i "/^DAEMONS/ s/)/ @net-auto-wireless @net-auto-wired)/" /etc/rc.conf
sed -i "/^DAEMONS/ s/ network / /" /etc/rc.conf
echo -e "\nWIRELESS_INTERFACE=wlan0" >> /etc/rc.conf
echo -e "WIRED_INTERFACE=eth0" >> /etc/rc.conf
echo "options iwlagn led_mode=2" > /etc/modprobe.d/iwlagn.conf

# sound
# ------------------------------------------------------------------------
pacman --noconfirm -S alsa-utils alsa-plugins
sed -i "/^DAEMONS/ s/)/ @alsa)/" /etc/rc.conf
mv /etc/asound.conf /etc/asound.conf.orig || true
#if alsamixer isn't working, try alsamixer -Dhw and speaker-test -Dhw -c 2

# video
# ------------------------------------------------------------------------
pacman --noconfirm -S base-devel mesa mesa-demos # linux-headers

# x
# ------------------------------------------------------------------------
pacman --noconfirm -S xorg xorg-server xorg-xinit xorg-utils xorg-server-utils xdotool xorg-xlsfonts
${AURHELPER} --noconfirm -S xf86-input-wacom-git

# environment/wm/etc.
# ------------------------------------------------------------------------
#pacman --noconfirm -S xfce4 compiz ccsm
pacman --noconfirm -S xcompmgr xscreensaver hsetroot
pacman --noconfirm -S rxvt-unicode urxvt-url-select
#${AURHELPER} -S rxvt-unicode-cvs # need to manually edit out patch lines
pacman --noconfirm -S urxvt-url-select
pacman --noconfirm -S gtk2
pacman --noconfirm -S ghc alex happy gtk2hs-buildtools cabal-install
${AURHELPER} --noconfirm -S physlock
${AURHELPER} --noconfirm -S unclutter
pacman --noconfirm -S dbus upower
sed -i "/^DAEMONS/ s/)/ @dbus)/" /etc/rc.conf

# TODO: another install script for this
# following as non root user, make sure \$HOME/.cabal/bin is in path
# make sure to nuke existing .ghc and .cabal directories first
#su ${USERNAME}
#cd \$HOME
#rm -rf \$HOME/.ghc \$HOME/.cabal
# TODO: consider adding just .cabal to the path as well
#export PATH=$PATH:\$HOME/.cabal/bin
#cabal update
# # NOT USING following line... alex, happy and gtk2hs-buildtools installed via paman
# # cabal install alex happy xmonad xmonad-contrib gtk2hs-buildtools
#cabal install xmonad xmonad-contrib taffybar
#cabal install c2hs language-c x11-xft xmobar --flags "all-extensions"
pacman --noconfirm -S wireless_tools # don't want it, but xmobar does
#note that I installed xmobar from github instead
#exit

# fonts
# ------------------------------------------------------------------------
pacman --noconfirm -S terminus-font
${AURHELPER} --noconfirm -S webcore-fonts
${AURHELPER} --noconfirm -S libspiro
${AURHELPER} --noconfirm -S fontforge
${AURHELPER} -S freetype2-git-infinality # will prompt for freetype2 replacement
# TODO: sed infinality and change to OSX or OSX2 mode
#	and create the sym link from /etc/fonts/conf.avail to conf.d

# misc apps
# ------------------------------------------------------------------------
pacman --noconfirm -S htop openssh keychain bash-completion git vim
pacman --noconfirm -S chromium flashplugin
pacman --noconfirm -S scrot mypaint bc
${AURHELPER} --noconfirm -S task-git
${AURHELPER} --noconfirm -S stellarium
# googlecl discovery requires the svn googlecl version and google-api-python-client and httplib2, gflags
${AURHELPER} --noconfirm -S googlecl-svn
${AURHELPER} --noconfirm -S googlecl-svn python2-google-api-python-client python2-httplib2 python2-gflags python-simplejson
#${AURHELPER} --noconfirm -S google-talkplugin
${AURHELPER} --noconfirm -S argyll dispcalgui
# TODO: argyll

# extras
# ------------------------------------------------------------------------

${AURHELPER} -S --noconfirm haskell-mtl haskell-hscolour haskell-x11
${AURHELPER} -S --noconfirm xmonad-darcs xmonad-contrib-darcs xmobar-git
${AURHELPER} -S --noconfirm trayer-srg-git
#skype
pacman -S --noconfirm zip # for pent buftabs
#${AURHELPER} -S --noconfirm aurora
#${AURHELPER} -S --noconfirm aurora-pentadactyl-buftabs-git
#${AURHELPER} -S --noconfirm terminus-font-ttf
mkdir -p /home/${USERNAME}/.pentadactyl/plugins && ln -sf /usr/share/aurora-pentadactyl-buftabs/buftabs.js /home/${USERNAME}/.pentadactyl/plugins/buftabs.js

POST_EOF

# ------------------------------------------------------------------------
# Post install in chroot
# ------------------------------------------------------------------------
#echo "chroot and run /post_install"
chroot /install /post_install
mv /install/post_install /.

# ------------------------------------------------------------------------
# NOTES/TODO
# ------------------------------------------------------------------------
