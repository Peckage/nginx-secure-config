# Troubleshooting Guide

Common issues and solutions for nginx secure configuration.

## Table of Contents

1. [Setup Script Issues](#setup-script-issues)
2. [SSL/TLS Errors](#ssltls-errors)
3. [Configuration Test Failures](#configuration-test-failures)
4. [Service Issues](#service-issues)
5. [Performance Problems](#performance-problems)
6. [Security Audit Failures](#security-audit-failures)

---

## Setup Script Issues

### Error: "SSL_CTX_load_verify_locations failed"

**Full Error:**
```
nginx: [emerg] SSL_CTX_load_verify_locations("/etc/nginx/ssl/chain.pem") failed
```

**Cause:** The SSL chain file referenced in the configuration doesn't exist. This is normal for fresh installations.

**Solution:**

The setup script now handles this gracefully. When prompted, choose 'y' to continue. SSL will be properly configured when you add sites with certificates.

If you're manually configuring:
1. Use `snippets/ssl-params.conf` (OCSP disabled) for standard SSL
2. Or configure OCSP only after obtaining certificates

### Error: "ssl_stapling ignored, no OCSP responder URL"

**Full Error:**
```
nginx: [warn] "ssl_stapling" ignored, no OCSP responder URL in the certificate
```

**Cause:** Your certificate doesn't include an OCSP responder URL.

**Solution:**

This is just a warning and can be safely ignored. The setup script will ask if you want to continue.

To remove the warning permanently:
1. Use `snippets/ssl-params.conf` instead of `ssl-params-ocsp.conf`
2. OCSP stapling is now disabled by default in the global config

### Error: "nginx is not installed"

**Cause:** Nginx package is not present on the system.

**Solution:**

The setup script will prompt to install nginx. Answer 'y' to proceed.

Manual installation:
```bash
# Debian/Ubuntu
sudo apt update && sudo apt install nginx

# CentOS/RHEL/Rocky
sudo yum install nginx

# Fedora
sudo dnf install nginx

# Arch Linux
sudo pacman -S nginx
```

---

## SSL/TLS Errors

### Error: "certificate verify failed"

**Cause:** Incomplete or incorrect certificate chain.

**Solution:**

1. **Use fullchain.pem instead of cert.pem:**
   ```nginx
   ssl_certificate /etc/letsencrypt/live/domain/fullchain.pem;  # Correct
   # NOT: ssl_certificate /etc/letsencrypt/live/domain/cert.pem;
   ```

2. **Verify certificate chain:**
   ```bash
   sudo ./scripts/ssl-check.sh yourdomain.com
   ```

3. **Test certificate validity:**
   ```bash
   openssl verify -CAfile /etc/letsencrypt/live/domain/chain.pem \
                  /etc/letsencrypt/live/domain/fullchain.pem
   ```

### Error: "No such file or directory" (SSL files)

**Cause:** SSL certificate paths are incorrect or files don't exist.

**Solution:**

1. **Check if certificates exist:**
   ```bash
   ls -la /etc/letsencrypt/live/yourdomain.com/
   ```

2. **Obtain certificates:**
   ```bash
   # Let's Encrypt
   sudo certbot --nginx -d yourdomain.com

   # Or self-signed for testing
   sudo ./scripts/ssl-setup.sh self-signed yourdomain.com
   ```

3. **Verify paths in configuration:**
   ```bash
   grep -r "ssl_certificate" /etc/nginx/sites-enabled/
   ```

### Error: "DH parameters not found"

**Cause:** Diffie-Hellman parameters file doesn't exist.

**Solution:**

Generate DH parameters (takes several minutes):
```bash
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 4096
sudo chmod 600 /etc/nginx/ssl/dhparam.pem
```

Or use 2048-bit (faster, still secure):
```bash
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
```

### Error: "ssl_stapling_verify" failed

**Cause:** OCSP stapling verification is enabled but chain certificate is missing or incorrect.

**Solution:**

1. **Option A: Disable OCSP (recommended if certificates don't support it)**
   ```nginx
   include snippets/ssl-params.conf;  # No OCSP
   ```

2. **Option B: Fix OCSP configuration**
   - Edit `snippets/ssl-params-ocsp.conf`
   - Set correct path to chain.pem:
     ```nginx
     ssl_trusted_certificate /etc/letsencrypt/live/yourdomain.com/chain.pem;
     ```

3. **Check certificate OCSP support:**
   ```bash
   sudo ./scripts/ssl-check.sh yourdomain.com
   ```

---

## Configuration Test Failures

### Error: "nginx: configuration file test failed"

**Solution:**

1. **View detailed error:**
   ```bash
   sudo nginx -t
   ```

2. **Check syntax errors:**
   - Missing semicolons
   - Unmatched brackets `{}`
   - Invalid directive names

3. **Validate specific file:**
   ```bash
   sudo nginx -t -c /etc/nginx/nginx.conf
   ```

4. **Check file permissions:**
   ```bash
   sudo ls -la /etc/nginx/nginx.conf
   sudo ls -la /etc/nginx/sites-enabled/
   ```

### Error: "conflicting server name"

**Cause:** Multiple server blocks with same `server_name`.

**Solution:**

1. **Find conflicts:**
   ```bash
   grep -r "server_name" /etc/nginx/sites-enabled/
   ```

2. **Disable duplicate:**
   ```bash
   sudo ./scripts/manage-site.sh disable conflicting-site.com
   ```

3. **Or modify to use different server_name**

### Error: "unknown directive"

**Cause:** Directive not available in your nginx version or module missing.

**Solution:**

1. **Check nginx version:**
   ```bash
   nginx -V
   ```

2. **Common issues:**
   - `brotli`: Requires nginx-extras package or compiled module
   - `more_clear_headers`: Requires headers-more module
   - `ssl_stapling`: Requires OpenSSL support

3. **Comment out unsupported directives**

---

## Service Issues

### Error: "nginx: [emerg] bind() to 0.0.0.0:80 failed"

**Cause:** Port 80 or 443 is already in use.

**Solution:**

1. **Check what's using the port:**
   ```bash
   sudo lsof -i :80
   sudo lsof -i :443
   ```

2. **Stop conflicting service:**
   ```bash
   # Apache
   sudo systemctl stop apache2

   # Or kill specific process
   sudo kill <PID>
   ```

3. **Verify nginx can start:**
   ```bash
   sudo systemctl start nginx
   ```

### Error: "nginx.service failed with result 'exit-code'"

**Solution:**

1. **Check systemd logs:**
   ```bash
   sudo journalctl -xeu nginx.service
   ```

2. **Check nginx error log:**
   ```bash
   sudo tail -50 /var/log/nginx/error.log
   ```

3. **Test configuration:**
   ```bash
   sudo nginx -t
   ```

4. **Try starting in foreground:**
   ```bash
   sudo nginx -g 'daemon off;'
   # Press Ctrl+C to stop
   ```

### Error: "Permission denied" accessing log files

**Cause:** Log directory permissions incorrect.

**Solution:**

```bash
sudo mkdir -p /var/log/nginx
sudo chown -R www-data:www-data /var/log/nginx  # Ubuntu/Debian
# Or
sudo chown -R nginx:nginx /var/log/nginx        # CentOS/RHEL
sudo chmod 755 /var/log/nginx
```

---

## Performance Problems

### Issue: Slow Response Times

**Diagnosis:**

1. **Check nginx status:**
   ```bash
   sudo systemctl status nginx
   ```

2. **Check error logs:**
   ```bash
   sudo tail -100 /var/log/nginx/error.log
   ```

3. **Monitor resource usage:**
   ```bash
   htop
   # Or
   top
   ```

**Solutions:**

1. **Increase worker connections:**
   ```nginx
   # In nginx.conf
   events {
       worker_connections 4096;  # Increase if needed
   }
   ```

2. **Enable caching:**
   ```nginx
   proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g;
   ```

3. **Optimize buffers:**
   ```nginx
   client_body_buffer_size 512k;
   client_max_body_size 50M;
   ```

### Issue: High Memory Usage

**Solutions:**

1. **Reduce worker processes:**
   ```nginx
   worker_processes 2;  # Instead of auto
   ```

2. **Reduce buffer sizes:**
   ```nginx
   client_body_buffer_size 128k;
   large_client_header_buffers 4 8k;
   ```

3. **Limit connections:**
   ```nginx
   limit_conn addr 10;
   ```

### Issue: Rate Limiting Too Aggressive

**Symptoms:** Legitimate users getting 429 or 503 errors.

**Solutions:**

1. **Increase burst size:**
   ```nginx
   limit_req zone=general burst=50 nodelay;  # Increase burst
   ```

2. **Increase rate limits:**
   ```nginx
   limit_req_zone $binary_remote_addr zone=general:10m rate=100r/s;
   ```

3. **Add whitelist:**
   ```nginx
   geo $limit {
       default 1;
       10.0.0.0/8 0;      # Internal network
       192.168.0.0/16 0;  # Private network
   }

   map $limit $limit_key {
       0 "";
       1 $binary_remote_addr;
   }

   limit_req_zone $limit_key zone=general:10m rate=50r/s;
   ```

---

## Security Audit Failures

### Running Security Audit

```bash
sudo ./scripts/security-audit.sh

# With URL testing
sudo ./scripts/security-audit.sh https://yourdomain.com
```

### Common Failures and Fixes

#### ✗ TLS 1.0 not disabled

**Fix:**
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

#### ✗ Server tokens not disabled

**Fix:**
```nginx
server_tokens off;
```

#### ✗ Security headers missing

**Fix:**
```nginx
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

Or include the security headers snippet:
```nginx
include snippets/security-headers.conf;
```

#### ✗ DH parameters too small

**Fix:**
```bash
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 4096
```

#### ✗ Rate limiting not configured

**Fix:**
```nginx
# In nginx.conf http block
limit_req_zone $binary_remote_addr zone=general:10m rate=50r/s;

# In server block
limit_req zone=general burst=20 nodelay;
```

---

## Getting More Help

### Diagnostic Commands

```bash
# Check nginx status
sudo systemctl status nginx

# View all nginx errors
sudo tail -100 /var/log/nginx/error.log

# Test configuration
sudo nginx -t

# View nginx version and modules
nginx -V

# Check listening ports
sudo netstat -tlnp | grep nginx
# Or
sudo ss -tlnp | grep nginx

# Check SSL certificate
sudo ./scripts/ssl-check.sh yourdomain.com

# Run security audit
sudo ./scripts/security-audit.sh https://yourdomain.com
```

### Log Locations

```bash
# Error log
/var/log/nginx/error.log

# Access log
/var/log/nginx/access.log

# Site-specific logs
/var/log/nginx/<sitename>-error.log
/var/log/nginx/<sitename>-access.log

# Systemd journal
sudo journalctl -u nginx -f
```

### Configuration Locations

```bash
# Main configuration
/etc/nginx/nginx.conf

# Site configurations
/etc/nginx/sites-available/
/etc/nginx/sites-enabled/

# Configuration snippets
/etc/nginx/snippets/

# SSL certificates
/etc/letsencrypt/live/<domain>/
/etc/nginx/ssl/
```

### Online Testing Tools

- **SSL/TLS Test:** https://www.ssllabs.com/ssltest/
- **Security Headers:** https://securityheaders.com/
- **HTTP/2 Test:** https://tools.keycdn.com/http2-test
- **Configuration Validator:** https://ssl-config.mozilla.org/

### Reporting Issues

When reporting issues, include:

1. **Error messages:**
   ```bash
   sudo nginx -t
   sudo tail -50 /var/log/nginx/error.log
   ```

2. **System information:**
   ```bash
   nginx -V
   cat /etc/os-release
   ```

3. **Configuration files (sanitized):**
   ```bash
   sudo grep -v "ssl_certificate" /etc/nginx/sites-enabled/mysite.com
   ```

4. **Steps to reproduce the issue**

---

## Additional Resources

- [Nginx Documentation](https://nginx.org/en/docs/)
- [SSL Configuration Guide](./SSL-CONFIGURATION.md)
- [Security Hardening Guide](./SECURITY-HARDENING.md)
- [Nginx Troubleshooting](https://www.nginx.com/resources/wiki/start/topics/tutorials/debugging/)
