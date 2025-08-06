#!/bin/bash

# Configuration variables - customize these as needed
NEW_USER="appdev"
SSH_PORT="22"  # Change this if you use a non-standard SSH port
EDITOR="vim"
RUNTIMES=("openjdk-21-jdk")  # Add other runtimes here if needed

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

# Update package list and upgrade existing packages
echo -e "${YELLOW}Updating package list and upgrading packages...${NC}"
apt-get update
apt-get upgrade -y

# Install essential packages
echo -e "${YELLOW}Installing essential packages...${NC}"
apt-get install -y curl git ufw

# Install Nginx
echo -e "${YELLOW}Installing Nginx...${NC}"
apt install software-properties-common
add-apt-repository ppa:ondrej/nginx
apt update
apt install -y nginx-full

# Setup UFW firewall
echo -e "${YELLOW}Configuring UFW firewall...${NC}"
ufw allow "$SSH_PORT"
ufw allow 'Nginx Full'  # Allows both HTTP (80) and HTTPS (443)
ufw --force enable

# install certbot
echo -e "${YELLOW}Installing certbot for Nginx...${NC}"
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# config Nginx to get a certificate with certbot
certbot --nginx

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

    if [ -f ./server.vim ]; then
        cp ./server.vim "$vimrc_path"
    else
        # Minimal Vim config if local file not found
        cat > "$vimrc_path" << 'EOL'
syntax on
set tabstop=4
set shiftwidth=4
set expandtab
set number
set hlsearch
set backspace=indent,eol,start
set nobackup
set nowritebackup
set noswapfile
EOL
    fi

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

if [ -f ./tmux.conf ]; then
    cp ./tmux.conf /home/$NEW_USER/.tmux.conf
    chown $NEW_USER:$NEW_USER /home/$NEW_USER/.tmux.conf
else
    # Minimal tmux config if local file not found
    cat > /home/$NEW_USER/.tmux.conf << 'EOL'
# Enable mouse mode
set -g mouse on

# Set easier window split keys
bind-key v split-window -h
bind-key h split-window -v

# Easy config reload
bind-key r source-file ~/.tmux.conf \; display-message "tmux.conf reloaded"

# Enable 256 colors
set -g default-terminal "screen-256color"

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1
EOL
    chown $NEW_USER:$NEW_USER /home/$NEW_USER/.tmux.conf
fi

# Setup Clojure environment
echo -e "${YELLOW}Setting up Clojure environment...${NC}"
mkdir -p /home/$NEW_USER/.config/clojure
if [ -f ./new-user.edn ]; then
    cp ./new-user.edn /home/$NEW_USER/.config/clojure/
else
    # Minimal deps.edn with rebel-readline
    cat > /home/$NEW_USER/.config/clojure/deps.edn << 'EOL'
{:aliases
 {:repl {:extra-deps {com.bhauman/rebel-readline {:mvn/version "0.1.4"}}
         :main-opts ["-m" "rebel-readline.main"]}}
EOL
fi
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.config

# Final message
echo -e "${GREEN}Setup complete!${NC}"
echo -e "Here's what was done:"
echo -e "  - Updated system packages"
echo -e "  - Installed and configured:"
echo -e "    * Docker for containers"
echo -e "    * NGINX with HTTPS"
echo -e "    * UFW firewall (SSH and NGINX ports open)"
echo -e "    * Vim as default editor"
echo -e "    * OpenJDK 21 for Clojure development"
echo -e "  - Created user '${NEW_USER}' with SSH access (if root had keys)"
echo -e "  - Installed and configured tmux"
echo -e "  - Set up Clojure environment with rebel-readline"
echo -e "\nYou can now visit your server's IP address (with HTTPS) to see the NGINX welcome page"
echo -e "Note: Your browser will show a security warning because we're using a self-signed certificate"
echo -e "\nYou can login as ${NEW_USER} and use tmux for your development sessions."
