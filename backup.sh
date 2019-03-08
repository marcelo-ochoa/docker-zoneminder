#!/bin/bash

#Backup mysql
mysqldump -u root -pmysqlpsswd -h ${ZM_DB_HOST:-localhost} --all-databases | gzip > /var/backups/alldb_backup-`date +'%Y%m%d%H%M%S'`.sql.gz

#Backup important file ... of the configuration ...
cp  /etc/hosts  /var/backups/

