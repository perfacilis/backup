#!/bin/bash
# Backup script

# The folders to back-up, separate with a space between each
BACKUP_DIRS=(/home /root /etc /var/www /backup)

# Only mysql dumps will remain here until next backup, other files are directly moved to backup server
day=`date +%A`
BACKUP_DEST_DIR=/backup/${day}/

RSYNC_SECRET=`dirname $0`/rsync.secret
RSYNC_PROFILE="username@backup.perfacilis.com::profile/${day}"
RSYNC="rsync -trlqz --exclude=temp/ --password-file=$RSYNC_SECRET"

# Put password in secret file, since its more secure than 'export RSYNC_PASSWORD=...'
echo 'RSYNCSECRETHERE' > $RSYNC_SECRET
chmod 600 $RSYNC_SECRET

# make sure backup directory exists and is empty
echo -n "Setting up backup directory..."
if [ ! -d ${BACKUP_DEST_DIR} ]; then
  mkdir -p ${BACKUP_DEST_DIR}
fi

rm -Rf ${BACKUP_DEST_DIR}*
echo "Completed!"

# backup directories directly to target
echo -n "Backing up directories..."
for i in ${BACKUP_DIRS[@]}
do
  echo -n "${i}..."

  ABSOLUTE=${i/#\//}
  TARGET=${ABSOLUTE//\//_}
  ${RSYNC} --delete /${i}/ ${RSYNC_PROFILE}/${TARGET}/
done
echo "Completed!"

# backup mysql databases
echo "Backing up mysql databases"
if [ ! -d ${BACKUP_DEST_DIR}mysql ]; then
  mkdir ${BACKUP_DEST_DIR}mysql
fi

for DB in `mysql --defaults-file=/etc/mysql/debian.cnf -e 'show databases' | grep -v Database`;
do
  if [ ${DB} != 'information_schema' -a ${DB} != 'performance_schema' ]; then
    echo -n "Backup database ${DB}..."
    SQLDUMP_FILE=${BACKUP_DEST_DIR}mysql/${DB}
    SQLDUMP_FILE_ABS=${SQLDUMP_FILE/#\//}

    mysqldump --defaults-file=/etc/mysql/debian.cnf -f --events ${DB} > ${SQLDUMP_FILE}.sql
    echo "Voltooid!"
  fi
done

# list of installed packages, this can be used with "dpkg --set-selections < packagelist.txt && apt-get dselect-upgrade -y"
echo -n "Backup list of installed packages..."
dpkg --get-selections > ${BACKUP_DEST_DIR}/packagelist.txt
echo "Completed!"

# sync to backup server
echo "Syncing backup to backup server..."
${RSYNC} ${BACKUP_DEST_DIR}/ ${RSYNC_PROFILE}
echo "Completed!"

# Delete secret when done
rm $RSYNC_SECRET
