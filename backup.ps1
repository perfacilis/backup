#!/usr/bin/env pwsh
# Title:        Perfacilis Incremental Back-up script for Powershell
# Description:  Create back-ups of dirs and dbs by copying them to Perfacilis' back-up servers
#               schtasks /Create /SC HOURLY /TN "Backup" /TR "C:\backup\backup.ps1" /RU SYSTEM
# Author:       Roy Arisse <support@perfacilis.com>
# See:          https://github.com/perfacilis/backup
# Version:      0.1.3
# Usage:        pwsh C:\backup\backup.ps1

$BACKUP_LOCAL_DIR="C:\backup"
$BACKUP_DIRS=@($BACKUP_LOCAL_DIR, "C:\Users", "C:\ProgramData", "C:\Program Files\Steam")

$RSYNC_TARGET="username@backup.perfacilis.com::profile"
$RSYNC_DEFAULTS="-trlqz4 --delete --delete-excluded --prune-empty-dirs"
$RSYNC_EXCLUDE=@("rsync/", "*/[Tt]emp/", "*[Cc]ache*", "*.dmp", "*.tmp", "*.bak", "weights.bin")
$RSYNC_SECRET="RSYNCSECRETHERE"

# Amount of increments per interval and duration per interval resp.
$INCREMENTS=@{hourly=24; daily=7; weekly=4; monthly=12; yearly=5}
$DURATIONS=@{hourly=3600; daily=86400; weekly=604800; monthly=2419200; yearly=31536000}

# ++++++++++ NO CHANGES REQUIRED BELOW THIS LINE ++++++++++

$ErrorActionPreference = "Stop"
$RSYNC="rsync/bin/rsync.exe"

function log() {
    Param(
        [String]$message
    )

    # Anyone know a tty -s equivalent check?
    Write-Host "$message"

    # Use backup.ps1 or whatever the current file name is as source
    New-EventLog -Source $MyInvocation.MyCommand.Name -LogName Application -ErrorAction SilentlyContinue
    Write-EventLog -Source $MyInvocation.MyCommand.Name -LogName Application -EventID 1105 -Message "$message"
}

function check_only_instance() {
    # Todo
}

function prepare_local_dir() {
    if (-Not (Test-Path -LiteralPath $BACKUP_LOCAL_DIR)) {
        New-Item -Path $BACKUP_LOCAL_DIR -ItemType Directory | Out-Null
    }
}

function prepare_remote_dir() {
    Param(
        [String]$TARGET
    )

    if (-Not $TARGET) {
        throw "Usage: prepare_remote_dir remote/dir/structure"
    }

    # Remove options that delete empty dirs
    $RSYNC_OPTS=$((get_rsync_opts) -Replace "(--(delete-excluded|delete|prune-empty-dirs))","")
    $RSYNC_TARGET_CYG=$(prefix_cygdrive $RSYNC_TARGET)

    # Create temp dir
    $EMPTYDIR=Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid())
    $EMPTYDIR_CYG=$(prefix_cygdrive $EMPTYDIR)
    New-Item -ItemType Directory -Path $EMPTYDIR | Out-Null

    $TREE=""
    ForEach($DIR in $TARGET.Split('/')) {
        $TREE=("$TREE/$DIR").Trim("/")
        $ARGS="$RSYNC_OPTS $EMPTYDIR_CYG/ $RSYNC_TARGET_CYG/$TREE"
        Start-Process -FilePath "$RSYNC" -ArgumentList "$ARGS" -Wait -NoNewWindow
    }

    # Remove empty dir
    Remove-Item -Path $EMPTYDIR
}

# Replace "C:/" with "/cygdrive/c"
function prefix_cygdrive() {
    Param(
        [String]$Path
    )

    $Replaced=$($Path -Replace "(?:^([A-z]):[/\\])", "/cygdrive/`$1/")
    return $Replaced
}

function get_last_inc_file() {
    Param(
        [String]$PERIOD
    )

    return "$BACKUP_LOCAL_DIR/last_inc_$PERIOD"
}

function get_next_increment() {
    Param(
        [String]$PERIOD
    )

    $LIMIT=$INCREMENTS[$PERIOD]

    if (-Not $LIMIT) {
        $ERROR = "Usage: get_next_increment PERIOD`nperiod = "
        $ERROR +=$INCREMENTS.keys
        throw "$ERROR"
    }

    $LAST=0
    $INCFILE=$(get_last_inc_file $PERIOD)
    if (-Not (Test-Path -PathType Leaf -Path $INCFILE)) {
        return 0
    }

    # Rad last increment from INCFILE
    $LAST=[Int]$(Get-Content $INCFILE -TotalCount 1)

    $NEXT=$($LAST+1)
    if ($NEXT -ge $LIMIT) {
        return 0;
    }

    return $NEXT
}

