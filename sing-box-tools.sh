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
    latest_version=$(curl -Ls "https://github.com/$repository_name/releases/latest" | grep -oE 'tag\/v[^\"]+' | head -1 | awk -F'/' '{print $NF}')

    # Check if the version is found
    if [ -z "$latest_version" ]; then
        echo_color -red "Failed to fetch the latest release version."
        exit 1
    fi

    # Return the latest release version
    echo "$latest_version"
}

# Function: validate_version
# Purpose: Validate the version format.
# Usage: validate_version <version>
# Parameters:
#   <version>: Version string to validate (e.g., "v1.0.0").
# Example:
#   validate_version "v1.0.0"
validate_version() {
    # Check if the version is provided
    if [[ -z "$1" ]]; then
        return 1
    fi
    # Check if the version format is valid
    if [[ ! "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
    fi
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
            # If the version format is invalid, continue to prompt for user input
            while true; do
                read_color -blue "Enter the release version you want to install (e.g., v1.0.0): " APP_VERSION
                # Validate the version format
                validate_version "$APP_VERSION" && break
                echo_color -red "Invalid version format, please retry."
            done
        fi
    fi
    echo_color -blue "Installing version: $APP_VERSION"

    # Get the operating system name and system architecture
    read os arch <<<"$(get_system_info)"
    # Check os and arch, os must be linux / darwin, arch must be arm64 / amd64, x86_64 should be replaced with amd64
    case "$os" in
    linux)
        os="linux"
        ;;
    darwin)
        os="darwin"
        ;;
    *)
        echo_color -red "Unsupported operating system: $os, currently only support linux and darwin."
        exit 1
        ;;
    esac
    case "$arch" in
    x86_64 | amd64)
        arch="amd64"
        ;;
    arm64)
        arch="arm64"
        ;;
    *)
        echo_color -red "Unsupported system architecture: $arch, currently only support amd64 and arm64."
        exit 1
        ;;
    esac

    # Define the application file name based on the operating system and system architecture
    APP_FILE="sing-box-${APP_VERSION#v}-$os-$arch.tar.gz"

    # Download the application release file
    download_release_file "$APP_REPO" "$APP_VERSION" "$APP_FILE" "/tmp/$APP_FILE"

    # Extract the application release file to the bin directory
    tar -xzf "/tmp/$APP_FILE" -C "$BIN_DIR" --strip-components=1
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

# Function: upgrade_app
# Purpose: Upgrade the application.
upgrade_app() {
    echo_color -blue "Upgrading the application..."

    # Check if the installation directory exists
    if [[ -d "$INSTALL_DIR" ]]; then
        # Check auto_confirm flag
        if [[ "$auto_confirm" == true ]]; then
            # Auto-confirm without prompting for user input
            echo "(Auto confirm) Upgrading the application..."
        else
            # Prompt for user input to confirm upgrade, default to cancel
            read_color -yellow "Do you want to upgrade the application? (Y/n): " -r
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                echo "Upgrade canceled."
                exit 0
            fi
            echo "Upgrading the application..."
        fi
    else
        echo_color -red "Installation directory not found: $INSTALL_DIR"
        exit 1
    fi

    # Define the application repository
    APP_REPO="SagerNet/sing-box"

    # Auto fetch the latest release version if not provided
    if [[ -z "$APP_VERSION" ]]; then
        APP_VERSION=$(get_latest_release_version "$APP_REPO")

        # Check if the latest release version is fetched successfully
        if [[ -z "$APP_VERSION" ]]; then
            if [[ "$auto_confirm" == true ]]; then
                echo_color -red "(Auto confirm) Failed to fetch the latest release version, cannot auto upgrade, exiting..."
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
            # If the
            while true; do
                read_color -blue "Enter the release version you want to upgrade to (e.g., v1.0.0): " APP_VERSION
                # Validate the version format
                validate_version "$APP_VERSION" && break
                echo_color -red "Invalid version format, please retry."
            done
        fi
    fi
    echo_color -blue "Upgrading to version: $APP_VERSION"

    # Get the operating system name and system architecture
    read os arch <<<"$(get_system_info)"
    # Define the application file name based on the operating system and system architecture
    APP_FILE="sing-box-${APP_VERSION#v}-$os-$arch.tar.gz"

    # Download the application release file
    download_release_file "$APP_REPO" "$APP_VERSION" "$APP_FILE" "/tmp/$APP_FILE"

    # Extract the application release file to the bin directory
    tar -xzf "/tmp/$APP_FILE" -C "$INSTALL_DIR/bin" --strip-components=1
    echo_color -green "Application upgraded to: $APP_VERSION"
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
        return
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
        return
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
        cat "$CONFIG_FILE"
    else
        echo_color -red "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
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
    config_content='{
    "log": {
        "disabled": '${LOG_DISABLED:-false}',
        "level": "'${LOG_LEVEL:-info}'",
        "output": "'${LOG_OUTPUT:-$LOG_DIR/sing-box.log}'",
        "timestamp": '${LOG_TIMESTAMP:-true}'
    },
    "inbounds": ['
    if [[ "${LOG_DISABLED:-false}" == false ]]; then
        mkdir -p "$LOG_DIR"
    fi

    # socks5 inbound
    if [[ -n "$S5_PORT" ]]; then
        config_content+=$(generate_socks5_inbound)
        config_content+=","
    fi
    # hysteria2 inbound
    if [[ -n "$HY2_PORT" ]]; then
        config_content+=$(generate_hysteria2_inbound)
        config_content+=","
    fi
    # trojan inbound
    if [[ -n "$TROJAN_PORT" ]]; then
        config_content+=$(generate_trojan_inbound)
        config_content+=","
    fi
    # vless inbound
    if [[ -n "$VLESS_PORT" ]]; then
        config_content+=$(generate_vless_inbound)
        config_content+=","
    fi

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

# Function: generate_vless_inbound
# Purpose: Generate the vless inbound configuration.
# Usage: generate_vless_inbound --port=<port> --uuid=<uuid> --server_name=<server_name>
# Options:
#   --port=<port>        : Port number for the vless inbound, default is 443.
#   --uuid=<uuid>        : UUID for the vless inbound, default is a random string.
#   --server_name=<server_name>: Server name for the vless inbound, default is www.cloudflare.com.
# Example:
#   generate_vless_inbound --port=443 --uuid=uuid --server_name=www.cloudflare.com
generate_vless_inbound() {
    # Default values
    local port="${VLESS_PORT:-443}"
    local uuid="${VLESS_UUID:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"
    local server_name="${VLESS_SERVER_NAME:-www.cloudflare.com}"
    local vless_path="${VLESS_PATH:-/vless}"

    # Parse input parameters
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --uuid=*) uuid="${1#--uuid=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
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
            "path": "'"$vless_path"'",
            "headers": {
                "host": "'"$server_name"'"
            },
            "max_early_data": 2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
        }
    }'
}

