#!/bin/bash

# Configuration variables - customize these as needed
NEW_USER="appdev"
SSH_PORT="22"  # Change this if you use a non-standard SSH port
EDITOR="vim"
RUNTIMES=("openjdk-21-jdk")  # Add other runtimes here if needed
BACKEND_URL=""  # Set to backend URL if you have one (e.g., "http://localhost:3000"), leave empty for static-only
DOMAIN=""  # Set to your domain name (e.g., "example.com"), leave empty for default
USE_WWW=false  # Set to true to also use www.domain.com

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}" >&2
    exit 1
fi

# Check if SSH keys are configured before securing SSH
echo -e "${YELLOW}Checking SSH key configuration...${NC}"
if [ ! -f /root/.ssh/authorized_keys ] || [ ! -s /root/.ssh/authorized_keys ]; then
    echo -e "${RED}ERROR: No SSH keys found in /root/.ssh/authorized_keys${NC}"
    echo -e "${RED}Please add your SSH public key to /root/.ssh/authorized_keys before running this script${NC}"
    echo -e "${RED}This script will disable password authentication and root login, so SSH keys are required${NC}"
    exit 1
fi

# Secure SSH configuration
echo -e "${YELLOW}Securing SSH configuration...${NC}"
sed "s/SSH_PORT/$SSH_PORT/g; s/NEW_USER/$NEW_USER/g" ./sshd_config > /etc/ssh/sshd_config

# Restart SSH service to apply new configuration
echo -e "${YELLOW}Restarting SSH service to apply new configuration...${NC}"
systemctl restart ssh

# Update package list and upgrade existing packages
echo -e "${YELLOW}Updating package list and upgrading packages...${NC}"
apt-get update
apt-get upgrade -y

# Install essential packag/es
echo -e "${YELLOW}Installing essential packages...${NC}"
apt-get install -y curl git ufw fail2ban zsh

# Install clojure
echo -e "${YELLOW}Installing Clojure...${NC}"
curl -L -O https://github.com/clojure/brew-install/releases/latest/download/linux-install.sh
chmod +x linux-install.sh
./linux-install.sh

# Install Nginx
echo -e "${YELLOW}Installing Nginx...${NC}"
apt install software-properties-common
add-apt-repository ppa:ondrej/nginx
apt update
apt install -y nginx-full

# Setup UFW firewall
echo -e "${YELLOW}Configuring UFW firewall...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"
ufw allow 'Nginx Full'  # Allows both HTTP (80) and HTTPS (443)
ufw --force enable

# install certbot
echo -e "${YELLOW}Installing certbot for Nginx...${NC}"
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# Note: SSL configuration will be handled after nginx configuration is set up
echo -e "${YELLOW}SSL configuration will be set up after nginx configuration${NC}"

# Configure fail2ban
echo -e "${YELLOW}Configuring fail2ban...${NC}"
cp ./jail.local /etc/fail2ban/jail.local
cp ./nginx-401.conf /etc/fail2ban/filter.d/
systemctl enable fail2ban
systemctl start fail2ban
echo -e "${GREEN}fail2ban configured and started${NC}"

# Configure nginx with complete configuration
echo -e "${YELLOW}Configuring nginx with complete configuration...${NC}"

# Create backups
mkdir -p /etc/nginx-backup
chmod 700 /etc/nginx-backup
cp /etc/nginx/nginx.conf /etc/nginx-backup/nginx.conf
cp /etc/nginx/sites-available/default /etc/nginx-backup/default

# Replace main nginx configuration
if [ -f ./nginx.conf ]; then
    cp ./nginx.conf /etc/nginx/nginx.conf
    echo -e "${GREEN}Main nginx configuration updated${NC}"
fi

# Replace default site configuration
if [ -f ./sites-available-default ]; then
    cp ./sites-available-default /etc/nginx/sites-available/default

    # Configure server domains if set
    if [ -n "$DOMAIN" ]; then
        if [ "$USE_WWW" = true ]; then
            SERVER_DOMAINS="$DOMAIN www.$DOMAIN"
            echo -e "${YELLOW}Configuring nginx with domains: $SERVER_DOMAINS${NC}"
        else
            SERVER_DOMAINS="$DOMAIN"
            echo -e "${YELLOW}Configuring nginx with domain: $SERVER_DOMAINS${NC}"
        fi
        sed -i "s|SERVER_DOMAINS_PLACEHOLDER|$SERVER_DOMAINS|" /etc/nginx/sites-available/default
        sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /etc/nginx/sites-available/default
    else
        echo -e "${YELLOW}No domain configured, using default server name${NC}"
        sed -i "s|SERVER_DOMAINS_PLACEHOLDER|_|" /etc/nginx/sites-available/default
        sed -i "s|DOMAIN_PLACEHOLDER|yourdomain.com|g" /etc/nginx/sites-available/default
    fi

    # Configure backend URL if set
    if [ -n "$BACKEND_URL" ]; then
        echo -e "${YELLOW}Configuring nginx with backend proxy to: $BACKEND_URL${NC}"
        sed -i "s|BACKEND_URL_PLACEHOLDER|$BACKEND_URL|g" /etc/nginx/sites-available/default
    else
        echo -e "${YELLOW}No backend URL configured, using static-only nginx configuration${NC}"
        # Remove backend proxy configuration for static-only setup
        sed -i '/location \/api\/ {/,/}/d' /etc/nginx/sites-available/default
        sed -i '/location \/login {/,/}/d' /etc/nginx/sites-available/default
    fi

    echo -e "${GREEN}Default site configuration updated${NC}"
fi

# Test and reload nginx configuration
if nginx -t; then
    systemctl reload nginx
    echo -e "${GREEN}Nginx configuration updated successfully${NC}"
