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
# User
######################################################################
useradd -m -G users,wheel user1
echo "user:Attach4player4darken" | chpasswd

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