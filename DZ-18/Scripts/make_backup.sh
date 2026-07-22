#!/bin/bash

Target=$1
BackUpName=$2
Repo=$3
TempBackUpDir="/mnt/backup_remote_dir"
StartDir="$(pwd)"

echo "Target: $Target"
echo "BackUpName: $BackUpName"
echo "Repo: $Repo"

if [ ! -d "$TempBackUpDir" ]; then
        mkdir -p "$TempBackUpDir"
fi

sshfs "$Target" "$TempBackUpDir"

if [ $? -eq 0 ]; then
        cd "$TempBackUpDir"
        borg create --stats "$Repo"::"$BackUpName"-{now:%Y-%m-%d_%H:%M:%S} . 
        cd "$StartDir" 
        umount "$TempBackUpDir"
else
    echo "Can't mount remote dir for restore"
fi



