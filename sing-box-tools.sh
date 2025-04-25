#!/bin/bash

# Title: SingBox Tools
# Description: A collection of useful functions for shell scripts.

# Define
INSTALL_DIR="${INSTALL_DIR:-"$HOME/sing-box"}"
BIN_DIR="${BIN_DIR:-"$INSTALL_DIR/bin"}"
LOG_DIR="${LOG_DIR:-"$INSTALL_DIR/logs"}"
SSL_DIR="${SSL_DIR:-"$INSTALL_DIR/ssl"}"
CONFIG_DIR="${CONFIG_DIR:-"$INSTALL_DIR/conf"}"
CONFIG_FILE="${CONFIG_FILE:-"$CONFIG_DIR/config.json"}"

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

    # Parse options
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
            # Stop parsing options when an invalid option is encountered
            break
            ;;
        esac
        shift
    done

    # Get the prompt to be displayed
    prompt="${1}"

    # Read user input with the prompt and selected color
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
    # Default values
    local charset="A-Za-z0-9" # Default charset: Alphanumeric (letters + digits)
    local length=8            # Default length

    # Parse input parameters
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --charset=*) charset="${1#--charset=}" ;;
        --length=*) length="${1#--length=}" ;;
        esac
        shift
    done

    # Expand character sets like A-Z, a-z, and 0-9 directly
    charset="${charset//A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ}"
    charset="${charset//a-z/abcdefghijklmnopqrstuvwxyz}"
    charset="${charset//0-9/0123456789}"

    # Generate random string
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
    # Generate each segment of the UUID
    local part1=$(gen_random_string --charset="abcdef0-9" --length=8)  # First part (8 characters)
    local part2=$(gen_random_string --charset="abcdef0-9" --length=4)  # Second part (4 characters)
    local part3="4$(gen_random_string --charset="abcdef0-9" --length=3)"  # Third part (4 characters, version is 4)
    local part4=$(gen_random_string --charset="89ab" --length=1)$(gen_random_string --charset="abcdef0-9" --length=3)  # Fourth part (4 characters, 8-9-a-b for variant)
    local part5=$(gen_random_string --charset="abcdef0-9" --length=12) # Fifth part (12 characters)

    # Combine them into the UUID v4 format
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
        if [[ "$auto_confirm" == true ]]; then
            echo "(Auto confirm) Install missing dependencies..."
        else
            read_color -yellow "Install missing dependencies now? (Y/n): " -r
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                echo_color "Cancel installed."
                exit 1
            fi
        fi
        if command -v apt-get &>/dev/null; then
            PKG_MANAGER="apt-get install -y"
            UPDATE_CMD="apt-get update"
        elif command -v yum &>/dev/null; then
            PKG_MANAGER="yum install -y"
            UPDATE_CMD=""
        elif command -v brew &>/dev/null; then
            PKG_MANAGER="brew install"
            UPDATE_CMD="brew update"
        elif command -v apk &>/dev/null; then
            PKG_MANAGER="apk add"
            UPDATE_CMD="apk update"
        else
            echo_color -red "Package manager not found! Please install missing dependencies manually."
            exit 1
        fi

        [[ -n "$UPDATE_CMD" ]] && $UPDATE_CMD

        for dep in "${missing_dependencies[@]}"; do
            echo_color -yellow "Installing $dep..."
            if ! $PKG_MANAGER "$dep"; then
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
    # Check if repository name is provided
    if [ -z "$1" ]; then
        echo_color -red "Usage: get_latest_release_version <repository_name>"
        exit 1
    fi

    # Assign input parameter to local variable
    local repository_name="$1"

    # Fetch the latest release version using curl, following redirects and extracting version info
    latest_version=$(curl -Ls "https://github.com/$repository_name/releases/latest" \
        | grep -oE "$repository_name/releases/tag/[^\"]+" \
        | head -1 \
        | awk -F'/' '{print $NF}')

    # Check if the version is found
    if [ -z "$latest_version" ]; then
        echo_color -red "Failed to fetch the latest release version."
        exit 1
    fi

    # Return the latest release version
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

    if [[ -z "$repo" || -z "$version" || -z "$file_name" || -z "$destination" ]]; then
        echo_color -red "Failed to download release file, missing parameters."
        echo_color -red "Usage: download_release_file <repository_name> <version> <file_name> <destination_path>"
        exit 1
    fi

    local download_url="https://github.com/$repo/releases/download/$version/$file_name"
    echo "Downloading $file_name from $download_url to $destination..."

    # Check if the destination exists
    if [[ -f "$destination" ]]; then
        if [[ "$auto_confirm" == true ]]; then
            echo "(Auto confirm) Destination file already exists: $destination, skipping download..."
            return 0
        fi

        # Prompt for user input to confirm skipping download, default to skip
        read_color -yellow "Destination file already exists: $destination, do you want to skip download? (Y/n): " -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            # Delete the existing file if user chooses to download
            rm -f "$destination"
        else
            echo "Skipping download..."
            return 0
        fi
    fi

    curl -L --fail "$download_url" -o "$destination"
    if [[ $? -eq 0 ]]; then
        echo "Download successful!"
    else
        echo "Download failed!"
        exit 1
    fi
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

    if [[ -z "$repo" || -z "$file_name" || -z "$destination" ]]; then
        echo_color -red "Failed to download source code file, missing parameters."
        echo_color -red "Usage: download_source_code_file <repository_name> <file_name> <destination_path>"
        exit 1
    fi

    local download_url="https://github.com/$repo/archive/refs/tags/$file_name"
    echo "Downloading source code file from $download_url to $destination..."

    # Check if the destination exists
    if [[ -f "$destination" ]]; then
        if [[ "$auto_confirm" == true ]]; then
            echo "(Auto confirm) Destination file already exists: $destination, skipping download..."
            return 0
        fi

        # Prompt for user input to confirm skipping download, default to skip
        read_color -yellow "Destination file already exists: $destination, do you want to skip download? (Y/n): " -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            # Delete the existing file if user chooses to download
            rm -f "$destination"
        else
            echo "Skipping download..."
            return 0
        fi
    fi

    curl -L --fail "$download_url" -o "$destination"
    if [[ $? -eq 0 ]]; then
        echo "Download successful!"
    else
        echo "Download failed!"
        exit 1
    fi
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
    # Default values
    local domain="www.cloudflare.com" # Default domain name
    local days=36500                  # Default number of days the certificate is valid
    local key_path="./${domain}.key"  # Default path to save the private key file
    local cert_path="./${domain}.crt" # Default path to save the certificate file

    # Parse input parameters
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --domain=*) domain="${1#--domain=}" ;;
        --days=*) days="${1#--days=}" ;;
        --key_path=*) key_path="${1#--key_path=}" ;;
        --cert_path=*) cert_path="${1#--cert_path=}" ;;
        esac
        shift
    done

    # Generate the SSL certificate
    openssl req -new -newkey rsa:2048 -days "$days" -nodes -x509 -keyout "$key_path" -out "$cert_path" -subj "/CN=$domain" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo_color -red "Failed to generate SSL certificate."
        exist 1
    fi
}

