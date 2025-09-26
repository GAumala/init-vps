#!/bin/bash

# Additional security hardening for web applications

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Applying additional security hardening...${NC}"

# 1. Set proper file permissions
echo -e "${YELLOW}Setting secure file permissions...${NC}"
chmod 600 /etc/ssh/sshd_config
chmod 600 /etc/fail2ban/jail.local
chmod 644 /etc/nginx/nginx.conf

# 2. Disable unnecessary services
echo -e "${YELLOW}Disabling unnecessary services...${NC}"
systemctl disable bluetooth 2>/dev/null || true
systemctl disable cups 2>/dev/null || true
systemctl disable avahi-daemon 2>/dev/null || true

# 3. Configure automatic security updates
echo -e "${YELLOW}Configuring automatic security updates...${NC}"
apt-get install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOL'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOL

# 4. Set up log rotation for security logs
echo -e "${YELLOW}Configuring log rotation...${NC}"
cat > /etc/logrotate.d/security << 'EOL'
/var/log/auth.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root adm
}

/var/log/nginx/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 www-data adm
    postrotate
        systemctl reload nginx
    endscript
}
EOL

# 5. Configure kernel security parameters
echo -e "${YELLOW}Setting kernel security parameters...${NC}"
cat >> /etc/sysctl.conf << 'EOL'

# Security hardening
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.ip_forward = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
EOL

sysctl -p

# 6. Set up AIDE (file integrity monitoring)
echo -e "${YELLOW}Setting up file integrity monitoring...${NC}"
apt-get install -y aide
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db


echo -e "${GREEN}Security hardening complete!${NC}"
echo -e "Additional security measures applied:"
echo -e "  - Secure file permissions"
echo -e "  - Disabled unnecessary services"
echo -e "  - Automatic security updates"
echo -e "  - Log rotation for security logs"
echo -e "  - Kernel security parameters"
echo -e "  - File integrity monitoring (AIDE)"
