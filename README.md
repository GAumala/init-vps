# 🚀 Ubuntu VPS Quick Setup

**Automate your DigitalOcean VPS setup** with this script that configures a secure Ubuntu server ready to deploy apps in minutes! ⏱️

## ✨ Features

- 🔒 Secure server setup with UFW firewall (SSH + NGINX only)
- 🌐 NGINX with HTTPS (Let's Encrypt or self-signed)
- 💻 Programming runtimes:
  - OpenJDK 21 + Clojure (`deps.edn` with rebel-readline)
  - Docker for containerization
  - Tmux with sensible defaults
  - Vim configuration for both root and `appdev` user
- 👨‍💻 Dedicated `appdev` user with SSH access

## 🛠️ Prerequisites

- Fresh Ubuntu 22.04/24.04 VPS (tested on DigitalOcean)
- Root access via SSH
- (Optional) Domain name pointed to your VPS for HTTPS

## 🚦 Quick Start

1. **Clone the repository** on your new VPS:
```bash
   git clone https://github.com/GAumala/init-vps.git
   cd init-vps
```
2. **Review configuration** and edit variables at the top of init-vps.sh
```bash
NEW_USER="appdev"              # Your app username
DOMAIN_NAME="example.com"      # Your domain (or leave default for self-signed SSL)
EMAIL="admin@example.com"      # For Let's Encrypt
```
3. **Run the script** with `bash init-vps.sh`
