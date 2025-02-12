#!/bin/bash
# Script to manage sing-box deployment in $HOME directory

# Define directories
BASE_DIR="$HOME/sing-box"
CONF_DIR="$BASE_DIR/conf"
LOG_DIR="$BASE_DIR/log"
SRC_DIR="$BASE_DIR/source"
INSTALL_DIR="$BASE_DIR/bin"
SSL_DIR="$BASE_DIR/ssl"
init_dir(){
    mkdir -p "$BASE_DIR" "$CONF_DIR" "$LOG_DIR" "$SRC_DIR" "$INSTALL_DIR" "$SSL_DIR"
}
init_dir

# Define file
CONFIG_FILE="$CONF_DIR/config.json"
LOG_FILE="$LOG_DIR/sing-box.log"
VERSION_FILE="$BASE_DIR/VERSION"

# Define exec file and cmd
SERVICE_BINARY="$INSTALL_DIR/sing-box"
SERVICE_CMD="$SERVICE_BINARY run -c $CONFIG_FILE"

# Echo text with color
# Usage: echo_color "Text to display" --color="color_name"
# Example: echo_color "Hello World" --color="green"
echo_color() {
    local text="$1"     # The first argument is the text to display
    local color="reset" # Default color is reset (no color)

    shift  # Move past the text parameter

    # Parse options (handle key-value style like --color="green")
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --color=*)   color="${1#--color=}" ;;
            *) echo "Invalid option: $1"; return 1 ;;  # Catch any invalid options
        esac
        shift
    done

    # Color Codes (String to ANSI code mapping)
    case "$color" in
        black)   color_code="30" ;;
        red)     color_code="31" ;;
        green)   color_code="32" ;;
        yellow)  color_code="33" ;;
        blue)    color_code="34" ;;
        magenta) color_code="35" ;;
        cyan)    color_code="36" ;;
        white)   color_code="37" ;;
        reset)   color_code="0"  ;;
        *)       echo "Invalid color: $color"; return 1 ;;
    esac

    echo -n -e "\033[${color_code}m${text}\033[0m"
}

