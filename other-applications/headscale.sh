#!/usr/bin/bash
export DEBIAN_FRONTEND=noninteractive

# References:
# https://github.com/juanfont/headscale/blob/main/docs/running-headscale-container.md
# https://github.com/juanfont/headscale/blob/main/config-example.yaml

################################################
##### Preparation
################################################

# Create directory
sudo mkdir -p /etc/selfhosted/headscale

# Create Docker network
sudo docker network create headscale

# Create Docker volumes
sudo docker volume create headscale

################################################
##### Docker Compose
################################################

sudo tee /etc/selfhosted/headscale/docker-compose.yml << EOF
services:
  headscale:
    image: headscale/headscale:0.16.4
    container_name: headscale
    restart: always
    networks:
      - headscale
      - caddy
    volumes:
      - /etc/selfhosted/headscale/:/etc/headscale/
      - headscale:/var/lib/headscale
    command: headscale serve

volumes:
  headscale:
    external: true

networks:
  headscale:
    external: true
  caddy:
    external: true
EOF

################################################
##### Headscale configuration
################################################

# DNS points to Pi-Hole
# DERP / STUN is enabled without Tailscale's list
# TLS is disabled since caddy will supply it

# Import Headscale's configuration file
sudo tee /etc/selfhosted/headscale/config.yaml << EOF
---
server_url: https://network.$BASE_DOMAIN
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 0.0.0.0:50443
grpc_allow_insecure: false
private_key_path: /var/lib/headscale/private.key
ip_prefixes:
  - fd7a:115c:a1e0::/48
  - 100.64.0.0/10
derp:
  server:
    enabled: true
    region_id: 999
    region_code: "headscale"
    region_name: "Headscale Embedded DERP"
    stun_listen_addr: "0.0.0.0:3478"
  urls: []
  paths: []
  auto_update_enabled: false
  update_frequency: 24h
disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m
node_update_check_interval: 10s
db_type: sqlite3
db_path: /var/lib/headscale/db.sqlite
acme_url: https://acme-v02.api.letsencrypt.org/directory
acme_email: ""
tls_letsencrypt_hostname: ""
tls_client_auth_mode: relaxed
tls_letsencrypt_cache_dir: /var/lib/headscale/cache
tls_letsencrypt_challenge_type: HTTP-01
tls_letsencrypt_listen: ":http"
tls_cert_path: ""
tls_key_path: ""
log_level: info
acl_policy_path: ""
dns_config:
  nameservers:
    - 172.31.0.100
  domains: []
  magic_dns: true
  base_domain: $BASE_DOMAIN
unix_socket: /var/run/headscale.sock
unix_socket_permission: "0770"
logtail:
  enabled: false
randomize_client_port: false
EOF

################################################
##### DERP configuration
################################################

# To be confirmed if required. If so, also add to headscale config:
# derp -> paths -> - /etc/headscale/derp.yaml
# https://tailscale.com/kb/1118/custom-derp-servers/
# https://github.com/juanfont/headscale/blob/main/derp-example.yaml
sudo tee /etc/selfhosted/headscale/derp.yaml << EOF
regions:
  999:
    regionid: 999
    regioncode: headscale
    regionname: Headscale Embedded DERP
    nodes:
      - name: headscale
        regionid: 999
        hostname: network-derp.$BASE_DOMAIN
EOF

################################################
##### Caddyfile
################################################

sudo tee -a /etc/selfhosted/caddy/Caddyfile << EOF

# Headscale
network.$BASE_DOMAIN {
        import default-header

        reverse_proxy headscale:8080 {
                header_up X-Real-IP {remote_host}
        }

        @forbidden {
                path /windows
                path /apple
        }

        respond @forbidden 403
}

# DERP / STUN
# To be confirmed if required
network-derp.$BASE_DOMAIN {
        import default-header

        reverse_proxy headscale:3478 {
                header_up X-Real-IP {remote_host}
        }
}
EOF

################################################
##### Post installation
################################################

# # Create headspace namespace
# sudo docker exec headscale headscale namespaces create private

# # Create pre-authenticated key
# sudo docker exec headscale headscale --namespace private preauthkeys create --reusable --expiration 1h

# # Connect Tailscale to headscale (Windows)

# REG ADD "HKLM\Software\Tailscale IPN" /v UnattendedMode /t REG_SZ /d always
# REG ADD "HKLM\Software\Tailscale IPN" /v LoginURL /t REG_SZ /d "https://network.$BASE_DOMAIN"

# # Connect Tailscale to headscale (Linux)
# sudo tailscale up --login-server https://network.$BASE_DOMAIN --authkey $PRE_AUTH_KEY

# # Override local DNS
# # https://github.com/juanfont/headscale/issues/280
# # -x : ensures that DNS traffic is preferably routed to the DNS servers on this interface, unless there are other, more specific domains configured on other interfaces
# sudo resolvectl -a wg0 -x