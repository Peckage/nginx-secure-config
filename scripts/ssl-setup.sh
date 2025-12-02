#!/bin/bash

#############################################
# SSL Certificate Setup Script
# Automates SSL certificate installation
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NGINX_CONF_DIR="/etc/nginx"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Please run: sudo $0"
   exit 1
fi

usage() {
    echo -e "${BLUE}SSL Certificate Setup Script${NC}\n"
    echo "Usage: $0 <command> <domain> [options]"
    echo ""
    echo "Commands:"
    echo "  certbot <domain> [email]   Install Let's Encrypt SSL with Certbot"
    echo "  self-signed <domain>       Generate self-signed certificate (development only)"
    echo "  custom <domain>            Instructions for installing custom certificate"
    echo ""
    echo "Examples:"
    echo "  $0 certbot example.com admin@example.com"
    echo "  $0 self-signed dev.local"
    echo ""
    exit 1
}

# Install certbot if not present
install_certbot() {
    if command -v certbot &> /dev/null; then
        echo -e "${GREEN}Certbot is already installed${NC}"
        return 0
    fi

    echo -e "${BLUE}Installing Certbot...${NC}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    fi

    case "$OS" in
        ubuntu|debian)
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y certbot python3-certbot-nginx
            ;;
        *)
            echo -e "${RED}Please install certbot manually for your OS${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}Certbot installed${NC}"
}

# Setup Let's Encrypt certificate
setup_letsencrypt() {
    local domain=$1
    local email=$2

    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain is required${NC}"
        usage
    fi

    install_certbot

    echo -e "${BLUE}Setting up Let's Encrypt SSL for: $domain${NC}"

    if [ -z "$email" ]; then
        certbot --nginx -d "$domain"
    else
        certbot --nginx -d "$domain" --email "$email" --agree-tos --no-eff-email
    fi

    echo -e "${GREEN}SSL certificate installed successfully${NC}"
    echo -e "${YELLOW}Certificate will auto-renew. Test renewal with:${NC}"
    echo "  certbot renew --dry-run"
}

# Generate self-signed certificate
setup_selfsigned() {
    local domain=$1

    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain is required${NC}"
        usage
    fi

    echo -e "${BLUE}Generating self-signed certificate for: $domain${NC}"
    echo -e "${YELLOW}WARNING: Self-signed certificates should only be used for development${NC}\n"

    local ssl_dir="$NGINX_CONF_DIR/ssl/$domain"
    mkdir -p "$ssl_dir"

    # Generate private key and certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$ssl_dir/privkey.pem" \
        -out "$ssl_dir/fullchain.pem" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$domain"

    chmod 600 "$ssl_dir/privkey.pem"
    chmod 644 "$ssl_dir/fullchain.pem"

    echo -e "${GREEN}Self-signed certificate generated${NC}"
    echo -e "${YELLOW}Certificate location:${NC}"
    echo "  Key: $ssl_dir/privkey.pem"
    echo "  Cert: $ssl_dir/fullchain.pem"
    echo ""
    echo -e "${YELLOW}Update your nginx config to use these paths${NC}"
}

# Instructions for custom certificate
setup_custom() {
    local domain=$1

    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain is required${NC}"
        usage
    fi

    local ssl_dir="$NGINX_CONF_DIR/ssl/$domain"
    mkdir -p "$ssl_dir"

    echo -e "${BLUE}Custom SSL Certificate Setup for: $domain${NC}\n"
    echo "1. Obtain your SSL certificate files from your certificate authority"
    echo ""
    echo "2. Copy your certificate files to:"
    echo "   Private key:     $ssl_dir/privkey.pem"
    echo "   Certificate:     $ssl_dir/fullchain.pem"
    echo "   CA Bundle:       $ssl_dir/chain.pem (optional)"
    echo ""
    echo "3. Set proper permissions:"
    echo "   chmod 600 $ssl_dir/privkey.pem"
    echo "   chmod 644 $ssl_dir/fullchain.pem"
    echo ""
    echo "4. Update your nginx site configuration:"
    echo "   ssl_certificate $ssl_dir/fullchain.pem;"
    echo "   ssl_certificate_key $ssl_dir/privkey.pem;"
    echo ""
    echo "5. Test and reload nginx:"
    echo "   nginx -t && systemctl reload nginx"
}

# Main
main() {
    local command=$1
    shift

    case "$command" in
        certbot|letsencrypt)
            setup_letsencrypt "$@"
            ;;
        self-signed|selfsigned)
            setup_selfsigned "$@"
            ;;
        custom)
            setup_custom "$@"
            ;;
        *)
            usage
            ;;
    esac
}

if [ $# -eq 0 ]; then
    usage
fi

main "$@"