# Read with color prompt
# Usage: read_color "Prompt to display" input --color="color_name"
# Example: read_color "Enter your input: " input --color="magenta"
read_color() {
    local prompt_message="$1"   # The message for the prompt
    local input_variable="$2"   # The variable to store the input
    local color="reset"         # Default color is reset (no color)
    local color_code=""         # Initialize color code

    shift 2  # Move past the message and variable parameters

    # Parse options (handle key-value style like --color="green")
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --color=*) color="${1#--color=}" ;;
            *) echo "Invalid option: $1"; return 1 ;;  # Catch any invalid options
        esac
        shift
    done

    # Map color to ANSI code
    case "$color" in
        black)   color_code="30" ;;
        red)     color_code="31" ;;
        green)   color_code="32" ;;
        yellow)  color_code="33" ;;
        blue)    color_code="34" ;;
        magenta) color_code="35" ;;
        cyan)    color_code="36" ;;
        white)   color_code="37" ;;
        reset)   color_code="0"  ;;
        *)       echo "Invalid color: $color"; return 1 ;;
    esac

    # Display the prompt with the combined color
    read -p "$(echo -e "\033[${color_code}m${prompt_message}\033[0m")" "$input_variable"
}

check_and_install_deps() {
    echo_color "Checking required dependencies...\n" --color="blue"

    local dependencies=("curl" "make" "openssl" "go" "jq")
    missing_dependencies=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_dependencies+=("$dep")
        fi
    done

    if [ ${#missing_dependencies[@]} -gt 0 ]; then
        echo_color "The following dependencies are missing: ${missing_dependencies[*]}\n" --color="yellow"
        read_color "Do you want to install them now? (Y/n): " user_input --color="magenta"; user_input=${user_input:-Y}
        if [[ "$user_input" == "y" || "$user_input" == "Y" ]]; then
            # Install missing dependencies
            for dep in "${missing_dependencies[@]}"; do
                echo_color "Installing $dep...\n" --color="yellow"
                if command -v apt-get &> /dev/null; then  # Debian/Ubuntu
                    apt-get update && apt-get install -y "$dep"
                elif command -v yum &> /dev/null; then  # CentOS/RHEL
                    yum install -y "$dep"
                elif command -v brew &> /dev/null; then  # macOS use Homebrew
                    brew install "$dep"
                else
                    echo_color "Unsupported package manager. Please install $dep manually. Exiting...\n" --color="red"
                    exit 1
                fi
            done

            # Recheck if all dependencies are installed
            for dep in "${missing_dependencies[@]}"; do
                if ! command -v "$dep" &> /dev/null; then
                    echo_color "Failed to install $dep. Please install it manually.\n" --color="red"
                    exit 1
                else
                    echo_color "Successfully installed $dep.\n" --color="blue"
                fi
            done
            echo_color "All missing dependencies have been successfully installed.\n" --color="green"
        else
            echo_color "Chose not to install missing dependencies. Exiting...\n" --color="yellow"
            exit 1
        fi
    else
        echo_color "All dependencies are already installed.\n" --color="green"
    fi
}

get_latest_version() {
    if [[ -z "$LATEST_VERSION" ]]; then
        echo_color "Fetching the latest version from GitHub...\n" --color="blue"
        LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
        if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == "null" ]]; then
            echo_color "Unable to fetch the latest version from GitHub.\n" --color="red"
            read_color "Enter the latest version manually (e.g., v1.11.1): " LATEST_VERSION --color="magenta"
            if [[ $LATEST_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo_color "Manually set the latest version: $LATEST_VERSION\n" --color="yellow"
            else
                echo_color "Invalid version format. Exiting...\n" --color="red"
                exit 1
            fi
        fi
        echo_color "Latest version fetched successfully: $LATEST_VERSION\n" --color="green"
    fi
}

download_source_code() {
    VERSION=$1
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/archive/refs/tags/$VERSION.tar.gz"
    echo_color "Source code download url: "; echo_color "$DOWNLOAD_URL\n" --color="cyan"
    curl -L "$DOWNLOAD_URL" -o "$SRC_DIR/sing-box.tar.gz"
    if [ $? -ne 0 ]; then
        echo_color "Failed to download version $VERSION. Please check the version number.\n" --color="red"
        exit 1
    fi
    tar -xzf "$SRC_DIR/sing-box.tar.gz" -C "$SRC_DIR" --strip-components=1
    echo_color "Source code for version $VERSION downloaded and extracted to "; echo_color "$SRC_DIR\n" --color="cyan"
}

build_service() {
    echo_color "Starting build service...\n"
    cd "$SRC_DIR"
    make -s VERSION="$VERSION" > /dev/null
    if [ $? -ne 0 ]; then
        echo_color "Service build failed, check all dependencies are installed.\n" --color="red"
        exit 1
    fi
    mv "$SRC_DIR/sing-box" "$INSTALL_DIR/"
    echo_color "Service built and installed to "; echo_color "$INSTALL_DIR\n" --color="green";
}

# Function to generate a self-signed SSL certificate and private key
# Arguments:
# 1. common_name (e.g., example.com)
# 2. cert_path (Path to save the certificate file, e.g., /etc/ssl/certs/mycert.crt)
# 3. key_path (Path to save the private key file, e.g., /etc/ssl/private/mykey.key)
# 4. days (Optional: the number of days the certificate will be valid, default is 36500 days, or ~100 years)
generate_ssl_certificate() {
  local common_name="$1"   # The Common Name (CN) for the certificate (e.g., domain name)
  local cert_path="$2"     # Path where the certificate will be saved
  local key_path="$3"      # Path where the private key will be saved
  local days="${4:-36500}" # The certificate validity period (default is 36500 days)

  # Ensure that cert_path and key_path are provided
  if [ -z "$cert_path" ] || [ -z "$key_path" ]; then
    echo_color "Generate SSL certificate failed. Usage: generate_ssl_certificate <common_name> <cert_path> <key_path> [days]" --color="red"
    exit 1
  fi

  # Generate the self-signed certificate and private key
  openssl req -new -newkey rsa:2048 -days "$days" -nodes -x509 -keyout "$key_path" -out "$cert_path" -subj "/CN=$common_name" > /dev/null 2>&1
}

PROTOCOL_CONFIGS=(
    "socks5:generate_socks5_config"
    "hysteria2:generate_hysteria2_config"
    "vless:generate_vless_config"
    "shadowsocks:generate_shadowsocks_config"
)

generate_shadowsocks_config() {
    read_color "Enter Shadowsocks port (default 8080): " ss_port --color="magenta"; ss_port=${ss_port:-8080}
    read_color "Enter Shadowsocks password (default pwIfFx5jm5EsV27b2cJm0g==): " ss_password --color="magenta"; ss_password=${ss_password:-"pwIfFx5jm5EsV27b2cJm0g=="}

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

generate_vless_config() {
    read_color "Enter VLESS port (default 8080): " vless_port --color="magenta"; vless_port=${vless_port:-8080}
    read_color "Enter VLESS uuid (default bf000d23-0752-40b4-affe-68f7707a9661): " vless_uuid --color="magenta"; vless_uuid=${vless_uuid:-"bf000d23-0752-40b4-affe-68f7707a9661"}
    read_color "Enter VLESS path (default /): " vless_path --color="magenta"; vless_path=${vless_path:-"/"}
    read_color "Enter TLS server name (default bing.com): " server_name --color="magenta"; server_name=${server_name:-"bing.com"}
    
    cert_path="$SSL_DIR/$server_name.crt"
    key_path="$SSL_DIR/$server_name.key"
    generate_ssl_certificate $server_name $cert_path $key_path

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

generate_hysteria2_config() {
    read_color "Enter Hysteria listen port (default 8080): " hysteria_port --color="magenta"; hysteria_port=${hysteria_port:-8080}
    read_color "Enter password (default password): " user_password --color="magenta"; user_password=${user_password:-"password"}
    read_color "Enter TLS server name (default bing.com): " server_name --color="magenta"; server_name=${server_name:-"bing.com"}

    cert_path="$SSL_DIR/$server_name.crt"
    key_path="$SSL_DIR/$server_name.key"
    generate_ssl_certificate $server_name $cert_path $key_path

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

generate_socks5_config() {
    read_color "Enter socks5 port (default 1080): " socks_port --color="magenta"; socks_port=${socks_port:-1080}
    read_color "Enter socks5 username: " socks_username --color="magenta"
    read_color "Enter socks5 password: " socks_password --color="magenta"
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

echo_available_protocols() {
    protocol_list=()
    for entry in "${PROTOCOL_CONFIGS[@]}"; do
        protocol="${entry%%:*}"
        protocol_list+=("$protocol")
    done
    echo_color "Available protocols: "; echo_color "${protocol_list[*]}\n" --color="green"
}

show_config() {
    [ -f "$CONFIG_FILE" ] && jq . "$CONFIG_FILE" || echo_color "No configuration file found at $CONFIG_FILE\n" --color="yellow"
}

generate_config() {
    # Display the available protocols
    echo_available_protocols

    echo_color "Enter protocols you want to configure (comma-separated, e.g., $(IFS=,; echo "${protocol_list[*]}")): " --color="magenta"
    read selected_protocols
    IFS=',' read -ra protocols_array <<< "$selected_protocols"
    if [[ -z "$selected_protocols" ]]; then
        echo_color "No input provided. Exiting...\n" --color="yellow"
        return 1
    fi
    
    CONFIG_CONTENT='{
    "log": {
        "disabled": false,
        "level": "info",
        "output": "'$LOG_FILE'",
        "timestamp": true
    },
    "inbounds": ['

    # Loop config protocols
    for protocol in "${protocols_array[@]}"; do
        generator=""
        for entry in "${PROTOCOL_CONFIGS[@]}"; do
            key="${entry%%:*}"
            value="${entry#*:}"
            if [[ "$key" == "$protocol" ]]; then
                generator="$value"
                break
            fi
        done

        if [[ -n "$generator" ]]; then
            echo_color "Start configure "; echo_color "$protocol" --color="yellow"; echo_color " protocol.\n"
            # Dynamically call the generator function based on the protocol
            CONFIG_CONTENT+=$($generator)
            CONFIG_CONTENT+=','
        else
            echo_color "Unknown protocol '$protocol', skipped.\n" --color="yellow"
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
    echo "$CONFIG_CONTENT" | jq . > "$CONFIG_FILE"
    echo_color "Configuration file created at " --color="green"; echo_color "$CONFIG_FILE\n" --color="cyan"

    read_color "Try start service now? (Y/n)" user_input --color="magenta"; user_input=${user_input:-Y}
    if [[ "$user_input" == "y" || "$user_input" == "Y" ]]; then
        start_service
    fi
}

add_protocol() {
    read_color "Enter protocol you want to add: " protocol --color="magenta" 
    generator=""
    for entry in "${PROTOCOL_CONFIGS[@]}"; do
        key="${entry%%:*}"
        value="${entry#*:}"
        if [[ "$key" == "$protocol" ]]; then
            generator="$value"
            break
        fi
    done

    if [[ -n "$generator" ]]; then
        jq --argjson generator "$($generator)" '.inbounds += [$generator]' "$CONFIG_FILE" > temp_config.json && mv temp_config.json "$CONFIG_FILE"
        echo_color "Protocol $protocol added to inbounds.\n" --color="green"
    else
        echo_color "Protocol $protocol not found.\n" --color="yellow"
    fi
}

remove_protocol() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo_color "Configuration file not found: $CONFIG_FILE\n" --color="red"
        return 1
    fi

    local protocol_list
    protocol_list=$(jq -r '.inbounds[] | .type' "$CONFIG_FILE" | sort -u)
    if [[ -z "$protocol_list" ]]; then
        echo_color "No protocols or ports found in inbounds.\n" --color="red"
        return 1
    fi

    while true; do
        echo_color "Select one protocol to delete:\n" --color="magenta"
        select protocol in $protocol_list; do
            if [[ -z "$protocol" ]]; then
                echo_color "No protocol selected, exiting operation.\n" --color="cyan"
                break 2
            fi
            read_color "Confirm delete $protocol protocol? (y/N): " confirm --color="red"; confirm=${confirm:-N}
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                jq --arg protocol "$protocol" 'del(.inbounds[] | select(.type == $protocol))' "$CONFIG_FILE" > tmp_config.json && mv tmp_config.json "$CONFIG_FILE"
                echo_color "Protocol $protocol has been deleted.\n" --color="yellow"
            else
                echo_color "Aborted.\n" --color="cyan"
            fi
            break
        done

        protocol_list=$(jq -r '.inbounds[] | .type' "$CONFIG_FILE" | sort -u)
        if [[ -z "$protocol_list" ]]; then
            echo_color "No protocols left to delete.\n" --color="yellow"
            break
        fi
    done
}

update_protocol() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo_color "Configuration file not found: $CONFIG_FILE\n" --color="red"
        return 1
    fi

    local protocol_list
    protocol_list=$(jq -r '.inbounds[] | .type' "$CONFIG_FILE" | sort -u)
    read_color "Enter protocol you want to modify: " protocol --color="magenta" 
    if ! echo "$protocol_list" | grep -qw "^$protocol$"; then
        echo_color "Protocol $protocol not found.\n" --color="yellow"
        return 1
    fi

    generator=""
    for entry in "${PROTOCOL_CONFIGS[@]}"; do
        key="${entry%%:*}"
        value="${entry#*:}"
        if [[ "$key" == "$protocol" ]]; then
            generator="$value"
            break
        fi
    done

    if [[ -n "$generator" ]]; then
        jq --arg protocol "$protocol" --argjson generator "$($generator)" \
            '.inbounds |= map(
                if .type == $protocol then
                    $generator
                else
                    .
                end
            )' "$CONFIG_FILE" > temp_config.json && mv temp_config.json "$CONFIG_FILE"
        echo_color "Protocol $protocol added to inbounds.\n" --color="green"
    else
        echo_color "Protocol $protocol not found.\n" --color="yellow"
    fi
}

install_service() {
    echo_color "Installing sing-box service to: "; echo_color "$BASE_DIR\n" --color="cyan";
    while true; do
        read_color "Enter the install version (Latest: $LATEST_VERSION): " VERSION --color="magenta"; VERSION=${VERSION:-$LATEST_VERSION}
        if [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        echo_color "Invalid version format. Please use 'vX.Y.Z' (e.g., v1.2.3).\n" --color="red"
    done
    
    download_source_code "$VERSION"
    build_service
    echo "$VERSION" > "$VERSION_FILE" # Record installed version

    # Clean up source directory
    rm -rf "$SRC_DIR"
    echo_color "Source directory cleaned up.\n"

    echo_color "Sing-box service $VERSION installed successfully.\n" --color="green"

    read_color "Continue to generate base configuration? (Y/n)" user_input --color="magenta"; user_input=${user_input:-Y}
    if [[ "$user_input" == "y" || "$user_input" == "Y" ]]; then
        generate_config
    fi
}

upgrade_service() {
    if [ ! -f "$VERSION_FILE" ]; then
        echo_color "Service not installed, please install first.\n" --color="yellow"
        return
    fi

    echo_color "Current version: $(cat "$VERSION_FILE") "
    if [ "$(printf '%s\n' "$LATEST_VERSION" "$LOCAL_VERSION" | sort -V | head -n1)" == "$LATEST_VERSION" ]; then
        echo_color "(Latest)\n" --color="cyan"
    else
        echo_color "(Latest version $LATEST_VERSION)\n" --color="red"
    fi
    
    while true; do
        read_color "Enter the version to upgrade/downgrade to (default $LATEST_VERSION): " VERSION --color="magenta"; VERSION=${VERSION:-$LATEST_VERSION}
        if [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        echo_color "Invalid version format. Please use the format 'vX.Y.Z', where X, Y, and Z are numbers." --color="red"
    done

    stop_service

    # Perform the upgrade/downgrade
    download_source_code "$VERSION"
    build_service
    echo "$VERSION" > "$VERSION_FILE" # Update installed version

    # Clean up source directory
    rm -rf "$SRC_DIR"
    echo "Source directory cleaned up."

    # Restart service
    restart_service
    echo_color "Service upgraded/downgrade to version $VERSION. Configuration file retained." --color="green"
}

uninstall_service() {
    read_color "Uninstall sing-box service? (y/N): " confirm --color="red"; confirm=${confirm:-N}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo_color "Aborted.\n" --color="cyan"
        return 1
    fi

    stop_service
    echo_color "Remove sing-box service dir: "; echo_color "$BASE_DIR\n" --color="red";
    rm -rf "$BASE_DIR"
    echo_color "Uninstall service successfully.\n" --color="green"
}

start_service() {
    pid=$(pgrep -f -x "$SERVICE_CMD")
    if [ -n "$pid" ]; then
        echo_color "Service is already running.\n" --color="yellow"
        return 0
    fi

    if [ ! -x "$SERVICE_BINARY" ]; then
        echo_color "Service binary not found or not executable at $SERVICE_BINARY\n" --color="red"
        return 1
    fi
    if [ ! -f "$CONFIG_FILE" ]; then
        echo_color "Configuration file not found: $CONFIG_FILE\n" --color="red"
        return 1
    fi
    nohup $SERVICE_CMD > "$LOG_FILE" 2>&1 &

    sleep 1
    new_pid=$(pgrep -f -x "$SERVICE_CMD")
    if [ -n "$new_pid" ]; then
        echo_color "Sing-box service started successfully (PID: $new_pid).\n" --color="green"
        return 0
    fi

    echo_color "Failed to start Sing-box service!\n" --color="red"
    tail -n 10 "$LOG_FILE"
    return 1
}

stop_service() {
    pid=$(pgrep -f -x "$SERVICE_CMD")
    if [ -n "$pid" ]; then
        kill "$pid"
        echo_color "Service stopped.\n" --color="green"
    else
        echo_color "Service is not running.\n" --color="yellow"
    fi
}

restart_service() {
    stop_service
    sleep 1
    start_service
}

show_service_status() {
    if [ -f "$VERSION_FILE" ]; then
        LOCAL_VERSION=$(cat "$VERSION_FILE")
        echo_color "Service version: "; echo_color "$LOCAL_VERSION " --color="green";
        if [ "$(printf '%s\n' "$LATEST_VERSION" "$LOCAL_VERSION" | sort -V | head -n1)" == "$LATEST_VERSION" ]; then
            echo_color "(Latest)\n" --color="cyan"
        else
            echo_color "(Latest version $LATEST_VERSION)\n" --color="red"
        fi
    else
        echo_color "Service version: "; echo_color "Not installed " --color="yellow"; echo_color "(Latest version $LATEST_VERSION)\n" --color="cyan"
    fi

    pid=$(pgrep -f -x "$SERVICE_CMD")
    if [ -n "$pid" ]; then
        echo_color "Service status : "; echo_color "Running (PID $pid)\n" --color="green"
    else
        echo_color "Service status : "; echo_color "Not running\n" --color="yellow"
    fi
}

# Function to print menu
print_menu() {
    echo_color "**************************************************************\n" --color="blue"
    echo_color "                   Sing-box Tools Menu\n" --color="cyan"
    echo_color "**************************************************************\n" --color="blue"
    show_service_status
    echo_color "**************************************************************\n" --color="blue"

    # Print System Management Section
    echo_color "[System Management]\n" --color="yellow"
    echo "1. Install sing-box"
    echo "2. Upgrade sing-box"
    echo "3. Uninstall sing-box"
    echo "-------------------------"

    # Print Service Management Section
    echo_color "[Service Management]\n" --color="yellow"
    echo "4. Start sing-box"
    echo "5. Stop sing-box"
    echo "6. Restart sing-box"
    echo "-------------------------"

    # Print Configuration Section
    echo_color "[Configuration]\n" --color="yellow"
    echo "7. Show config"
    echo "8. Reset config"
    echo "-------------------------"

    # Print Protocol Management Section
    echo_color "[Protocol Management]\n" --color="yellow"
    echo "a. Add Protocol"
    echo "b. Remove Protocol"
    echo "c. Update Protocol"
    echo_color "**************************************************************\n" --color="blue"
    
    # Print Quit Option
    echo "0. Quit"
}

# main
check_and_install_deps
get_latest_version
clear

while true; do
    print_menu
    read_color "Enter your choice: " choice --color="magenta"; clear
    case $choice in
        1) install_service ;;
        2) upgrade_service ;;
        3) uninstall_service ;;
        4) start_service ;;
        5) stop_service ;;
        6) restart_service ;;
        7) show_config ;;
        8) generate_config ;;
        a) add_protocol ;;
        b) remove_protocol ;;
        c) update_protocol ;;
        0) clear; break ;;
        *) echo_color "Invalid choice. Please enter again!\n" --color="red" ;;
    esac
done