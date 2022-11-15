#!/usr/bin/bash
export DEBIAN_FRONTEND=noninteractive

################################################
##### Update system and install base packages
################################################

# Update system
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

# Install base packages
sudo apt install -y \
  wireguard \
  zstd \
  tar

################################################
##### AppArmor
################################################

# Install AppArmor
sudo apt -y install \
  apparmor \
  apparmor-utils \
  apparmor-profiles \
  apparmor-profiles-extra

# Enable AppArmor
sudo sed -i 's/rootwait/rootwait lsm=apparmor/g' /boot/cmdline.txt

################################################
##### Docker
################################################

# References:
# https://docs.docker.com/engine/install/debian/#install-using-the-repository

# Install dependencies
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker’s official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Setup Docker's repository
sudo tee /etc/apt/sources.list.d/docker.list << EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable
EOF

# Install Docker engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

#############################
# REBOOT
#############################

sudo reboot

#############################
# Automatic updates
#############################

# Download and install system updates/docker images and then reboot once a week (Saturdays at 5am)
sudo tee /etc/systemd/system/automatic-updates.service << EOF
[Unit]
Description=Automatically update system

[Service]
Type=oneshot
ExecStart=/usr/bin/apt update
ExecStart=/usr/bin/apt upgrade -y
ExecStart=/usr/bin/apt autoremove -y

ExecStart=/usr/bin/docker compose -f /etc/selfhosted/nextcloud/docker-compose.yml pull
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/obsidian/docker-compose.yml pull
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/penpot/docker-compose.yml pull
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/pihole/docker-compose.yml pull
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/vaultwarden/docker-compose.yml pull
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/caddy/docker-compose.yml build --pull --no-cache

ExecStart=/usr/bin/docker compose -f /etc/selfhosted/nextcloud/docker-compose.yml down
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/obsidian/docker-compose.yml down
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/penpot/docker-compose.yml down
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/pihole/docker-compose.yml down
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/vaultwarden/docker-compose.yml down
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/caddy/docker-compose.yml down

ExecStart=/usr/bin/docker compose -f /etc/selfhosted/nextcloud/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/obsidian/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/penpot/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/pihole/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/vaultwarden/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/caddy/docker-compose.yml up -d

ExecStart=/usr/bin/docker image prune -f
ExecStart=/usr/sbin/reboot
EOF

sudo tee /etc/systemd/system/automatic-updates.timer << EOF
[Unit]
Description=Automatically update system
RefuseManualStart=no
RefuseManualStop=no

[Timer]
Unit=automatic-updates.service
OnCalendar=Sat *-*-* 05:00:00

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable automatic-updates.timer

#############################
# Automatic Docker volumes backup
#############################

# Backup script
sudo tee /usr/local/bin/automatic-backups.sh << 'EOF'
#!/usr/bin/bash

VOLUME_NAME_ARRAY=("vaultwarden" "nextcloud-postgres" "obsidian" "penpot-postgres" "penpot-assets")

USER_ID=$(stat -c '%u' /var/lib/docker/volumes/nextcloud-data/_data)

for VOLUME_NAME in ${VOLUME_NAME_ARRAY[@]}; do
  tar -I zstd --exclude="/var/lib/docker/volumes/nextcloud-data/_data/admin/files/backups" -cf /var/lib/docker/volumes/nextcloud-data/_data/admin/files/backups/$VOLUME_NAME-$(date +'%d-%m-%Y').tar.zstd -C /var/lib/docker/volumes/$VOLUME_NAME ./
  chown -R $USER_ID:$USER_ID /var/lib/docker/volumes/nextcloud-data/_data/admin/files/backups
done
EOF

sudo chmod +x /usr/local/bin/automatic-backups.sh

# Shutdown containers, backup their volumes and restart them every day
sudo tee /etc/systemd/system/automatic-backups.service << EOF
[Unit]
Description=Automatically backup docker containers

[Service]
Type=oneshot

ExecStart=/usr/bin/docker compose -f /etc/selfhosted/vaultwarden/docker-compose.yml down
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/nextcloud/docker-compose.yml down
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/obsidian/docker-compose.yml down
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/penpot/docker-compose.yml down

ExecStart=/usr/local/bin/automatic-backups.sh

ExecStart=/usr/bin/docker compose -f /etc/selfhosted/vaultwarden/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/nextcloud/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/obsidian/docker-compose.yml up -d
ExecStart=/usr/bin/docker compose -f /etc/selfhosted/penpot/docker-compose.yml up -d

ExecStart=/usr/bin/docker exec --user www-data nextcloud php occ files:scan --all
EOF

sudo tee /etc/systemd/system/automatic-backups.timer << EOF
[Unit]
Description=Automatically backup docker containers
RefuseManualStart=no
RefuseManualStop=no

[Timer]
Unit=automatic-backups.service
OnCalendar=*-*-* 04:00:00

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable automatic-backups.timer

################################################
##### Setup containers
################################################

sudo ./applications/caddy.sh
sudo ./applications/pihole.sh
sudo ./applications/vaultwarden.sh
sudo ./applications/nextcloud.sh
sudo ./applications/obsidian.sh
sudo ./applications/penpot.sh

################################################
##### Steam Link
################################################

# References:
# https://www.raspberrypi.org/documentation/configuration/hdmi-config.md
# https://www.raspberrypi.org/documentation/configuration/config-txt/memory.md
# https://www.raspberrypi.org/documentation/configuration/config-txt/video.md

# Reserve 256MB of memory for GPU
echo 'gpu_mem=256' | sudo tee -a /boot/config.txt

# Enable 4K 60 FPS
echo 'hdmi_enable_4kp60=1' | sudo tee -a /boot/config.txt

# Install Steam Link
sudo apt install -y steamlink

# Autostart Steam Link at boot
sudo tee /etc/systemd/system/steamlink.service << EOF
[Unit]
Description=Start Steam Link at boot

[Service]
Type=simple
User=pi
ExecStart=/usr/bin/steamlink
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable steamlink.service

################################################
##### Cleanup
################################################

# Protect /etc/selfhosted
sudo chown -R root:root /etc/selfhosted
sudo chmod 700 /etc/selfhosted