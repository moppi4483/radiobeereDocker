#!/bin/bash
LOG_LOCATION=/usr
exec > >(tee -i $LOG_LOCATION/radiobeere_installLog.log)
exec 2>&1

# Install packages via package manager

#apt-get --yes install rename samba-common samba apache2 php mariadb-server php-mysql minidlna streamripper python-mysqldb

# Download and install Mutagen

apt-get update && apt-get --yes upgrade
apt-get --yes install wget python3 python3-pip git rename apache2 php mariadb-server php-mysql streamripper
#apt-get --yes install samba-common samba minidlna

pip install mysql-connector-python

cd /temp
wget https://github.com/quodlibet/mutagen/archive/refs/tags/release-1.45.1.tar.gz
tar -xf release*.gz
cd mutagen*
python3 setup.py build
su -c "python3 setup.py install"
cd ..
rm release*.gz
#rm -R mutagen*

cd /
git clone https://github.com/moppi4483/radiobeere


password=radiobeerePASSWD

cd /radiobeere/setup
sed 's/password/'$password'/g' radiobeere.sql > temp_file
mv temp_file radiobeere.sql

sed 's/password/'$password'/g' ../login.py > temp_file
mv temp_file ../login.py
chmod 755 ../login.py

sed 's/password/'$password'/g' ../var/www/include/db-connect.php > temp_file
mv temp_file ../var/www/include/db-connect.php
chmod 644 ../var/www/include/db-connect.php


cat radiobeere.sql | mysql -u root

# Create system and Samba user radiobeere

#useradd --no-create-home radiobeere
#(echo "radiobeere" ; sleep 5 ; echo "radiobeere") | passwd radiobeere
#(echo "radiobeere" ; sleep 5 ; echo "radiobeere") | smbpasswd -s -a radiobeere

# Move frontend files to web root

#mv ../var/www/* /var/www
#chmod 777 /var/www/content/img/podcast

# Link web root to RadioBeere directory

#echo "/var/www /radiobeere/var/www none bind 0 0" >> /etc/fstab
#mount -al

# Declare changed files as unchanged to git

cd /radiobeere
git update-index --assume-unchanged login.py
git update-index --assume-unchanged setup/radiobeere.sql
git update-index --assume-unchanged var/www/include/db-connect.php


# Create Samba share
<<com

cp /etc/samba/smb.conf /etc/samba/smb.conf.original

cat >> /etc/samba/smb.conf << EOF

[Aufnahmen]
path = /var/www
public = yes
writeable = yes
create mask = 0755
directory mask = 0755
guest ok = yes
browseable = yes
EOF

/etc/init.d/samba restart
com

# Change Apache root directory

cp /etc/apache2/sites-available/000-default.conf \
/etc/apache2/sites-available/000-default.conf.original

sed 's/DocumentRoot \/var\/www\/html/DocumentRoot \/radiobeere\/var\/www/g' \
/etc/apache2/sites-available/000-default.conf > temp_file
mv temp_file /etc/apache2/sites-available/000-default.conf


cp /etc/apache2/apache2.conf \
/etc/apache2/apache2.conf.original

sed 's/\/var\/www\//\/radiobeere\/var\/www\//g' \
/etc/apache2/apache2.conf > temp_file
mv temp_file /etc/apache2/apache2.conf


#/etc/init.d/apache2 restart

# Configure ReadyMedia DLNA-Server
<<com
cp /etc/minidlna.conf /etc/minidlna.conf.original

sed 's/media_dir=\/var\/lib\/minidlna/media_dir=\/var\/www\/content\/Aufnahmen/g' \
/etc/minidlna.conf > temp_file
mv temp_file /etc/minidlna.conf
sed 's/#network_interface=/network_interface=eth0/g' \
/etc/minidlna.conf > temp_file
mv temp_file /etc/minidlna.conf
sed 's/#friendly_name=/friendly_name=RadioBeere/g' \
/etc/minidlna.conf > temp_file
mv temp_file /etc/minidlna.conf
sed 's/#inotify=yes/inotify=yes/g' \
/etc/minidlna.conf > temp_file
mv temp_file /etc/minidlna.conf

/etc/init.d/minidlna restart
com
# Add cronjobs

cat >> /etc/crontab << EOF
15 0 * * * root /radiobeere/setup/update-system >> /radiobeere/var/www/dist-upgrade.log 2>&1 ; /radiobeere/setup/shorten-log
0 0 * * * root /radiobeere/rb-timer-update.py > /dev/null 2>&1
5 0 * * * root /radiobeere/rb-rec-cleanup.py > /dev/null 2>&1
#10 0 * * * root rm /var/lib/minidlna/files.db > /dev/null 2>&1 ; /etc/init.d/minidlna restart > /dev/null 2>&1
#
EOF

# Grant sudo rights to user www-data

cat >> /etc/sudoers << EOF
www-data ALL=NOPASSWD:/radiobeere/rb-timer-update.py
www-data ALL=NOPASSWD:/radiobeere/rb-rec-cleanup.py
www-data ALL=NOPASSWD:/radiobeere/podcast.py
www-data ALL=NOPASSWD:/radiobeere/setup/update-radiobeere
www-data ALL=NOPASSWD:/sbin/reboot
EOF

