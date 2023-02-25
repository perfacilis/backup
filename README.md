# RSYNC incremental backup script

See: https://www.perfacilis.com/blog/systeembeheer/linux/rsync-daily-weekly-monthly-incremental-back-ups.html

Bash Rsync backup script free to use. I'm using this script to back-up all my 
Linux workstations and servers without (much) trouble, nonetheless this script 
comes with no warranty whatsoever.

## We're desperate for your feedback...

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
sudo chmod +x /etc/cron.hourly/backup

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
Download the zip and extract so you get "C:\backup\rsync\bin\rsync.exe"

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

# Create an hourly scheduled task
$action = New-ScheduledTaskAction -Execute "C:/backup/backup.ps1"
$trigger = New-ScheduledTaskTrigger -RepetitionInterval "PT1H" -RepetitionDuration "PT1H"
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable
$task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings
Register-ScheduledTask 'backup' -InputObject $task
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
readonly RSYNC_DEFAULTS="-trlqpz4 --delete --delete-excluded --prune-empty-dirs -e 'ssh'"
readonly RSYNC_EXCLUDE=(tmp/ temp/)
readonly RSYNC_SECRET=''
```

## Contributing

Any bugs or ideas for improvement can be reported using GitHub's Issues thingy.

If you know `bash` or `pwsh` and see how the scripts can be improved, don't be
shy and create a Pull Request.