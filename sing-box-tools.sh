#!/bin/bash
# sing-box-tools.sh - A simple tool to manage the Sing Box
# Supports setup, reset, status, start, stop, restart, tunnel operations.
# It also supports the -y flag to automatically execute commands without prompts, and -h for help.

# Define
INSTALL_DIR="${INSTALL_DIR:-"$HOME/sing-box"}"
BIN_DIR="${BIN_DIR:-"$INSTALL_DIR/bin"}"
BIN_FILE="$BIN_DIR/sing-box"
BIN_FILE_CLOUDFLARED="$BIN_DIR/cloudflared"
LOG_DISABLED="${LOG_DISABLED:-true}"
LOG_LEVEL="${LOG_LEVEL:-info}"
LOG_TIMESTAMP="${LOG_TIMESTAMP:-true}"
LOG_DIR="${LOG_DIR:-"$INSTALL_DIR/logs"}"
LOG_OUTPUT="$LOG_DIR/sing-box.log"
LOG_OUTPUT_CLOUDFLARED="$LOG_DIR/cloudflared.log"
SSL_DIR="${SSL_DIR:-"$INSTALL_DIR/ssl"}"
CONFIG_DIR="${CONFIG_DIR:-"$INSTALL_DIR/conf"}"
CONFIG_FILE_SINGBOX="${CONFIG_FILE_SINGBOX:-"$CONFIG_DIR/config.json"}"

# Function: echo_color
# Purpose: Echo text with customizable color and optional newline control.
# Usage: echo_color -n [-red | -blue | ...] "Hello World"
# Options:
#   -n       : Option to not add a newline after the text.
#   -red     : Red text color.
#   -green   : Green text color.
#   -yellow  : Yellow text color.
#   -blue    : Blue text color.
#   -magenta : Magenta text color.
#   -cyan    : Cyan text color.
#   -white   : White text color.
# Example:
#   echo_color -n -red "This is red without newline"
#   echo_color -blue "This is blue with newline"
echo_color() {
    local text=""        # The text to be echoed
    local color_code="0" # Default color code, which is reset, i.e., no color
    local newline=true   # Default to add a newline after the text

    # Parse options
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        -n) newline=false ;; # Do not add a newline

        -red) color_code="31" ;;     # 红色
        -green) color_code="32" ;;   # 绿色
        -yellow) color_code="33" ;;  # 黄色
        -blue) color_code="34" ;;    # 蓝色
        -magenta) color_code="35" ;; # 品红色
        -cyan) color_code="36" ;;    # 青色
        -white) color_code="37" ;;   # 白色
        *)
            # Stop parsing options when an invalid option is encountered
            break
            ;;
        esac
        shift
    done

    # Get the text to be echoed
    text="${@}"

    # Echo the text with the selected color, and add a newline if required
    if [[ "$newline" == true ]]; then
        echo -e "\033[${color_code}m${text}\033[0m"
    else
        echo -n -e "\033[${color_code}m${text}\033[0m"
    fi
}

# Function: read_color
# Purpose: Read user input with customizable color and optional prompt.
# Usage: read_color [-red | -blue | ...] ["Enter your name:"] name
# Options:
#   -red     : Red text color.
#   -green   : Green text color.
#   -yellow  : Yellow text color.
#   -blue    : Blue text color.
#   -magenta : Magenta text color.
#   -cyan    : Cyan text color.
#   -white   : White text color.
# Example:
#   read_color -blue "Enter your name:" name
read_color() {
    local prompt=""      # The prompt to be displayed
    local color_code="0" # Default color code, which is reset, i.e., no color

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        -red) color_code="31" ;;     # 红色
        -green) color_code="32" ;;   # 绿色
        -yellow) color_code="33" ;;  # 黄色
        -blue) color_code="34" ;;    # 蓝色
        -magenta) color_code="35" ;; # 品红色
        -cyan) color_code="36" ;;    # 青色
        -white) color_code="37" ;;   # 白色
        *)
            break
            ;;
        esac
        shift
    done

    prompt="${1}"
    read -p $'\033['"${color_code}"'m'"${prompt}"$'\033[0m ' "${@:2}"
}

