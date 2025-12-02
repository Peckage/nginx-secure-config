#!/bin/bash

#############################################
# Nginx Security Audit Script
# Verifies security configuration
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NGINX_CONF="/etc/nginx/nginx.conf"
PASS=0
FAIL=0
WARN=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Nginx Security Audit${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Test function
test_config() {
    local test_name=$1
    local command=$2
    local expected=$3
    local severity=${4:-"error"}  # error or warning

    if eval "$command" | grep -q "$expected"; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASS++))
        return 0
    else
        if [ "$severity" = "warning" ]; then
            echo -e "${YELLOW}⚠${NC} $test_name"
            ((WARN++))
        else
            echo -e "${RED}✗${NC} $test_name"
            ((FAIL++))
        fi
        return 1
    fi
}

# Test URL security
test_url() {
    local test_name=$1
    local url=$2
    local header=$3
    local expected=$4

    if [ -z "$url" ]; then
        echo -e "${YELLOW}⚠${NC} $test_name - No URL provided, skipping"
        ((WARN++))
        return 1
    fi

    result=$(curl -s -I "$url" 2>/dev/null | grep -i "$header" || echo "")

    if echo "$result" | grep -qi "$expected"; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "   Expected: $expected"
        echo -e "   Got: ${result:-'(header not found)'}"
        ((FAIL++))
        return 1
    fi
}

echo -e "${BLUE}Configuration Tests:${NC}\n"

# SSL/TLS Configuration
test_config "TLS 1.0 disabled" "grep 'ssl_protocols' $NGINX_CONF" "TLSv1.2 TLSv1.3"
test_config "Server tokens disabled" "grep 'server_tokens' $NGINX_CONF" "server_tokens off"
test_config "Session tickets disabled" "grep 'ssl_session_tickets' $NGINX_CONF" "ssl_session_tickets off"

# OCSP stapling is optional - check if configured
if grep -q "ssl_stapling on" "$NGINX_CONF" 2>/dev/null || find /etc/nginx/sites-enabled /etc/nginx/conf.d -type f -exec grep -q "ssl_stapling on" {} \; 2>/dev/null; then
    echo -e "${GREEN}✓${NC} OCSP stapling enabled (optional)"
    ((PASS++))
else
    echo -e "${YELLOW}⚠${NC} OCSP stapling not enabled (optional - only needed if certificates support it)"
    ((WARN++))
fi

# Security Headers
test_config "X-Frame-Options configured" "grep 'X-Frame-Options' $NGINX_CONF" "DENY\|SAMEORIGIN"
test_config "X-Content-Type-Options configured" "grep 'X-Content-Type-Options' $NGINX_CONF" "nosniff"
test_config "X-XSS-Protection configured" "grep 'X-XSS-Protection' $NGINX_CONF" "1; mode=block"
test_config "Referrer-Policy configured" "grep 'Referrer-Policy' $NGINX_CONF" "no-referrer\|strict-origin"
test_config "Permissions-Policy configured" "grep 'Permissions-Policy' $NGINX_CONF" "geolocation=()"

# Rate Limiting
test_config "Rate limiting zones defined" "grep 'limit_req_zone' $NGINX_CONF" "zone="
test_config "Login rate limiting configured" "grep 'zone=login' $NGINX_CONF" "rate=" "warning"

# DH Parameters
if [ -f "/etc/nginx/ssl/dhparam.pem" ]; then
    echo -e "${GREEN}✓${NC} DH parameters file exists"
    ((PASS++))

    # Check DH size
    dh_size=$(openssl dhparam -in /etc/nginx/ssl/dhparam.pem -text -noout 2>/dev/null | grep "DH Parameters" | grep -oP '\(\K[0-9]+' || echo "0")
    if [ "$dh_size" -ge 2048 ]; then
        echo -e "${GREEN}✓${NC} DH parameters >= 2048 bits ($dh_size bits)"
        ((PASS++))
    else
        echo -e "${RED}✗${NC} DH parameters too small ($dh_size bits, should be >= 2048)"
        ((FAIL++))
    fi
else
    echo -e "${RED}✗${NC} DH parameters file not found"
    ((FAIL++))
fi

