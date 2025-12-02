#!/bin/bash

#############################################
# Nginx Site Management Script
# Manages site configurations and symlinks
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
SITES_AVAILABLE="$NGINX_CONF_DIR/sites-available"
SITES_ENABLED="$NGINX_CONF_DIR/sites-enabled"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$REPO_DIR/templates"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Please run: sudo $0"
   exit 1
fi

# Show usage
usage() {
    echo -e "${BLUE}Nginx Site Management Script${NC}\n"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add <domain> [template]    Add a new site configuration"
    echo "                             Templates: static, proxy, php (default: static)"
    echo "  enable <domain>            Enable a site (create symlink)"
    echo "  disable <domain>           Disable a site (remove symlink)"
    echo "  remove <domain>            Remove a site configuration"
    echo "  list                       List all available sites"
    echo "  list-enabled               List enabled sites"
    echo "  test                       Test nginx configuration"
    echo "  reload                     Reload nginx"
    echo ""
    echo "Examples:"
    echo "  $0 add example.com static"
    echo "  $0 add api.example.com proxy"
    echo "  $0 enable example.com"
    echo "  $0 disable example.com"
    echo ""
    exit 1
}

# Add a new site
add_site() {
    local domain=$1
    local template=${2:-static}

    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain name is required${NC}"
        usage
    fi

    echo -e "${BLUE}Adding new site: $domain${NC}"

    # Check if site already exists
    if [ -f "$SITES_AVAILABLE/$domain" ]; then
        echo -e "${YELLOW}Warning: Site configuration already exists${NC}"
        read -p "Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 1
        fi
    fi

    # Determine template
    local template_file=""
    case "$template" in
        static)
            template_file="$TEMPLATES_DIR/static-site.conf"
            ;;
        proxy|reverse-proxy)
            template_file="$TEMPLATES_DIR/reverse-proxy.conf"
            ;;
        php|php-fpm)
            template_file="$TEMPLATES_DIR/php-fpm.conf"
            ;;
        *)
            echo -e "${RED}Error: Unknown template '$template'${NC}"
            echo "Available templates: static, proxy, php"
            exit 1
            ;;
    esac

    if [ ! -f "$template_file" ]; then
        echo -e "${RED}Error: Template file not found: $template_file${NC}"
        exit 1
    fi

    # Copy template and replace domain
    cp "$template_file" "$SITES_AVAILABLE/$domain"
    sed -i "s/example\.com/$domain/g" "$SITES_AVAILABLE/$domain"

    # Create web root directory
    local web_root="/var/www/$domain"
    mkdir -p "$web_root"

    # Detect nginx user
    local nginx_user=$(grep -E "^user " "$NGINX_CONF_DIR/nginx.conf" | awk '{print $2}' | sed 's/;//')
    nginx_user=${nginx_user:-www-data}

    chown -R "$nginx_user:$nginx_user" "$web_root"

    # Create SSL directory
    mkdir -p "$NGINX_CONF_DIR/ssl/$domain"

    echo -e "${GREEN}Site configuration created: $SITES_AVAILABLE/$domain${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Edit the configuration: $SITES_AVAILABLE/$domain"
    echo "2. Place your site files in: $web_root"
    echo "3. Configure SSL certificate (recommended: certbot --nginx -d $domain)"
    echo "4. Enable the site: $0 enable $domain"
    echo "5. Test and reload: $0 test && $0 reload"
}

# Enable a site
enable_site() {
    local domain=$1

    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain name is required${NC}"
        usage
    fi

    if [ ! -f "$SITES_AVAILABLE/$domain" ]; then
        echo -e "${RED}Error: Site configuration not found: $domain${NC}"
        echo "Available sites:"
        ls -1 "$SITES_AVAILABLE" 2>/dev/null || echo "  (none)"
        exit 1
    fi

    if [ -L "$SITES_ENABLED/$domain" ]; then
        echo -e "${YELLOW}Site is already enabled: $domain${NC}"
        exit 0
    fi

    echo -e "${BLUE}Enabling site: $domain${NC}"
    ln -s "$SITES_AVAILABLE/$domain" "$SITES_ENABLED/$domain"
    echo -e "${GREEN}Site enabled${NC}"
    echo -e "${YELLOW}Don't forget to test and reload nginx:${NC}"
    echo "  $0 test && $0 reload"
}

# Disable a site
disable_site() {
    local domain=$1

    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain name is required${NC}"
        usage
    fi

    if [ ! -L "$SITES_ENABLED/$domain" ]; then
        echo -e "${YELLOW}Site is not enabled: $domain${NC}"
        exit 0
    fi

    echo -e "${BLUE}Disabling site: $domain${NC}"
    rm "$SITES_ENABLED/$domain"
    echo -e "${GREEN}Site disabled${NC}"
    echo -e "${YELLOW}Reload nginx to apply changes:${NC}"
    echo "  $0 reload"
}

# Remove a site
remove_site() {
    local domain=$1

    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain name is required${NC}"
        usage
    fi

    echo -e "${RED}WARNING: This will permanently delete the site configuration${NC}"
    echo "Domain: $domain"
    echo "Config: $SITES_AVAILABLE/$domain"
    read -p "Are you sure? (yes/no) " -r
    echo

    if [[ ! $REPLY == "yes" ]]; then
        echo "Cancelled"
        exit 1
    fi

    # Disable first if enabled
    if [ -L "$SITES_ENABLED/$domain" ]; then
        echo -e "${BLUE}Disabling site...${NC}"
        rm "$SITES_ENABLED/$domain"
    fi

    # Remove configuration
    if [ -f "$SITES_AVAILABLE/$domain" ]; then
        echo -e "${BLUE}Removing configuration...${NC}"
        rm "$SITES_AVAILABLE/$domain"
        echo -e "${GREEN}Site removed${NC}"
    else
        echo -e "${YELLOW}Configuration file not found${NC}"
    fi
}

# List available sites
list_sites() {
    echo -e "${BLUE}Available sites:${NC}"
    if [ -d "$SITES_AVAILABLE" ]; then
        ls -1 "$SITES_AVAILABLE" 2>/dev/null || echo "  (none)"
    else
        echo "  (none)"
    fi
}

# List enabled sites
list_enabled() {
    echo -e "${BLUE}Enabled sites:${NC}"
    if [ -d "$SITES_ENABLED" ]; then
        ls -1 "$SITES_ENABLED" 2>/dev/null || echo "  (none)"
    else
        echo "  (none)"
    fi
}

# Test nginx configuration
test_config() {
    echo -e "${BLUE}Testing nginx configuration...${NC}"
    if nginx -t; then
        echo -e "${GREEN}Configuration test passed${NC}"
        return 0
    else
        echo -e "${RED}Configuration test failed${NC}"
        return 1
    fi
}

# Reload nginx
reload_nginx() {
    echo -e "${BLUE}Reloading nginx...${NC}"
    if systemctl reload nginx; then
        echo -e "${GREEN}Nginx reloaded successfully${NC}"
    else
        echo -e "${RED}Failed to reload nginx${NC}"
        exit 1
    fi
}

# Main command router
main() {
    local command=$1
    shift

    case "$command" in
        add)
            add_site "$@"
            ;;
        enable)
            enable_site "$@"
            ;;
        disable)
            disable_site "$@"
            ;;
        remove)
            remove_site "$@"
            ;;
        list)
            list_sites
            ;;
        list-enabled)
            list_enabled
            ;;
        test)
            test_config
            ;;
        reload)
            reload_nginx
            ;;
        *)
            usage
            ;;
    esac
}

# Run main function
if [ $# -eq 0 ]; then
    usage
fi

main "$@"
