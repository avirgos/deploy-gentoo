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
VG_NAME="VG1"
NEW_HOSTNAME="<hostname>"

######################################################################
# Hostname
######################################################################
echo "hostname=\"${NEW_HOSTNAME}\"" > /etc/conf.d/hostname
hostname "${NEW_HOSTNAME}"
sed -i "s/localhost/${NEW_HOSTNAME}/g" /etc/hosts

######################################################################
# SSH
######################################################################
rc-update add sshd default
/etc/init.d/sshd start
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
rc-service sshd restart

######################################################################
# Utilisateur
######################################################################
useradd -m -G users,wheel exam1
echo "exam1:Attach4player4darken" | chpasswd

######################################################################
# cronie
######################################################################
emerge -K cronie
rc-update add cronie default

######################################################################
# syslog-ng
######################################################################
emerge -K syslog-ng
rc-update add syslog-ng default

echo "
destination d_login {
    file("/var/log/login.log");
};

filter f_login {
    program("login");
};

log {
    source(src);
    filter(f_login);
    destination(d_login);
};
" | tee -a /etc/syslog-ng/syslog-ng.conf
rc-service syslog-ng restart

######################################################################
# cron 
######################################################################
mkdir -p /home/toto/data
mkdir -p /mnt/backup

echo "
#!/bin/bash

source_dir=\"/home/toto/data\"
backup_dir=\"/mnt/backup\"
timestamp=\$(date +%Y%m%d%H%M%S)

if [ -d \"\$source_dir\" ]; then
    # Créer une archive tar du répertoire source
    tar -czf \"\$backup_dir/backup_\$timestamp.tar.gz\" -C \"\$source_dir\" .
    echo \"Backup successfully completed.\"
else
    echo \"Error : The source directory does not exist.\"
    exit 1
fi
" > /etc/cron.d/backup.sh
chmod u+x /etc/cron.d/backup.sh

####################################################
# cron.d : lancer le script tous les jours à 15h20 #
####################################################
echo "20 15 * * * root /etc/cron.d/backup.sh" > /etc/cron.d/backup

/etc/init.d/cronie restart

######################################################################
# apache 
######################################################################
emerge -K www-servers/apache
rc-update add apache2 default

mkdir -p /etc/ssl/apache2
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/apache2/server.key -out /etc/ssl/apache2/server.crt

echo "ServerName localhost" >> /etc/apache2/httpd.conf

/etc/init.d/apache2 start

######################################################################
# proftpd
######################################################################
emerge -K net-ftp/proftpd
rc-update add proftpd default

cp /etc/proftpd/proftpd.conf.sample /etc/proftpd/proftpd.conf

/etc/init.d/proftpd start

######################################################################
# RAID 
######################################################################
emerge sys-fs/mdadm

modprobe raid1
mknod /dev/md1 b 9 1
mdadm --create --metadata=0.9 /dev/md1 --level=1 --raid-devices=2 /dev/sda4 missing

cfdisk /dev/md1         # md1p1
mkfs.ext3 /dev/md1p1

mkdir -p /mnt/backup
echo "/dev/md1p1 /mnt/backup ext3 defaults 0 2" >> /etc/fstab
mount /mnt/backup