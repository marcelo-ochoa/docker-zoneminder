#!/bin/bash


set -e

#trays to fix problem with https://github.com/QuantumObject/docker-zoneminder/issues/22
chown www-data /dev/shm
mkdir -p /var/run/zm
chown www-data:www-data /var/run/zm

#to fix problem with data.timezone that appear at 1.28.108 for some reason
sed  -i "s|\;date.timezone =|date.timezone = \"${TZ:-America/New_York}\"|" /etc/php/7.0/apache2/php.ini
#if ZM_DB_HOST variable is provided in container use it as is, if not left as localhost
ZM_DB_HOST=${ZM_DB_HOST:-localhost}
sed  -i "s|ZM_DB_HOST=localhost|ZM_DB_HOST=$ZM_DB_HOST|" /etc/zm/zm.conf
#if ZM_SERVER_HOST variable is provided in container use it as is, if not left 02-multiserver.conf unchanged
if [ -v ZM_SERVER_HOST ]; then sed -i "s|#ZM_SERVER_HOST=|ZM_SERVER_HOST=${ZM_SERVER_HOST}|" /etc/zm/conf.d/02-multiserver.conf; fi

if [ -f /var/cache/zoneminder/configured ]; then
        echo 'already configured.'
        /sbin/wait-for-it.sh -h $ZM_DB_HOST -p 3306 -t 300
        /sbin/zm.sh&
else
        
        #configuration for zoneminder
        #cp /etc/mysql/mysql.conf.d/mysqld.cnf /usr/my.cnf
        #this only happends if -V was used and data was not from another container for that reason need to recreate the db.
        fi
        
        #check if Directory inside of /var/cache/zoneminder are present.
        if [ ! -d /var/cache/zoneminder/events ]; then
           mkdir -p /var/cache/zoneminder/events
           mkdir -p /var/cache/zoneminder/images
           mkdir -p /var/cache/zoneminder/temp
        fi
        
        chown -R root:www-data /var/cache/zoneminder /etc/zm/zm.conf
        chmod -R 770 /var/cache/zoneminder /etc/zm/zm.conf
        
        #needed to fix problem with ubuntu ... and cron 
        update-locale
        date > /var/cache/zoneminder/configured
        
        /sbin/zm.sh&
fi
