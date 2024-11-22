#!/bin/bash
# Script to manage sing-box deployment in $HOME directory

# Define directories
BASE_DIR="$HOME/sing-box"
SRC_DIR="$BASE_DIR/source"
INSTALL_DIR="$BASE_DIR/bin"
CONFIG_FILE="$BASE_DIR/config.json"
LOG_FILE="$BASE_DIR/sing-box.log"
VERSION_FILE="$BASE_DIR/version.txt"
SERVICE_CMD="$INSTALL_DIR/sing-box run -c $CONFIG_FILE"

# Function: Check local version and service status
check_local_status() {
    if [ -f "$VERSION_FILE" ]; then
        LOCAL_VERSION=$(cat "$VERSION_FILE")
        echo "Local version: $LOCAL_VERSION"
    else
        echo "Local version: Not installed"
    fi

    pid=$(pgrep -f -x "$SERVICE_CMD")
    if [ -n "$pid" ]; then
        echo "Service status: Running (PID $pid)"
    else
        echo "Service status: Not running"
    fi
}

# Function: Download and extract source code for the specified version
download_source() {
    VERSION=$1
    echo "Downloading sing-box source code for version $VERSION..."
    mkdir -p "$SRC_DIR"
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/archive/refs/tags/$VERSION.tar.gz"
    curl -L "$DOWNLOAD_URL" -o "$SRC_DIR/sing-box.tar.gz"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download version $VERSION. Please check the version number."
        exit 1
    fi
    tar -xzf "$SRC_DIR/sing-box.tar.gz" -C "$SRC_DIR" --strip-components=1
    echo "Source code for version $VERSION downloaded and extracted to $SRC_DIR."
}

# Function: Build sing-box using make
build_singbox() {
    echo "Building sing-box using make..."
    mkdir -p "$INSTALL_DIR"
    cd "$SRC_DIR"
    make
    if [ $? -ne 0 ]; then
        echo "Error: Build failed. Please ensure all dependencies are installed."
        exit 1
    fi
    mv "$SRC_DIR/sing-box" "$INSTALL_DIR/"
    echo "sing-box built and installed to $INSTALL_DIR."
}

generate_socks5_config() {
    read -p "Enter SOCKS5 port (default 1080): " socks5_port
    socks5_port=${socks5_port:-1080}

    read -p "Enter SOCKS5 username: " socks5_username
    read -p "Enter SOCKS5 password: " socks5_password

    echo "{
        \"type\": \"socks\",
        \"listen\": \"::\",
        \"listen_port\": $socks5_port,
        \"users\": [
            {
                \"username\": \"$socks5_username\",
                \"password\": \"$socks5_password\"
            }
        ]
    }"
}

generate_hysteria2_config() {
    read -p "Enter Hysteria listen port (default 8080): " hysteria_port
    hysteria_port=${hysteria_port:-8080}

    read -p "Enter password (default password): " user_password
    user_password=${user_password:-"password"}

    read -p "Enter TLS server name (default bing.com): " server_name
    server_name=${server_name:-"bing.com"}

    cert_dir="$BASE_DIR/certs"
    mkdir -p $cert_dir
    cert_path="$cert_dir/cert.pem"
    key_path="$cert_dir/key.pem"
    openssl req -new -newkey rsa:2048 -days 36500 -nodes -x509 -keyout "$key_path" -out "$cert_path" -subj "/CN=$server_name" > /dev/null 2>&1

    echo "{
        \"type\": \"hysteria2\",
        \"listen\": \"::\",
        \"listen_port\": $hysteria_port,
        \"users\": [
            {
                \"password\": \"$user_password\"
            }
        ],
        \"tls\": {
            \"enabled\": true,
            \"server_name\": \"$server_name\",
            \"key_path\": \"$key_path\",
            \"certificate_path\": \"$cert_path\"
        }
    }"
}

