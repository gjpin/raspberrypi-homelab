#!/usr/bin/bash
export DEBIAN_FRONTEND=noninteractive

# References:
# https://hub.docker.com/_/ghost
# https://ghost.org/docs/config/#configuration-options
# https://hub.docker.com/_/mysql

################################################
##### Preparation
################################################

# Create directory
sudo mkdir -p /etc/selfhosted/ghost

# Create Docker network
sudo docker network create ghost

# Create Docker volumes
sudo docker volume create ghost-mysql

################################################
##### Docker Compose
################################################

sudo tee /etc/selfhosted/ghost/docker-compose.yml << EOF
services:
  ghost:
    image: ghost:5-alpine
    container_name: ghost
    restart: always
    networks:
      - ghost
      - caddy
    env_file:
      - config.env

  ghost-mysql:
    image: mysql:8-debian
    container_name: ghost-mysql
    restart: always
    networks:
      - ghost
    volumes:
      - ghost-mysql:/var/lib/mysql
    env_file:
      - config.env

volumes:
  ghost-mysql:
    external: true

networks:
  ghost:
    external: true
  caddy:
    external: true
EOF

################################################
##### Environment variables
################################################

DATABASE_PASSWORD=$(openssl rand -hex 48)

sudo tee /etc/selfhosted/ghost/config.env << EOF
url=https://${BASE_DOMAIN}:443
MYSQL_DATABASE=ghost
MYSQL_ROOT_PASSWORD=$DATABASE_PASSWORD
database__client=mysql
database__connection__host=ghost-mysql
database__connection__user=root
database__connection__database=ghost
database__connection__password=$DATABASE_PASSWORD
NODE_ENV=production
EOF

################################################
##### Caddyfile
################################################

sudo tee -a /etc/selfhosted/caddy/Caddyfile << EOF

${BASE_DOMAIN} {
        import default-header

        reverse_proxy ghost:2368 {
                header_up X-Real-IP {remote_host}
        }
}
EOF