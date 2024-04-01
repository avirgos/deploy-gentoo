#!/bin/bash

######################################################################
# Template
######################################################################
set -o errexit  # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset  # Exit if variable not set.
IFS=$'\n\t'     # Remove the initial space and instead use '\n'.

######################################################################
# Global variables
######################################################################
USERNAME="<username>"
LOCAL_IP="<local-ip>"
LOCATION_REPO="<location-repo>"

STAGE3_FILE="stage3-amd64-openrc-20240121T170320Z.tar.xz"  
PORTAGE_FILE="portage-latest.tar.bz2"                       
DISTFILES_FILE="distfiles.tar.bz2"                          
PACKAGES_FILE="packages.tar.bz2"                           

######################################################################
# Partitioning
######################################################################
cfdisk /dev/sda

######################################################################
# File system
######################################################################
mkfs.ext3 /dev/sda1  # /boot
mkfs.ext3 /dev/sda2  # /
mkfs.ext3 /dev/sda5  # /home
mkfs.ext3 /dev/sda6  # /var
mkswap /dev/sda7     # swap

######################################################################
# Mounting the file system 
######################################################################
mount /dev/sda2 /mnt/gentoo
mkdir /mnt/gentoo/boot
mount /dev/sda1 /mnt/gentoo/boot
mkdir /mnt/gentoo/home
mount /dev/sda5 /mnt/gentoo/home
mkdir /mnt/gentoo/var
mount /dev/sda6 /mnt/gentoo/var
swapon /dev/sda7

######################################################################
# Packages
######################################################################
##########
# stage3 #
##########
rsync -avP "${USERNAME}"@"${LOCAL_IP}":"${LOCATION_REPO}"/deploy-gentoo/"${STAGE3_FILE}" /mnt/gentoo/
cd /mnt/gentoo
tar xJf stage3*

###########
# portage #
###########
rsync -avP "${USERNAME}"@"${LOCAL_IP}":"${LOCATION_REPO}"/deploy-gentoo/"${PORTAGE_FILE}" /mnt/gentoo/usr/
cd /mnt/gentoo/usr
tar xjf "${PORTAGE_FILE}"

#############
# distfiles #
#############
rsync -avP "${USERNAME}"@"${LOCAL_IP}":"${LOCATION_REPO}"/deploy-gentoo/"${DISTFILES_FILE}" /mnt/gentoo/var/cache/
cd /mnt/gentoo/var/cache
tar xjf "${DISTFILES_FILE}"

############
# packages #
############
rsync -avP "${USERNAME}"@"${LOCAL_IP}":"${LOCATION_REPO}"/deploy-gentoo/"${PACKAGES_FILE}" /mnt/gentoo/var/cache/
tar xjf "${PACKAGES_FILE}"

######################################################################
# chroot
######################################################################
cd /
mount -t proc none /mnt/gentoo/proc
mount -o bind /dev /mnt/gentoo/dev
cp -L /etc/resolv.conf /mnt/gentoo/etc/
chroot /mnt/gentoo /bin/bash <<'EOF'
env-update && source /etc/profile

#    #################################################################
# -> # portage 
#    #################################################################
env-update
ln -s /usr/portage /var/db/repos/gentoo
env-update

######################################################################
# Kernel
######################################################################
emerge -K gentoo-kernel-bin

######################################################################
# cronie
######################################################################
emerge -K cronie
rc-update add cronie default

######################################################################
# dhcpcd
######################################################################
emerge -K dhcpcd
rc-update add dhcpcd default

######################################################################
# grub
######################################################################
emerge -K grub
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

######################################################################
# Password
######################################################################
echo "root:Attach3player3darken" | chpasswd

######################################################################
# Time
######################################################################
echo 'TIMEZONE="Europe/Paris"' > /etc/conf.d/clock

######################################################################
# Keyboard
######################################################################
sed -i 's/keymap="us"/keymap="fr"/' /etc/conf.d/keymaps

######################################################################
# fstab
######################################################################
echo "/dev/sda1      /boot       ext2    noauto,noatime       0 2" >> /etc/fstab
echo "/dev/sda2      /           ext3    noatime              0 1" >> /etc/fstab
echo "/dev/sda5      /home       ext3    noatime              0 2" >> /etc/fstab
echo "/dev/sda6      /var        ext3    noatime              0 2" >> /etc/fstab
echo "/dev/sda7      none        swap    sw                   0 0" >> /etc/fstab

exit

EOF

######################################################################
# Redémarrage 
######################################################################
reboot
