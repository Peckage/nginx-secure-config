#!/bin/bash
# =============================================================================
# Kwik.zip Nginx Deploy Script
# Addon-style: drops config files without modifying nginx.conf
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_CONF_D="/etc/nginx/conf.d"
SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Deploying Kwik.zip Nginx Configuration (Addon Mode)${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root: sudo ./deploy.sh${NC}"
    exit 1
fi

# Check nginx is installed
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}❌ Nginx is not installed${NC}"
    exit 1
fi

# Create backup
BACKUP_DIR="/etc/nginx/backup-kwikzip-$(date +%Y%m%d-%H%M%S)"
echo -e "${YELLOW}📦 Creating backup at $BACKUP_DIR${NC}"
mkdir -p "$BACKUP_DIR"
[ -d "$NGINX_CONF_D" ] && cp -r "$NGINX_CONF_D" "$BACKUP_DIR/" 2>/dev/null || true
[ -d "$SITES_AVAILABLE" ] && cp -r "$SITES_AVAILABLE" "$BACKUP_DIR/" 2>/dev/null || true

# Create directories if needed
mkdir -p "$NGINX_CONF_D" "$SITES_AVAILABLE" "$SITES_ENABLED"
mkdir -p /var/log/nginx /var/www/kwik.zip

# Deploy conf.d files
echo -e "${GREEN}📝 Deploying conf.d files...${NC}"
cp "$SCRIPT_DIR/conf.d/kwikzip-ratelimit.conf" "$NGINX_CONF_D/"
cp "$SCRIPT_DIR/conf.d/kwikzip-performance.conf" "$NGINX_CONF_D/"
cp "$SCRIPT_DIR/conf.d/kwikzip-upstream.conf" "$NGINX_CONF_D/"

# Deploy site config
echo -e "${GREEN}📝 Deploying site config...${NC}"
cp "$SCRIPT_DIR/sites-available/kwik.zip" "$SITES_AVAILABLE/"

# Enable site
echo -e "${GREEN}🔗 Enabling kwik.zip site...${NC}"
ln -sf "$SITES_AVAILABLE/kwik.zip" "$SITES_ENABLED/kwik.zip"

# Test config
echo -e "${YELLOW}🔍 Testing nginx configuration...${NC}"
if nginx -t 2>&1; then
    echo -e "${GREEN}✅ Configuration test passed!${NC}"
else
    echo -e "${RED}❌ Configuration test failed! Restoring backup...${NC}"
    rm -f "$NGINX_CONF_D/kwikzip-"*.conf
    rm -f "$SITES_AVAILABLE/kwik.zip" "$SITES_ENABLED/kwik.zip"
    exit 1
fi

# Reload nginx
echo -e "${GREEN}🔄 Reloading nginx...${NC}"
systemctl reload nginx || systemctl restart nginx

echo ""
echo -e "${GREEN}✅ Kwik.zip deployed successfully!${NC}"
echo ""
echo "Files installed:"
echo "  - $NGINX_CONF_D/kwikzip-ratelimit.conf"
echo "  - $NGINX_CONF_D/kwikzip-performance.conf"
echo "  - $NGINX_CONF_D/kwikzip-upstream.conf"
echo "  - $SITES_AVAILABLE/kwik.zip"
echo "  - $SITES_ENABLED/kwik.zip -> (symlink)"
echo ""
echo -e "${YELLOW}🔐 SSL Setup:${NC}"
echo "  If you don't have SSL certs yet, run:"
echo "  sudo certbot certonly --webroot -w /var/www/kwik.zip -d kwik.zip -d www.kwik.zip"
echo "   - Logs: /var/log/nginx/kwikzip-*.log"
echo ""
echo "🔐 SSL Note: Make sure you have certificates at:"
echo "   - /etc/letsencrypt/live/kwik.zip/fullchain.pem"
echo "   - /etc/letsencrypt/live/kwik.zip/privkey.pem"
echo ""
echo "   If not, run: sudo certbot certonly --webroot -w /var/www/kwik.zip -d kwik.zip -d www.kwik.zip"
