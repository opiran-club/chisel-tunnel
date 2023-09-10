#!/bin/bash
# Color variables for better readability
WHITE="\e[37m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m"

# Function to print messages with color
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function for user input
get_user_input() {
    local prompt=$1
    local variable_name=$2
    read -p "${prompt}: " $variable_name
}

# Function to check and install packages
install_package() {
    local package_name=$1
    print_message "${YELLOW}" "Installing ${package_name}..."
    apt update
    apt install "${package_name}" -qqy
}

# Function to check and clone a Git repository
clone_git_repo() {
    local repo_url=$1
    local repo_dir=$2
    print_message "${YELLOW}" "Cloning repository from ${repo_url}..."
    git clone "${repo_url}" "${repo_dir}"
}

# Function to move files and make them executable
move_and_chmod() {
    local source_file=$1
    local destination=$2
    mv "${source_file}" "${destination}"
    chmod +x "${destination}"
}

# Function to enable and restart services
enable_and_restart_service() {
    local service_name=$1
    systemctl daemon-reload
    systemctl enable "${service_name}"
    systemctl restart "${service_name}"
}

# Configurable variables
ETH=$(ip route get 8.8.8.8 | awk '{printf $5}')
CHISEL_REPO="https://github.com/Talangor/chisel-bash.git"
CHISEL_DEST_DIR="/usr/local/bin"

# Check root access
if [[ $EUID -ne 0 ]]; then
    print_message "${RED}" "Please run this script as root!"
    exit 1
fi

# User inputs
clear
get_user_input "Remote IP Address" "IPADDR"
get_user_input "Remote port" "RPORT"
get_user_input "Remote fingerprint" "FP"

# Install required packages
install_package "dante-server"
install_package "python3"
install_package "git"

# Clone the chisel repository
clone_git_repo "${CHISEL_REPO}" "chisel-bash"
move_and_chmod "chisel-bash/chisel" "${CHISEL_DEST_DIR}/chisel"

# Create proxy.py script
cat <<EOT > /usr/local/bin/proxy.py
# ... (your proxy.py script content) ...
EOT

# Create chisel.sh script
cat <<EOT > /usr/local/bin/chisel.sh
#!/bin/bash
chisel client --fingerprint $FP $IPADDR:$RPORT localhost:3128 1.1.1.1:53/udp
EOT
chmod +x /usr/local/bin/chisel.sh

# Create chisel-cron.sh script
cat <<EOT > /usr/local/bin/chisel-cron.sh
#!/bin/bash
python3 /usr/local/bin/proxy.py
EOT
chmod +x /usr/local/bin/chisel-cron.sh

# Create and configure systemd service for chisel
cat <<EOT > /etc/systemd/system/chisel.service
[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/chisel.sh

[Install]
WantedBy=default.target
EOT

# Enable and start chisel service
enable_and_restart_service "chisel"

# Create and configure dante-server (socks proxy)
cat <<EOT > /etc/danted.conf
errorlog: syslog
internal: $ETH port = 443
external: $ETH
socksmethod: username #rfc931 none
user.privileged: root
user.unprivileged: nobody
client pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: error connect disconnect
        socksmethod: username
}
socks pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        command: connect bind bindreply udpreply
        log: error connect disconnect
        socksmethod: username
}
route {
        from: 0.0.0.0/0 to: 0.0.0.0/0 via: 127.0.0.1 port = 3128
        proxyprotocol: http_v1.0
        command: connect
}
EOT

# Disable and stop systemd-resolved
systemctl mask systemd-resolved
systemctl stop systemd-resolved

# Start dante-server
systemctl start danted

# Configure DNS resolution to use local resolver
echo 'nameserver 127.0.0.1' > /etc/resolv.conf

# Display chisel service status
systemctl status chisel

# Display dante-server status
systemctl status danted
