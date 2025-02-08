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

# Check local version and service status
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

# Download and extract source code for the specified version
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

# Build sing-box using make
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

# Protocol registration table (local to this function)
PROTOCOL_CONFIGS=(
    "socks5:generate_socks_config"
    "hysteria2:generate_hysteria2_config"
    "vless:generate_vless_config"
    "shadowsocks:generate_shadowsocks_config"
)

# Generate configuration for Shadowsocks protocol
generate_shadowsocks_config() {
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

# Generate configuration for VLESS protocol
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

# Generate configuration for hysteria2 protocol
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

# Generate configuration for socks protocol
generate_socks_config() {
    read -p "Enter SOCKS port (default 1080): " socks_port
    socks_port=${socks_port:-1080}

    read -p "Enter SOCKS username: " socks_username
    read -p "Enter SOCKS password: " socks_password

    echo "{
        \"type\": \"socks\",
        \"listen\": \"::\",
        \"listen_port\": $socks_port,
        \"users\": [
            {
                \"username\": \"$socks_username\",
                \"password\": \"$socks_password\"
            }
        ]
    }"
}

# Display the current configuration file
show_config() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo "No configuration file found."
    fi
}

# Generate configuration file
generate_config() {
    CONFIG_CONTENT='{
    "log": {
        "disabled": false,
        "level": "info",
        "output": "'$LOG_FILE'",
        "timestamp": true
    },
    "inbounds": ['

    # Loop through protocol registration table
    for entry in "${PROTOCOL_CONFIGS[@]}"; do
        protocol="${entry%%:*}"
        generator="${entry#*:}"
        
        # Prompt user for input
        read -p "Do you want to configure $protocol protocol? (y/n): " user_input
        if [[ "$user_input" == "y" || "$user_input" == "Y" ]]; then
            CONFIG_CONTENT+=$($generator)
            CONFIG_CONTENT+=','
        fi
    done

    # Remove trailing comma and finalize the configuration
    CONFIG_CONTENT=$(echo "$CONFIG_CONTENT" | sed '$s/,$//')
    CONFIG_CONTENT+='],
    "outbounds": [
        {
            "type": "direct"
        }
    ]
}
'

    # Write to configuration file
    echo "$CONFIG_CONTENT" | tee "$CONFIG_FILE"
    echo "Configuration file created at $CONFIG_FILE."
}

# Install sing-box
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

# Upgrade sing-box
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

# Uninstall sing-box
uninstall_singbox() {
    echo "Uninstalling sing-box from $BASE_DIR..."
    stop_singbox
    rm -rf "$BASE_DIR"
    echo "sing-box uninstalled successfully."
}

# Start sing-box
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

# Stop sing-box
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
            sleep 3
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