else
    echo -e "${RED}Nginx configuration test failed${NC}"
    exit 1
fi

# Run certbot to get SSL certificate (if domain is configured)
if [ -n "$DOMAIN" ]; then
    echo -e "${YELLOW}Running certbot to get SSL certificate for: $SERVER_DOMAINS${NC}"
    echo -e "${YELLOW}Certbot will prompt you for email and domain confirmation${NC}"
    certbot --nginx
else
    echo -e "${YELLOW}No domain configured - skipping SSL certificate setup${NC}"
    echo -e "${YELLOW}To set up SSL later, run: certbot --nginx${NC}"
fi

# Install docker via script
echo -e "${YELLOW}Installing docker...${NC}"
 curl -fsSL https://get.docker.com -o get-docker.sh
 sh ./get-docker.sh

# Install programming runtimes
echo -e "${YELLOW}Installing programming runtimes...${NC}"
apt-get install -y "${RUNTIMES[@]}"

# Create appdev user
echo -e "${YELLOW}Creating $NEW_USER user...${NC}"
if id "$NEW_USER" &>/dev/null; then
    echo -e "${YELLOW}User $NEW_USER already exists, skipping creation.${NC}"
else
    adduser --disabled-password --gecos "" "$NEW_USER"
fi

# Install and configure Vim for both root and appdev
echo -e "${YELLOW}Setting up Vim...${NC}"
apt-get install -y vim

# Function to setup vim config
setup_vim_config() {
    local user=$1
    local home_dir=$2

    # Determine the right config file location
    local vimrc_path="$home_dir/.vimrc"

    cp ./server.vim "$vimrc_path"

    # Set proper ownership if not root
    if [ "$user" != "root" ]; then
        chown "$user:$user" "$vimrc_path"
    fi
    chmod 644 "$vimrc_path"
}

# Setup vim for root
setup_vim_config "root" "/root"

# Setup vim for appdev
setup_vim_config "$NEW_USER" "/home/$NEW_USER"

# Make vim the default editor for both users
update-alternatives --set editor /usr/bin/vim.basic

# Setup SSH keys for appdev user
echo -e "${YELLOW}Configuring SSH for $NEW_USER...${NC}"
if [ -d /root/.ssh ] && [ -f /root/.ssh/authorized_keys ]; then
    mkdir -p /home/$NEW_USER/.ssh
    cp /root/.ssh/authorized_keys /home/$NEW_USER/.ssh/
    chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
    chmod 700 /home/$NEW_USER/.ssh
    chmod 600 /home/$NEW_USER/.ssh/authorized_keys
else
    echo -e "${YELLOW}No root authorized_keys found, skipping SSH key setup${NC}"
fi

# Install and configure tmux for appdev user
echo -e "${YELLOW}Setting up tmux...${NC}"
apt-get install -y tmux

cp ./tmux.conf /home/$NEW_USER/.tmux.conf
chown $NEW_USER:$NEW_USER /home/$NEW_USER/.tmux.conf

# Setup zsh configuration
echo -e "${YELLOW}Setting up zsh configuration...${NC}"

# Function to setup zsh config
setup_zsh_config() {
    local user=$1
    local home_dir=$2

    cp ./server.zshrc "$home_dir/.zshrc"

    # Set proper ownership if not root
    if [ "$user" != "root" ]; then
        chown "$user:$user" "$home_dir/.zshrc"
    fi
    chmod 644 "$home_dir/.zshrc"
}

# Setup zsh for root
setup_zsh_config "root" "/root"

# Setup zsh for appdev
setup_zsh_config "$NEW_USER" "/home/$NEW_USER"

# Change default shell to zsh for both users
echo -e "${YELLOW}Setting zsh as default shell...${NC}"
chsh -s /bin/zsh root
chsh -s /bin/zsh "$NEW_USER"

# Lock root account password to prevent password-based access
echo -e "${YELLOW}Locking root account password...${NC}"
passwd -l root

# Setup Clojure environment
echo -e "${YELLOW}Setting up Clojure environment...${NC}"
mkdir -p /home/$NEW_USER/.clojure
cp ./new-user.edn /home/$NEW_USER/.clojure/deps.edn
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.clojure

# Apply additional security hardening
echo -e "${YELLOW}Applying additional security hardening...${NC}"
if [ -f ./security-hardening.sh ]; then
    chmod +x ./security-hardening.sh
    ./security-hardening.sh
else
    echo -e "${YELLOW}No security-hardening.sh found, skipping additional hardening${NC}"
fi

# set defaul branch "main" globally for appdev user
sudo -u appdev git config --global init.defaultBranch main

# Final message
echo -e "${GREEN}Setup complete!${NC}"
echo -e "Here's what was done:"
echo -e "  - Updated system packages"
echo -e "  - Secured SSH configuration (disabled root login, password auth, restricted to ${NEW_USER})"
echo -e "  - Installed and configured:"
echo -e "    * Docker for containers"
echo -e "    * NGINX with HTTPS (certbot configured)"
echo -e "    * UFW firewall (SSH and NGINX ports open)"
echo -e "    * fail2ban for intrusion prevention"
echo -e "    * Vim as default editor with custom config"
echo -e "    * zsh as default shell with enhanced history and completion"
echo -e "    * tmux for session management"
echo -e "    * OpenJDK 21 for Clojure development"
echo -e "  - Created user '${NEW_USER}' with SSH access"
echo -e "  - Set up Clojure environment with rebel-readline"
echo -e "\nYou can now visit your server's IP address (with HTTPS) to see the NGINX welcome page"
echo -e "Note: Your browser will show a security warning because we're using a self-signed certificate"
echo -e "\nYou can login as ${NEW_USER} and use tmux for your development sessions."
echo -e "The server is now secured with SSH key-only access, fail2ban protection, and a hardened configuration."
