# Kwik.zip Deployment Guide

Complete guide for deploying kwik.zip with maximum security using this nginx configuration.

## Overview

Kwik.zip is a zero-knowledge encrypted file sharing service. This configuration provides:
- Maximum security headers for privacy
- Optimized large file upload/download
- Rate limiting for abuse prevention
- Zero-knowledge privacy protections
- Next.js reverse proxy configuration

## Prerequisites

- Ubuntu/Debian/CentOS server with root access
- Domain name pointing to your server
- kwik.zip application installed

## Quick Deployment

### 1. Set Up Nginx

```bash
# Clone this repository
git clone https://github.com/Peckage/nginx-secure-config.git
cd nginx-secure-config

# Run setup
sudo ./scripts/setup.sh
```

### 2. Configure kwik.zip Site

```bash
# Copy kwik.zip template to sites-available
sudo cp templates/kwikzip-nextjs.conf /etc/nginx/sites-available/kwik.zip

# Edit configuration
sudo nano /etc/nginx/sites-available/kwik.zip
```

**Important: Update these values:**

```nginx
# Line 13-14: Your domain
server_name your-domain.com www.your-domain.com;

# Line 24-25: Your domain
server_name your-domain.com www.your-domain.com;

# Line 28-29: SSL certificate paths
ssl_certificate /etc/nginx/ssl/your-domain.com/fullchain.pem;
ssl_certificate_key /etc/nginx/ssl/your-domain.com/privkey.pem;

# Line 45: Match your MAX_FILE_SIZE from .env
# If .env MAX_FILE_SIZE=5368709120 (5GB), set:
client_max_body_size 5500M;  # 5GB + 10% overhead
```

### 3. Set Up SSL Certificate

```bash
# Using Let's Encrypt
sudo ./scripts/ssl-setup.sh certbot your-domain.com admin@your-domain.com

# Wait for certificate generation...
```

### 4. Enable Site

```bash
# Enable the site
sudo ./scripts/manage-site.sh enable kwik.zip

# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### 5. Start kwik.zip Application

```bash
# Navigate to kwik.zip directory
cd /path/to/kwikzip

# Build for production
pnpm build

# Start with PM2 (recommended)
pm2 start pnpm --name kwikzip -- start
pm2 save
pm2 startup

# Or use systemd (see below)
```

## File Size Configuration

**CRITICAL:** Nginx `client_max_body_size` must match or exceed your kwik.zip `MAX_FILE_SIZE`.

### Matching File Sizes

| MAX_FILE_SIZE (.env) | client_max_body_size (nginx) |
|---------------------|------------------------------|
| 104857600 (100MB)   | 120M                         |
| 524288000 (500MB)   | 600M                         |
| 1073741824 (1GB)    | 1200M                        |
| 2147483648 (2GB)    | 2300M                        |
| 5368709120 (5GB)    | 5500M                        |
| 10737418240 (10GB)  | 11000M                       |

**Formula:** `client_max_body_size = MAX_FILE_SIZE * 1.1`

### Update nginx Configuration

Edit `/etc/nginx/sites-available/kwik.zip`:

```nginx
# Line ~45
client_max_body_size 5500M;  # For 5GB files

# Line ~121 (upload endpoint)
client_max_body_size 5500M;  # Match above
```

### Update kwik.zip .env

```bash
# Edit .env
nano /path/to/kwikzip/.env

# Set file size limits
MAX_FILE_SIZE=5368709120
NEXT_PUBLIC_MAX_FILE_SIZE=5368709120
```

Restart both nginx and kwik.zip after changes.

## Rate Limiting Configuration

The configuration includes built-in rate limiting:

### Current Limits

```nginx
# General pages: 10 requests/second per IP
location / {
    limit_req zone=general burst=20 nodelay;
}

# File uploads: 10 uploads/minute per IP
location /api/upload {
    limit_req zone=login burst=10 nodelay;
}