# Function: gen_random_string
# Purpose: Generate a random string, given the length and character set, charset and length are optional.
# Usage: gen_random_string [--charset=<charset>] [--length=<length>]
# Options:
#   --charset=<charset> : Character set to generate the random string (default: A-Za-z0-9).
#   --length=<length>   : Length of the random string (default: 8).
# Example:
#   gen_random_string # Default random string, 8 characters long, alphanumeric
#   gen_random_string --charset='A-Za-z0-9!@#$%^&*()_+' --length=8 # Special characters in charset
#   gen_random_string --charset='A-Za-z'\''0-9' --length=8 # Single quote in charset
gen_random_string() {
    local charset="A-Za-z0-9" # Default charset: Alphanumeric (letters + digits)
    local length=8            # Default length

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --charset=*) charset="${1#--charset=}" ;;
        --length=*) length="${1#--length=}" ;;
        esac
        shift
    done

    charset="${charset//A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ}"
    charset="${charset//a-z/abcdefghijklmnopqrstuvwxyz}"
    charset="${charset//0-9/0123456789}"

    local random_string=""
    for i in $(seq 1 "$length"); do
        rand_index=$((RANDOM % ${#charset}))
        random_char="${charset:$rand_index:1}"
        random_string+="$random_char"
    done

    echo "$random_string"
}

# Function: gen_uuid_v4
# Purpose: Generate a random UUID of version 4, adhering to the RFC 4122 standard.
# Usage: gen_uuid_v4
# Options: None
# Example:
#   gen_uuid_v4 # Generate a random UUID v4
# UUID v4 Format:
#   xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
#     - The first three segments are random characters: 8 characters, 4 characters, and 4 characters.
#     - The third segment starts with a "4" to indicate the version (UUID v4).
#     - The fourth segment starts with a value between 8 and b, representing the variant.
#     - The final segment is random, with 12 characters.
gen_uuid_v4() {
    local part1=$(gen_random_string --charset="abcdef0-9" --length=8)                                                 # First part (8 characters)
    local part2=$(gen_random_string --charset="abcdef0-9" --length=4)                                                 # Second part (4 characters)
    local part3="4$(gen_random_string --charset="abcdef0-9" --length=3)"                                              # Third part (4 characters, version is 4)
    local part4=$(gen_random_string --charset="89ab" --length=1)$(gen_random_string --charset="abcdef0-9" --length=3) # Fourth part (4 characters, 8-9-a-b for variant)
    local part5=$(gen_random_string --charset="abcdef0-9" --length=12)                                                # Fifth part (12 characters)
    echo "$part1-$part2-$part3-$part4-$part5"
}

# Function: get_system_info
# Purpose: Retrieve the operating system name and system architecture.
# Usage: read os arch <<< "$(get_system_info)"
# Output:
#   - First value: Operating system name (e.g., linux, darwin, freebsd).
#   - Second value: System architecture (e.g., x86_64, arm64, i386).
# Example:
#   read os arch <<< "$(get_system_info)"
#   echo "OS: $os, Arch: $arch"
get_system_info() {
    local os_name=$(uname -s | tr '[:upper:]' '[:lower:]') # Get the operating system name in lowercase, e.g., linux, darwin, freebsd
    local arch=$(uname -m)                                 # Get the system architecture, e.g., x86_64, arm64, i386
    echo "$os_name $arch"                                  # Output the operating system name and system architecture separated by a space
}

# Function: check_and_install_deps
# Purpose: Check if the given dependencies are installed and prompt the user to install missing ones.
# Arguments:
#   - List of dependencies (commands) to check.
# Usage: check_and_install_deps curl git vim
# Output:
#   - If dependencies are missing, prompts the user to install them.
#   - Supports installation through apt-get, yum, or brew based on available package managers.
# Example:
#   check_and_install_deps curl git vim
check_and_install_deps() {
    local dependencies=("$@")
    local missing_dependencies=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_dependencies+=("$dep")
        fi
    done

    if [ ${#missing_dependencies[@]} -gt 0 ]; then
        echo_color -yellow "Missing dependencies: ${missing_dependencies[*]}"
        prompt_info="Do you want to install them now? (Y/n): "
        if [[ "$auto_confirm" == true ]]; then
            echo_color -n -yellow "$prompt_info" && echo_color -green "(Auto confirm)"
        else
            read_color -yellow "$prompt_info" -r
            [[ -n $REPLY && ! $REPLY =~ ^[Yy]$ ]] && echo_color -red "Canceled." && exit 1
        fi

        local pkg_manager=""
        local update_cmd=""
        if command -v apt-get &>/dev/null; then
            pkg_manager="apt-get install -y"
            update_cmd="apt-get update"
        elif command -v yum &>/dev/null; then
            pkg_manager="yum install -y"
            update_cmd=""
        elif command -v brew &>/dev/null; then
            pkg_manager="brew install"
            update_cmd="brew update"
        elif command -v apk &>/dev/null; then
            pkg_manager="apk add"
            update_cmd="apk update"
        else
            echo_color -red "Package manager not found! Please install missing dependencies manually."
            exit 1
        fi

        [[ -n "$update_cmd" ]] && $update_cmd

        for dep in "${missing_dependencies[@]}"; do
            echo_color -yellow "Installing $dep..."
            if ! $pkg_manager "$dep"; then
                echo_color -red "Failed to install $dep. Please install it manually."
                exit 1
            fi
            echo_color -green "Successfully installed $dep."
        done
    fi
}

# Function: get_latest_release_version
# Purpose: Fetch and return the latest release version from a GitHub repository.
# Usage: latest_version=$(get_latest_release_version <repository_name>)
# Parameters:
#   <repository_name>: GitHub repository in the form "owner/repository" (e.g., "SagerNet/sing-box").
# Output:
#   The latest release version (e.g., "v1.11.0")
# Example:
#   latest_version=$(get_latest_release_version "SagerNet/sing-box")
#   echo "Latest version: $latest_version"
get_latest_release_version() {
    local repository_name="$1"

    latest_version=$(curl -Ls "https://github.com/$repository_name/releases/latest" |
        grep -oE "$repository_name/releases/tag/[^\"]+" |
        head -1 |
        awk -F'/' '{print $NF}')

    if [ -z "$latest_version" ]; then
        echo_color -red "Failed to fetch the latest release version."
        return 1
    fi

    echo "$latest_version"
}

# Function: download_release_file
# Purpose: Download a specific release file from GitHub releases.
# Usage: download_release_file <repository_name> <version> <file_name> <destination_path>
# Parameters:
#   <repository_name>: GitHub repository in the form "owner/repository" (e.g., "SagerNet/sing-box").
#   <version>: Release version in the format "v1.0.0".
#   <file_name>: Name of the release file to download (e.g., "sing-box-v1.0.0-linux-x86_64.tar.gz").
#   <destination_path>: Destination path to save the downloaded file (e.g., "/tmp/sing-box-v1.0.0-linux-x86_64.tar.gz").
# Example:
#   download_release_file "SagerNet/sing-box" "v1.0.0" "sing-box-v1.0.0-linux-x86_64.tar.gz" "/tmp/sing-box-v1.0.0-linux-x86_64.tar.gz"
download_release_file() {
    local repo="$1"
    local version="$2"
    local file_name="$3"
    local destination="$4"

    local download_url="https://github.com/$repo/releases/download/$version/$file_name"
    echo "Downloading $file_name from $download_url to $destination..."

    if [[ -f "$destination" ]]; then
        echo_color -yellow "File already exists: $destination"
        prompt_info="Are you sure you want to redownload it? (y/N): "
        if [[ "$auto_confirm" == true ]]; then
            echo_color -n -yellow "$prompt_info" && echo_color -green "(Auto confirm)"
            return 0
        else
            read_color -yellow "$prompt_info" -r
            [[ -z $REPLY || ! $REPLY =~ ^[Yy]$ ]] && return 0
        fi

        rm -f "$destination"
    fi

    if ! curl -L --fail "$download_url" -o "$destination"; then
        echo_color -red "Download failed!"
        exit 1
    fi

    echo "Download successful!"
}

# Function: download_source_code_file
# Purpose: Download a specific source code file from GitHub repository.
# Usage: download_source_code_file <repository_name> <file_name> <destination_path>
# Parameters:
#   <repository_name>: GitHub repository in the form "owner/repository" (e.g., "SagerNet/sing-box").
#   <file_name>: Name of the source code file to download (e.g., "v1.0.0.tar.gz").
#   <destination_path>: Destination path to save the downloaded file (e.g., "/tmp/v1.0.0.tar.gz").
# Example:
#   download_source_code_file "SagerNet/sing-box" "v1.0.0.tar.gz" "/tmp/v1.0.0.tar.gz"
download_source_code_file() {
    local repo="$1"
    local file_name="$2"
    local destination="$3"

    local download_url="https://github.com/$repo/archive/refs/tags/$file_name"
    echo "Downloading source code file from $download_url to $destination..."

    if [[ -f "$destination" ]]; then
        echo_color -yellow "File already exists: $destination"
        prompt_info="Are you sure you want to redownload it? (y/N): "
        if [[ "$auto_confirm" == true ]]; then
            echo_color -n -yellow "$prompt_info" && echo_color -green "(Auto confirm)"
            return 0
        else
            read_color -yellow "$prompt_info" -r
            [[ -z $REPLY || ! $REPLY =~ ^[Yy]$ ]] && return 0
        fi

        rm -f "$destination"
    fi

    if ! curl -L --fail "$download_url" -o "$destination"; then
        echo_color -red "Download failed!"
        exit 1
    fi

    echo "Download successful!"
}

# Function: generate_ssl_cert
# Purpose: Generate a self-signed SSL certificate
# Usage: generate_ssl_cert --domain=<domain> --days=<days> --key_path=<key_path> --cert_path=<cert_path>
# Options:
#   --domain=<domain>   : Domain name for the SSL certificate (default: www.cloudflare.com).
#   --days=<days>       : Number of days the certificate is valid (default: 36500).
#   --key_path=<key_path> : Path to save the private key file (default: ./<domain>.key).
#   --cert_path=<cert_path>: Path to save the certificate file (default: ./<domain>.crt).
# Example:
#   generate_ssl_cert --domain=example.com --days=365
generate_ssl_cert() {
    local domain="www.cloudflare.com" # Default domain name
    local days=36500                  # Default number of days the certificate is valid
    local key_path="./${domain}.key"  # Default path to save the private key file
    local cert_path="./${domain}.crt" # Default path to save the certificate file

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --domain=*) domain="${1#--domain=}" ;;
        --days=*) days="${1#--days=}" ;;
        --key_path=*) key_path="${1#--key_path=}" ;;
        --cert_path=*) cert_path="${1#--cert_path=}" ;;
        esac
        shift
    done

    openssl req -new -newkey rsa:2048 -days "$days" -nodes -x509 -keyout "$key_path" -out "$cert_path" -subj "/CN=$domain" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo_color -red "Failed to generate SSL certificate."
        exist 1
    fi
}

