# Quick Start Guide

Get your nginx secure configuration up and running in 5 minutes!

## Installation

### 1. Clone the Repository

```bash
cd ~/projects
git clone https://github.com/Peckage/nginx-secure-config.git
cd nginx-secure-config
```

### 2. Run Setup

```bash
sudo ./scripts/setup.sh
```

This automatically:
- Detects your OS
- Installs nginx if needed
- Backs up existing config
- Installs secure configuration
- Generates DH parameters
- Starts nginx

## Add Your First Website

### Static Website

```bash
# Add site
sudo ./scripts/manage-site.sh add mysite.com static

# Configure SSL (Let's Encrypt)
sudo ./scripts/ssl-setup.sh certbot mysite.com admin@mysite.com

# Enable and reload
sudo ./scripts/manage-site.sh enable mysite.com
sudo ./scripts/manage-site.sh test
sudo ./scripts/manage-site.sh reload
```

Your site files go in: `/var/www/mysite.com`

### Reverse Proxy (Node.js, Python, etc.)

```bash
# Add site
sudo ./scripts/manage-site.sh add api.mysite.com proxy

# Edit config to set backend port
sudo nano /etc/nginx/sites-available/api.mysite.com
# Change: server 127.0.0.1:3000 to your app's port

# Configure SSL
sudo ./scripts/ssl-setup.sh certbot api.mysite.com admin@mysite.com

# Enable and reload
sudo ./scripts/manage-site.sh enable api.mysite.com
sudo ./scripts/manage-site.sh reload
```

### PHP Application (WordPress, Laravel, etc.)

```bash
# Add site
sudo ./scripts/manage-site.sh add blog.mysite.com php

# Edit PHP-FPM socket path if needed
sudo nano /etc/nginx/sites-available/blog.mysite.com

# Configure SSL
sudo ./scripts/ssl-setup.sh certbot blog.mysite.com admin@mysite.com

# Enable and reload
sudo ./scripts/manage-site.sh enable blog.mysite.com
sudo ./scripts/manage-site.sh reload
```

Your PHP files go in: `/var/www/blog.mysite.com`

## Common Commands

```bash
# List all sites
sudo ./scripts/manage-site.sh list

# List enabled sites
sudo ./scripts/manage-site.sh list-enabled

# Disable a site
sudo ./scripts/manage-site.sh disable mysite.com

# Remove a site
sudo ./scripts/manage-site.sh remove mysite.com

# Test config
sudo ./scripts/manage-site.sh test

# Reload nginx
sudo ./scripts/manage-site.sh reload

# View logs
sudo tail -f /var/log/nginx/mysite.com-access.log
sudo tail -f /var/log/nginx/mysite.com-error.log
```

## Firewall Setup

### Ubuntu/Debian (UFW)

```bash
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

### CentOS/RHEL/Fedora (firewalld)

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## SSL Certificate Renewal

Let's Encrypt certificates auto-renew. Test with:

```bash
sudo certbot renew --dry-run
```

## What's Included?

- **Security**: TLS 1.2/1.3, security headers, rate limiting, file protection
- **Performance**: Gzip, caching, optimized buffers
- **Templates**: Static, reverse proxy, PHP-FPM
- **Scripts**: Automated setup, site management, SSL configuration
- **Cross-platform**: Works on Ubuntu, Debian, CentOS, RHEL, Fedora, Arch

## File Locations

- **Main config**: `/etc/nginx/nginx.conf`
- **Site configs**: `/etc/nginx/sites-available/`
- **Enabled sites**: `/etc/nginx/sites-enabled/` (symlinks)
- **Snippets**: `/etc/nginx/snippets/`
- **SSL certs**: `/etc/nginx/ssl/<domain>/`
- **Web root**: `/var/www/<domain>/`
- **Logs**: `/var/log/nginx/`

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Review [SECURITY.md](SECURITY.md) for security best practices
- Customize security headers in `/etc/nginx/snippets/security-headers.conf`
- Set up rate limiting for login/API endpoints
- Configure monitoring and log analysis
- Enable fail2ban for additional protection

## Troubleshooting

### Configuration test fails

```bash
sudo nginx -t
# Check the error message and fix the config
```

### Site not loading

```bash
# Check if enabled
sudo ls -la /etc/nginx/sites-enabled/

# Check logs
sudo tail -f /var/log/nginx/error.log
```

### SSL errors

```bash
# Check certificate files exist
ls -la /etc/nginx/ssl/mysite.com/

# Verify certificate
openssl x509 -in /etc/nginx/ssl/mysite.com/fullchain.pem -text -noout
```

### Permission errors

```bash
# Fix web directory ownership
sudo chown -R www-data:www-data /var/www/mysite.com  # Ubuntu/Debian
sudo chown -R nginx:nginx /var/www/mysite.com        # CentOS/RHEL
```

## Support

- Open an issue on GitHub
- Check the [documentation](README.md)
- Review [contributing guidelines](CONTRIBUTING.md)

## Repository

https://github.com/Peckage/nginx-secure-config