# File Permissions
echo -e "\n${BLUE}File Permission Tests:${NC}\n"

if [ -f "$NGINX_CONF" ]; then
    perms=$(stat -c %a "$NGINX_CONF" 2>/dev/null || stat -f %OLp "$NGINX_CONF" 2>/dev/null)
    if [ "$perms" = "644" ] || [ "$perms" = "600" ]; then
        echo -e "${GREEN}✓${NC} nginx.conf permissions correct ($perms)"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠${NC} nginx.conf permissions unusual ($perms)"
        ((WARN++))
    fi
fi

if [ -d "/etc/nginx/ssl" ]; then
    perms=$(stat -c %a "/etc/nginx/ssl" 2>/dev/null || stat -f %OLp "/etc/nginx/ssl" 2>/dev/null)
    if [ "$perms" = "700" ]; then
        echo -e "${GREEN}✓${NC} SSL directory permissions correct ($perms)"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠${NC} SSL directory permissions should be 700 (currently $perms)"
        ((WARN++))
    fi
fi

# Service Status
echo -e "\n${BLUE}Service Tests:${NC}\n"

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓${NC} Nginx service is running"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Nginx service is not running"
    ((FAIL++))
fi

if nginx -t &>/dev/null; then
    echo -e "${GREEN}✓${NC} Nginx configuration is valid"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Nginx configuration has errors"
    ((FAIL++))
fi

# URL Tests (if URL provided)
if [ -n "$1" ]; then
    URL=$1
    echo -e "\n${BLUE}Live URL Tests: $URL${NC}\n"

    test_url "X-Frame-Options header" "$URL" "x-frame-options" "deny\|sameorigin"
    test_url "X-Content-Type-Options header" "$URL" "x-content-type-options" "nosniff"
    test_url "X-XSS-Protection header" "$URL" "x-xss-protection" "1; mode=block"
    test_url "Referrer-Policy header" "$URL" "referrer-policy" "no-referrer\|strict-origin"
    test_url "HSTS header" "$URL" "strict-transport-security" "max-age="
    test_url "Permissions-Policy header" "$URL" "permissions-policy" "geolocation=()"
    test_url "Content-Security-Policy header" "$URL" "content-security-policy" "default-src\|script-src"
    test_url "Cross-Origin-Opener-Policy" "$URL" "cross-origin-opener-policy" "same-origin"

    # Test that server version is hidden
    if curl -s -I "$URL" | grep -i "server:" | grep -qv "nginx/[0-9]"; then
        echo -e "${GREEN}✓${NC} Server version hidden"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠${NC} Server version may be exposed"
        ((WARN++))
    fi
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Audit Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${GREEN}Passed:${NC} $PASS"
echo -e "${RED}Failed:${NC} $FAIL"
echo -e "${YELLOW}Warnings:${NC} $WARN"

TOTAL=$((PASS + FAIL + WARN))
if [ $TOTAL -gt 0 ]; then
    SCORE=$((PASS * 100 / TOTAL))
    echo -e "\n${BLUE}Security Score: $SCORE%${NC}"

    if [ $SCORE -ge 90 ]; then
        echo -e "${GREEN}Excellent security configuration!${NC}"
    elif [ $SCORE -ge 75 ]; then
        echo -e "${YELLOW}Good security, but could be improved${NC}"
    else
        echo -e "${RED}Security needs improvement${NC}"
    fi
fi

echo -e "\n${BLUE}Recommendations:${NC}\n"

if [ $FAIL -gt 0 ]; then
    echo "1. Fix all failed tests above"
fi

if [ -z "$1" ]; then
    echo "2. Run with URL to test live headers: $0 https://yourdomain.com"
fi

echo "3. Test SSL configuration: https://www.ssllabs.com/ssltest/"
echo "4. Test security headers: https://securityheaders.com/"
echo "5. Run vulnerability scan: nikto -h https://yourdomain.com"
echo "6. Enable fail2ban for additional protection"
echo "7. Keep nginx and OpenSSL updated"
echo "8. Review logs regularly: tail -f /var/log/nginx/error.log"

echo ""

# Exit code
if [ $FAIL -gt 0 ]; then
    exit 1
else
    exit 0
fi
