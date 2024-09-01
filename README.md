# RSYNC incremental backup script

Rsync backup script free to use:
- Linux implementation in bash
    - See: https://www.perfacilis.com/blog/systeembeheer/linux/rsync-daily-weekly-monthly-incremental-back-ups.html
- Windows implementation in Powershell
    - See: https://www.perfacilis.com/blog/systeembeheer/windows/windows-incremental-back-up-using-rsync-and-powershell.html

I'm using this script to back-up all my Windows & Linux workstations and 
servers without trouble, nonetheless this script comes with no warranty
whatsoever.

**Please check the integrity of your back-ups periodically!**


## We're hoping for your feedback...

![GIF I like it a lot](https://i.imgflip.com/lo6p.gif)

Tried this script for a bit? Like it? Or hate it?

It would help my business like a lot if you would take just 60 seconds out of 
your time and tell us what you think:
http://g.page/perfacilis/review


## Installation

### Installation on Linux

Simply download the latest version, change the `readonly` variables in the first 
few lines of the script and install it as an (hourly) cronjob. For example:

```bash
# Never copy-pasta stuff from the webz into your terminal, always check first!
wget -qO- https://raw.githubusercontent.com/perfacilis/backup/master/backup | sudo tee /etc/cron.hourly/backup
sudo chmod 700 /etc/cron.hourly/backup

# Change BACKUP_LOCAL_DIR, BACKUP_DIRS, etc
nano /etc/cron.hourly/backup

# Optionally run it manually
sudo /etc/cron.hourly/backup

# Or watch your syslog
tail -f /var/log/syslog | grep --color --line-buffered "backup:"
```

### Installation on Windows

First, you'll need a Windows implementation of Rsync, for example:
    https://itefix.net/cwrsync-client
Download the zip and extract so you get `C:\backup\rsync\bin\rsync.exe`

Then, like the Linux installation, download the latest version, change the 
variables in the first few lines and install a Scheduled Task. For example:

```shell
New-Item -Path "C:/backup" -ItemType Directory
Set-Location C:/backup

# Retrieve cwrsync (cygwin rsync), run commented out TLS-fix for older pwsh versions
#[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri https://itefix.net/dl/free-software/cwrsync_6.2.8_x64_free.zip -OutFile rsync.zip
Expand-Archive rsync.zip
Remove-Item rsync.zip

# Download the file, don't forget to change the settings!
Invoke-WebRequest -Uri https://raw.githubusercontent.com/perfacilis/backup/master/backup.bs1 -OutFile backup.ps1

# Create an hourly scheduled task, powershell flavour
# See: Task Scheduler » Microsoft » Windows » Powershell » ScheduledJobs
$trigger = New-JobTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) -RepeatIndefinitely
$callback = {Start-Process "powershell.exe" -ArgumentList "C:\backup\backup.ps1" -Wait -NoNewWindow}
Register-ScheduledJob -Name "backup.ps1" -Trigger $trigger -MaxResultCount 99 -ScriptBlock $callback
```


## Basic usage

### Rsync profile

Default usage, backup to a server with an Rsync profile:

```bash
readonly RSYNC_TARGET="username@backup.perfacilis.com::profile"
readonly RSYNC_DEFAULTS="-trlqpz4 --delete --delete-excluded --prune-empty-dirs"
readonly RSYNC_EXCLUDE=(tmp/ temp/)
readonly RSYNC_SECRET='RSYNCSECRETHERE'
```

### Local backup

If you want to backup to a USB disk for example:

```bash
readonly RSYNC_TARGET="/media/user/backup_drive"
readonly RSYNC_DEFAULTS="-trlqpz4 --delete --delete-excluded --prune-empty-dirs"
readonly RSYNC_EXCLUDE=(tmp/ temp/)
readonly RSYNC_SECRET=''
```

### Rsync over ssh

Rsync using ssh to communicate instead of rsync profiles.
You'll have to set up SSH Public Key authentication:

```bash
readonly RSYNC_TARGET="username@backup.perfacilis.com:/path/on/ssh/server"
readonly RSYNC_DEFAULTS="-trlqpz4 --delete --delete-excluded --prune-empty-dirs -e "'"ssh -p 2222"'""
readonly RSYNC_EXCLUDE=(tmp/ temp/)
readonly RSYNC_SECRET=''
```


## Databases

When `$DB_LIST` is not empty, the script tries to backup all listed names into 
a GZIP file. Therefore, leave empty if you don't want to backup databases. For
every database, `$DB_DUMP` is run, so change this according to your database 
system.

See some examples below.

### MySQL examples
For **MariaDB** use `mariadb` instead of `mysql` and `mariadb-dump` instead of
`mysqldump`.

```bash
readonly DB_LIST="database1 database2"
readonly DB_LIST="$(mysql --defaults-file=/etc/mysql/debian.cnf -e "SHOW DATABASES;" -B -N | grep -v 'Database')"

readonly DB_DUMP="mysqldump --defaults-file=/etc/mysql/debian.cnf -E -R --max-allowed-packet=512MB -q --single-transaction -Q --skip-comments"
readonly DB_NAME="mysqldump --defaults-file=/etc/mysql/debian.cnf --ssl-mode=VERIFY_CA --ssl-ca=ca.pem --ssl-cert=client-cert.pem --ssl-key=client-key.pem -E -R --max-allowed-packet=512MB -q --single-transaction -Q --skip-comments"
readonly DB_DUMP="mysqldump --defaults-extra-file=/root/.mysqldump -E -R --max-allowed-packet=512MB -q --single-transaction -Q --skip-comments"
readonly DB_DUMP="mysqldump --username=PLSDONT --password=PLSDONT -E -R --max-allowed-packet=512MB -q --single-transaction -Q --skip-comments"
```

Example of `/root/.mysqldump` file:
```bash
[mysql]
user=USERNAME
password=PASSWORD

[mysqldump]
user=USERNAME
password=PASSWORD
```

### PostgreSQL examples

```bash
readonly DB_LIST="$(psql -h 127.0.0.1 -U restore --no-password -l -t | grep '^ \w' | grep -v 'template' | awk '{print $1}')"
readonly DB_DUMP="pg_dump -h 127.0.0.1 -U restore --no-password -d"
```

It's recommended to create a user to allow databases to be dumped without user
interaction:
```bash
sudo -u postgres psql -c "CREATE USER restore SUPERUSER PASSWORD 'secret';"
sudo -u postgres psql -c "GRANT pg_read_all_data TO restore;
echo '*:*:*:restore:SECRETPASSWORD' | sudo tee /root/.pgpass
sudo chmod 600 /root/.pgpass
```

### Database encryption
If you set `$DB_ENCRYPTION_KEY`, the GZIP file will be encrypted using that 
public key. You can generate a public key using:

```bash
openssl req -x509 -nodes -newkey rsa:2048 -keyout PRIVATE.key -out PUBLIC.pem
```

The encrypted GZIP file can be decrypted using the private key:

```bash
openssl smime -decrypt -inform DER -in EXAMPLE.sql.gz.enc -inkey PRIVATE.key > EXAMPLE.sql.gz
```


## Contributing

Any bugs or ideas for improvement can be reported using GitHub's Issues thingy.

If you know `bash` or `pwsh` and see how the scripts can be improved, don't be
shy and create a Pull Request.