# Function: install_app
# Purpose: Install the application.
install_app() {
    echo_color -blue "Installing the application..."

    # Check if the installation directory exists, if exists, prompt for user input to confirm reinstall
    if [[ -d "$INSTALL_DIR" ]]; then
        # Check auto_confirm flag
        if [[ "$auto_confirm" == true ]]; then
            # Auto-confirm without prompting for user input
            echo "(Auto confirm) Installation directory already exists: $INSTALL_DIR, reinstalling the application..."
        else
            # Prompt for user input to confirm reinstall, default to cancel
            read_color -yellow "Installation directory already exists: $INSTALL_DIR, do you want to reinstall the application? (Y/n): " -r
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                echo "Installation canceled."
                exit 0
            fi
            echo "Reinstalling the application..."
        fi
    fi
    mkdir -p "$BIN_DIR"

    # Define the application repository
    APP_REPO="SagerNet/sing-box"

    # Auto fetch the latest release version if not provided
    if [[ -z "$APP_VERSION" ]]; then
        APP_VERSION=$(get_latest_release_version "$APP_REPO")

        # Check if the latest release version is fetched successfully
        if [[ -z "$APP_VERSION" ]]; then
            if [[ "$auto_confirm" == true ]]; then
                echo_color -red "(Auto confirm) Failed to fetch the latest release version, cannot auto install, exiting..."
                exit 1
            fi
            echo_color -red "Failed to fetch the latest release version, please manually input the version."
        else
            if [[ "$auto_confirm" == true ]]; then
                echo "(Auto confirm) Latest release version: $APP_VERSION"
            else
                # Prompt for user input to confirm the latest release version or manually input the version
                read_color -yellow "Do you want to use the latest release version $APP_VERSION? (Y/n): " -r
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    APP_VERSION=""
                fi
            fi
        fi

        # IF the APP_VERSION is not set, prompt for user input to manually input the version
        if [[ -z "$APP_VERSION" ]]; then
            read_color -blue "Enter the release version you want to install (e.g., v1.0.0): " APP_VERSION
        fi
    fi
    echo_color -blue "Installing version: $APP_VERSION"

    # Get the operating system name and system architecture
    read os arch <<<"$(get_system_info)"
    # When arch is x86_64, replace it with amd64
    arch="${arch/x86_64/amd64}"
    echo_color -blue "Operating system: $os, System architecture: $arch"

    # Check os and arch
    # Release only support darwin/amd64, darwin/arm64, linux/amd64, linux/arm64
    # Other use the source code
    if [[ "$os" != "darwin" && "$os" != "linux" ]] || [[ "$arch" != "amd64" && "$arch" != "arm64" ]]; then
        # Define the application source code file name based on the version number
        app_file="${APP_VERSION}.tar.gz"
        # Download the application source code file
        download_source_code_file "$APP_REPO" "$app_file" "/tmp/$app_file"
        # Extract the application source code file
        rm -rf "/tmp/sing-box-${APP_VERSION#v}"
        tar -xzf "/tmp/$app_file" -C "/tmp"
        # Make
        cd "/tmp/sing-box-${APP_VERSION#v}"
        make VERSION="${APP_VERSION#v}" >/dev/null
        if [ $? -ne 0 ]; then
            echo_color -red "Build failed!"
            exit 1
        fi
        # Move to the bin directory
        mv "/tmp/sing-box-${APP_VERSION#v}/sing-box" "$BIN_DIR"
    else
        # Define the application file name based on the operating system and system architecture
        app_file="sing-box-${APP_VERSION#v}-$os-$arch.tar.gz"
        # Download the application release file
        download_release_file "$APP_REPO" "$APP_VERSION" "$app_file" "/tmp/$app_file"
        # Extract the application release file to the bin directory
        tar -xzf "/tmp/$app_file" -C "$BIN_DIR" --strip-components=1
    fi

    echo_color -green "Application installed to: $INSTALL_DIR"
}

