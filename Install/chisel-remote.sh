#!/bin/bash
# Author: https://github.com/Talangor

# Color variables
WHITE="\e[37m"
BLUE="\e[34m"
MAGENTA="\e[35m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
BLACK="\e[30m"
PINK="\e[38;5;206m"
ORANGE="\e[38;5;208m"
NC="\e[0m"

# Print a colorized message
print_message() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Check if script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message "${RED}" "Please run this script as root!"
        exit 1
    fi
}

# Function to display a progress bar
display_progress() {
    local duration=$1
    local sleep_interval=0.1
    local progress=0
    local bar_length=40

    while [ $progress -lt $duration ]; do
        echo -ne "\r[${YELLOW}"
        for ((i = 0; i < bar_length; i++)); do
            if [ $i -lt $((progress * bar_length / duration)) ]; then
                echo -ne "#"
            else
                echo -ne "-"
            fi
        done
        echo -ne "${RED}] ${progress}%"
        progress=$((progress + 1))
        sleep $sleep_interval
    done
    echo -ne "\r[${YELLOW}"
    for ((i = 0; i < bar_length; i++)); do
        echo -ne "#"
    done
    echo -ne "${RED}] ${progress}%"
    echo
}

# Function to print error message and exit
fail() {
    cleanup
    local msg="$1"
    print_message "${RED}" "Error: ${msg}" 1>&2
    exit 1
}

check_root

# Input port
clear
echo ""
echo -e "${BLUE}PLEASE ENTER YOUR DESIRED PORT (PREFERRED 443):${NC}"
read -r -p "" LPORT
echo -e "${YELLOW}PLEASE WAIT AND CALM IT TAKES 2 MINUTS ${NC}"

# Function to install required packages
install_dependencies() {
    local packages=("curl" "wget" "gzip" "tar" "unzip" "squid")
    print_message "${YELLOW}" "Installing required packages..."
    for package in "${packages[@]}"; do
        apt-get install -y "$package"
    done
    print_message "${GREEN}" "Required packages installed successfully."
}

install_dependencies | display_progress 100

# Function to check for curl or wget
check_curl_or_wget() {
    if command -v curl > /dev/null; then
        GET="curl"
        if [[ $INSECURE = "true" ]]; then GET="$GET --insecure"; fi
        GET="$GET --fail -# -L"
    elif command -v wget > /dev/null; then
        GET="wget"
        if [[ $INSECURE = "true" ]]; then GET="$GET --no-check-certificate"; fi
        GET="$GET -qO-"
    else
        fail "Neither wget nor curl are installed"
    fi
}

# Check dependencies
check_dependency() {
    if ! command -v "$1" > /dev/null; then
        fail "$1 is not installed"
    fi
}

# Check OS and ARCH
check_os_and_arch() {
    case $(uname -s) in
        Darwin) OS="darwin";;
        Linux) OS="linux";;
        *) fail "unknown os: $(uname -s)";;
    esac

    case $(uname -m) in
        *arm64*) ARCH="arm64";;
        *64*) ARCH="amd64";;
        *arm*) ARCH="arm";;
        *386*) ARCH="386";;
        *) fail "unknown arch: $(uname -m)";;
    esac
}

# Check dependencies
check_dependency bash
check_dependency find
check_dependency xargs
check_dependency sort
check_dependency tail
check_dependency cut
check_dependency du
check_curl_or_wget
check_os_and_arch

# Configurable variables
USER="opiran"
PROG="chisel"
MOVE="true"
RELEASE="v1.7.7"
INSECURE="false"
OUT_DIR="/usr/local/bin"
GH="https://github.com"

cleanup() {
    rm -rf "$TMP_DIR"
}

