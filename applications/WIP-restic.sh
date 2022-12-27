#!/usr/bin/bash
export DEBIAN_FRONTEND=noninteractive

# References:
# https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html#local
# https://restic.readthedocs.io/en/stable/040_backup.html

# Format drive
sudo fdisk -l

# Delete old partition layout and re-read partition table
sudo wipefs -af /dev/sdb1
sudo sgdisk --zap-all --clear /dev/sdb1
sudo partprobe /dev/sdb1

# Partition disk and re-read partition table
sudo sgdisk -n 0:0:0 -t 0:8300 -c 0:backups /dev/sdb1
sudo partprobe /dev/sdb1

# Format partition to EXT4
sudo mkfs.ext4 -L backups /dev/sdb1

# Mount partition and setup automount
sudo mkdir -p /mnt/backups
sudo mount -t ext4 /dev/sdb1 /mnt/backups
sudo chown -R ${USER}:${USER} /mnt/backups
sudo tee -a /etc/fstab << EOF
PARTUUID=$(blkid -s UUID -o value /dev/sdb1) /mnt/backups ext4 defaults,noatime 0 2
EOF

# Create directory
sudo mkdir -p /etc/selfhosted/restic

################################################
##### Docker Compose
################################################

sudo tee /etc/selfhosted/restic/docker-compose.yml << EOF
services:
  restic:
    image: restic/restic:latest
    container_name: restic
    restart: always
    volumes:
      - caddy-data:/srv/caddy-data
      - caddy-config:/srv/caddy-config
      - caddy-webdav:/srv/caddy-webdav
      - immich:/srv/immich
      - immich-postgres:/srv/immich-postgres
      - obsidian:/srv/obsidian
      - pihole:/srv/pihole
      - radicale:/srv/radicale
      - vaultwarden:/srv/vaultwarden
    env_file:
      - config.env

volumes:
  caddy-data:
    external: true
  caddy-config:
    external: true
  caddy-webdav:
    external: true
  immich:
    external: true
  immich-postgres:
    external: true
  obsidian:
    external: true
  pihole:
    external: true
  radicale:
    external: true
  vaultwarden:
    external: true
EOF

################################################
##### Environment variables
################################################

sudo tee /etc/selfhosted/restic/config.env << EOF
RESTIC_PASSWORD=$(openssl rand -hex 48)
RESTIC_COMPRESSION=auto
RESTIC_REPOSITORY=/mnt/backups
EOF