# Function: uninstall_app
# Purpose: Uninstall the application.
uninstall_app() {
    echo_color -blue "Uninstalling the application..."

    # Check if the installation directory exists
    if [[ -d "$INSTALL_DIR" ]]; then
        # Check auto_confirm flag
        if [[ "$auto_confirm" == true ]]; then
            # Auto-confirm without prompting for user input
            echo "(Auto confirm) Uninstalling the application..."
        else
            # Prompt for user input to confirm uninstall, default to cancel
            read_color -yellow "Do you want to uninstall the application? (Y/n): " -r
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                echo "Uninstallation canceled."
                exit 0
            fi
            echo "Uninstalling the application..."
        fi
    else
        echo_color -red "Installation directory not found: $INSTALL_DIR"
        exit 1
    fi

    # Remove the installation directory
    rm -rf "$INSTALL_DIR"
    echo_color -green "Application uninstalled: $INSTALL_DIR"
}

# Function: start_service
start_service() {
    echo_color -blue "Starting the service..."

    # Check if the binary file not exists, exit if not found
    if [[ ! -f "$BIN_DIR/sing-box" ]]; then
        echo_color -red "Binary file not found: $BIN_DIR/sing-box"
        exit 1
    fi

    # Check if the service is already running
    if pgrep -f "$BIN_DIR/sing-box" >/dev/null; then
        echo_color -yellow "Service is already running."
        return 0
    fi

    # Start the service in the background
    nohup "$BIN_DIR/sing-box" run -c "$CONFIG_FILE" >/dev/null 2>&1 &
    echo_color -green "Service started."
}

# Function: stop_service
stop_service() {
    echo_color -blue "Stopping the service..."

    # Check if the service is running
    if ! pgrep -f "$BIN_DIR/sing-box" >/dev/null; then
        echo_color -yellow "Service is not running."
        return 0
    fi

    # Stop the service
    pkill -f "$BIN_DIR/sing-box"
    echo_color -green "Service stopped."
}

