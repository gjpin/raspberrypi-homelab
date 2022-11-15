#!/usr/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Create directory
sudo mkdir -p /etc/selfhosted/caddy

# Create Docker network
sudo docker network create caddy

# Create Docker volumes
sudo docker volume create caddy-data
sudo docker volume create caddy-config

################################################
##### Docker Compose
################################################

sudo tee /etc/selfhosted/caddy/docker-compose.yml << EOF
services:
  caddy:
    build:
      context: /etc/selfhosted/caddy
    container_name: caddy
    restart: always
    ports:
      - 443:443
    networks:
      - caddy
    volumes:
      - /etc/selfhosted/caddy/Caddyfile:/etc/caddy/Caddyfile
      - caddy-data:/data
      - caddy-config:/config

volumes:
  caddy-data:
    external: true
  caddy-config:
    external: true

networks:
  caddy:
    external: true
EOF

################################################
##### Dockerfile
################################################

sudo tee /etc/selfhosted/caddy/Dockerfile << EOF
FROM caddy:2-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
EOF

################################################
##### Kernel configurations
################################################

# References:
# https://github.com/lucas-clemente/quic-go/wiki/UDP-Receive-Buffer-Size

sudo sysctl net.core.rmem_max=2500000
sudo tee /etc/sysctl.d/99-udp-max-buffer-size.conf << EOF
net.core.rmem_max=2500000
EOF

################################################
##### Caddyfile
################################################

sudo tee /etc/selfhosted/caddy/Caddyfile << EOF
{
        acme_dns cloudflare $CLOUDFLARE_API_TOKEN
}

(default-header) {
        header {
                # Disable FLoC tracking
                Permissions-Policy "interest-cohort=()"

                # Enable HSTS
                Strict-Transport-Security "max-age=31536000;"

                # Disable clients from sniffing the media type
                X-Content-Type-Options "nosniff"

                # Clickjacking protection
                X-Frame-Options "SAMEORIGIN"

                # Enable cross-site filter (XSS) and tell browser to block detected attacks
                X-XSS-Protection "1; mode=block"

                # Prevent search engines from indexing
                X-Robots-Tag "none"

                # Remove X-Powered-By header
                -X-Powered-By

                # Remove Server header
                -Server
        }
}
EOF