install_app() {
    if [[ -d "$INSTALL_DIR" ]]; then
        echo_color -yellow "Installation directory already exists: $INSTALL_DIR"
        prompt_info="Are you sure you want to reinstall the application? (Y/n): "
        if [[ "$auto_confirm" == true ]]; then
            echo_color -n -yellow "$prompt_info" && echo_color -green "(Auto confirm)"
        else
            read_color -yellow "$prompt_info" -r
            [[ -n "$REPLY" && ! $REPLY =~ ^[Yy]$ ]] && echo_color -red "Canceled." && exit 1
        fi
    fi
    mkdir -p "$BIN_DIR"

    app_repo="SagerNet/sing-box"
    if [[ -z "$SINGBOX_VERSION" ]]; then
        if ! SINGBOX_VERSION=$(get_latest_release_version "$app_repo"); then
            echo_color -red "Failed to fetch the latest release version, need to manually input the version."
        else
            echo_color "Latest release version: $SINGBOX_VERSION"
            prompt_info="Do you want to install the latest release version? (Y/n): "
            if [[ "$auto_confirm" == true ]]; then
                echo_color -n -yellow "$prompt_info" && echo_color -green "(Auto confirm)"
            else
                read_color -yellow "$prompt_info" -r
                [[ -n $REPLY && ! $REPLY =~ ^[Yy]$ ]] && SINGBOX_VERSION=""
            fi
        fi

        if [[ -z "$SINGBOX_VERSION" ]]; then
            read_color -blue "Enter the release version you want to install (e.g., v1.0.0): " SINGBOX_VERSION
        fi
    fi
    echo_color -blue "Installing version: $SINGBOX_VERSION"

    read os arch <<<"$(get_system_info)"
    arch="${arch/x86_64/amd64}"
    echo_color -blue "Operating system: $os, System architecture: $arch"
    if [[ "$os" != "darwin" && "$os" != "linux" ]] || [[ "$arch" != "amd64" && "$arch" != "arm64" ]]; then
        # Define the application source code file name based on the version number
        app_file="${SINGBOX_VERSION}.tar.gz"
        # Download the application source code file
        download_source_code_file "$app_repo" "$app_file" "/tmp/$app_file"
        # Extract the application source code file
        rm -rf "/tmp/sing-box-${SINGBOX_VERSION#v}"
        tar -xzf "/tmp/$app_file" -C "/tmp"
        # Make
        cd "/tmp/sing-box-${SINGBOX_VERSION#v}"
        if ! make VERSION="${SINGBOX_VERSION#v}" >/dev/null; then
            echo_color -red "Build failed!"
            exit 1
        fi
        # Move to the bin directory
        mv "/tmp/sing-box-${SINGBOX_VERSION#v}/sing-box" "$BIN_DIR"
    else
        # Define the application file name based on the operating system and system architecture
        app_file="sing-box-${SINGBOX_VERSION#v}-$os-$arch.tar.gz"
        # Download the application release file
        download_release_file "$app_repo" "$SINGBOX_VERSION" "$app_file" "/tmp/$app_file"
        # Extract the application release file to the bin directory
        tar -xzf "/tmp/$app_file" -C "$BIN_DIR" --strip-components=1
    fi

    echo_color -green "Application installed to: $INSTALL_DIR"
}

