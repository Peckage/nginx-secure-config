# Contributing to Nginx Secure Config

Thank you for considering contributing to Nginx Secure Config! This document provides guidelines for contributing.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected behavior vs actual behavior
- Your environment (OS, nginx version, etc.)
- Relevant logs or error messages

### Suggesting Features

Feature suggestions are welcome! Please:
- Check if the feature has already been requested
- Provide a clear use case
- Explain why it would benefit users
- Include examples if applicable

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**
4. **Test thoroughly** on multiple platforms if possible
5. **Update documentation** as needed
6. **Commit with clear messages**: `git commit -m "Add feature: description"`
7. **Push to your fork**: `git push origin feature/your-feature-name`
8. **Open a Pull Request**

### Code Standards

#### Shell Scripts
- Use `#!/bin/bash` shebang
- Include error handling with `set -e`
- Add comments for complex logic
- Use meaningful variable names
- Follow Google Shell Style Guide

Example:
```bash
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Function with clear purpose
check_nginx() {
    if command -v nginx &> /dev/null; then
        echo -e "${GREEN}Nginx found${NC}"
        return 0
    fi
    return 1
}
```

#### Nginx Configuration
- Use 4 spaces for indentation
- Add comments explaining complex rules
- Group related directives
- Follow nginx best practices

Example:
```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;

# SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:...';
```

#### Documentation
- Use Markdown format
- Include code examples
- Keep explanations clear and concise
- Update README.md if adding features

### Testing

Before submitting:

1. **Test on multiple OS distributions** (Ubuntu, Debian, CentOS if possible)
2. **Verify nginx configuration**: `nginx -t`
3. **Check script execution**: Run scripts with various inputs
4. **Test error handling**: Verify scripts handle errors gracefully
5. **Review security implications**: Ensure changes don't introduce vulnerabilities

### Commit Messages

Use clear, descriptive commit messages:

```
Add support for Brotli compression

- Add brotli configuration snippet
- Update nginx.conf with brotli settings
- Add documentation for enabling brotli
- Update setup script to detect brotli module
```

Format:
- First line: Brief summary (50 chars or less)
- Blank line
- Detailed description if needed
- Reference issues: `Fixes #123` or `Relates to #456`

### What to Contribute

We welcome contributions in these areas:

#### High Priority
- Bug fixes
- Security improvements
- Cross-platform compatibility
- Documentation improvements
- Test coverage

#### Features
- New configuration snippets
- Additional site templates
- Performance optimizations
- Monitoring/logging tools
- Backup utilities

#### Low Priority
- Code cleanup
- Style improvements
- Minor optimizations

### Development Setup

1. Clone your fork:
```bash
git clone https://github.com/yourusername/nginx-secure-config.git
cd nginx-secure-config
```

2. Create a test environment (VM or container recommended):
```bash
# Using Docker
docker run -it -v $(pwd):/workspace ubuntu:22.04 bash

# Install dependencies
apt-get update
apt-get install -y nginx openssl git
```

3. Make changes and test:
```bash
cd /workspace
sudo ./scripts/setup.sh
sudo ./scripts/manage-site.sh add test.local
nginx -t
```

### Security Guidelines

When contributing:
- Never commit sensitive data (keys, passwords, tokens)
- Follow OWASP security guidelines
- Use secure defaults
- Document security implications
- Test for common vulnerabilities

### License

By contributing, you agree that your contributions will be licensed under the MIT License.

### Code of Conduct

- Be respectful and constructive
- Welcome newcomers
- Focus on the code, not the person
- Accept constructive criticism gracefully
- Help others learn and grow

### Questions?

If you have questions about contributing:
- Open an issue with the "question" label
- Check existing issues and discussions
- Review the documentation

Thank you for contributing!
