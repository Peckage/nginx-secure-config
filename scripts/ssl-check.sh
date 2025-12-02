#!/bin/bash

#############################################
# SSL Certificate Validation Script
# Checks SSL certificates and OCSP support
#############################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   SSL Certificate Validator${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if domain is provided
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <domain>${NC}"
    echo "Example: $0 example.com"
    exit 1
fi

DOMAIN=$1

# Check if certificate exists in common locations
CERT_LOCATIONS=(
    "/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    "/etc/nginx/ssl/$DOMAIN/fullchain.pem"
    "/etc/ssl/certs/$DOMAIN.crt"
)

CERT_FILE=""
KEY_FILE=""
CHAIN_FILE=""

echo -e "${BLUE}Searching for SSL certificates...${NC}"

# Find certificate file
for location in "${CERT_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        CERT_FILE="$location"
        echo -e "${GREEN}Found certificate: $CERT_FILE${NC}"
        break
    fi
done

if [ -z "$CERT_FILE" ]; then
    echo -e "${RED}No certificate found for $DOMAIN${NC}"
    echo -e "${YELLOW}Checked locations:${NC}"
    for location in "${CERT_LOCATIONS[@]}"; do
        echo "  - $location"
    done
    exit 1
fi

# Find private key
KEY_LOCATIONS=(
    "/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    "/etc/nginx/ssl/$DOMAIN/privkey.pem"
    "/etc/ssl/private/$DOMAIN.key"
)

for location in "${KEY_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        KEY_FILE="$location"
        echo -e "${GREEN}Found private key: $KEY_FILE${NC}"
        break
    fi
done

# Find chain file
CHAIN_LOCATIONS=(
    "/etc/letsencrypt/live/$DOMAIN/chain.pem"
    "/etc/nginx/ssl/$DOMAIN/chain.pem"
)

for location in "${CHAIN_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        CHAIN_FILE="$location"
        echo -e "${GREEN}Found chain file: $CHAIN_FILE${NC}"
        break
    fi
done

echo ""

# Certificate information
echo -e "${BLUE}Certificate Information:${NC}"
openssl x509 -in "$CERT_FILE" -noout -subject -issuer -dates

echo ""

# Check OCSP support
echo -e "${BLUE}Checking OCSP Support:${NC}"
OCSP_URL=$(openssl x509 -in "$CERT_FILE" -noout -ocsp_uri)

if [ -z "$OCSP_URL" ]; then
    echo -e "${YELLOW}OCSP not supported by this certificate${NC}"
    echo -e "${YELLOW}You should use ssl-params.conf (without OCSP)${NC}"
    OCSP_SUPPORTED=false
else
    echo -e "${GREEN}OCSP URL found: $OCSP_URL${NC}"
    echo -e "${GREEN}OCSP is supported by this certificate${NC}"
    echo -e "${GREEN}You can use ssl-params-ocsp.conf${NC}"
    OCSP_SUPPORTED=true
fi

echo ""

# Check certificate validity
echo -e "${BLUE}Certificate Validity:${NC}"
if openssl x509 -in "$CERT_FILE" -noout -checkend 0 > /dev/null 2>&1; then
    echo -e "${GREEN}Certificate is currently valid${NC}"

    # Check if expiring soon (30 days)
    if ! openssl x509 -in "$CERT_FILE" -noout -checkend 2592000 > /dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Certificate expires in less than 30 days${NC}"
    fi
else
    echo -e "${RED}Certificate has expired!${NC}"
fi

echo ""

# Generate nginx configuration snippet
echo -e "${BLUE}Recommended nginx configuration:${NC}"
echo ""
echo -e "${GREEN}# SSL Certificate paths for $DOMAIN${NC}"
echo "ssl_certificate $CERT_FILE;"
echo "ssl_certificate_key $KEY_FILE;"
echo ""

if [ "$OCSP_SUPPORTED" = true ] && [ -n "$CHAIN_FILE" ]; then
    echo -e "${GREEN}# Use ssl-params-ocsp.conf with OCSP enabled${NC}"
    echo "include snippets/ssl-params-ocsp.conf;"
    echo ""
    echo "# Update ssl-params-ocsp.conf with:"
    echo "ssl_trusted_certificate $CHAIN_FILE;"
else
    echo -e "${GREEN}# Use ssl-params.conf (without OCSP)${NC}"
    echo "include snippets/ssl-params.conf;"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
