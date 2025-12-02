# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - Canary Branch

### Fixed

#### SSL/TLS Configuration Issues
- **Fixed:** SSL certificate chain path error that prevented nginx from starting
  - Removed hardcoded `/etc/nginx/ssl/chain.pem` reference that doesn't exist in fresh installations
  - OCSP stapling now properly commented out by default in `snippets/ssl-params.conf`
  - Configuration now works out-of-the-box without SSL certificates present

- **Fixed:** OCSP stapling warnings on certificates without OCSP support
  - Disabled global OCSP stapling in `nginx.conf` to prevent warnings
  - Created separate `ssl-params-ocsp.conf` for certificates that support OCSP
  - Users can now choose appropriate SSL configuration based on their certificate

- **Fixed:** Setup script failing on SSL configuration validation
  - Enhanced `test_config()` function with intelligent error handling
  - Script now detects SSL-related warnings vs actual errors
  - Prompts user for decision on SSL warnings instead of failing
  - Provides helpful context about when warnings can be safely ignored

### Added

#### New Tools and Scripts
- **Added:** SSL certificate validation script (`scripts/ssl-check.sh`)
  - Automatically locates SSL certificates in common directories
  - Checks if certificate supports OCSP stapling
  - Validates certificate expiration and validity
  - Generates recommended nginx configuration snippets
  - Provides certificate information and chain validation

- **Added:** New SSL configuration snippet with OCSP enabled
  - `snippets/ssl-params-ocsp.conf` for certificates that support OCSP
  - Includes placeholder for domain-specific chain.pem path
  - Documented usage and requirements

#### Documentation
- **Added:** Comprehensive SSL Configuration Guide (`SSL-CONFIGURATION.md`)
  - Detailed explanation of both SSL configuration options
  - Step-by-step certificate installation instructions
  - Let's Encrypt integration guide
  - Certificate location reference for different setups
  - Troubleshooting section for common SSL issues
  - Testing procedures and verification commands

- **Added:** Complete Troubleshooting Guide (`TROUBLESHOOTING.md`)
  - Setup script issues and solutions
  - SSL/TLS error resolution
  - Configuration test failure fixes
  - Service startup problems
  - Performance optimization tips
  - Security audit failure remediation
  - Diagnostic commands and tools reference
  - Log file locations and analysis

### Changed

#### Configuration Files
- **Changed:** `nginx.conf` - Disabled global OCSP stapling
  - OCSP stapling commented out by default
  - Added explanatory comments about per-site OCSP configuration
  - Prevents errors when certificates don't support OCSP

- **Changed:** `snippets/ssl-params.conf` - Made OCSP optional
  - Commented out OCSP stapling directives
  - Added guidance comments for users
  - Noted Let's Encrypt certificate path convention
  - Configuration now works immediately after installation

- **Changed:** `scripts/setup.sh` - Improved error handling
  - Enhanced `test_config()` with detailed error detection
  - Distinguishes between warnings and critical errors
  - Interactive prompts for SSL-related warnings
  - Helpful messages explain what each warning means
  - Allows setup to continue with warnings after user confirmation

- **Changed:** `scripts/security-audit.sh` - Updated OCSP validation
  - OCSP stapling now treated as optional security feature
  - Checks both global config and site-specific configs
  - Reports OCSP status as warning (not error) when disabled
  - More flexible validation suitable for various certificate types

### Improved

#### User Experience
- **Improved:** Setup process now handles fresh installations gracefully
  - No more confusing SSL errors during initial setup
  - Clear explanations when SSL warnings occur
  - Interactive prompts guide users through setup decisions
  - Setup can complete successfully without SSL certificates

- **Improved:** SSL configuration flexibility
  - Two configuration options for different certificate types
  - Clear guidance on which option to use
  - Automated detection with `ssl-check.sh` script
  - Better support for self-signed and Let's Encrypt certificates

- **Improved:** Error messages and diagnostics
  - More descriptive error messages in setup script
  - Context-aware warnings explain the issue and resolution
  - Security audit provides actionable feedback
  - SSL check script offers specific recommendations

#### Developer Experience
- **Improved:** Configuration maintainability
  - Separated concerns: standard SSL vs OCSP-enabled SSL
  - Modular snippets easier to customize
  - Better comments and documentation in config files
  - Clearer organization of SSL-related settings

### Technical Details

#### Files Modified
```
nginx.conf                          - Disabled global OCSP stapling
snippets/ssl-params.conf           - Commented out OCSP directives
scripts/setup.sh                   - Enhanced error handling
scripts/security-audit.sh          - Updated OCSP validation logic
```

#### Files Added
```
snippets/ssl-params-ocsp.conf      - OCSP-enabled SSL configuration
scripts/ssl-check.sh               - SSL certificate validation tool
SSL-CONFIGURATION.md               - Comprehensive SSL guide
TROUBLESHOOTING.md                 - Complete troubleshooting reference
CHANGELOG.md                       - This file
```

### Migration Guide

If you're upgrading from a previous version:

1. **Backup your current configuration:**
   ```bash
   sudo cp -r /etc/nginx /etc/nginx-backup-$(date +%Y%m%d)
   ```

2. **Update configuration files:**
   ```bash
   sudo ./scripts/setup.sh
   ```

3. **Review SSL configuration:**
   - If you have certificates with OCSP support:
     ```bash
     sudo ./scripts/ssl-check.sh yourdomain.com
     ```
   - Update site configs to use appropriate SSL snippet

4. **Test configuration:**
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

5. **Run security audit:**
   ```bash
   sudo ./scripts/security-audit.sh https://yourdomain.com
   ```

### Breaking Changes

None. All changes are backward compatible. Existing configurations will continue to work.

### Deprecation Notices

None at this time.

### Security Notes

- OCSP stapling is still recommended when certificates support it
- Default configuration prioritizes working setup over optional security features
- Use `ssl-params-ocsp.conf` for production sites with proper certificates
- Follow SSL-CONFIGURATION.md guide for optimal security configuration

### Known Issues

None at this time. Previous SSL configuration issues have been resolved.

### Contributors

- Fixed SSL configuration issues preventing fresh installations
- Added SSL validation tooling
- Improved setup script error handling
- Created comprehensive documentation

---

## Previous Releases

### [1.0.0] - 2025-12-02

#### Added (Previous Version)
- Initial release with kwik.zip optimizations
- Removed file size limits for gigabyte transfers
- Optimized rate limiting for large file uploads/downloads
- Extended timeouts to 30 minutes for large file operations
- Increased connection limits for chunked uploads/downloads

#### Features (Previous Version)
- Security-hardened nginx configuration
- Performance-optimized buffer settings
- Cross-platform setup script
- Site management tools
- Template-based site configurations

---

## Roadmap

### Planned Features
- [ ] Automated SSL certificate renewal monitoring
- [ ] Enhanced rate limiting with IP whitelisting
- [ ] Docker container support
- [ ] Kubernetes deployment configurations
- [ ] Additional site templates (Django, Laravel, etc.)
- [ ] Web-based configuration generator
- [ ] Automated security scanning integration
- [ ] Performance monitoring dashboards

### Under Consideration
- GeoIP-based access control
- ModSecurity WAF integration
- Automated DDoS mitigation
- Multi-site SSL wildcard support
- Automated backup and restore
- Configuration versioning system

---

For more information, see:
- [SSL Configuration Guide](./SSL-CONFIGURATION.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)
- [Security Hardening Guide](./SECURITY-HARDENING.md)
- [Contributing Guidelines](./CONTRIBUTING.md)