# Function: uninstall_app
# Purpose: Uninstall the application.
uninstall_app() {
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo_color -yellow "Application not installed."
        return 0
    fi

    rm -rf "$INSTALL_DIR"
    echo_color -green "Application uninstalled."
}

start_singbox() {
    [[ ! -f "$BIN_FILE" ]] && echo_color -red "Sing-box binary file not found: $BIN_FILE" && exit 1

    if pgrep -f "$BIN_FILE" >/dev/null; then
        echo_color -yellow "Sing-box service is already running."
        return 0
    fi

    nohup "$BIN_FILE" run -c "$CONFIG_FILE_SINGBOX" >/dev/null 2>&1 &
    while ! pgrep -f "$BIN_FILE" >/dev/null; do
        echo_color -yellow "Waiting for sing-box service to start..."
        sleep 1
    done

    echo_color -green "Sing-box service started."
}

stop_singbox() {
    if ! pgrep -f "$BIN_FILE" >/dev/null; then
        echo_color -yellow "Sing-box service is not running."
        return 0
    fi

    pkill -f "$BIN_FILE"
    while pgrep -f "$BIN_FILE" >/dev/null; do
        echo_color -yellow "Waiting for sing-box service to stop..."
        sleep 1
    done

    echo_color -green "Sing-box service stopped."
}

show_status() {
    echo -n "      Application Status: "
    if [[ -x "$INSTALL_DIR" ]]; then
        if [[ -f "$BIN_FILE" ]]; then
            echo_color -green "Installed (v"$("$BIN_FILE" version | head -n 1 | awk '{print $3}')")"
        else
            echo_color -red "Binary Missing"
        fi
    else
        echo_color -red "Uninstalled"
    fi

    echo -n "      Config File Status: "
    if [[ -f "$CONFIG_FILE_SINGBOX" ]]; then
        echo_color -green "Exists"
    else
        echo_color -red "Missing"
    fi

    echo -n "          Service Status: "
    if pgrep -f "$BIN_FILE" >/dev/null; then
        echo_color -green "Running"
    else
        echo_color -red "Stopped"
    fi

    if [[ -f "$BIN_FILE_CLOUDFLARED" ]]; then
        echo -n "Cloudflare Tunnel Status: "
        if pgrep -f "$BIN_FILE_CLOUDFLARED" >/dev/null; then
            echo_color -n -green "Running"
            local tunnel_domain=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG_OUTPUT_CLOUDFLARED" | head -n 1 | sed 's|https://||')
            local local_tunnel_url=$(grep 'Settings:' "$LOG_OUTPUT_CLOUDFLARED" | sed -n 's/.*url:\([^] ]*\).*/\1/p')
            echo_color -green " ($tunnel_domain -> $local_tunnel_url)"
        else
            echo_color -red "Stopped"
        fi
    fi
}

# Function: show_config
# Purpose: Show the configuration file content.
show_config() {
    [[ -f "$CONFIG_FILE_SINGBOX" ]] || {
        echo_color -red "Config file not exists."
        return 0
    }

    echo_color -cyan "Configuration File: $CONFIG_FILE_SINGBOX"
    echo_color -yellow "Last Modified: $(date -r "$CONFIG_FILE_SINGBOX" "+%Y-%m-%d %H:%M:%S")"

    command -v jq >/dev/null 2>&1 && jq . "$CONFIG_FILE_SINGBOX" || cat "$CONFIG_FILE_SINGBOX"
}

# Function: show_nodes
# Purpose: Show the node configurations from the inbound section of the config file.
show_nodes() {
    [[ -f "$CONFIG_FILE_SINGBOX" ]] || {
        echo_color -red "Config file not exists."
        return 0
    }

    echo_color -cyan "Config File: $CONFIG_FILE_SINGBOX"
    echo_color -yellow "Last Modified: $(date -r "$CONFIG_FILE_SINGBOX" "+%Y-%m-%d %H:%M:%S")"

    local count=$(jq '.inbounds | length' "$CONFIG_FILE_SINGBOX")
    echo_color -green "Total inbounds: $count"
    ((count == 0)) && return 0

    local node_name=$(hostname)

    local ip4=$(curl -4 -s ip.sb || echo "")
    [[ -n "$ip4" ]] && {
        echo_color -green "\nIPv4 Nodes:" $ip4
        output_nodes "$ip4" "$node_name"
    }

    local ip6=$(curl -6 -s ip.sb || echo "")
    [[ "$ip6" == *:* ]] && ip6="[$ip6]" || ip6=""
    [[ -n "$ip6" ]] && {
        echo_color -green "\nIPv6 Nodes:" $ip6
        output_nodes "$ip6" "$node_name"
    }

    [[ -f "$LOG_OUTPUT_CLOUDFLARED" ]] && {
        local tunnel_domain=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG_OUTPUT_CLOUDFLARED" | head -n 1 | sed 's|https://||')
        [[ -n "$tunnel_domain" ]] && {
            echo_color -green "\nCloudflare Tunnel Nodes:" $tunnel_domain
            output_nodes "$tunnel_domain" "$node_name"
        }
    }
}