# File downloads: 100 requests/second per IP
location ~ ^/api/download/ {
    limit_req zone=api burst=200 nodelay;
}
```

### Adjust Rate Limits

Edit `/etc/nginx/nginx.conf` to change zones:

```nginx
# More strict upload limiting (5 uploads/minute)
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

# Less strict downloads (200 requests/second)
limit_req_zone $binary_remote_addr zone=api:10m rate=200r/s;
```

## Security Headers

The kwik.zip configuration includes zero-knowledge optimized headers:

### Key Security Features

1. **X-Frame-Options: DENY** - Prevents clickjacking
2. **Referrer-Policy: no-referrer** - Zero referrer leakage
3. **CSP with unsafe-inline/unsafe-eval** - Allows Web Crypto API
4. **Cache-Control: no-store** - No caching of sensitive data
5. **X-Robots-Tag: noindex** - Download links not indexed

### Privacy-Critical Headers

```nginx
# Download pages - MAXIMUM privacy
location ~ ^/d/ {
    add_header X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, nocache" always;
    add_header Cache-Control "no-store, no-cache, must-revalidate, private, max-age=0" always;
}
```

## Performance Tuning

### For Large Files (5GB+)

```nginx
# Increase timeouts
client_body_timeout 600s;
proxy_send_timeout 900s;
proxy_read_timeout 900s;

# Disable buffering for large uploads
proxy_buffering off;
proxy_request_buffering off;
```

### For High Traffic

```nginx
# Increase worker connections (nginx.conf)
worker_connections 8192;

# Increase keepalive
keepalive 64;
upstream kwikzip_app {
    server 127.0.0.1:3000;
    keepalive 64;  # More persistent connections
}
```

## Systemd Service (Alternative to PM2)

Create `/etc/systemd/system/kwikzip.service`:

```ini
[Unit]
Description=Kwik.zip Zero-Knowledge File Sharing
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/kwikzip
Environment=NODE_ENV=production
ExecStart=/usr/bin/pnpm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable kwikzip
sudo systemctl start kwikzip
sudo systemctl status kwikzip
```

## Monitoring

### Check Nginx Status

```bash
# Test configuration
sudo nginx -t

# View access logs
sudo tail -f /var/log/nginx/kwikzip-access.log

# View error logs
sudo tail -f /var/log/nginx/kwikzip-error.log
```

### Check kwikzip Status

```bash
# PM2
pm2 status kwikzip
pm2 logs kwikzip

# Systemd
sudo systemctl status kwikzip
sudo journalctl -u kwikzip -f
```

### Monitor File Storage

```bash
# Check disk usage
du -sh /path/to/kwikzip/uploads

# Check number of files
find /path/to/kwikzip/uploads -type f | wc -l

# Database size
du -h /path/to/kwikzip/data/kwikzip.db
```

## Cleanup Cron Job

Essential for expired file deletion:

```bash
# Edit crontab
crontab -e

# Add cleanup job (every 5 minutes)
*/5 * * * * cd /var/www/kwikzip && pnpm cleanup >> /var/log/kwikzip-cleanup.log 2>&1

# Or hourly
0 * * * * cd /var/www/kwikzip && pnpm cleanup >> /var/log/kwikzip-cleanup.log 2>&1
```

## Firewall Configuration

### UFW (Ubuntu/Debian)

```bash
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

### firewalld (CentOS/RHEL)

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## Security Hardening

### 1. File Upload Directory

```bash
# Ensure uploads directory is not web-accessible
sudo chown -R www-data:www-data /var/www/kwikzip/uploads
sudo chmod 750 /var/www/kwikzip/uploads

# Nginx blocks direct access in config
location /uploads/ {
    deny all;
}
```

### 2. Database Protection

```bash
# Protect database directory
sudo chmod 750 /var/www/kwikzip/data
sudo chown www-data:www-data /var/www/kwikzip/data

# Nginx blocks database access
location ~ \.(db|sqlite|sqlite3)$ {
    deny all;
}
```

### 3. Environment Variables

```bash
# Protect .env file
sudo chmod 600 /var/www/kwikzip/.env
sudo chown www-data:www-data /var/www/kwikzip/.env
```

