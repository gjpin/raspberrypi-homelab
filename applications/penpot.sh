#!/usr/bin/bash
export DEBIAN_FRONTEND=noninteractive

# References:
# https://help.penpot.app/technical-guide/getting-started/#install-with-docker
# https://help.penpot.app/technical-guide/configuration/

# Create directory
sudo mkdir -p /etc/selfhosted/penpot

# Create Docker network
sudo docker network create penpot

# Create Docker volumes
sudo docker volume create penpot-postgres
sudo docker volume create penpot-assets

################################################
##### Docker Compose
################################################

sudo tee /etc/selfhosted/penpot/docker-compose.yml << EOF
services:
  penpot-frontend:
    image: penpotapp/frontend:latest
    container_name: penpot-frontend
    volumes:
      - penpot-assets:/opt/data
    env_file:
      - config.env
    depends_on:
      - penpot-backend
      - penpot-exporter
    networks:
      - penpot
      - caddy

  penpot-backend:
    image: penpotapp/backend:latest
    container_name: penpot-backend
    volumes:
      - penpot-assets:/opt/data
    depends_on:
      - penpot-postgres
      - penpot-redis
    env_file:
      - config.env
    networks:
      - penpot

  penpot-exporter:
    image: penpotapp/exporter:latest
    container_name: penpot-exporter
    env_file:
      - config.env
    environment:
      - PENPOT_PUBLIC_URI=http://penpot-frontend
    networks:
      - penpot

  penpot-postgres:
    image: postgres:15-alpine
    container_name: penpot-postgres
    restart: always
    stop_signal: SIGINT
    env_file:
      - config.env
    volumes:
      - penpot-postgres:/var/lib/postgresql/data
    networks:
      - penpot
      
  penpot-redis:
    image: redis:alpine
    container_name: penpot-redis
    restart: always
    networks:
      - penpot

volumes:
  penpot-postgres:
    external: true
  penpot-assets:
    external: true

networks:
  penpot:
    external: true
  caddy:
    external: true
EOF

################################################
##### Environment variables
################################################

DATABASE_PASSWORD=$(openssl rand -hex 48)

sudo tee /etc/selfhosted/penpot/config.env << EOF
POSTGRES_INITDB_ARGS=--data-checksums
POSTGRES_DB=penpot
POSTGRES_USER=penpot
POSTGRES_PASSWORD=$DATABASE_PASSWORD
PENPOT_PUBLIC_URI=https://penpot.$BASE_DOMAIN
PENPOT_FLAGS=enable-registration enable-login disable-email-verification
PENPOT_HTTP_SERVER_HOST=0.0.0.0
PENPOT_DATABASE_URI=postgresql://penpot-postgres/penpot
PENPOT_DATABASE_USERNAME=penpot
PENPOT_DATABASE_PASSWORD=$DATABASE_PASSWORD
PENPOT_REDIS_URI=redis://penpot-redis/0
PENPOT_ASSETS_STORAGE_BACKEND=assets-fs
PENPOT_STORAGE_ASSETS_FS_DIRECTORY=/opt/data/assets
PENPOT_TELEMETRY_ENABLED=false
PENPOT_SMTP_DEFAULT_FROM=no-reply@example.com
PENPOT_SMTP_DEFAULT_REPLY_TO=no-reply@example.com
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

# Penpot
penpot.$BASE_DOMAIN {
        import default-header

        encode gzip

        reverse_proxy penpot-frontend:80 {
                header_up X-Real-IP {remote_host}
        }
}
EOF