# Function: output_nodes
# Purpose: Output links using given IP and node name
output_nodes() {
    local ip="$1"
    local node_name="$2"

    jq -c '.inbounds[]' "$CONFIG_FILE_SINGBOX" | while read -r inbound; do
        local type=$(echo "$inbound" | jq -r '.type')
        local port=$(echo "$inbound" | jq -r '.listen_port')
        local sni=$(echo "$inbound" | jq -r '.tls.server_name // empty')
        local host=$(echo "$inbound" | jq -r '.transport.headers.host // empty')
        local path=$(echo "$inbound" | jq -r '.transport.path // "/"')
        local uuid=$(echo "$inbound" | jq -r '.users[0].uuid // empty')
        local user=$(echo "$inbound" | jq -r '.users[0].username // empty')
        local pass=$(echo "$inbound" | jq -r '.users[0].password // empty')

        [[ "$ip" == *"trycloudflare"* ]] && {
            local local_tunnel_port=$(grep 'Settings:' "$LOG_OUTPUT_CLOUDFLARED" | sed -n 's/.*url:[^:]*:\/\/[^:]*:\([0-9]*\).*/\1/p')
            [[ -z "$local_tunnel_port" || "$local_tunnel_port" != "$port" ]] && continue

            port=443
            sni="$ip"
            host="$ip"
        }

        case "$type" in
        socks)
            echo "socks://$(echo -n "$user:$pass" | base64)@$ip:$port#$node_name"
            ;;
        vless)
            echo "vless://$uuid@$ip:$port?security=tls&sni=$sni&fp=chrome&allowInsecure=1&type=ws&host=$host&path=$path#$node_name"
            ;;
        vmess)
            echo "vmess://$uuid@$ip:$port?security=tls&sni=$sni&fp=chrome&allowInsecure=1&type=ws&host=$host&path=$path#$node_name"
            ;;
        trojan)
            echo "trojan://$pass@$ip:$port?security=tls&sni=$sni&fp=chrome&allowInsecure=1&type=ws&host=$host&path=$path#$node_name"
            ;;
        hysteria2)
            echo "hysteria2://$pass@$ip:$port?sni=$sni&insecure=1#$node_name"
            ;;
        tuic)
            echo "tuic://$uuid:$pass@$ip:$port?sni=$sni&alpn=h3&congestion_control=bbr&insecure=1#$node_name"
            ;;
        anytls)
            echo "anytls://$pass@$ip:$port?security=tls&sni=$sni#$node_name"
            ;;
        esac
    done
}

gen_singbox_config() {
    if [[ -f "$CONFIG_FILE_SINGBOX" ]]; then
        echo_color -yellow "Configuration file already exists: $CONFIG_FILE_SINGBOX"
        prompt_info="Are you sure you want to overwrite it? (Y/n): "
        if [[ "$auto_confirm" == true ]]; then
            echo_color -n -yellow "$prompt_info" && echo_color -green "(Auto confirm)"
        else
            read_color -yellow "$prompt_info" -r
            [[ -n $REPLY && ! $REPLY =~ ^[Yy]$ ]] && return 0
        fi
    fi

    mkdir -p "$CONFIG_DIR"

    echo -e "$(gen_singbox_config_content)" >"$CONFIG_FILE_SINGBOX"
    echo_color -green "Configuration file generated: $CONFIG_FILE_SINGBOX"
}

gen_singbox_config_content() {
    config_content='{
    "log": {
        "disabled": '$LOG_DISABLED',
        "level": "'$LOG_LEVEL'",
        "output": "'$LOG_OUTPUT'",
        "timestamp": '$LOG_TIMESTAMP'
    },
    "inbounds": ['

    [[ -n "$S5_PORT" ]] && config_content+=$(generate_socks5_inbound)","
    [[ -n "$HY2_PORT" ]] && config_content+=$(generate_hysteria2_inbound)","
    [[ -n "$TUIC_PORT" ]] && config_content+=$(generate_tuic_inbound)","
    [[ -n "$VLESS_PORT" ]] && config_content+=$(generate_vless_inbound)","
    [[ -n "$VMESS_PORT" ]] && config_content+=$(generate_vmess_inbound)","
    [[ -n "$TROJAN_PORT" ]] && config_content+=$(generate_trojan_inbound)","
    [[ -n "$ANYTLS_PORT" ]] && config_content+=$(generate_anytls_inbound)","

    config_content=$(echo "$config_content" | sed '$s/,$//')
    config_content+='],
    "outbounds": [
        {
            "type": "direct"
        }
    ]
}
'

    echo -e "$config_content"
}

# Function: generate_socks5_inbound
# Purpose: Generate the socks5 inbound configuration.
# Usage: generate_socks5_inbound --port=<port> --username=<username> --password=<password>
# Options:
#   --port=<port>        : Port number for the socks5 inbound, default is 10240.
#   --username=<username>: Username for the socks5 inbound, default is a random string.
#   --password=<password>: Password for the socks5 inbound, default is a random string.
# Example:
#   generate_socks5_inbound --port=10240 --username=user --password=password
generate_socks5_inbound() {
    local port="${S5_PORT:-10240}"
    local username="${S5_USERNAME:-$(gen_random_string --length=6 --charset=a-z)}"
    local password="${S5_PASSWORD:-$(gen_random_string --length=8 --charset=A-Za-z0-9@_)}"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --username=*) username="${1#--username=}" ;;
        --password=*) password="${1#--password=}" ;;
        esac
        shift
    done

    echo '{
        "type": "socks",
        "listen": "::",
        "listen_port": '"$port"',
        "users": [
            {
                "username": "'"$username"'",
                "password": "'"$password"'"
            }
        ]
    }'
}

