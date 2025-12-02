#!/bin/bash

#############################################
# Nginx Secure Config - System Setup Script
# Adapts configuration to any Linux system
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
NGINX_CONF_DIR="/etc/nginx"
NGINX_USER="nginx"
NGINX_GROUP="nginx"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Nginx Secure Config Setup${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Please run: sudo $0"
   exit 1
fi

# Detect OS and set appropriate values
detect_os() {
    echo -e "${BLUE}Detecting operating system...${NC}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        echo -e "${RED}Cannot detect operating system${NC}"
        exit 1
    fi

    echo -e "${GREEN}Detected: $OS ${VER:-}${NC}\n"

    # Set nginx user based on OS
    case "$OS" in
        ubuntu|debian)
            NGINX_USER="www-data"
            NGINX_GROUP="www-data"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            NGINX_USER="nginx"
            NGINX_GROUP="nginx"
            ;;
        arch|manjaro)
            NGINX_USER="http"
            NGINX_GROUP="http"
            ;;
        *)
            echo -e "${YELLOW}Unknown OS, using default nginx:nginx${NC}"
            NGINX_USER="nginx"
            NGINX_GROUP="nginx"
            ;;
    esac

    echo -e "${GREEN}Nginx user set to: ${NGINX_USER}:${NGINX_GROUP}${NC}\n"
}

# Check if nginx is installed
check_nginx() {
    echo -e "${BLUE}Checking for nginx installation...${NC}"

    if command -v nginx &> /dev/null; then
        NGINX_VERSION=$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+')
        echo -e "${GREEN}Nginx ${NGINX_VERSION} is installed${NC}\n"
        return 0
    else
        echo -e "${YELLOW}Nginx is not installed${NC}"
        read -p "Would you like to install nginx? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_nginx
        else
            echo -e "${RED}Nginx is required. Exiting.${NC}"
            exit 1
        fi
    fi
}

# Install nginx
install_nginx() {
    echo -e "${BLUE}Installing nginx...${NC}"

    case "$OS" in
        ubuntu|debian)
            apt-get update
            apt-get install -y nginx
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y nginx
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm nginx
            ;;
        *)
            echo -e "${RED}Automatic installation not supported for this OS${NC}"
            echo "Please install nginx manually and run this script again"
            exit 1
            ;;
    esac

    echo -e "${GREEN}Nginx installed successfully${NC}\n"
}

# Backup existing configuration
backup_config() {
    echo -e "${BLUE}Backing up existing nginx configuration...${NC}"

    BACKUP_DIR="/etc/nginx-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    if [ -d "$NGINX_CONF_DIR" ]; then
        cp -r "$NGINX_CONF_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
        echo -e "${GREEN}Backup created at: $BACKUP_DIR${NC}\n"
    else
        echo -e "${YELLOW}No existing configuration to backup${NC}\n"
    fi
}

# Create necessary directories
create_directories() {
    echo -e "${BLUE}Creating directory structure...${NC}"

    mkdir -p "$NGINX_CONF_DIR"/{sites-available,sites-enabled,snippets,ssl,conf.d}
    mkdir -p /var/log/nginx
    mkdir -p /var/www/html

    # Create SSL directory with restricted permissions
    chmod 700 "$NGINX_CONF_DIR/ssl"

    echo -e "${GREEN}Directories created${NC}\n"
}

# Generate DH parameters
generate_dhparams() {
    echo -e "${BLUE}Checking for DH parameters...${NC}"

    DHPARAM_FILE="$NGINX_CONF_DIR/ssl/dhparam.pem"

    if [ -f "$DHPARAM_FILE" ]; then
        echo -e "${GREEN}DH parameters already exist${NC}\n"
    else
        echo -e "${YELLOW}DH parameters not found. Generating (this may take several minutes)...${NC}"
        openssl dhparam -out "$DHPARAM_FILE" 4096
        chmod 600 "$DHPARAM_FILE"
        echo -e "${GREEN}DH parameters generated${NC}\n"
    fi
}

