#!/usr/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Create directory
sudo mkdir -p /etc/selfhosted/nextcloud

# Create Docker network
sudo docker network create nextcloud

# Create Docker volumes
sudo docker volume create nextcloud
sudo docker volume create nextcloud-data
sudo docker volume create nextcloud-config
sudo docker volume create nextcloud-postgres

# Mount Nextcloud's in Caddy's container
sudo sed -i '/    volumes:/a \      - nextcloud:/var/www/html' /etc/selfhosted/caddy/docker-compose.yml
sudo sed -i '/^volumes:/a \  nextcloud:' /etc/selfhosted/caddy/docker-compose.yml
sudo sed -i '/  nextcloud:/a \    external: true' /etc/selfhosted/caddy/docker-compose.yml

################################################
##### Docker Compose
################################################

sudo tee /etc/selfhosted/nextcloud/docker-compose.yml << EOF
services:
  nextcloud:
    image: nextcloud:stable-fpm-alpine
    container_name: nextcloud
    restart: always
    networks:
      - nextcloud
      - caddy
    volumes:
      - nextcloud:/var/www/html
      - nextcloud-data:/var/www/html/data
      - nextcloud-config:/var/www/html/config
    env_file:
      - config.env
    depends_on:
      - nextcloud-postgres
      - nextcloud-redis

  nextcloud-cron:
    image: nextcloud:stable-fpm-alpine
    container_name: nextcloud-cron
    restart: always
    networks:
      - nextcloud
    volumes:
      - nextcloud:/var/www/html
      - nextcloud-data:/var/www/html/data
      - nextcloud-config:/var/www/html/config
    entrypoint: /cron.sh
    depends_on:
      - nextcloud-postgres
      - nextcloud-redis

  nextcloud-postgres:
    image: postgres:15-alpine
    container_name: nextcloud-postgres
    restart: always
    networks:
      - nextcloud
    volumes:
      - nextcloud-postgres:/var/lib/postgresql/data
    env_file:
      - config.env

  nextcloud-redis:
    image: redis:alpine
    container_name: nextcloud-redis
    restart: always
    networks:
      - nextcloud
    command: redis-server /etc/redis/redis.conf
    volumes:
      - /etc/selfhosted/nextcloud/redis.conf:/etc/redis/redis.conf

volumes:
  nextcloud:
    external: true
  nextcloud-data:
    external: true
  nextcloud-config:
    external: true
  nextcloud-postgres:
    external: true

networks:
  nextcloud:
    external: true
  caddy:
    external: true
EOF

################################################
##### Environment variables
################################################

sudo tee /etc/selfhosted/nextcloud/config.env << EOF
POSTGRES_HOST=nextcloud-postgres
POSTGRES_DB=nextcloud
POSTGRES_USER=nextcloud
REDIS_HOST=nextcloud-redis
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=$(openssl rand -hex 48)
POSTGRES_PASSWORD=$(openssl rand -hex 48)
REDIS_HOST_PASSWORD=$(openssl rand -hex 48)
NEXTCLOUD_TRUSTED_DOMAINS=cloud.$BASE_DOMAIN
EOF

################################################
##### Redis configuration
################################################

# References:
# https://raw.githubusercontent.com/redis/redis/7.0/redis.conf

sudo tee /etc/selfhosted/nextcloud/redis.conf << EOF
requirepass $(sudo sed -n -e 's/^.*\(REDIS_HOST_PASSWORD=\)//p' /etc/selfhosted/nextcloud/config.env)
EOF

################################################
##### Kernel configurations
################################################

# References:
# https://github.com/lucas-clemente/quic-go/wiki/UDP-Receive-Buffer-Size

sudo sysctl vm.overcommit_memory=1
sudo tee /etc/sysctl.d/99-overcommit-memory.conf << EOF
vm.overcommit_memory=1
EOF

################################################
##### Caddyfile
################################################

sudo tee -a /etc/selfhosted/caddy/Caddyfile << EOF

# Nextcloud
cloud.$BASE_DOMAIN {
        import default-header

        encode gzip

        # https://caddyserver.com/docs/caddyfile/directives/php_fastcgi
        root * /var/www/html
        php_fastcgi nextcloud:9000 {
                env front_controller_active true
        }
        file_server

        # https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/reverse_proxy_configuration.html#caddy
        redir /.well-known/carddav /remote.php/dav
        redir /.well-known/caldav /remote.php/dav

        # https://github.com/nextcloud/docker/blob/master/.examples/docker-compose/with-nginx-proxy/postgres/fpm/web/nginx.conf#L122
        # https://github.com/blazekjan/docker-selfhosted-apps/blob/main/nextcloud/compose.yaml
        @forbidden {
                path /build/*
                path /tests/*
                path /config/*
                path /lib/*
                path /3rdparty/*
                path /templates/*
                path /data/*
                path /autotest
                path /occ
                path /issue
                path /indie
                path /db_
                path /console
                path /.htaccess
                path /.xml
                path /README
                path /db_structure
                path /console.php
        }

        respond @forbidden 403
}
EOF