# Function: generate_hysteria2_inbound
# Purpose: Generate the hysteria2 inbound configuration.
# Usage: generate_hysteria2_inbound --port=<port> --password=<password> --server_name=<server_name>
# Options:
#   --port=<port>        : Port number for the hysteria2 inbound, default is 10240.
#   --password=<password>: Password for the hysteria2 inbound.
#   --server_name=<server_name>: Server name for the hysteria2 inbound, default is www.cloudflare.com.
# Example:
#   generate_hysteria2_inbound --port=10240 --password=password --server_name=www.cloudflare.com
generate_hysteria2_inbound() {
    local port="${HY2_PORT:-10240}"
    local password="${HY2_PASSWORD:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${HY2_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --password=*) password="${1#--password=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        esac
        shift
    done

    mkdir -p "$SSL_DIR"
    generate_ssl_cert --domain="$server_name" --key_path="$SSL_DIR/${server_name}.key" --cert_path="$SSL_DIR/${server_name}.crt"

    echo '{
        "type": "hysteria2",
        "listen": "::",
        "listen_port": '"$port"',
        "users": [
            {
                "password": "'"$password"'"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "'"$server_name"'",
            "key_path": "'"$SSL_DIR/${server_name}.key"'",
            "certificate_path": "'"$SSL_DIR/${server_name}.crt"'"
        }
    }'
}

# Function: generate_vless_inbound
# Purpose: Generate the vless inbound configuration.
# Usage: generate_vless_inbound --port=<port> --uuid=<uuid> --server_name=<server_name>
# Options:
#   --port=<port>        : Port number for the vless inbound, default is 10240.
#   --uuid=<uuid>        : UUID for the vless inbound.
#   --server_name=<server_name>: Server name for the vless inbound, default is www.cloudflare.com.
# Example:
#   generate_vless_inbound --port=10240 --uuid=uuid --server_name=www.cloudflare.com
generate_vless_inbound() {
    local port="${VLESS_PORT:-10240}"
    local uuid="${VLESS_UUID:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${VLESS_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"
    local transport_path="${VLESS_PATH:-/vless}"
    local transport_host="${VLESS_HOST:-$server_name}"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --uuid=*) uuid="${1#--uuid=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        --path=*) transport_path="${1#--path=}" ;;
        --host=*) transport_host="${1#--host=}" ;;
        esac
        shift
    done

    mkdir -p "$SSL_DIR"
    generate_ssl_cert --domain="$server_name" --key_path="$SSL_DIR/${server_name}.key" --cert_path="$SSL_DIR/${server_name}.crt"

    echo '{
        "type": "vless",
        "listen": "::",
        "listen_port": '"$port"',
        "users": [
            {
                "uuid": "'"$uuid"'"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "'"$server_name"'",
            "key_path": "'"$SSL_DIR/${server_name}.key"'",
            "certificate_path": "'"$SSL_DIR/${server_name}.crt"'"
        },
        "multiplex": {
            "enabled": true
        },
        "transport": {
            "type": "ws",
            "path": "'"$transport_path"'",
            "headers": {
                "host": "'"$transport_host"'"
            },
            "max_early_data": 2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
        }
    }'
}

# Function: generate_vmess_inbound
# Purpose: Generate the vmess inbound configuration.
# Usage: generate_vmess_inbound --port=<port> --uuid=<uuid> --server_name=<server_name>
# Options:
#   --port=<port>        : Port number for the vmess inbound, default is 10240.
#   --uuid=<uuid>        : UUID for the vmess inbound.
#   --server_name=<server_name>: Server name for the vmess inbound, default is www.cloudflare.com.
# Example:
#   generate_vmess_inbound --port=10240 --uuid=uuid --server_name=www.cloudflare.com
generate_vmess_inbound() {
    local port="${VMESS_PORT:-10240}"
    local uuid="${VMESS_UUID:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${VMESS_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"
    local transport_path="${VMESS_PATH:-/}"
    local transport_host="${VMESS_HOST:-$server_name}"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --uuid=*) uuid="${1#--uuid=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        --path=*) transport_path="${1#--path=}" ;;
        --host=*) transport_host="${1#--host=}" ;;
        esac
        shift
    done

    mkdir -p "$SSL_DIR"
    generate_ssl_cert --domain="$server_name" --key_path="$SSL_DIR/${server_name}.key" --cert_path="$SSL_DIR/${server_name}.crt"

    echo '{
        "type": "vmess",
        "listen": "::",
        "listen_port": '"$port"',
        "users": [
            {
                "uuid": "'"$uuid"'"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "'"$server_name"'",
            "key_path": "'"$SSL_DIR/${server_name}.key"'",
            "certificate_path": "'"$SSL_DIR/${server_name}.crt"'"
        },
        "multiplex": {
            "enabled": true
        },
        "transport": {
            "type": "ws",
            "path": "'"$transport_path"'",
            "headers": {
                "host": "'"$transport_host"'"
            },
            "max_early_data": 2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
        }
    }'
}

# Function: generate_trojan_inbound
# Purpose: Generate the trojan inbound configuration.
# Usage: generate_trojan_inbound --port=<port> --password=<password> --server_name=<server_name>
# Options:
#   --port=<port>        : Port number for the trojan inbound, default is 10240.
#   --password=<password>: Password for the trojan inbound.
#   --server_name=<server_name>: Server name for the trojan inbound, default is www.cloudflare.com.
# Example:
#   generate_trojan_inbound --port=10240 --password=password --server_name=www.cloudflare.com
generate_trojan_inbound() {
    local port="${TROJAN_PORT:-10240}"
    local password="${TROJAN_PASSWORD:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${TROJAN_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"
    local transport_path="${TROJAN_PATH:-/trojan}"
    local transport_host="${TROJAN_HOST:-$server_name}"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --password=*) password="${1#--password=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        --path=*) transport_path="${1#--path=}" ;;
        --host=*) transport_host="${1#--host=}" ;;
        esac
        shift
    done

    mkdir -p "$SSL_DIR"
    generate_ssl_cert --domain="$server_name" --key_path="$SSL_DIR/${server_name}.key" --cert_path="$SSL_DIR/${server_name}.crt"

    echo '{
        "type": "trojan",
        "listen": "::",
        "listen_port": '"$port"',
        "users": [
            {
                "password": "'"$password"'"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "'"$server_name"'",
            "key_path": "'"$SSL_DIR/${server_name}.key"'",
            "certificate_path": "'"$SSL_DIR/${server_name}.crt"'"
        },
        "multiplex": {
            "enabled": true
        },
        "transport": {
            "type": "ws",
            "path": "'"$transport_path"'",
            "headers": {
                "host": "'"$transport_host"'"
            },
            "max_early_data": 2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
        }
    }'
}

