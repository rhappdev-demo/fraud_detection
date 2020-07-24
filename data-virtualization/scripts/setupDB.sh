#! /usr/bin/sh

/opt/rh/rh-mysql57/root/usr/bin/mysql -u user --password=mypassword -h 127.0.0.1 mysqlsampledb -e 'source /tmp/scripts/mysql.sql'
exit