# Return biggest interval to backup
function get_interval_to_backup() {
    $NOW=$(Get-Date)

    # Sort hashtable in reverse order, to get biggest possible interval
    ForEach($ITEM in $($DURATIONS.GetEnumerator() | Sort-Object -Property value -Descending)) {
        $PERIOD = $ITEM.name
        $DURATION= $ITEM.value

        if ($DURATION -eq 0) {
            continue
        }

        $LAST=[datetime]0
        $INCFILE=$(get_last_inc_file $PERIOD)
        if (Test-Path -PathType Leaf -Path $INCFILE) {
            $LAST=[DateTime]$((Get-Item $INCFILE).LastWriteTime)
        }

        $DIFF=$(New-Timespan -Start $LAST -End $NOW).TotalSeconds
        if ($DIFF -gt $DURATION) {
            return $PERIOD
        }
    }
}

function get_rsync_opts() {
    $EXCLUDE="$(Get-Location)/rsync.exclude"
    $SECRET="$(Get-Location)/rsync.secret"
    $OPTS=$RSYNC_DEFAULTS

    # Exclude file simply doesn't work, so we're adding separate arguments
    if ($RSYNC_EXCLUDE) {
        ForEach($ITEM in $RSYNC_EXCLUDE) {
            $OPTS+=" --exclude=`"$ITEM`""
        }
    }

    # Don't know how bypass the chmod 600 check on W1nd0ws
    # So for new we'll use the less secure environment variable
    if ($RSYNC_SECRET) {
        ${env:RSYNC_PASSWORD}="$RSYNC_SECRET"
    }

    return $OPTS
}

function backup_packagelist() {
    $TODO=$(get_interval_to_backup)
    if (-Not $TODO) {
        return
    }

    log "Back-up list of installed packages"
    Get-Package | Format-List Name,Version,Source,ProviderName > $BACKUP_LOCAL_DIR/packagelist.txt
}

function backup_mysql() {
    # Todo
}

function backup_folders() {
    $RSYNC_OPTS=$(get_rsync_opts)
    $PERIOD=$(get_interval_to_backup)

    if (-Not $PERIOD) {
        log "No intervals to back-up yet."
        exit
    }

    $INC=$(get_next_increment $PERIOD)
    log "Moving $PERIOD back-up to target: $INC"

    prepare_remote_dir "current"

    # Replace "C:/" with "/cygdrive/c"
    $RSYNC_TARGET_CYG=$(prefix_cygdrive $RSYNC_TARGET)

    ForEach ($DIR in $BACKUP_DIRS) {
        # Replace other unwanted characters like "/", with "_"
        $TARGET=$($DIR -Replace "([^\w]+)","_").Trim("_")

        # Make path absolute if target is not RSYNC profile
        # Also remove "user@server:" for SSH setups
        $INCDIR="/$PERIOD/$INC/$TARGET"
        if (-Not $RSYNC_SECRET) {
            $INCDIR=$($RSYNC_TARGET_CYG -Replace "(^.+:)","")+$INCDIR
        }

        $DIR_CYG=$(prefix_cygdrive $DIR)

        log "- $DIR"
        $ARGS="$RSYNC_OPTS --backup --backup-dir=`"$INCDIR`" `"$DIR_CYG/`" `"$RSYNC_TARGET_CYG/current/$TARGET`""
        Start-Process -FilePath "$RSYNC" -ArgumentList "$ARGS" -Wait -NoNewWindow
    }
}

function signoff_increments() {
    Param(
        [DateTime]$STARTTIME
    )

    $PERIOD=$(get_interval_to_backup)
    $INCFILE=$(get_last_inc_file $PERIOD)
    $INC=$(get_next_increment $PERIOD)

    $INC > $INCFILE
    (Get-Item $INCFILE).LastWriteTime=$STARTTIME
}

function cleanup() {
    # Remove RSYNC_PASSWORD from env, before someone sees it...
    if ($RSYNC_SECRET) {
        Remove-Item env:RSYNC_PASSWORD
    }
}

function main() {
    try {
        $starttime=$(Get-Date)

        log "Back-up initiated at $(Get-Date)"

        check_only_instance
        prepare_local_dir

        backup_packagelist
        backup_mysql
        backup_folders

        signoff_increments $starttime

        log "Back-up completed at $(Get-Date)"
    } catch {
        # This is moreless our "set -e"
        Write-Host -ForegroundColor Red $_
        Write-Host -ForegroundColor Red $_.ScriptStackTrace
        exit 1
    } finally {
        # Instead of trap cleanup on EXIT, finally is also executed on exit
        cleanup
    }
}

main