# Function: generate_anytls_inbound
# Purpose: Generate the anytls inbound configuration.
# Usage: generate_anytls_inbound --port=<port> --password=<password> --server_name=<server_name>
# Options:
#   --port=<port>        : Port number for the anytls inbound, default is 10240.
#   --password=<password>: Password for the anytls inbound.
#   --server_name=<server_name>: Server name for the anytls inbound, default is www.cloudflare.com.
# Example:
#   generate_anytls_inbound --port=10240 --password=password --server_name=www.cloudflare.com
generate_anytls_inbound() {
    local port="${ANYTLS_PORT:-10240}"
    local password="${ANYTLS_PASSWORD:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${ANYTLS_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --password=*) password="${1#--password=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        esac
        shift
    done

    mkdir -p "$SSL_DIR"
    generate_ssl_cert --domain="$server_name" --key_path="$SSL_DIR/${server_name}.key" --cert_path="$SSL_DIR/${server_name}.crt"

    echo '{
        "type": "anytls",
        "listen": "::",
        "listen_port": '"$port"',
        "users": [
            {
                "password": "'"$password"'"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "'"$server_name"'",
            "key_path": "'"$SSL_DIR/${server_name}.key"'",
            "certificate_path": "'"$SSL_DIR/${server_name}.crt"'"
        }
    }'
}

# Function: generate_tuic_inbound
# Purpose: Generate the tuic inbound configuration.
# Usage: generate_tuic_inbound --port=<port> --uuid=<uuid> --password=<password> --server_name=<server_name>
# Options:
#   --port=<port>        : Port number for the tuic inbound, default is 10240.
#   --uuid=<uuid>        : UUID for the tuic inbound.
#   --password=<password>: Password for the tuic inbound, default is empty string.
#   --server_name=<server_name>: Server name for the tuic inbound, default is www.cloudflare.com.
# Example:
#   generate_tuic_inbound --port=10240 --uuid=uuid --password=password --server_name=www.cloudflare.com
generate_tuic_inbound() {
    local port="${TUIC_PORT:-10240}"
    local uuid="${TUIC_UUID:-${UUID:-$(gen_uuid_v4)}}"
    local password="${TUIC_PASSWORD:-}"
    local server_name="${TUIC_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --uuid=*) uuid="${1#--uuid=}" ;;
        --password=*) password="${1#--password=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        esac
        shift
    done

    mkdir -p "$SSL_DIR"
    generate_ssl_cert --domain="$server_name" --key_path="$SSL_DIR/${server_name}.key" --cert_path="$SSL_DIR/${server_name}.crt"

    echo '{
        "type": "tuic",
        "listen": "::",
        "listen_port": '"$port"',
        "users": [
            {
                "uuid": "'"$uuid"'",
                "password": "'"$password"'"
            }
        ],
        "congestion_control": "bbr",
        "tls": {
            "enabled": true,
            "server_name": "'"$server_name"'",
            "alpn": ["h3"],
            "key_path": "'"$SSL_DIR/${server_name}.key"'",
            "certificate_path": "'"$SSL_DIR/${server_name}.crt"'"
        }
    }'
}

# Function: install_cloudflared
# Purpose: Install Cloudflare Tunnel (cloudflared) based on system and architecture.
install_cloudflared() {
    if [[ -f "$BIN_FILE_CLOUDFLARED" ]]; then
        echo_color -yellow "Cloudflare tunnel already installed: $BIN_FILE_CLOUDFLARED"
        prompt_info="Are you sure you want to reinstall it? (Y/n): "
        if [[ "$auto_confirm" == true ]]; then
            echo_color -n -yellow "$prompt_info" && echo_color -green "(Auto confirm)"
        else
            read_color -yellow "$prompt_info" -r
            [[ -n $REPLY && ! $REPLY =~ ^[Yy]$ ]] && echo_color -red "Canceled." && exit 1
        fi
    fi

    local repo="cloudflare/cloudflared"
    if [[ -z "$CLOUDFLARED_VERSION" ]]; then
        if ! CLOUDFLARED_VERSION=$(get_latest_release_version "$repo"); then
            echo_color -red "Failed to fetch the latest release version, need to manually input the version."
            CLOUDFLARED_VERSION=""
        else
            echo_color "Latest release version: $CLOUDFLARED_VERSION"
            prompt_info="Do you want to install the latest release version? (Y/n): "
            if [[ "$auto_confirm" == true ]]; then
                echo_color -n -yellow "$prompt_info" && echo_color -green "(Auto confirm)"
            else
                read_color -yellow "$prompt_info" -r
                [[ -n $REPLY && ! $REPLY =~ ^[Yy]$ ]] && CLOUDFLARED_VERSION=""
            fi
        fi

        if [[ -z "$CLOUDFLARED_VERSION" ]]; then
            read_color -blue "Enter the release version you want to install (e.g., v1.0.0): " CLOUDFLARED_VERSION
        fi
    fi
    echo_color -blue "Installing version: $CLOUDFLARED_VERSION"

    read os arch <<<"$(get_system_info)"
    arch="${arch/x86_64/amd64}"
    echo_color -blue "Operating system: $os, System architecture: $arch"

    if [[ ! "$os" =~ ^(darwin|linux)$ ]] || [[ ! "$arch" =~ ^(amd64|arm64)$ ]]; then
        echo_color -red "Unsupported platform: only darwin/linux amd64/arm64 are supported."
        exit 1
    fi

    local file="cloudflared-$os-$arch"
    [[ "$os" == "darwin" ]] && file="$file.tgz"

    local tmp_file="/tmp/$file"
    download_release_file "$repo" "$CLOUDFLARED_VERSION" "$file" "$tmp_file"

    mkdir -p "$BIN_DIR"
    if [[ "$file" == *.tgz ]]; then
        tar -xzf "$tmp_file" -C "$BIN_DIR" || {
            echo_color -red "Failed to extract $file"
            return 1
        }
    else
        mv "$tmp_file" "$BIN_FILE_CLOUDFLARED" || return 1
    fi

    chmod +x "$BIN_FILE_CLOUDFLARED" || return 1

    echo_color -green "Cloudflare tunnel installed: $BIN_FILE_CLOUDFLARED"
}

# Function: uninstall_cloudflared
# Purpose: Uninstall Cloudflare Tunnel (cloudflared).
uninstall_cloudflared() {
    if [[ ! -f "$BIN_FILE_CLOUDFLARED" ]]; then
        echo_color -yellow "Cloudflare tunnel is not installed."
        return 0
    fi

    rm -f "$BIN_FILE_CLOUDFLARED"
    echo_color -green "Cloudflare tunnel uninstalled."
}