# Function: generate_socks5_inbound
# Purpose: Generate the socks5 inbound configuration.
# Usage: generate_socks5_inbound --port=<port> --username=<username> --password=<password>
# Options:
#   --port=<port>        : Port number for the socks5 inbound, default is 1080.
#   --username=<username>: Username for the socks5 inbound, default is a random string.
#   --password=<password>: Password for the socks5 inbound, default is a random string.
# Example:
#   generate_socks5_inbound --port=1080 --username=user --password=password
generate_socks5_inbound() {
    # Default values
    local port="${S5_PORT:-1080}"
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
#   --port=<port>        : Port number for the hysteria2 inbound, default is 443.
#   --password=<password>: Password for the hysteria2 inbound, default is a random string.
#   --server_name=<server_name>: Server name for the hysteria2 inbound, default is www.cloudflare.com.
# Example:
#   generate_hysteria2_inbound --port=443 --password=password --server_name=www.cloudflare.com
generate_hysteria2_inbound() {
    # Default values
    local port="${HY2_PORT:-443}"
    local password="${HY2_PASSWORD:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"
    local server_name="${HY2_SERVER_NAME:-www.cloudflare.com}"

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

# Function: generate_trojan_inbound
# Purpose: Generate the trojan inbound configuration.
# Usage: generate_trojan_inbound --port=<port> --password=<password> --server_name=<server_name>
# Options:
#   --port=<port>        : Port number for the trojan inbound, default is 443.
#   --password=<password>: Password for the trojan inbound, default is a random string.
#   --server_name=<server_name>: Server name for the trojan inbound, default is www.cloudflare.com.
# Example:
#   generate_trojan_inbound --port=443 --password=password --server_name=www.cloudflare.com
generate_trojan_inbound() {
    # Default values
    local port="${TROJAN_PORT:-443}"
    local password="${TROJAN_PASSWORD:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"
    local server_name="${TROJAN_SERVER_NAME:-www.cloudflare.com}"
    local trojan_path="${TROJAN_PATH:-/trojan}"

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
            "path": "'"$trojan_path"'",
            "headers": {
                "host": "'"$server_name"'"
            },
            "max_early_data": 2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
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
        install | uninstall | upgrade | start | stop | restart | status | gen_config | show_config | setup)
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
            echo "  upgrade    : Upgrade the application."
            echo "  start      : Start the service."
            echo "  stop       : Stop the service."
            echo "  restart    : Restart the service."
            echo "  status     : Display the status of the application and service."
            echo "  gen_config : Generate the configuration file."
            echo "  show_config: Show the configuration file content."
            echo "  setup      : Setup the application."
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

    # Perform the action based on the selected action
    case "$action" in
    install)
        install_app
        ;;
    uninstall)
        uninstall_app
        ;;
    upgrade)
        upgrade_app
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
    setup)
        install_app
        generate_config
        stop_service
        sleep 0.5
        start_service
        show_status
        ;;
    esac

    # Exit the script
    exit 0
}
main "$@"
