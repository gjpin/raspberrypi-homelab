# Requirements
## Cloudflare:

 - DNS managed by Cloudflare
 - [Cloudflare API token](https://dash.cloudflare.com/profile/api-tokens) with `Zone-Zone-Read` and `Zone-DNS-Edit` permissions

## Environment variables
```
export BASE_DOMAIN="example.com"
export CLOUDFLARE_API_TOKEN=""
```

# Setup
## From backups
1. Set environment variables
2. Create/Update cloudflare records for vault/cloud/pihole/obsidian/penpot pointing to wireguard IP
3. Manually go through setup.sh
4. Replace credentials with existing ones:
  - /etc/selfhosted/nextcloud/config.env
    - NEXTCLOUD_ADMIN_PASSWORD
    - POSTGRES_PASSWORD
    - REDIS_HOST_PASSWORD
  - /etc/selfhosted/obsidian/config.env
    - COUCHDB_PASSWORD
  - /etc/selfhosted/penpot/config.env
    - POSTGRES_PASSWORD
    - PENPOT_DATABASE_PASSWORD
  - /etc/selfhosted/pihole/config.env
    - ADMIN_TOKEN
    - WEBPASSWORD
  - /etc/selfhosted/vaultwarden/config.env
    - ADMIN_TOKEN
5. Restore Docker volumes (see below "Restore all Docker volumes + WireGuard configs")
6. Restore WireGuard backup (see below "Restore all Docker volumes + WireGuard configs")
7. Enable Wireguard: `sudo systemctl enable --now wg-quick@wg0`
8. Start containers:
```
sudo docker compose -f /etc/selfhosted/caddy/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/pihole/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/vaultwarden/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/nextcloud/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/obsidian/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/penpot/docker-compose.yml up -d
```

## From scratch
1. Set environment variables
2. Create/Update cloudflare records for vault/cloud/pihole/obsidian/penpot pointing to wireguard IP
3. Manually go through setup.sh
4. Get generated credentials:
  - /etc/selfhosted/nextcloud/config.env
    - NEXTCLOUD_ADMIN_PASSWORD
    - POSTGRES_PASSWORD
    - REDIS_HOST_PASSWORD
  - /etc/selfhosted/obsidian/config.env
    - COUCHDB_PASSWORD
  - /etc/selfhosted/penpot/config.env
    - POSTGRES_PASSWORD
    - PENPOT_DATABASE_PASSWORD
  - /etc/selfhosted/pihole/config.env
    - ADMIN_TOKEN
    - WEBPASSWORD
  - /etc/selfhosted/vaultwarden/config.env
    - ADMIN_TOKEN
5. Configure and enable WireGuard
6. Start containers:
```
sudo docker compose -f /etc/selfhosted/caddy/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/pihole/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/vaultwarden/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/nextcloud/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/obsidian/docker-compose.yml up -d
sudo docker compose -f /etc/selfhosted/penpot/docker-compose.yml up -d
```
7. Create penpot user: `sudo docker exec -ti penpot-backend ./manage.sh create-profile -u "Your Email" -p "Your Password" -n "Your Full Name"`
8. Fix postgres 15 permissions on nextcloud:
```bash
sudo docker compose -f /etc/selfhosted/docker-compose.yml exec -T nextcloud-postgres psql -U nextcloud -d nextcloud <<-EOSQL
    GRANT CREATE ON SCHEMA public TO public;
EOSQL
```
9. Add server local IP to router as DNS server
10. Create folder 'backups' manually in Nextcloud for docker volumes backups (do not forget to keep this folder automatically synced with several clients)
11. Access services:
  - Vaultwarden: ```vault.$BASE_DOMAIN```
  - Nextcloud: ```cloud.$BASE_DOMAIN```
  - Pi-hole: ```pihole.$BASE_DOMAIN```
  - Obsidian: ```obsidian.$BASE_DOMAIN```
  - Penpot: ```penpot.$BASE_DOMAIN```
12. Install Nextcloud apps: 
  - Bookmarks (required by floccus)
  - Contacts
  - Nextcloud Office
  - Deck
13. Disable apps in Nextcloud (cloud.$BASE_DOMAIN/settings/apps):
  - Accessibility
  - Activity
  - Circles
  - Collaborative Tags
  - Comments
  - Contacts Interaction
  - Dashboard
  - Federation
  - First run wizard
  - Recommendations
  - Share by mail
  - Support
  - Usage survey
  - User status
  - Weather status
14. Add lists to Pi-hole (https://firebog.net):
  - Regex (add to https://pihole.$BASE_DOMAIN/admin/groups-domains.php):
    - https://github.com/mmotti/pihole-regex/blob/master/regex.list
  - Privacy:
    - https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt
    - https://v.firebog.net/hosts/Easyprivacy.txt
    - https://v.firebog.net/hosts/Prigent-Ads.txt
    - https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
    - https://raw.githubusercontent.com/safing/intel-data/master/lists/analytics.txt
    - https://raw.githubusercontent.com/safing/intel-data/master/lists/telemetry.txt
    - https://raw.githubusercontent.com/safing/intel-data/master/lists/tracking-other.txt
  - Advertisement:
    - https://v.firebog.net/hosts/AdguardDNS.txt
    - https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
    - https://v.firebog.net/hosts/Easylist.txt
    - https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext
    - https://raw.githubusercontent.com/AdAway/adaway.github.io/master/hosts.txt
    - https://raw.githubusercontent.com/safing/intel-data/master/lists/ads.txt
  - Security:
    - https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt
    - https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt
    - https://malware-filter.gitlab.io/malware-filter/phishing-filter-hosts.txt
    - https://urlhaus.abuse.ch/downloads/hostfile/
    - https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt
    - https://v.firebog.net/hosts/RPiList-Malware.txt
    - https://v.firebog.net/hosts/RPiList-Phishing.txt
    - https://someonewhocares.org/hosts/zero/hosts
    - https://raw.githubusercontent.com/safing/intel-data/master/lists/fraud.txt
    - https://raw.githubusercontent.com/safing/intel-data/master/lists/malware.txt
    - https://raw.githubusercontent.com/safing/intel-data/master/lists/phishing.txt
    - https://raw.githubusercontent.com/stamparm/ipsum/master/levels/3.txt
    - https://raw.githubusercontent.com/r-a-y/mobile-hosts/master/AdguardDNS.txt
  - List of lists:
    - https://dbl.oisd.nl/


# How Tos
## Reload Caddy configuration
```sudo docker exec caddy caddy reload --config /etc/caddy/Caddyfile --force```

## Restore Docker volumes from backups
```bash
sudo docker compose -f /etc/selfhosted/docker-compose.yml stop vaultwarden

sudo docker compose -f /etc/selfhosted/docker-compose.yml rm -f vaultwarden

sudo docker volume rm vaultwarden

sudo docker volume create vaultwarden

sudo tar -I zstd -xf /var/lib/docker/volumes/nextcloud-data/_data/admin/files/backups/vaultwarden-15-10-2022.tar.zstd -C /var/lib/docker/volumes/vaultwarden

sudo docker compose -f /etc/selfhosted/docker-compose.yml create vaultwarden

sudo docker compose -f /etc/selfhosted/docker-compose.yml start vaultwarden
```

## Update Nextcloud's postgres
```bash
# Backup database
sudo docker compose -f /etc/selfhosted/docker-compose.yml exec -T nextcloud-postgres pg_dumpall -U nextcloud > nextcloud-postgres-$(date +'%d-%m-%Y').sql

# Stop nextcloud containers
sudo docker compose -f /etc/selfhosted/docker-compose.yml stop nextcloud
sudo docker compose -f /etc/selfhosted/docker-compose.yml stop nextcloud-cron
sudo docker compose -f /etc/selfhosted/docker-compose.yml stop nextcloud-postgres
sudo docker compose -f /etc/selfhosted/docker-compose.yml stop nextcloud-redis

# Remove postgres container
sudo docker compose -f /etc/selfhosted/docker-compose.yml rm --force nextcloud-postgres

# Delete database volume and re-create it
sudo docker volume rm nextcloud-postgres
sudo docker volume create nextcloud-postgres

# Update docker-compose with new postgres version
sudo nano /etc/selfhosted/docker-compose.yml

# Bring database container back up
sudo docker compose -f /etc/selfhosted/docker-compose.yml create nextcloud-postgres
sudo docker compose -f /etc/selfhosted/docker-compose.yml start nextcloud-postgres

# Restore database backup
sudo docker compose -f /etc/selfhosted/docker-compose.yml exec -T nextcloud-postgres psql -U nextcloud -d nextcloud < nextcloud-postgres-$(date +'%d-%m-%Y').sql

# Start remaining nextcloud containers
sudo docker compose -f /etc/selfhosted/docker-compose.yml start nextcloud
sudo docker compose -f /etc/selfhosted/docker-compose.yml start nextcloud-cron
sudo docker compose -f /etc/selfhosted/docker-compose.yml start nextcloud-redis

# Fix postgres 15 permissions
sudo docker compose -f /etc/selfhosted/docker-compose.yml exec -T nextcloud-postgres psql -U nextcloud -d nextcloud <<-EOSQL
    GRANT CREATE ON SCHEMA public TO public;
EOSQL
```

## Backup all Docker volumes + WireGuard configs
```bash
################################################
##### On server
################################################

# Create backups directory
mkdir -p ${HOME}/backups

# Backup Docker volumes
VOLUME_NAME_ARRAY=("caddy-data" "caddy-config" "vaultwarden" "nextcloud" "nextcloud-config" "nextcloud-data" "nextcloud-postgres" "obsidian" "pihole" "penpot-assets" "penpot-postgres")
for VOLUME_NAME in ${VOLUME_NAME_ARRAY[@]}; do
  sudo tar -I zstd --exclude="/var/lib/docker/volumes/nextcloud-data/_data/admin/files/backups" -cf ${HOME}/backups/$VOLUME_NAME-$(date +'%d-%m-%Y').tar.zstd -C /var/lib/docker/volumes/$VOLUME_NAME ./
done

# Backup WireGuard directory
sudo tar -I zstd -cf ${HOME}/backups/wireguard.tar.zstd -C /etc/wireguard ./

################################################
##### On localhost
################################################

# Create backups directory
mkdir -p ${HOME}/backups

# Download backups to localhost
scp pi@192.168.1.253:/home/pi/backups/* ${HOME}/backups
```

## Restore all Docker volumes + WireGuard configs
```bash
################################################
##### On server
################################################

mkdir -p ${HOME}/backups

################################################
##### On localhost
################################################

scp ${HOME}/backups/* pi@192.168.1.253:/home/pi/backups

################################################
##### On remote
################################################

sudo tar -I zstd -xf ${HOME}/backups/wireguard.tar.zstd -C /etc/wireguard

sudo tar -I zstd -xf ${HOME}/backups/caddy-data-15-11-2022.tar.zstd -C /var/lib/docker/volumes/caddy-data
sudo tar -I zstd -xf ${HOME}/backups/caddy-config-15-11-2022.tar.zstd -C /var/lib/docker/volumes/caddy-config

sudo tar -I zstd -xf ${HOME}/backups/vaultwarden-15-11-2022.tar.zstd -C /var/lib/docker/volumes/vaultwarden

sudo tar -I zstd -xf ${HOME}/backups/nextcloud-15-11-2022.tar.zstd -C /var/lib/docker/volumes/nextcloud
sudo tar -I zstd -xf ${HOME}/backups/nextcloud-config-15-11-2022.tar.zstd -C /var/lib/docker/volumes/nextcloud-config
sudo tar -I zstd -xf ${HOME}/backups/nextcloud-data-15-11-2022.tar.zstd -C /var/lib/docker/volumes/nextcloud-data
sudo tar -I zstd -xf ${HOME}/backups/nextcloud-postgres-15-11-2022.tar.zstd -C /var/lib/docker/volumes/nextcloud-postgres

sudo tar -I zstd -xf ${HOME}/backups/obsidian-15-11-2022.tar.zstd -C /var/lib/docker/volumes/obsidian

sudo tar -I zstd -xf ${HOME}/backups/pihole-15-11-2022.tar.zstd -C /var/lib/docker/volumes/pihole

sudo tar -I zstd -xf ${HOME}/backups/penpot-assets-15-11-2022.tar.zstd -C /var/lib/docker/volumes/penpot-assets
sudo tar -I zstd -xf ${HOME}/backups/penpot-postgres-15-11-2022.tar.zstd -C /var/lib/docker/volumes/penpot-postgres
```