# Function: show_status
# Purpose: Show the application and service status, format the output.
show_status() {
    echo -n "Application Status: "
    if [[ -x "$INSTALL_DIR" ]]; then
        if [[ -f "$BIN_DIR/sing-box" ]]; then
            echo_color -green "Installed (v"$("$BIN_DIR/sing-box" version | head -n 1 | awk '{print $3}')")"
        else
            echo_color -red "Binary Missing"
        fi
    else
        echo_color -red "Not Installed"
    fi

    echo -n "Config File: "
    if [[ -f "$CONFIG_FILE" ]]; then
        echo_color -green "Exists"
    else
        echo_color -red "Missing"
    fi

    echo -n "Service Status: "
    if pgrep -f "$BIN_DIR/sing-box" >/dev/null; then
        echo_color -green "Running"
    else
        echo_color -red "Stopped"
    fi
}

# Function: show_config
# Purpose: Show the configuration file content.
show_config() {
    # Check if the configuration file exists
    if [[ -f "$CONFIG_FILE" ]]; then
        echo_color -cyan "Configuration File: $CONFIG_FILE"
        echo_color -yellow "Last Modified: $(date -r "$CONFIG_FILE" "+%Y-%m-%d %H:%M:%S")"
        if command -v jq >/dev/null 2>&1; then
            cat "$CONFIG_FILE" | jq .
        else
            cat "$CONFIG_FILE"
        fi
    else
        echo_color -red "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

# Function: show_nodes
# Purpose: Show the node configurations from the inbound section of the config file.
show_nodes() {
    [[ -f "$CONFIG_FILE" ]] || { echo_color -red "Config file not found: $CONFIG_FILE"; exit 1; }

    echo_color -cyan "Config File: $CONFIG_FILE"
    echo_color -yellow "Last Modified: $(date -r "$CONFIG_FILE" "+%Y-%m-%d %H:%M:%S")"

    local count=$(jq '.inbounds | length' "$CONFIG_FILE")
    echo_color -green "Total inbounds: $count"
    (( count == 0 )) && return 0

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
}

# Function: output_nodes
# Purpose: Output links using given IP and node name
output_nodes() {
    local ip="$1"
    local node_name="$2"

    jq -c '.inbounds[]' "$CONFIG_FILE" | while read -r inbound; do
        local type=$(echo "$inbound" | jq -r '.type')
        local port=$(echo "$inbound" | jq -r '.listen_port')
        local sni=$(echo "$inbound" | jq -r '.tls.server_name // empty')
        local host=$(echo "$inbound" | jq -r '.transport.headers.host // empty')
        local path=$(echo "$inbound" | jq -r '.transport.path // "/"')
        local uuid=$(echo "$inbound" | jq -r '.users[0].uuid // empty')
        local user=$(echo "$inbound" | jq -r '.users[0].username // empty')
        local pass=$(echo "$inbound" | jq -r '.users[0].password // empty')

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

# Function: generate_config
# Purpose: Generate the configuration file.
generate_config() {
    echo_color -blue "Generating the configuration file..."

    # Check if the configuration file exists, if exists, prompt for user input to confirm overwrite
    if [[ -f "$CONFIG_FILE" ]]; then
        # Check auto_confirm flag
        if [[ "$auto_confirm" == true ]]; then
            # Auto-confirm without prompting for user input
            echo "(Auto confirm) Configuration file already exists: $CONFIG_FILE, overwriting..."
        else
            # Prompt for user input to confirm overwrite, default to cancel
            read_color -yellow "Configuration file already exists: $CONFIG_FILE, do you want to overwrite? (Y/n): " -r
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                echo "Configuration file generation canceled."
                exit 0
            fi
            echo "Overwriting the configuration file..."
        fi
    fi

    # Create the configuration directory if it does not exist
    mkdir -p "$CONFIG_DIR"

    # Generate the configuration file content
    config_content=$(generate_config_content)

    # Write the configuration file content to the configuration file
    echo -e "$config_content" >"$CONFIG_FILE"
    echo_color -green "Configuration file generated: $CONFIG_FILE"
}

# Function: generate_config_content
# Purpose: Generate the configuration file content.
# Usage: generate_config_content
# Output: Configuration file content
generate_config_content() {
    LOG_DISABLED="${LOG_DISABLED:-true}"
    if [[ "${LOG_DISABLED}" == false ]]; then
        mkdir -p "$LOG_DIR"
    fi

    config_content='{
    "log": {
        "disabled": '${LOG_DISABLED}',
        "level": "'${LOG_LEVEL:-info}'",
        "output": "'${LOG_OUTPUT:-$LOG_DIR/sing-box.log}'",
        "timestamp": '${LOG_TIMESTAMP:-true}'
    },
    "inbounds": ['

    # socks5 inbound
    [[ -n "$S5_PORT" ]] && config_content+=$(generate_socks5_inbound)","
    # hysteria2 inbound
    [[ -n "$HY2_PORT" ]] && config_content+=$(generate_hysteria2_inbound)","
    # tuic inbound
    [[ -n "$TUIC_PORT" ]] && config_content+=$(generate_tuic_inbound)","
    # vless inbound
    [[ -n "$VLESS_PORT" ]] && config_content+=$(generate_vless_inbound)","
    # vmess inbound
    [[ -n "$VMESS_PORT" ]] && config_content+=$(generate_vmess_inbound)","
    # trojan inbound
    [[ -n "$TROJAN_PORT" ]] && config_content+=$(generate_trojan_inbound)","
    # anytls inbound
    [[ -n "$ANYTLS_PORT" ]] && config_content+=$(generate_anytls_inbound)","

    # Remove trailing comma and finalize the configuration
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
    # Default values
    local port="${S5_PORT:-10240}"
    local username="${S5_USERNAME:-$(gen_random_string --length=6 --charset=a-z)}"
    local password="${S5_PASSWORD:-$(gen_random_string --length=8 --charset=A-Za-z0-9@_)}"

    # Parse input parameters
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
    # Default values
    local port="${HY2_PORT:-10240}"
    local password="${HY2_PASSWORD:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${HY2_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"

    # Parse input parameters
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --password=*) password="${1#--password=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        esac
        shift
    done

    # Generate the tls key and certificate
    mkdir -p "$SSL_DIR"
    # Generate the tls key and certificate if not provided
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
    # Default values
    local port="${VLESS_PORT:-10240}"
    local uuid="${VLESS_UUID:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${VLESS_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"
    local transport_path="${VLESS_PATH:-/vless}"
    local transport_host="${VLESS_HOST:-$server_name}"

    # Parse input parameters
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

    # Generate the tls key and certificate
    mkdir -p "$SSL_DIR"
    # Generate the tls key and certificate if not provided
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
    # Default values
    local port="${VMESS_PORT:-10240}"
    local uuid="${VMESS_UUID:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${VMESS_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"
    local transport_path="${VMESS_PATH:-/}"
    local transport_host="${VMESS_HOST:-$server_name}"

    # Parse input parameters
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

    # Generate the tls key and certificate
    mkdir -p "$SSL_DIR"
    # Generate the tls key and certificate if not provided
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
    # Default values
    local port="${TROJAN_PORT:-10240}"
    local password="${TROJAN_PASSWORD:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${TROJAN_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"
    local transport_path="${TROJAN_PATH:-/trojan}"
    local transport_host="${TROJAN_HOST:-$server_name}"

    # Parse input parameters
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

    # Generate the tls key and certificate
    mkdir -p "$SSL_DIR"
    # Generate the tls key and certificate if not provided
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
    # Default values
    local port="${ANYTLS_PORT:-10240}"
    local password="${ANYTLS_PASSWORD:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${ANYTLS_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"

    # Parse input parameters
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --password=*) password="${1#--password=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        esac
        shift
    done

    # Generate the tls key and certificate
    mkdir -p "$SSL_DIR"
    # Generate the tls key and certificate if not provided
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
    # Default values
    local port="${TUIC_PORT:-10240}"
    local uuid="${TUIC_UUID:-${UUID:-$(gen_uuid_v4)}}"
    local password="${TUIC_PASSWORD:-}"
    local server_name="${TUIC_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"

    # Parse input parameters
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --uuid=*) uuid="${1#--uuid=}" ;;
        --password=*) password="${1#--password=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        esac
        shift
    done

    # Generate the tls key and certificate
    mkdir -p "$SSL_DIR"
    # Generate the tls key and certificate if not provided
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

