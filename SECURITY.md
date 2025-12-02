# Security Best Practices

This document outlines the security measures implemented and additional recommendations.

## Implemented Security Features

### 1. TLS/SSL Configuration

- **TLS 1.2 and 1.3 only** - Older protocols disabled
- **Strong cipher suites** - Modern, secure ciphers preferred
- **Perfect Forward Secrecy** - ECDHE key exchange
- **OCSP Stapling** - Improved certificate validation
- **4096-bit DH parameters** - Strong Diffie-Hellman key exchange
- **Session tickets disabled** - Prevents certain attacks

### 2. HTTP Security Headers

#### X-Frame-Options
```nginx
X-Frame-Options: SAMEORIGIN
```
Prevents clickjacking attacks by controlling iframe embedding.

#### X-Content-Type-Options
```nginx
X-Content-Type-Options: nosniff
```
Prevents MIME type sniffing attacks.

#### X-XSS-Protection
```nginx
X-XSS-Protection: 1; mode=block
```
Enables browser XSS filtering.

#### Strict-Transport-Security (HSTS)
```nginx
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```
Forces HTTPS connections for 1 year.

#### Content-Security-Policy
Template includes commented CSP header. Customize based on your needs:
```nginx
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'
```

#### Referrer-Policy
```nginx
Referrer-Policy: strict-origin-when-cross-origin
```
Controls referrer information sent with requests.

#### Permissions-Policy
```nginx
Permissions-Policy: geolocation=(), microphone=(), camera=()
```
Restricts browser features.

### 3. Rate Limiting

Pre-configured zones to prevent abuse:

- **General traffic**: 10 requests/second
- **Login endpoints**: 5 requests/minute
- **API endpoints**: 100 requests/second

Helps prevent:
- Brute force attacks
- DDoS attacks
- API abuse
- Resource exhaustion

### 4. File Access Protection

Automatically blocks access to:
- Hidden files (`.git`, `.env`, `.htaccess`)
- Version control directories
- Configuration files
- Backup files (`~`, `.bak`)
- Database files (`.sql`, `.sqlite`, `.db`)
- Log files

### 5. Server Information Hiding

- **server_tokens off** - Hides nginx version
- **Remove Server header** - Prevents server fingerprinting
- **Remove X-Powered-By** - Hides backend technology

### 6. Request Size Limits

```nginx
client_max_body_size 20M;
client_body_buffer_size 128k;
large_client_header_buffers 4 8k;
```

Prevents memory exhaustion attacks.

### 7. Timeout Configuration

```nginx
client_body_timeout 10;
client_header_timeout 10;
send_timeout 10;
```

Prevents slowloris attacks.

## Additional Security Recommendations

### 1. Firewall Configuration

**UFW (Ubuntu/Debian):**
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

**firewalld (CentOS/RHEL):**
```bash
sudo firewall-cmd --set-default-zone=public
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 2. Fail2Ban Integration

Install and configure Fail2Ban to block repeated failed requests:

```bash
sudo apt-get install fail2ban  # Ubuntu/Debian
sudo yum install fail2ban      # CentOS/RHEL
```

Create `/etc/fail2ban/jail.local`:
```ini
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log

[nginx-badbots]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log

[nginx-noproxy]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
```

### 3. ModSecurity WAF

For advanced protection, install ModSecurity:

```bash
# Ubuntu/Debian
sudo apt-get install libmodsecurity3 libnginx-mod-security

# Configure
sudo mkdir -p /etc/nginx/modsec
sudo cp /usr/share/modsecurity-crs/crs-setup.conf.example /etc/nginx/modsec/crs-setup.conf
```

Add to nginx config:
```nginx
modsecurity on;
modsecurity_rules_file /etc/nginx/modsec/main.conf;
```

### 4. Regular Updates

Keep nginx and system packages updated:

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get upgrade

# CentOS/RHEL
sudo yum update
```

Enable automatic security updates:

```bash
# Ubuntu/Debian
sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### 5. SSL Certificate Monitoring

Monitor certificate expiration:

```bash
# Add to crontab
0 0 * * 0 certbot renew --quiet
```

Set up alerts for expiring certificates.

### 6. Log Monitoring

Use log analysis tools:

**GoAccess** (real-time log analyzer):
```bash
sudo apt-get install goaccess
goaccess /var/log/nginx/access.log --log-format=COMBINED
```

**Logwatch** (daily log summaries):
```bash
sudo apt-get install logwatch
```

### 7. Intrusion Detection

Install AIDE (Advanced Intrusion Detection Environment):

```bash
sudo apt-get install aide
sudo aideinit
```

Monitor file integrity regularly.

### 8. Secure File Permissions

```bash
# Nginx config directory
sudo chmod -R 755 /etc/nginx
sudo chmod 644 /etc/nginx/nginx.conf
sudo chmod 644 /etc/nginx/sites-available/*
sudo chmod 700 /etc/nginx/ssl

# Web directories
sudo chmod -R 755 /var/www
sudo chown -R www-data:www-data /var/www
```

### 9. Disable Unused Modules

Check loaded modules:
```bash
nginx -V 2>&1 | grep -o with-http_[a-z_]*
```

Compile custom nginx without unnecessary modules.

### 10. IP Whitelisting

For admin areas:
```nginx
location /admin {
    allow 203.0.113.0/24;
    allow 198.51.100.0/24;
    deny all;
}
```

## Security Auditing

### 1. SSL/TLS Testing

Test with SSL Labs:
```
https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com
```

Command-line testing:
```bash
# Test SSL/TLS
nmap --script ssl-enum-ciphers -p 443 yourdomain.com

# Check certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
```

### 2. Security Headers Testing

Test with SecurityHeaders.com:
```
https://securityheaders.com/?q=yourdomain.com
```

### 3. Vulnerability Scanning

```bash
# Nikto web vulnerability scanner
nikto -h https://yourdomain.com

# OWASP ZAP
zap-cli quick-scan https://yourdomain.com
```

### 4. Configuration Testing

```bash
# Test nginx config
nginx -t

# Check for security issues
nginx -T | grep -i "ssl\|security\|header"
```

## Incident Response

### 1. Monitor Suspicious Activity

Watch for:
- Unusual traffic patterns
- Multiple 4xx/5xx errors
- Geographic anomalies
- Large request sizes
- Rapid requests from single IP

### 2. Block Malicious IPs

Temporary block:
```nginx
deny 203.0.113.42;
```

Permanent block via fail2ban or firewall:
```bash
sudo ufw deny from 203.0.113.42
```

### 3. Review Logs

```bash
# Failed login attempts
grep "401" /var/log/nginx/access.log

# Suspicious user agents
grep -i "bot\|crawler\|scanner" /var/log/nginx/access.log

# Large requests
awk '($10 > 1000000)' /var/log/nginx/access.log
```

## Compliance

### GDPR Considerations

- Log retention policies
- IP address anonymization
- Cookie consent
- Data encryption (SSL/TLS)

### PCI DSS Requirements

- TLS 1.2+ only
- Strong encryption
- Regular security audits
- Access controls
- Log monitoring

### HIPAA Compliance

- Encryption in transit (SSL/TLS)
- Access logging
- User authentication
- Regular security assessments

## Security Checklist

- [ ] HTTPS enabled on all sites
- [ ] HSTS enabled (after testing HTTPS)
- [ ] Strong SSL/TLS configuration
- [ ] Security headers configured
- [ ] Rate limiting on sensitive endpoints
- [ ] Firewall configured and enabled
- [ ] Fail2Ban installed and configured
- [ ] Regular security updates enabled
- [ ] SSL certificate auto-renewal configured
- [ ] Log monitoring in place
- [ ] File permissions properly set
- [ ] Unnecessary modules disabled
- [ ] Server version hidden
- [ ] DDoS protection configured
- [ ] Backup strategy implemented
- [ ] Intrusion detection system active
- [ ] Regular security audits scheduled
- [ ] Incident response plan documented

## Resources

- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [CIS Nginx Benchmark](https://www.cisecurity.org/)
- [Nginx Security Advisories](https://nginx.org/en/security_advisories.html)

## Reporting Security Issues

If you discover a security vulnerability, please email security@example.com with:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

Please allow 48 hours for initial response.
