# Nginx Secure Configuration

A comprehensive, production-ready nginx configuration with security best practices, automated setup, and site management tools.

## Features

- **Security Hardened**: Modern TLS/SSL configuration, security headers, rate limiting
- **Performance Optimized**: Gzip compression, file caching, optimized buffers
- **Cross-Platform**: Auto-detects OS and adapts to Ubuntu, Debian, CentOS, RHEL, Fedora, Arch
- **Easy Management**: Scripts for setup, site management, and SSL configuration
- **Template-Based**: Pre-configured templates for static sites, reverse proxies, and PHP applications
- **Modular Design**: Reusable configuration snippets

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd nginx-secure-config
```

### 2. Run Setup Script

```bash
sudo ./scripts/setup.sh
```

This will:
- Detect your operating system
- Install nginx (if not present)
- Backup existing configuration
- Install secure configuration files
- Generate DH parameters
- Set proper permissions
- Start nginx service

### 3. Add Your First Site

```bash
# For a static website
sudo ./scripts/manage-site.sh add example.com static

# For a reverse proxy (Node.js, Python, etc.)
sudo ./scripts/manage-site.sh add api.example.com proxy

# For PHP application
sudo ./scripts/manage-site.sh add blog.example.com php
```

### 4. Configure SSL Certificate

```bash
# Using Let's Encrypt (recommended for production)
sudo ./scripts/ssl-setup.sh certbot example.com admin@example.com

# Or self-signed for development
sudo ./scripts/ssl-setup.sh self-signed dev.local
```

### 5. Enable Site and Reload

```bash
sudo ./scripts/manage-site.sh enable example.com
sudo ./scripts/manage-site.sh test
sudo ./scripts/manage-site.sh reload
```

## Directory Structure

```
nginx-secure-config/
├── nginx.conf                  # Main nginx configuration
├── snippets/                   # Reusable configuration snippets
│   ├── security-headers.conf   # Security headers
│   ├── ssl-params.conf         # SSL/TLS parameters
│   ├── proxy-params.conf       # Reverse proxy settings
│   ├── deny-files.conf         # Block sensitive files
│   ├── rate-limiting.conf      # Rate limiting configs
│   └── cache-static.conf       # Static file caching
├── templates/                  # Site configuration templates
│   ├── static-site.conf        # Static website template
│   ├── reverse-proxy.conf      # Reverse proxy template
│   └── php-fpm.conf            # PHP-FPM template
└── scripts/                    # Management scripts
    ├── setup.sh                # Initial setup script
    ├── manage-site.sh          # Site management
    └── ssl-setup.sh            # SSL configuration
```

## Site Management

### Adding a Site

```bash
sudo ./scripts/manage-site.sh add <domain> [template]
```

Templates:
- `static` - Static HTML/CSS/JS websites
- `proxy` - Reverse proxy for backend applications
- `php` - PHP-FPM applications (WordPress, Laravel, etc.)

### Enabling/Disabling Sites

```bash
# Enable a site (creates symlink to sites-enabled)
sudo ./scripts/manage-site.sh enable <domain>

# Disable a site (removes symlink)
sudo ./scripts/manage-site.sh disable <domain>
```

### Listing Sites

```bash
# List all available sites
sudo ./scripts/manage-site.sh list

# List enabled sites
sudo ./scripts/manage-site.sh list-enabled
```

### Removing a Site

```bash
sudo ./scripts/manage-site.sh remove <domain>
```

### Testing and Reloading

```bash
# Test configuration
sudo ./scripts/manage-site.sh test

# Reload nginx
sudo ./scripts/manage-site.sh reload
```

## SSL/TLS Configuration

### Let's Encrypt (Recommended)

```bash
# With email
sudo ./scripts/ssl-setup.sh certbot example.com admin@example.com

# Interactive mode
sudo ./scripts/ssl-setup.sh certbot example.com
```

Certificates auto-renew via certbot's systemd timer.

### Self-Signed Certificate (Development)

```bash
sudo ./scripts/ssl-setup.sh self-signed dev.local
```

### Custom Certificate

```bash
sudo ./scripts/ssl-setup.sh custom example.com
```

Follow the instructions to place your certificate files.

## Security Features

### Headers

All sites include security headers by default:
- `X-Frame-Options: SAMEORIGIN` - Clickjacking protection
- `X-Content-Type-Options: nosniff` - MIME type sniffing protection
- `X-XSS-Protection: 1; mode=block` - XSS protection
- `Referrer-Policy: strict-origin-when-cross-origin` - Referrer control
- `Permissions-Policy` - Feature/permissions control
- `Strict-Transport-Security` - HSTS (HTTPS enforcement)

### TLS/SSL

- TLS 1.2 and 1.3 only
- Strong cipher suites
- OCSP stapling
- Session ticket disabled
- 4096-bit DH parameters

### Rate Limiting

Pre-configured zones:
- `general`: 10 requests/second (general traffic)
- `login`: 5 requests/minute (authentication endpoints)
- `api`: 100 requests/second (API endpoints)

Apply in your site config:
```nginx
location /login {
    limit_req zone=login burst=5 nodelay;
    # ... other config
}
```

### File Protection

Automatic blocking of:
- Hidden files (except `.well-known`)
- Version control directories (`.git`, `.svn`, etc.)
- Configuration files (`.env`, `package.json`, etc.)
- Backup files
- Log and database files

## Configuration Snippets

### Security Headers

```nginx
include snippets/security-headers.conf;
```

### SSL Parameters

```nginx
include snippets/ssl-params.conf;
```

### Proxy Settings

```nginx
location / {
    proxy_pass http://backend;
    include snippets/proxy-params.conf;
}
```

### Deny Sensitive Files

```nginx
include snippets/deny-files.conf;
```

### Cache Static Files

```nginx
include snippets/cache-static.conf;
```

### Rate Limiting

```nginx
include snippets/rate-limiting.conf;
```

## Customization

### Edit Main Configuration

```bash
sudo nano /etc/nginx/nginx.conf
```

### Edit Site Configuration

```bash
sudo nano /etc/nginx/sites-available/<domain>
```

### Edit Snippets

```bash
sudo nano /etc/nginx/snippets/<snippet-name>.conf
```

### Custom Rate Limits

Edit `/etc/nginx/nginx.conf`:
```nginx
limit_req_zone $binary_remote_addr zone=custom:10m rate=50r/s;
```

Apply in site config:
```nginx
limit_req zone=custom burst=100 nodelay;
```

## Firewall Configuration

### UFW (Ubuntu/Debian)

```bash
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