# Function: start_cloudflared
# Purpose: Start cloudflare tunnel with optional parameters.
# Usage: start_cloudflared --protocol=<protocol> --port=<port> --no-tls-verify
# Options:
#   --protocol=<protocol> : Protocol to use for the tunnel, default is https
#   --port=<port>         : Port number for the tunnel, default is 10240
#   --no-tls-verify       : Skip TLS verification
# Example:
#   start_cloudflared --protocol=https --port=10240 --no-tls-verify
start_cloudflared() {
    local protocol=${CLOUDFLARED_PROTOCOL:-https}
    local port=${CLOUDFLARED_PORT:-10240}
    local no_tls_verify=${CLOUDFLARED_NO_TLS_VERIFY:-true}

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --protocol=*) protocol="${1#--protocol=}" ;;
        --port=*) port="${1#--port=}" ;;
        --no-tls-verify) no_tls_verify=true ;;
        esac
        shift
    done

    [[ ! -x "$BIN_FILE_CLOUDFLARED" ]] && echo_color -red "Cloudflared binary file not found: $BIN_FILE_CLOUDFLARED" && exit 1

    local cmd="$BIN_FILE_CLOUDFLARED tunnel --url $protocol://localhost:$port"
    [[ "$no_tls_verify" == true ]] && cmd+=" --no-tls-verify"

    if pgrep -f "$cmd" >/dev/null; then
        echo_color -yellow "Cloudflared service on port $port is already running."
        return 0
    fi

    mkdir -p "$LOG_DIR"
    nohup $cmd >"$LOG_OUTPUT_CLOUDFLARED" 2>&1 &

    local attempt=0
    local max_attempts=30
    local tunnel_url=""
    while [[ $attempt -lt $max_attempts ]]; do
        tunnel_url=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG_OUTPUT_CLOUDFLARED" | head -n 1)
        [[ -n "$tunnel_url" ]] && break

        echo_color -yellow "Waiting for tunnel URL... (Attempt $((attempt + 1))/$max_attempts)"
        sleep 1
        ((attempt++))
    done
    if [[ -z "$tunnel_url" ]]; then
        echo_color -red "Failed to get the tunnel URL after $max_attempts attempts."
        return 1
    fi

    echo_color -green "Cloudflared service started, tunnel URL: $tunnel_url"
}

stop_cloudflared() {
    if ! pgrep -f "$BIN_FILE_CLOUDFLARED" >/dev/null; then
        echo_color -yellow "Cloudflared service is not running."
        return 0
    fi

    pkill -f "$BIN_FILE_CLOUDFLARED"
    while pgrep -f "$BIN_FILE_CLOUDFLARED" >/dev/null; do
        echo_color -yellow "Waiting for cloudflared service to stop..."
        sleep 1
    done
    rm -rf "$LOG_OUTPUT_CLOUDFLARED"

    echo_color -green "Cloudflared service stopped."
}

setup() {
    install_app
    gen_singbox_config
    stop_singbox
    start_singbox
    show_status
    show_nodes
}

reset() {
    prompt_info="Are you sure you want to reset the application? (Y/n): "
    if [[ "$auto_confirm" == true ]]; then
        echo_color -n -yellow "$prompt_info" && echo_color -green "(Auto confirm)"
    else
        read_color -yellow "$prompt_info" -r
        [[ -n $REPLY && ! $REPLY =~ ^[Yy]$ ]] && echo_color -red "Canceled." && exit 1
    fi

    stop_singbox
    uninstall_app
}

parse_parameters() {
    [[ $# -eq 0 ]] && set -- "-h"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        setup | reset | start | stop | restart | status | show_nodes)
            main_action="$1"
            ;;
        tunnel)
            main_action="tunnel"
            shift
            case "$1" in
            enable | disable | start | stop | restart)
                sub_action="$1"
                ;;
            *)
                echo_color -red "Unknown parameter: $1"
                echo_color -green "Use -h or --help for usage."
                return
                ;;
            esac
            ;;
        -y | --yes)
            auto_confirm=true
            ;;
        -h | --help)
            show_help
            return
            ;;
        *)
            echo_color -red "Unknown parameter: $1"
            echo_color -green "Use -h or --help for usage."
            return
            ;;
        esac
        shift
    done

    if [[ -z "$main_action" ]]; then
        echo_color -red "No command specified."
        echo_color -green "Use -h or --help for usage."
        return
    fi
}

show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -y                   Automatically execute commands without prompts."
    echo "  -h                   Show this help message."
    echo ""
    echo "Commands:"
    echo "  setup                Setup the Sing Box."
    echo "  reset                Reset the Sing Box."
    echo "  status               Show the current status."
    echo "  start                Start the Sing Box."
    echo "  stop                 Stop the Sing Box."
    echo "  restart              Restart the Sing Box."
    echo "  tunnel enable        Enable the tunnel."
    echo "  tunnel disable       Disable the tunnel."
    echo "  tunnel status        Show tunnel status."
    echo "  tunnel start         Start the tunnel."
    echo "  tunnel stop          Stop the tunnel."
    echo "  tunnel restart       Restart the tunnel."
    echo ""
}

main() {
    parse_parameters "$@"
    check_and_install_deps openssl jq

    case "$main_action" in
    setup)
        setup
        ;;
    reset)
        reset
        ;;
    start)
        start_singbox
        ;;
    stop)
        stop_singbox
        ;;
    restart)
        stop_singbox
        start_singbox
        ;;
    status)
        show_status
        ;;
    show_nodes)
        show_nodes
        ;;
    tunnel)
        case "$sub_action" in
        enable)
            install_cloudflared
            stop_cloudflared
            start_cloudflared
            show_status
            ;;
        disable)
            stop_cloudflared
            uninstall_cloudflared
            ;;
        start)
            start_cloudflared
            ;;
        stop)
            stop_cloudflared
            ;;
        restart)
            stop_cloudflared
            start_cloudflared
            ;;
        esac
        ;;
    esac
}
main "$@"
