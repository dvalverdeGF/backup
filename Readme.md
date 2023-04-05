# Backup Script (WIP)

This script is designed to create backups of directories and upload them to a local, AWS S3, or SFTP destination. The script supports splitting the backup into volumes of a specified size and includes functionality for resuming an interrupted backup.
Usage

bash

./backup.sh [options]

## Options

    -d, --dir DIR: The directory to backup.
    -n, --name NAME: The name of the backup.
    -t, --target DIR: The target directory for the backup (default: $HOME/backup).
    --type TYPE: The type of backup. Valid values are local, aws, and sftp (default: local).
    -h, --help: Show the help message and exit.

## Requirements

    bash
    aws-cli (only required for AWS S3 backups)
    ssh (only required for SFTP backups)

## Functionality

The script takes several optional arguments and uses sensible defaults if not provided.

The -d or --dir argument specifies the directory to backup. This argument is required.

The -n or --name argument specifies the name of the backup. If not provided, the name of the directory being backed up is used.

The -t or --target argument specifies the target directory for the backup. This is where the backup volumes will be stored. If not provided, the $HOME/backup directory is used.

The --type argument specifies the type of backup. Valid values are local, aws, and sftp. If not provided, local is used.

The script creates a .backup directory in the user's home directory to store temporary files during the backup process. It also creates a .snar directory to store snapshot files, which are used to resume interrupted backups.

The script supports splitting the backup into volumes of a specified size using the max_volume_size variable. By default, volumes are split into 2GB files.

The script supports resuming interrupted backups. If a snapshot file exists for the backup, the script will use it to determine which files have already been backed up and will continue from where it left off.
Example Usage

Create a local backup of the /home/user/documents directory:

```
$ ./backup.sh --dir /home/user/documents
```

Create a backup of the /home/user/documents directory and upload it to an SFTP server:

```
$./backup.sh --dir /home/user/documents --type sftp --name my-backup --target /backup --sftp-user user --sftp-host sftp.example.com --sftp-path /backups
```