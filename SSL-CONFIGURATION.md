# SSL Configuration Guide

This guide explains how to properly configure SSL/TLS certificates with this nginx configuration.

## Overview

This repository provides two SSL configuration snippets:

1. **ssl-params.conf** - Standard SSL configuration (OCSP disabled)
2. **ssl-params-ocsp.conf** - SSL configuration with OCSP stapling enabled

## Which Configuration Should I Use?

Use the **SSL Certificate Validation Script** to determine which configuration is appropriate:

```bash
sudo ./scripts/ssl-check.sh yourdomain.com
```

This script will:
- Locate your SSL certificates
- Check if OCSP is supported
- Provide recommended nginx configuration
- Display certificate expiration information

## Configuration Options

### Option 1: Standard SSL (No OCSP)

Use `ssl-params.conf` when:
- Your certificate doesn't support OCSP
- You don't have a chain.pem file
- You're using self-signed certificates
- Setup warns about OCSP stapling

**Usage in site configuration:**

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    # Use standard SSL params (no OCSP)
    include snippets/ssl-params.conf;

    # ... rest of configuration
}
```

### Option 2: SSL with OCSP Stapling

Use `ssl-params-ocsp.conf` when:
- Your certificate supports OCSP (Let's Encrypt certificates do)
- You have a chain.pem file available
- You want optimal SSL performance and security

**Setup:**

1. Edit `snippets/ssl-params-ocsp.conf`:
```nginx
ssl_trusted_certificate /etc/letsencrypt/live/DOMAIN/chain.pem;
```

Replace `DOMAIN` with your actual domain name.

2. Use in site configuration:
```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # Use SSL params with OCSP
    include snippets/ssl-params-ocsp.conf;

    # ... rest of configuration
}
```

## Common SSL Certificate Locations

### Let's Encrypt (Certbot)
```
Certificate:   /etc/letsencrypt/live/DOMAIN/fullchain.pem
Private Key:   /etc/letsencrypt/live/DOMAIN/privkey.pem
Chain:         /etc/letsencrypt/live/DOMAIN/chain.pem
```

### Custom Location
```
Certificate:   /etc/nginx/ssl/DOMAIN/fullchain.pem
Private Key:   /etc/nginx/ssl/DOMAIN/privkey.pem
Chain:         /etc/nginx/ssl/DOMAIN/chain.pem
```

## Obtaining SSL Certificates

### Let's Encrypt (Recommended)

1. **Install Certbot:**
```bash
# Debian/Ubuntu
sudo apt install certbot python3-certbot-nginx

# CentOS/RHEL
sudo yum install certbot python3-certbot-nginx
```

2. **Obtain Certificate:**
```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

3. **Auto-renewal:**
```bash
sudo certbot renew --dry-run
```

Certbot automatically sets up a cron job for certificate renewal.

### Manual Certificate Installation

If you have a certificate from another provider:

1. **Create SSL directory:**
```bash
sudo mkdir -p /etc/nginx/ssl/yourdomain.com
sudo chmod 700 /etc/nginx/ssl
```

2. **Copy certificates:**
```bash
sudo cp fullchain.pem /etc/nginx/ssl/yourdomain.com/
sudo cp privkey.pem /etc/nginx/ssl/yourdomain.com/
sudo cp chain.pem /etc/nginx/ssl/yourdomain.com/  # if available
sudo chmod 600 /etc/nginx/ssl/yourdomain.com/*
```

3. **Verify installation:**
```bash
sudo ./scripts/ssl-check.sh yourdomain.com
```

## Troubleshooting

### Error: "ssl_stapling ignored, no OCSP responder URL"

**Cause:** Your certificate doesn't support OCSP, but OCSP stapling is enabled.

**Solution:** Use `ssl-params.conf` instead of `ssl-params-ocsp.conf`.

### Error: "SSL_CTX_load_verify_locations failed"

**Cause:** The chain.pem file path is incorrect or file doesn't exist.

**Solutions:**
1. Use `ssl-params.conf` (without OCSP)
2. Or verify the chain file exists and update the path in `ssl-params-ocsp.conf`

### Error: "certificate verify failed"

**Cause:** Certificate chain is incomplete or incorrect.

**Solutions:**
1. Ensure you're using fullchain.pem (not cert.pem)
2. Verify certificate order: server cert → intermediate cert → root cert
3. Run: `openssl verify -CAfile chain.pem fullchain.pem`

### Warning during setup.sh execution

The setup script now handles SSL warnings gracefully. If you see OCSP or SSL warnings:

1. These are normal for fresh installations
2. The script will ask if you want to continue
3. SSL will be properly configured when you add sites

## Testing SSL Configuration

### Test Configuration Syntax
```bash
sudo nginx -t
```

### Test SSL Strength
```bash
# Online test
https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com

# Local test with nmap
nmap --script ssl-enum-ciphers -p 443 yourdomain.com
```

### Test OCSP Stapling
```bash
echo | openssl s_client -connect yourdomain.com:443 -status 2>/dev/null | grep "OCSP Response"
```

### Verify Certificate Chain
```bash
echo | openssl s_client -connect yourdomain.com:443 -showcerts
```

## Security Best Practices

1. **Use Strong Certificates:**
   - Minimum 2048-bit RSA keys (4096-bit recommended)
   - Or use ECDSA certificates (faster, equally secure)

2. **Enable HSTS:**
   ```nginx
   add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
   ```

3. **Keep Certificates Updated:**
   - Set up automatic renewal
   - Monitor expiration dates
   - Test renewal process regularly

4. **Secure Private Keys:**
   - Permissions: 600 (read/write for owner only)
   - Never commit to version control
   - Store backups securely

5. **Monitor Certificate Health:**
   ```bash
   # Check expiration
   echo | openssl s_client -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

   # Check with ssl-check.sh
   sudo ./scripts/ssl-check.sh yourdomain.com
   ```

## Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [SSL Labs Testing Tool](https://www.ssllabs.com/ssltest/)
- [OCSP Stapling Explained](https://en.wikipedia.org/wiki/OCSP_stapling)

## Quick Reference

| Task | Command |
|------|---------|
| Check certificate validity | `sudo ./scripts/ssl-check.sh DOMAIN` |
| Test nginx config | `sudo nginx -t` |
| Obtain Let's Encrypt cert | `sudo certbot --nginx -d DOMAIN` |
| Renew certificates | `sudo certbot renew` |
| Reload nginx | `sudo systemctl reload nginx` |
| View certificate details | `openssl x509 -in cert.pem -text -noout` |

## Support

If you encounter issues:

1. Run the SSL validation script: `./scripts/ssl-check.sh yourdomain.com`
2. Check nginx error logs: `sudo tail -f /var/log/nginx/error.log`
3. Test configuration: `sudo nginx -t`
4. Review this guide's troubleshooting section
5. Open an issue with error output and certificate details (no private keys!)
