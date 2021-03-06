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

Simply download the latest version, change the `readonly` variables in the first 
few lines of the script and install it as an (hourly) cronjob. For example:

```bash
# Never copy-pasta stuff from the webz into your terminal, always check first!
wget -qO- https://raw.githubusercontent.com/perfacilis/backup/master/backup | sudo tee /etc/cron.hourly/backup
sudo chmod +x /etc/cron.hourly/backup

# Optionally run it manually
sudo /etc/cron.hourly/backup

# Or watch your syslog
tail -f /var/log/syslog | grep --color --line-buffered "backup:"
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

If you know `bash` and see how this script can be improved, don't be shy and 
create a Pull Request.