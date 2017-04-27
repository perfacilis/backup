#!/bin/bash
# Title:        Perfacilis Incremental Back-up script
# Description:  Create back-ups of dirs and dbs by copying them to Perfacilis' back-up servers
#               We strongly recommend to put this in /etc/cron.daily
# Author:       Roy Arisse <support@perfacilis.com>
# See:          https://admin.perfacilis.com
# Version:      0.3
# Usage:        bash /etc/cron.daily/makebackup.sh

# Force consistent directory names by using POSIX locale
export LC_ALL=C

NBACKUPS=30

# The folders to back-up, separate with a space between each
BACKUP_DIRS=(/home /root /etc /var/www /backup)
EXCLUDE="temp/,tmp/,cache/,.cache/,log/,logs/,*.log"
BACKUP_DEST_DIR=/backup/

RSYNC_SECRET=`dirname $0`/rsync.secret
RSYNC_EXCLUDE=`dirname $0`/rsync.exclude
RSYNC_PROFILE="username@backup.perfacilis.com::profile"
RSYNC="rsync -trlqz4 --delete --delete-excluded --prune-empty-dirs --exclude-from=$RSYNC_EXCLUDE --password-file=$RSYNC_SECRET"

MYSQL="mysql --defaults-file=/etc/mysql/debian.cnf"
MYSQLDUMP="mysqldump --defaults-file=/etc/mysql/debian.cnf --events --routines --max-allowed-packet=512MB --quick --quote-names"

# Ensure tempfiles are removed when done
trap "rm -f $RSYNC_SECRET $RSYNC_EXCLUDE" EXIT

# Log output
log() {
  MSG=`echo $1`
  logger -p local0.notice -t `basename $0` -- $MSG

  # Interactive shell
  if tty -s; then
    echo $MSG
  fi
}

# Put password in secret file, since its more secure than 'export RSYNC_PASSWORD=...'
echo 'RSYNCSECRETHERE' > $RSYNC_SECRET
chmod 600 $RSYNC_SECRET

# Prepare exclusion file
printf "${EXCLUDE//,/\n}" > $RSYNC_EXCLUDE

# Show date and time so we can monitor duration if needed
log "Back-up initiated at `date`"

# Make sure local backup directory exists and is empty
log "Setting up backup directory"
if [ ! -d $BACKUP_DEST_DIR ]; then
  mkdir -p $BACKUP_DEST_DIR

  # Ensure dir "0" exists remotely
  [ -d /tmp/emptydir ] || mkdir /tmp/emptydir
  ${RSYNC/--delete* /} /tmp/emptydir/ $RSYNC_PROFILE/0
  rm -r /tmp/emptydir
fi

LAST=""
NEXT=0
if [ -f $BACKUP_DEST_DIR/.last ]; then
  LAST=$(cat $BACKUP_DEST_DIR/.last | tr -d "\n")
fi

if [ ! -z "$LAST" ]; then
  NEXT=$(($LAST+1))
  if [ "$NEXT" -ge "$NBACKUPS" ]; then
    LAST=""
    NEXT=0
  fi
fi

log "Determined next increment: $NEXT"

log "Backing up mysql databases:"
for DB in `$MYSQL -e 'show databases' | grep -v Database`; do
  if [ $DB = 'information_schema' -o $DB = 'performance_schema' ]; then
    continue
  fi

  log "- $DB"

  SQLDUMP_FILE=$BACKUP_DEST_DIR/$DB.sql
  $MYSQLDUMP $DB | gzip > $SQLDUMP_FILE.gz
done

# List of installed packages, this can be used with "dpkg --set-selections < packagelist.txt && apt-get dselect-upgrade -y"
log "Backup list of installed packages"
dpkg --get-selections > $BACKUP_DEST_DIR/packagelist.txt

# Backup everything trough rsync, this is magic!
log "Moving to back-up server"
for i in ${BACKUP_DIRS[@]}; do
  ABSOLUTE=${i/#\//}
  TARGET=${ABSOLUTE//\//_}

  log "- $i"

  if [ ! -z "$LAST" ]; then
    $RSYNC --backup --backup-dir=/$NEXT/$TARGET $i/ $RSYNC_PROFILE/0/$TARGET
  else
    $RSYNC $i/ $RSYNC_PROFILE/$NEXT/$TARGET
  fi
done

# Update last increment
echo $NEXT > $BACKUP_DEST_DIR/.last

# Sign off with datetime
log "Back-up completed at `date`"