# Move the largest binary from temp dir to destination
move_binary() {
    TMP_BIN=$(find "$TMP_DIR" -type f -exec du -b {} + | sort -n | tail -n 1 | cut -f 2)
    if [[ ! -f "$TMP_BIN" ]]; then
        fail "could not find binary (largest file)"
    fi

    if [[ $(du -m "$TMP_BIN" | cut -f1) -lt 1 ]]; then
        fail "no binary found ($TMP_BIN is not larger than 1MB)"
    fi

    chmod +x "$TMP_BIN" || fail "chmod +x failed"

    if ! mv "$TMP_BIN" "$OUT_DIR/$PROG" 2>&1; then
        if [[ $OUT =~ "Permission denied" ]]; then
            echo "mv with sudo..."
            sudo mv "$TMP_BIN" "$OUT_DIR/$PROG" || fail "sudo mv failed"
        else
            fail "mv failed ($OUT)"
        fi
    fi

    echo "Installed at $OUT_DIR/$PROG"
}

	#choose from asset list
	URL=""
	FTYPE=""
	case "${OS}_${ARCH}" in
	"darwin_amd64")
		URL="https://raw.githubusercontent.com/opiran-club/opiran-panel/main/Install/chisel_1.7.7_darwin_amd64.gz"
		FTYPE=".gz"
		;;
	"darwin_arm64")
		URL="https://raw.githubusercontent.com/opiran-club/opiran-panel/main/Install/chisel_1.7.7_darwin_amd64.gz"
		FTYPE=".gz"
		;;
	"linux_386")
		URL="https://raw.githubusercontent.com/opiran-club/opiran-panel/main/Install/chisel_1.7.7_linux_386.gz"
		FTYPE=".gz"
		;;
	"linux_amd64")
		URL="https://raw.githubusercontent.com/opiran-club/opiran-panel/main/Install/chisel_1.7.7_linux_amd64.gz"
		FTYPE=".gz"
		;;
	"linux_arm64")
		URL="https://raw.githubusercontent.com/opiran-club/opiran-panel/main/Install/chisel_1.7.7_linux_arm64.gz"
		FTYPE=".gz"
		;;
	"linux_arm")
		URL="https://raw.githubusercontent.com/opiran-club/opiran-panel/main/Install/chisel_1.7.7_linux_armv6.gz"
		FTYPE=".gz"
		;;
	*) fail "No asset for platform ${OS}-${ARCH}";;
	esac
	echo -n " $USER/$PROG"
	if [ ! -z "$RELEASE" ]; then
		echo -n " $RELEASE"
	fi

install() {
cat <<EOT > /etc/squid/squid.conf
acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 21		# ftp
acl Safe_ports port 443		# https
acl Safe_ports port 70		# gopher
acl Safe_ports port 210		# wais
acl Safe_ports port 1025-65535	# unregistered ports
acl Safe_ports port 280		# http-mgmt
acl Safe_ports port 488		# gss-http
acl Safe_ports port 591		# filemaker
acl Safe_ports port 777		# multiling http
cache deny all
max_filedesc 4096
http_access allow localhost
include /etc/squid/conf.d/*.conf
http_access allow localhost
http_access deny all
http_port 3128
access_log none
coredump_dir /var/spool/squid
refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern ^gopher:	1440	0%	1440
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern \/(Packages|Sources)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern \/Release(|\.gpg)$ 0 0% 0 refresh-ims
refresh_pattern \/InRelease$ 0 0% 0 refresh-ims
refresh_pattern \/(Translation-.*)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern .		0	20%	4320
visible_hostname uajlxnfg.vm
EOT

CONFIG_FILE="/etc/squid/squid.conf"
if grep -qE "^\s*visible_hostname\s+" "$CONFIG_FILE"; then
	echo "visible_hostname directive found in the configuration file."
else
	echo "Adding visible_hostname directive to the configuration file."
	echo "visible_hostname $HOSTNAME" >> "$CONFIG_FILE"
fi
systemctl enable squid
systemctl restart squid.service
systemctl restart squid
cat <<EOT > /etc/sysctl.conf
fs.file-max = 65535
EOT
sysctl -p
cat <<EOT > /etc/systemd/system/chisel.service
[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/chisel.sh

[Install]
WantedBy=default.target
EOT

systemctl daemon-reload

cat <<EOT > /usr/local/bin/chisel.sh
#!/bin/bash
chisel server --key $RAND -p $LPORT
EOT

chmod +x /usr/local/bin/chisel.sh
systemctl enable chisel
systemctl restart chisel
systemctl status chisel
}

# Call the main install function
install
