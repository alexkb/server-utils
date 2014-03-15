#!/bin/sh

# Description: This is a simple script to backup important folders like website folders 
# as well as MySQL databases. It compresses the backup and pushes it to an offsite storage solution 
# like Amazon S3.
#
# Requirements: s3sync - http://s3sync.net/wiki.html
#
# Written by alex.bergin@gmail.com. Distributed under license GPLv2+ GNU GPL version 2 
# or later <http://gnu.org/licenses/gpl.html>
#
# You'll need a MySQL user to run these backups. The following should suffice:
# CREATE USER 'backup-reader'@'localhost' IDENTIFIED BY  '***'; 
# GRANT SELECT, SHOW DATABASES, LOCK TABLES ON * . * TO  'backup-reader'@'localhost' \
# IDENTIFIED BY  '***' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 \
# MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;

# Constants to configure
VHOSTS_FOLDER="/var/www/vhosts"
OTHER_FOLDERS="/etc/apache2 /etc/php5"
CURRDATE=`date '+%Y-%m-%d'`
MYSQL_USER="backup-reader" 
MYSQL_PASSWORD=`cat ~/mysql-backup-passwd`
OUTPUTDIR="/backups"
MYSQLDUMP="/usr/bin/mysqldump"
MYSQL="/usr/bin/mysql"
HOSTNAME=`hostname`
S3SYNCBIN="/opt/s3sync"
BUCKETNAME="ted-backups"
BACKUP_EXCLUDE_FLAGS="--exclude-vcs"
# End of Constants.

# Clean up any old sql backups
rm -rf "$OUTPUTDIR/mysql-dbs"; mkdir -p "$OUTPUTDIR/mysql-dbs"

# Get a list of all databases
databases=`$MYSQL --user=$MYSQL_USER --password=$MYSQL_PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`

# Dump each database in turn
for db in $databases; do
	if [ $db != "information_schema" ] && [ $db != "performance_schema" ] ; then
		echo "Dumping: $db"
		$MYSQLDUMP --force --opt --user=$MYSQL_USER --password=$MYSQL_PASSWORD --databases $db > "$OUTPUTDIR/mysql-dbs/$db.sql"
	fi
done
	
# Our new backup file
BACKUP_FILE="$HOSTNAME-backup-$CURRDATE.tar.gz"

# Compress site, sql dumps and more.
tar $BACKUP_EXCLUDE_FLAGS -czf $OUTPUTDIR/$BACKUP_FILE $VHOSTS_FOLDER $OUTPUTDIR/mysql-dbs $OTHER_FOLDERS

# Remove the dumps immediately - for security.
rm -rf "$OUTPUTDIR/mysql-dbs"; 

# Copy backup to S3
ruby $S3SYNCBIN/s3cmd.rb put $BUCKETNAME:scheduled/$BACKUP_FILE $OUTPUTDIR/$BACKUP_FILE

# Remove old backup from local disk
rm $OUTPUTDIR/$BACKUP_FILE