generate_vless_config() {
    read -p "Enter VLESS port (default 8080): " vless_port
    vless_port=${vless_port:-8080}

    read -p "Enter VLESS uuid (default bf000d23-0752-40b4-affe-68f7707a9661): " vless_uuid
    vless_uuid=${vless_uuid:-"bf000d23-0752-40b4-affe-68f7707a9661"}

    read -p "Enter VLESS path (default /): " vless_path
    vless_path=${vless_path:-"/"}

    read -p "Enter TLS server name (default bing.com): " server_name
    server_name=${server_name:-"bing.com"}
    
    cert_dir="$BASE_DIR/certs"
    mkdir -p $cert_dir
    cert_path="$cert_dir/cert.pem"
    key_path="$cert_dir/key.pem"
    openssl req -new -newkey rsa:2048 -days 36500 -nodes -x509 -keyout "$key_path" -out "$cert_path" -subj "/CN=$server_name" > /dev/null 2>&1

    echo "{
        \"type\": \"vless\",
        \"listen\": \"::\",
        \"listen_port\": $vless_port,
        \"users\": [
            {
                \"uuid\": \"$vless_uuid\"
            }
        ],
        \"tls\": {
            \"enabled\": true,
            \"server_name\": \"$server_name\",
            \"key_path\": \"$key_path\",
            \"certificate_path\": \"$cert_path\"
        },
        \"multiplex\": {
            \"enabled\": true
        },
        \"transport\": {
            \"type\": \"ws\",
            \"path\": \"$vless_path\",
            \"headers\": {
                \"host\": \"$server_name\"
            },
            \"max_early_data\": 2048,
            \"early_data_header_name\": \"Sec-WebSocket-Protocol\"
        }
    }"
}

generate_ss_config() {
    read -p "Enter Shadowsocks port (default 8080): " ss_port
    ss_port=${ss_port:-8080}

    read -p "Enter Shadowsocks password (default pwIfFx5jm5EsV27b2cJm0g==): " ss_password
    ss_password=${ss_password:-"pwIfFx5jm5EsV27b2cJm0g=="}

    echo "{
        \"type\": \"shadowsocks\",
        \"listen\": \"::\",
        \"listen_port\": $ss_port,
        \"password\": \"$ss_password\",
        \"network\": \"tcp\",
        \"method\": \"2022-blake3-aes-128-gcm\",
        \"multiplex\": {
            \"enabled\": true
        }
    }"
}

# Display the current configuration file
show_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "Current configuration:"
        cat "$CONFIG_FILE"
    else
        echo "No configuration file found."
    fi
}

# Generate configuration file
generate_config() {
    # Initialize configuration variables
    local current_inbounds=""
    local new_inbounds=""
    local is_update=false

    # Check if configuration file exists
    if [[ -f "$CONFIG_FILE" ]]; then
        read -p "Configuration file already exists. Do you want to update it? (y/n): " update_config
        if [[ ! "$update_config" =~ ^[yY]$ ]]; then
            echo "Exiting without changes."
            return
        fi

        # Read existing inbounds from the configuration file
        current_inbounds=$(jq '.inbounds' "$CONFIG_FILE")
        is_update=true
    else
        current_inbounds="[]"
    fi

    # Protocol options
    declare -A protocol_handlers=(
        ["1"]="SOCKS5"
        ["2"]="Hysteria2"
        ["3"]="Shadowsocks"
        ["4"]="VLESS"
        # Add more protocols here as needed
    )

    # Protocol configuration loop
    while true; do
        echo "Select a protocol to configure or update:"
        for key in "${!protocol_handlers[@]}"; do
            echo "$key) ${protocol_handlers[$key]}"
        done
        echo "0) Finish configuration"

        read -p "Enter your choice: " choice

        if [[ "$choice" == "0" ]]; then
            break
        elif [[ -n "${protocol_handlers[$choice]}" ]]; then
            case "${protocol_handlers[$choice]}" in
                "SOCKS5")
                    local socks5_config=$(generate_socks5_config)
                    if [[ -n "$socks5_config" ]]; then
                        current_inbounds=$(echo "$current_inbounds" | jq ". + [$socks5_config]")
                    fi
                    ;;
                "Hysteria2")
                    local hysteria2_config=$(generate_hysteria2_config)
                    if [[ -n "$hysteria2_config" ]]; then
                        current_inbounds=$(echo "$current_inbounds" | jq ". + [$hysteria2_config]")
                    fi
                    ;;
                "Shadowsocks")
                    local ss_config=$(generate_ss_config)
                    if [[ -n "$ss_config" ]]; then
                        current_inbounds=$(echo "$current_inbounds" | jq ". + [$ss_config]")
                    fi
                    ;;
                "VLESS")
                    local vless_config=$(generate_vless_config)
                    if [[ -n "$vless_config" ]]; then
                        current_inbounds=$(echo "$current_inbounds" | jq ". + [$vless_config]")
                    fi
                    ;;
                *)
                    echo "Unsupported protocol: ${protocol_handlers[$choice]}"
                    ;;
            esac
        else
            echo "Invalid choice. Please try again."
        fi
    done

    # Construct the full configuration
    local CONFIG_CONTENT=$(jq -n --argjson inbounds "$current_inbounds" --arg log_output "$LOG_FILE" '
    {
        log: {
            disabled: false,
            level: "info",
            output: $log_output,
            timestamp: true
        },
        inbounds: $inbounds,
        outbounds: [
            {
                type: "direct"
            }
        ]
    }')

    # Write the configuration to the file
    echo "$CONFIG_CONTENT" > "$CONFIG_FILE"
    echo "Configuration file $( [[ "$is_update" == true ]] && echo "updated" || echo "created" ) at $CONFIG_FILE."
}