# Copy configuration files
copy_configs() {
    echo -e "${BLUE}Installing configuration files...${NC}"

    # Update nginx user in main config
    sed -i "s/^user nginx;/user $NGINX_USER;/" "$REPO_DIR/nginx.conf"

    # Copy main nginx.conf
    cp "$REPO_DIR/nginx.conf" "$NGINX_CONF_DIR/nginx.conf"

    # Copy snippets
    cp -r "$REPO_DIR/snippets"/* "$NGINX_CONF_DIR/snippets/"

    echo -e "${GREEN}Configuration files installed${NC}\n"
}

# Set proper permissions
set_permissions() {
    echo -e "${BLUE}Setting file permissions...${NC}"

    chown -R root:root "$NGINX_CONF_DIR"
    chmod -R 644 "$NGINX_CONF_DIR"/*.conf
    chmod -R 644 "$NGINX_CONF_DIR"/snippets/*
    chmod 755 "$NGINX_CONF_DIR"
    chmod 755 "$NGINX_CONF_DIR"/{sites-available,sites-enabled,snippets,conf.d}
    chmod 700 "$NGINX_CONF_DIR/ssl"

    chown -R "$NGINX_USER:$NGINX_GROUP" /var/log/nginx
    chown -R "$NGINX_USER:$NGINX_GROUP" /var/www

    echo -e "${GREEN}Permissions set${NC}\n"
}

# Test nginx configuration
test_config() {
    echo -e "${BLUE}Testing nginx configuration...${NC}"

    # Capture output
    local test_output
    test_output=$(nginx -t 2>&1)
    local test_result=$?

    if [ $test_result -eq 0 ]; then
        echo -e "${GREEN}Configuration test passed${NC}\n"
        return 0
    else
        echo "$test_output"
        echo -e "${YELLOW}Warning: Configuration test detected issues${NC}"

        # Check if it's just SSL warnings that can be ignored
        if echo "$test_output" | grep -q "ssl_stapling.*ignored"; then
            echo -e "${YELLOW}OCSP stapling warnings detected - these are normal if certificates don't support OCSP${NC}"
            echo -e "${YELLOW}You can safely proceed or configure OCSP later${NC}\n"

            read -p "Continue despite warnings? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                return 0
            else
                return 1
            fi
        elif echo "$test_output" | grep -q "SSL_CTX_load_verify_locations.*failed"; then
            echo -e "${RED}SSL certificate chain file is missing${NC}"
            echo -e "${YELLOW}This is normal for fresh installations${NC}"
            echo -e "${YELLOW}SSL certificates will be configured when you add sites${NC}\n"

            read -p "Continue with setup? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                return 0
            else
                return 1
            fi
        else
            echo -e "${RED}Configuration test failed with errors${NC}"
            echo -e "${YELLOW}Please review the errors above${NC}\n"
            return 1
        fi
    fi
}

# Enable and start nginx
start_nginx() {
    echo -e "${BLUE}Starting nginx service...${NC}"

    systemctl enable nginx
    systemctl restart nginx

    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}Nginx is running${NC}\n"
    else
        echo -e "${RED}Failed to start nginx${NC}"
        echo "Check logs with: journalctl -xe -u nginx"
        exit 1
    fi
}

# Display next steps
show_next_steps() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}\n"

    echo -e "${BLUE}Next steps:${NC}\n"
    echo "1. Use the site management script to add your sites:"
    echo "   sudo $REPO_DIR/scripts/manage-site.sh add mysite.com"
    echo ""
    echo "2. Configure SSL certificates (Let's Encrypt recommended):"
    echo "   sudo certbot --nginx -d mysite.com"
    echo ""
    echo "3. Review and customize:"
    echo "   - Security headers: $NGINX_CONF_DIR/snippets/security-headers.conf"
    echo "   - Rate limiting: $NGINX_CONF_DIR/nginx.conf"
    echo "   - SSL settings: $NGINX_CONF_DIR/snippets/ssl-params.conf"
    echo ""
    echo "4. Check nginx status:"
    echo "   sudo systemctl status nginx"
    echo ""
    echo -e "${YELLOW}Important:${NC} Don't forget to configure your firewall:"
    echo "   sudo ufw allow 'Nginx Full'"
    echo "   # OR"
    echo "   sudo firewall-cmd --permanent --add-service={http,https}"
    echo "   sudo firewall-cmd --reload"
    echo ""
}

# Main execution
main() {
    detect_os
    check_nginx
    backup_config
    create_directories
    generate_dhparams
    copy_configs
    set_permissions

    if test_config; then
        start_nginx
        show_next_steps
    else
        echo -e "${RED}Setup incomplete due to configuration errors${NC}"
        exit 1
    fi
}

# Run main function
main
