#!/bin/bash

# Set default values
backup_dir=""
backup_name=""
target_dir="$HOME/backup"
max_volume_size=2097152
backup_type="local"
tmp_dir="$HOME/.backup"
# AWS S3 connection details
s3_bucket="my-backup-bucket"

# SFTP connection details
sftp_user="user"
sftp_host="host"
sftp_backup_path="/path/to/backup"

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d|--dir)
        backup_dir="$2"
        shift # past argument
        shift # past value
        ;;
        -n|--name)
        backup_name="$2"
        shift # past argument
        shift # past value
        ;;
        -t|--target)
        target_dir="$2"
        shift # past argument
        shift # past value
        ;;
        --type)
        backup_type="$2"
        shift # past argument
        shift # past value
        ;;
        --sftp-user)
        sftp_user="$2"
        shift # past argument
        shift # past value
        ;;
        --sftp-host)
        sftp_host="$2"
        shift # past argument
        shift # past value
        ;;
        --sftp-path)
        sftp_backup_path="$2"
        shift # past argument
        shift # past value
        ;;
        -h|--help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  -d, --dir DIR       Directory to backup"
        echo "  -n, --name NAME     Name of the backup"
        echo "  -t, --target DIR    Target directory for the backup (default: $HOME/backup)"
        echo "      --type TYPE     Type of backup (local, aws, sftp)"
        echo "      --sftp-user USER  SFTP username"
        echo "      --sftp-host HOST  SFTP hostname"
        echo "      --sftp-path PATH  SFTP backup path"
        echo "  -h, --help          Show this help message and exit"
        exit 0
        ;;
        *)
        shift # past argument
        ;;
    esac
done

if [[ $backup_type == "aws" ]]; then
    if ! command -v aws &> /dev/null; then
        echo "Error: aws-cli not found. Please install aws-cli or choose a different backup type."
        exit 1
    fi
elif [[ $backup_type == "sftp" ]]; then
    if ! ssh $sftp_user@$sftp_host "ls $sftp_backup_path" &> /dev/null; then
        echo "Error: could not connect to SFTP server. Please check the SFTP connection details or choose a different backup type."
        exit 1
    fi
fi

# Check required arguments
if [[ -z "$backup_dir" ]]; then
    echo "Error: missing required argument --dir" >&2
    exit 1
fi

# Set default backup name if not provided
if [[ -z "$backup_name" ]]; then
    backup_name="$(basename "$backup_dir")"
fi

# Create target directory if it doesn't exist
mkdir -p "$target_dir"

# Create .snar directory if it doesn't exist
snar_dir="$HOME/.snar"
mkdir -p "$snar_dir"

# Create .backup directory if it doesn't exist
if [[ -z "$tmp_dir" ]]; then
    echo "Error: \$tmp_dir is not set or is empty" >&2
    exit 1
fi

mkdir -p "$tmp_dir"

# Set snar file path
snar_file="$snar_dir/$backup_name.snar"

# Function to upload a backup volume to AWS S3
function upload_aws_backup_volume {
    volume_path="$1"
    volume_name="$(basename "$volume_path")"
    aws s3 cp "$volume_path" "s3://$s3_bucket/$volume_name"
}

# Function to upload a backup volume to SFTP
function upload_sftp_backup_volume {
    volume_path="$1"
    volume_name="$(basename "$volume_path")"
    scp "$volume_path" "$sftp_user@$sftp_host:$sftp_backup_path/$volume_name"
}

# Function to upload a backup volume to local directory
function upload_local_backup_volume {
    volume_path="$1"
    volume_name="$(basename "$volume_path")"
    if [[ $volume_path == $target_dir/backup.tar.gz.* ]]; then
        echo "El archivo de volumen $volume_name ya se encuentra en el directorio destino. No se realizará ninguna acción."
    else
        # Mueve el archivo de volumen al directorio destino.
        echo "Moviendo el volumen $volume_name al directorio destino..."
       mv "$volume_path" "$target_dir/$volume_name"
    fi
}
# Función para crear un nuevo volumen de backup y subirlo al destino de backup correspondiente.
function send_backup_volume {
    volume_number=$1
    # Crea el archivo de volumen en el directorio de origen.
    volume_path="$tmp_dir/$backup_name.tar.gz.$(printf "%02d" $volume_number)"
    # Verifica si el archivo existe antes de subirlo o moverlo.
    if [[ -e $volume_path ]]; then
        # Sube el archivo de volumen al destino de backup correspondiente.
        echo "Subiendo el volumen $volume_number al destino de backup..."
        if [[ $backup_type == "aws" ]]; then
            upload_aws_backup_volume "$volume_path"
        elif [[ $backup_type == "sftp" ]]; then
            upload_sftp_backup_volume "$volume_path"
        elif [[ $backup_type == "local" ]]; then
            upload_local_backup_volume "$volume_path"
        fi
        # Elimina el archivo de volumen del directorio origen.
        echo "Eliminando el volumen $volume_number del directorio origen..."
        rm "$volume_path"
    fi
    return 0
}

# Función para crear los volúmenes de backup necesarios.
function create_backup_volumes {
    echo "Creando archivo de backup multivolumen..."
    # Crea el archivo de backup inicial y lo divide en volúmenes.
    tar -cz "$backup_dir" | split -b "$max_volume_size" - "$tmp_dir/$backup_name.tar.gz."
    # Itera sobre los volúmenes de backup y los envía al servidor remoto.
    for (( volume_number=0; ; volume_number++ )); do
        volume_name=$(printf "%s.%02d" "$backup_name.tar.gz" "$volume_number")
        if [[ ! -f "$tmp_dir/$volume_name" ]]; then
            break
        fi
        if ! send_backup_volume "$volume_number"; then
            break
        fi
    done
}
create_backup_volumes