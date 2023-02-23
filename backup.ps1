#!/usr/bin/env pwsh
# Title:        Perfacilis Incremental Back-up script for Powershell
# Description:  Create back-ups of dirs and dbs by copying them to Perfacilis' back-up servers
#               schtasks /Create /SC HOURLY /TN "Backup" /TR "C:\backup\backup.ps1" /RU SYSTEM
# Author:       Roy Arisse <support@perfacilis.com>
# See:          https://github.com/perfacilis/backup
# Version:      0.1
# Usage:        pwsh C:\backup\backup.ps1

$BACKUP_LOCAL_DIR="C:\backup"
$BACKUP_DIRS=@($BACKUP_LOCAL_DIR, "C:\Users", "C:\ProgramData", "C:\Program Files\Steam")

$RSYNC_TARGET="username@backup.perfacilis.com::profile"
$RSYNC_DEFAULTS="-trlvqz4 --delete --delete-excluded --prune-empty-dirs"
$RSYNC_EXCLUDE=@("tmp\", "temp\")
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

    Write-Host "$message"
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
    $RSYNC_OPTS=$((get_rsync_opts) -Replace "(--(delete|delete-excluded|prune-empty-dirs))","")

    # Replace "C:/" with "/cygdrive/c"
    $RSYNC_TARGET=$($RSYNC_TARGET -Replace "(?:^([A-z]):/)", "/cygdrive/`$1/")

    # Create temp dir
    $EMPTYDIR=Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid())
    New-Item -ItemType Directory -Path $EMPTYDIR | Out-Null

    $TREE=""
    ForEach($DIR in $TARGET.Split('/')) {
        $TREE=("$TREE/$DIR").Trim("/")
        $ARGS="$RSYNC_OPTS $EMPTYDIR/ $RSYNC_TARGET/$TREE"
        Start-Process -FilePath "$RSYNC" -ArgumentList "$ARGS"
    }

    # Remove empty dir
    Remove-Item -Path $EMPTYDIR
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

    # Separating excludes with \n into exclude file
    if ($RSYNC_EXCLUDE) {
        if (-Not (Test-Path -PathType Leaf -Path $EXCLUDE)) {
            $RSYNC_EXCLUDE -Join "`n" > $EXCLUDE
        }

        $OPTS+=" --exclude-from=$EXCLUDE"
    }

    # Secret file: just spit into file
    if ($RSYNC_SECRET) {
        if (-Not (Test-Path -PathType Leaf -Path $SECRET)) {
            $RSYNC_SECRET > $SECRET
        }

        $OPTS+=" --password-file=$SECRET"
    }

    return $OPTS
}

function backup_packagelist() {
    # Todo
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
    $RSYNC_TARGET=$($RSYNC_TARGET -Replace "(?:^([A-z]):/)", "/cygdrive/`$1/")

    ForEach ($DIR in $BACKUP_DIRS) {
        # Replace other unwanted characters like "/", with "_"
        $TARGET=$($DIR -Replace "([^\w]+)","_").Trim("_")

        # Make path absolute if target is not RSYNC profile
        # Also remove "user@server:" for SSH setups, leave C: in-tact
        $INCDIR="/$PERIOD/$INC/$TARGET"
        if (-Not $RSYNC_SECRET) {
            $INCDIR=$($RSYNC_TARGET -Replace "(^.{2,}:)","")+$INCDIR
        }

        log "- $DIR"
        $ARGS="$RSYNC_OPTS --backup --backup-dir=$INCDIR $DIR/ $RSYNC_TARGET/current/$TARGET"
        Start-Process -FilePath "$RSYNC" -ArgumentList "$ARGS" -Wait
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
    #(Get-Item $INCFILE).LastWriteTime=$STARTTIME
}

function cleanup() {
    $EXCLUDE="$(Get-Location)/rsync.exclude"
    $SECRET="$(Get-Location)/rsync.secret"
    Remove-Item -Force $EXCLUDE,$SECRET -ErrorAction SilentlyContinue
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