### firewalld (CentOS/RHEL/Fedora)

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### iptables

```bash
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

## Monitoring and Logs

### View Access Logs

```bash
sudo tail -f /var/log/nginx/access.log
```

### View Error Logs

```bash
sudo tail -f /var/log/nginx/error.log
```

### Site-Specific Logs

```bash
sudo tail -f /var/log/nginx/<domain>-access.log
sudo tail -f /var/log/nginx/<domain>-error.log
```

### Check Nginx Status

```bash
sudo systemctl status nginx
```

### View Configuration

```bash
nginx -T
```

## Troubleshooting

### Test Configuration

```bash
sudo nginx -t
```

### Check Service Status

```bash
sudo systemctl status nginx
```

### View Recent Errors

```bash
sudo journalctl -xe -u nginx
```

### Common Issues

**Port 80/443 already in use:**
```bash
sudo lsof -i :80
sudo lsof -i :443
```

**Permission denied errors:**
```bash
# Check file permissions
ls -la /var/www/<domain>

# Fix ownership
sudo chown -R www-data:www-data /var/www/<domain>
```

**SSL certificate errors:**
```bash
# Verify certificate files exist
ls -la /etc/nginx/ssl/<domain>/

# Check certificate validity
openssl x509 -in /etc/nginx/ssl/<domain>/fullchain.pem -text -noout
```

## Performance Tuning

### Worker Processes

Adjust in `/etc/nginx/nginx.conf`:
```nginx
worker_processes auto;  # Uses number of CPU cores
```

### Worker Connections

```nginx
events {
    worker_connections 4096;  # Increase for high traffic
}
```

### Client Body Size

For file uploads:
```nginx
client_max_body_size 100M;
```

### Timeouts

```nginx
client_body_timeout 12;
client_header_timeout 12;
keepalive_timeout 15;
send_timeout 10;
```

## Advanced Features

### Load Balancing

```nginx
upstream backend {
    least_conn;  # or ip_hash, hash, random
    server backend1.example.com:3000 weight=3;
    server backend2.example.com:3000 weight=2;
    server backend3.example.com:3000 backup;
}
```

### HTTP/2 Server Push

```nginx
location = /index.html {
    http2_push /style.css;
    http2_push /script.js;
}
```

### GeoIP Blocking

```nginx
# Install GeoIP module first
geo $blocked_country {
    default 0;
    CN 1;  # Block China
    RU 1;  # Block Russia
}

server {
    if ($blocked_country) {
        return 403;
    }
}
```

## Maintenance

### Backup Configuration

```bash
sudo tar -czf nginx-backup-$(date +%Y%m%d).tar.gz /etc/nginx
```

### Update Configuration

```bash
cd nginx-secure-config
git pull
sudo ./scripts/setup.sh
```

### Renew SSL Certificates

Automatic with certbot. Manual test:
```bash
sudo certbot renew --dry-run
```

## Requirements

- Linux-based OS (Ubuntu, Debian, CentOS, RHEL, Fedora, Arch)
- Root/sudo access
- Nginx 1.18+ (installed automatically if needed)
- OpenSSL 1.1.1+

## Best Practices

1. **Always test** before reloading: `nginx -t && systemctl reload nginx`
2. **Use HTTPS** for all production sites
3. **Enable HSTS** only after confirming HTTPS works
4. **Keep nginx updated** for security patches
5. **Monitor logs** regularly for anomalies
6. **Backup configurations** before major changes
7. **Use rate limiting** on sensitive endpoints
8. **Keep SSL certificates** up to date
9. **Restrict file permissions** properly
10. **Regular security audits** with tools like `nmap` and `ssllabs.com`

## License

MIT License - Feel free to use and modify for your projects.

## Contributing

Contributions welcome! Please ensure all scripts are tested on multiple platforms.

## Support

For issues or questions, please open an issue on the repository.
