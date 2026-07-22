#!/bin/bash

Repo=$1
BackUpName=$2
Target=$3
TempBackUpDir="/mnt/backup_remote_dir"
StartDir="$(pwd)"

echo "Repo: $Repo"
echo "BackUp: $BackUpName"
echo "Target: $Target"

if [ ! -d "$TempBackUpDir" ]; then
        mkdir -p "$TempBackUpDir"
fi

sshfs "$Target" "$TempBackUpDir"

if [ $? -eq 0 ]; then
        cd "$TempBackUpDir"
        borg extract --list "$Repo"::"$BackUpName"
        cd "$StartDir" 
        umount "$TempBackUpDir"
else
    echo "Can't mount remote dir for restore"
fi