# Function: Install sing-box
install_singbox() {
    echo "Installing sing-box to $BASE_DIR..."
    read -p "Enter the version to install (e.g., v1.10.1): " VERSION
    if [[ ! $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid version format. Please use the format 'vX.Y.Z'."
        exit 1
    fi
    download_source "$VERSION"
    build_singbox
    echo "$VERSION" > "$VERSION_FILE" # Record installed version
    # Create a sample config file if not exists
    if [ -f "$CONFIG_FILE" ]; then
        read -p "Configuration file already exists. Overwrite? (y/n): " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            generate_config
        else
            echo "Using existing configuration file."
        fi
    else
        generate_config
    fi
    echo "sing-box installed successfully with version $VERSION."

    # Clean up source directory
    rm -rf "$SRC_DIR"
    echo "Source directory cleaned up."
}

# Function: Upgrade sing-box
upgrade_singbox() {
    if [ ! -f "$VERSION_FILE" ]; then
        echo "sing-box is not installed. Please install it first."
        return
    fi
    echo "Current version: $(cat "$VERSION_FILE")"
    read -p "Enter the version to upgrade to (e.g., v1.10.1): " VERSION
    if [[ ! $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid version format. Please use the format 'vX.Y.Z'."
        exit 1
    fi
    stop_singbox

    # Perform the upgrade
    download_source "$VERSION"
    build_singbox
    echo "$VERSION" > "$VERSION_FILE" # Update installed version

    echo "sing-box upgraded to version $VERSION. Configuration file retained."

    # Clean up source directory
    rm -rf "$SRC_DIR"
    echo "Source directory cleaned up."
}

# Function: Uninstall sing-box
uninstall_singbox() {
    echo "Uninstalling sing-box from $BASE_DIR..."
    stop_singbox
    rm -rf "$BASE_DIR"
    echo "sing-box uninstalled successfully."
}

# Function: Start sing-box
start_singbox() {
    echo "Starting sing-box..."
    pid=$(pgrep -f -x "$SERVICE_CMD")
    if [ -n "$pid" ]; then
        echo "sing-box is already running."
    else
        nohup "$INSTALL_DIR/sing-box" run -c "$CONFIG_FILE" > /dev/null 2>&1 &
        echo "sing-box started with PID $!"
    fi
}

# Function: Stop sing-box
stop_singbox() {
    echo "Stopping sing-box..."
    pid=$(pgrep -f -x "$SERVICE_CMD")
    if [ -n "$pid" ]; then
        kill "$pid"
        echo "sing-box stopped."
    else
        echo "sing-box is not running."
    fi
}

# Main script logic
check_local_status
while true; do
    echo "**************************************************"
    echo "1. Install sing-box"
    echo "2. Upgrade sing-box"
    echo "3. Uninstall sing-box"
    echo "4. Start sing-box"
    echo "5. Stop sing-box"
    echo "6. Restart sing-box"
    echo "7. Check status"
    echo "8. Show config"
    echo "9. Reset config"
    echo "0. Quit"
    read -p "Enter your choice (0-9): " choice
    echo "**************************************************"
    case $choice in
        1)
            install_singbox
            ;;
        2)
            upgrade_singbox
            ;;
        3)
            uninstall_singbox
            ;;
        4)
            start_singbox
            ;;
        5)
            stop_singbox
            ;;
        6)
            stop_singbox
            start_singbox
            ;;
        7)
            check_local_status
            ;;
        8)
            show_config
            ;;
        9)
            generate_config
            ;;
        0)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done