# Function: parse_parameters
parse_parameters() {
    # Auto add -h or --help option to display help message when no parameters are provided
    if [[ "$#" -eq 0 ]]; then
        set -- "-h"
    fi
    # Parse parameters
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        install | uninstall | start | stop | restart | status | gen_config | show_config | show_nodes | setup | reset)
            # Set the action to the first parameter
            action="$1"
            ;;
        -y | --yes)
            # Set the auto-confirm flag to true
            auto_confirm=true
            ;;
        -h | --help)
            # Display help message
            echo
            echo "Usage: $0 [options] [action]"
            echo
            echo "Options:"
            echo "  -h, --help : Display this help message."
            echo "  -y, --yes  : Auto-confirm without prompting for user input."
            echo
            echo "Actions:"
            echo "  install    : Install the application."
            echo "  uninstall  : Uninstall the application."
            echo "  start      : Start the service."
            echo "  stop       : Stop the service."
            echo "  restart    : Restart the service."
            echo "  status     : Display the status of the application and service."
            echo "  gen_config : Generate the configuration file."
            echo "  show_config: Show the configuration file content."
            echo "  show_nodes : Show the parsed nodes from configuration file content."
            echo "  setup      : Setup the application."
            echo "  reset      : Reset the application."
            echo
            echo "Environment Variables:"
            echo "  UUID       : Replace for VLESS_UUID / HY2_PASSWORD / TROJAN_PASSWORD / ANYTLS_PASSWORD"
            echo "  SERVER_NAME: Replace for VLESS_SERVER_NAME / HY2_SERVER_NAME / TROJAN_SERVER_NAME / ANYTLS_SERVER_NAME (default: www.cloudflare.com)"
            echo
            echo "  SOCKS5 Proxy:"
            echo "    S5_PORT    : SOCKS5 proxy port"
            echo "    S5_USERNAME: SOCKS5 username (default: random string)"
            echo "    S5_PASSWORD: SOCKS5 password (default: random string)"
            echo
            echo "  Hysteria2 Proxy:"
            echo "    HY2_PORT       : Hysteria2 proxy port"
            echo "    HY2_PASSWORD   : Hysteria2 password (default: generated)"
            echo "    HY2_SERVER_NAME: Hysteria2 server name (default: www.cloudflare.com)"
            echo
            echo "  Tuic Proxy:"
            echo "    TUIC_PORT       : Tuic proxy port"
            echo "    TUIC_UUID       : Tuic UUID (default: generated)"
            echo "    TUIC_PASSWORD   : Tuic password (default: empty)"
            echo "    TUIC_SERVER_NAME: Tuic server name (default: www.cloudflare.com)"
            echo
            echo "  VLESS Proxy:"
            echo "    VLESS_PORT       : VLESS proxy port"
            echo "    VLESS_UUID       : VLESS UUID (default: generated)"
            echo "    VLESS_SERVER_NAME: VLESS server name (default: www.cloudflare.com)"
            echo "    VLESS_PATH       : VLESS WebSocket path (default: /vless)"
            echo "    VLESS_HOST       : VLESS Host header (default: \$VLESS_SERVER_NAME)"
            echo
            echo "  Trojan Proxy:"
            echo "    TROJAN_PORT       : Trojan proxy port"
            echo "    TROJAN_PASSWORD   : Trojan password (default: generated)"
            echo "    TROJAN_SERVER_NAME: Trojan server name (default: www.cloudflare.com)"
            echo "    TROJAN_PATH       : Trojan WebSocket path (default: /trojan)"
            echo "    TROJAN_HOST       : Trojan Host header (default: \$TROJAN_SERVER_NAME)"
            echo
            echo "  AnyTLS Proxy:"
            echo "    ANYTLS_PORT       : AnyTLS proxy port"
            echo "    ANYTLS_PASSWORD   : AnyTLS password (default: generated)"
            echo "    ANYTLS_SERVER_NAME: AnyTLS server name (default: www.cloudflare.com)"
            echo
            echo "  VMess Proxy:"
            echo "    VMESS_PORT       : VMess proxy port"
            echo "    VMESS_UUID       : VMess UUID (default: generated)"
            echo "    VMESS_SERVER_NAME: VMess server name (default: www.cloudflare.com)"
            echo "    VMESS_PATH       : VMess WebSocket path (default: /)"
            echo "    VMESS_HOST       : VMess Host header (default: \$VMESS_SERVER_NAME)"
            echo
            exit 0
            ;;
        *)
            # Display error message for unknown parameters, and show usage
            echo "Unknown parameter: $1"
            echo "Use -h or --help option to display the help message."
            exit 1
            ;;
        esac
        shift
    done
}

# Function: main
main() {
    parse_parameters "$@"
    check_and_install_deps openssl jq

    # Perform the action based on the selected action
    case "$action" in
    install)
        install_app
        ;;
    uninstall)
        uninstall_app
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 0.5
        start_service
        ;;
    status)
        show_status
        ;;
    gen_config)
        generate_config
        ;;
    show_config)
        show_config
        ;;
    show_nodes)
        show_nodes
        ;;
    setup)
        install_app
        generate_config
        stop_service
        sleep 0.5
        start_service
        show_status
        show_nodes
        ;;
    reset)
        stop_service
        uninstall_app
        ;;
    esac

    # Exit the script
    exit 0
}
main "$@"
