#!/bin/sh
### In mysqld.sh (make sure this file is chmod +x):
# `chpst -u mysql` runs the given command as the user `mysql`.
# If you omit that part, the command will be run as root.
ZM_DB_HOST=${ZM_DB_HOST:-localhost}

# IF ZM_DB_HOST is set to localhost, start MySQL local. If not MySQL is running in a separate container
if [ "$ZM_DB_HOST" == "localhost" ]; then
  mkdir -p /var/run/mysqld
  chown mysql /var/run/mysqld
  exec chpst -u mysql /usr/bin/mysqld_safe  2>&1 
fi