### 4. Fail2ban (Optional but Recommended)

```bash
# Install fail2ban
sudo apt-get install fail2ban  # Ubuntu/Debian

# Create jail for kwik.zip
sudo nano /etc/fail2ban/jail.local
```

Add:

```ini
[kwikzip-upload-limit]
enabled = true
port = http,https
filter = kwikzip-upload
logpath = /var/log/nginx/kwikzip-access.log
maxretry = 10
findtime = 600
bantime = 3600
```

## Testing

### 1. Security Headers

```bash
curl -I https://your-domain.com
```

Look for:
- `X-Frame-Options: DENY`
- `Strict-Transport-Security`
- `Content-Security-Policy`
- `Referrer-Policy: no-referrer`

### 2. File Upload

Test with a sample file:
```bash
# Upload via web interface
# Check nginx logs
sudo tail -f /var/log/nginx/kwikzip-access.log
```

### 3. Rate Limiting

```bash
# Test upload rate limit (should block after 10 in 1 minute)
for i in {1..15}; do
    curl -X POST https://your-domain.com/api/upload
    sleep 1
done
```

### 4. SSL Test

Visit: https://www.ssllabs.com/ssltest/analyze.html?d=your-domain.com

Target: **A+ rating**

### 5. Security Headers Test

Visit: https://securityheaders.com/?q=your-domain.com

Target: **A+ rating**

## Troubleshooting

### File Upload Fails

```bash
# Check nginx error log
sudo tail -100 /var/log/nginx/kwikzip-error.log

# Common issues:
# 1. client_max_body_size too small
# 2. Timeouts too short
# 3. Disk space full
```

### 413 Request Entity Too Large

```nginx
# Increase in nginx config
client_max_body_size 10000M;
```

### 504 Gateway Timeout

```nginx
# Increase timeouts
proxy_send_timeout 900s;
proxy_read_timeout 900s;
```

### Rate Limit Errors (429)

```bash
# Check rate limit zones in /etc/nginx/nginx.conf
# Adjust limits or increase burst values
```

## Backup Strategy

### Database Backup

```bash
# Daily backup
0 2 * * * cp /var/www/kwikzip/data/kwikzip.db /backups/kwikzip-$(date +\%Y\%m\%d).db
```

### Encrypted Files Backup

```bash
# Note: These are encrypted, you can backup but cannot decrypt
tar -czf /backups/kwikzip-uploads-$(date +%Y%m%d).tar.gz /var/www/kwikzip/uploads
```

## Performance Benchmarks

Expected performance:
- **Upload speed**: Limited by client bandwidth + encryption overhead
- **Download speed**: Limited by server bandwidth
- **Concurrent users**: 100+ with default config
- **Max file size**: Up to 10GB with proper configuration

## Support

- **Nginx Config Issues:** Check nginx-secure-config repository
- **Kwik.zip Issues:** Check kwik.zip repository
- **Security Questions:** Review SECURITY-HARDENING.md

## Checklist

- [ ] Nginx installed and configured
- [ ] kwik.zip application deployed
- [ ] SSL certificate obtained (Let's Encrypt)
- [ ] Domain pointing to server
- [ ] File size limits matched (.env and nginx)
- [ ] Timeouts configured for large files
- [ ] Rate limiting configured
- [ ] Cleanup cron job active
- [ ] Firewall configured
- [ ] File permissions secured
- [ ] Monitoring set up
- [ ] Tested upload/download
- [ ] SSL Labs A+ rating
- [ ] SecurityHeaders.com A+ rating
- [ ] Backup strategy implemented

## Production URLs

After deployment, test:
- Main site: `https://your-domain.com`
- Upload: `https://your-domain.com/api/upload`
- Download: `https://your-domain.com/d/{id}#{key}`
- Stats: `https://your-domain.com/api/stats`

---

**Security Note:** This configuration is optimized for zero-knowledge privacy. The nginx layer adds defense-in-depth, but the true security comes from client-side encryption in kwik.zip itself.
