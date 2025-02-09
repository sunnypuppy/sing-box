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
LATEST_VERSION=""

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
# Example: read_color "Enter your input: " input --color="black"
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
        read_color "Do you want to install them now? (Y/n): " user_input --color="black"; user_input=${user_input:-Y}
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
                    echo_color "Unsupported package manager. Please install $dep manually. Exit.\n" --color="red"
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
            echo_color "Chose not to install missing dependencies. Exit.\n" --color="yellow"
            exit 1
        fi
    else
        echo_color "All dependencies are already installed.\n" --color="green"
    fi
}

get_latest_version() {
    echo_color "Fetching the latest version from GitHub...\n" --color="blue"
    LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
    if [[ -z "$LATEST_VERSION" ]]; then
        echo_color "Unable to fetch the latest version from GitHub.\n" --color="red"
        exit 1
    fi
    echo_color "Latest version fetched successfully: $LATEST_VERSION\n" --color="green"
}

download_source_code() {
    VERSION=$1
    mkdir -p "$SRC_DIR"
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
    mkdir -p "$INSTALL_DIR"
    cd "$SRC_DIR"
    make -s VERSION="$LATEST_VERSION"
    if [ $? -ne 0 ]; then
        echo_color "Service build failed, check all dependencies are installed.\n" --color="red"
        exit 1
    fi
    mv "$SRC_DIR/sing-box" "$INSTALL_DIR/"
    echo_color "Service built and installed to "; echo_color "$INSTALL_DIR\n" --color="green";
}

PROTOCOL_CONFIGS=(
    "socks5:generate_socks5_config"
    "hysteria2:generate_hysteria2_config"
    "vless:generate_vless_config"
    "shadowsocks:generate_shadowsocks_config"
)

generate_shadowsocks_config() {
    read_color "Enter Shadowsocks port (default 8080): " ss_port --color="black"; ss_port=${ss_port:-8080}
    read_color "Enter Shadowsocks password (default pwIfFx5jm5EsV27b2cJm0g==): " ss_password --color="black"; ss_password=${ss_password:-"pwIfFx5jm5EsV27b2cJm0g=="}

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
    read_color "Enter VLESS port (default 8080): " vless_port --color="black"; vless_port=${vless_port:-8080}
    read_color "Enter VLESS uuid (default bf000d23-0752-40b4-affe-68f7707a9661): " vless_uuid --color="black"; vless_uuid=${vless_uuid:-"bf000d23-0752-40b4-affe-68f7707a9661"}
    read_color "Enter VLESS path (default /): " vless_path --color="black"; vless_path=${vless_path:-"/"}
    read_color "Enter TLS server name (default bing.com): " server_name --color="black"; server_name=${server_name:-"bing.com"}
    
    cert_dir="$BASE_DIR/certs"; mkdir -p $cert_dir
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

generate_hysteria2_config() {
    read_color "Enter Hysteria listen port (default 8080): " hysteria_port --color="black"; hysteria_port=${hysteria_port:-8080}
    read_color "Enter password (default password): " user_password --color="black"; user_password=${user_password:-"password"}
    read_color "Enter TLS server name (default bing.com): " server_name --color="black"; server_name=${server_name:-"bing.com"}

    cert_dir="$BASE_DIR/certs"; mkdir -p $cert_dir
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

generate_socks5_config() {
    read_color "Enter socks5 port (default 1080): " socks_port --color="black"; socks_port=${socks_port:-1080}
    read_color "Enter socks5 username: " socks_username --color="black"
    read_color "Enter socks5 password:" socks_password --color="black"
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
    [ -f "$CONFIG_FILE" ] && jq . "$CONFIG_FILE" || echo_color "No configuration file ($CONFIG_FILE) found.\n" --color="yellow"
}

generate_config() {
    # Display the available protocols
    echo_available_protocols

    echo_color "Enter protocols you want to configure (comma-separated, e.g., ${protocol_list[0]},${protocol_list[1]}): " --color="black"
    read selected_protocols
    IFS=',' read -ra protocols_array <<< "$selected_protocols"
    
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
}

add_protocol() {
    read_color "Enter protocol you want to add: " protocol --color="black" 
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
        echo_color "Select one protocol to delete:\n" --color="black"
        select protocol in $protocol_list; do
            if [[ -z "$protocol" ]]; then
                echo_color "No protocol selected, exiting operation.\n" --color="cyan"
                break 2
            fi
            read_color "confirm delete $protocol protocol? (y/N): " confirm --color="red"; confirm=${confirm:-N}
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
    read_color "Enter protocol you want to modify: " protocol --color="black" 
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

###### Service Manager ######
service_manager() {
    clear

    while true; do
        echo "********************************************************"
        echo_color "\nService Manger\n\n" --color="blue"
        echo "********************************************************"

        echo "1. Install"
        echo "2. Upgrade"
        echo "3. Uninstall"
        echo "4. Start"
        echo "5. Stop"
        echo "6. Restart"
        echo "7. Status"
        echo "----------------"
        echo "0. Back"
        read_color "(Service Manger) Enter your choice: " choice --color="black"; clear
        echo "********************************************************"
        case $choice in
            1)
                install_service
                ;;
            2)
                upgrade_service
                ;;
            3)
                uninstall_service
                ;;
            4)
                start_service
                ;;
            5)
                stop_service
                ;;
            6)
                stop_service; sleep 1; start_service
                ;;
            7)
                show_service_status
                ;;
            0)
                clear; break
                ;;
            *)
                echo_color "Invalid choice. Please enter again!\n" --color="red"
                ;;
        esac
    done
}

install_service() {
    echo_color "Installing sing-box service to: "; echo_color "$BASE_DIR\n" --color="cyan";
    while true; do
        read_color "Enter the install version (Latest: $LATEST_VERSION): " VERSION --color="black"; VERSION=${VERSION:-$LATEST_VERSION}
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

    echo_color "Service $VERSION installed successfully.\n" --color="green"
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
        read_color "Enter the version to upgrade/downgrade to (default $LATEST_VERSION): " VERSION --color="black"; VERSION=${VERSION:-$LATEST_VERSION}
        if [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
        echo_color "Invalid version format. Please use the format 'vX.Y.Z', where X, Y, and Z are numbers." "red"
    done

    stop_service

    # Perform the upgrade/downgrade
    download_source_code "$VERSION"
    build_service
    echo "$VERSION" > "$VERSION_FILE" # Update installed version

    echo_color "Service upgraded/downgrade to version $VERSION. Configuration file retained." "green"

    # Clean up source directory
    rm -rf "$SRC_DIR"
    echo "Source directory cleaned up."
}

uninstall_service() {
    read_color "uninstall sing-box service? (y/N): " confirm --color="red"; confirm=${confirm:-N}
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

    if [ ! -x "$INSTALL_DIR/sing-box" ]; then
        echo_color "Service binary not found or not executable at $INSTALL_DIR/sing-box\n" --color="red"
        return 1
    fi
    if [ ! -f "$CONFIG_FILE" ]; then
        echo_color "Configuration file not found: $CONFIG_FILE\n" --color="red"
        return 1
    fi
    nohup "$INSTALL_DIR/sing-box" run -c "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &

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

###### Configuration Manager ######
configuration_manager() {
    clear

    while true; do
        echo "********************************************************"
        echo_color "\nConfiguration Manger\n\n" --color="blue"
        echo "********************************************************"

        echo "1. Generate"
        echo "2. Show"
        echo "3. Add Protocol"
        echo "4. Remove Protocol"
        echo "5. Update Protocol"
        echo "-------------------------"
        echo "0. Back"
        read_color "(Configuration Manger) Enter your choice: " choice --color="black"; clear
        echo "********************************************************"
        case $choice in
            1)
                generate_config
                ;;
            2)
                show_config
                ;;
            3)
                add_protocol
                ;;
            4)
                remove_protocol
                ;;
            5)
                update_protocol
                ;;
            0)
                clear; break
                ;;
            *)
                echo_color "Invalid choice. Please enter again!\n" --color="red"
                ;;
        esac
    done
}

main() {
    check_and_install_deps
    get_latest_version
    clear

    while true; do
        echo "********************************************************"
        echo_color "\nSing-box Tools\n\n" --color="blue"
        show_service_status
        echo "********************************************************"

        echo "1. Service Manager"
        echo "2. Configuration Manager"
        echo "-------------------------"
        echo "0. Quit"
        read_color "(Sing-box Tools) Enter your choice: " choice --color="black"; clear
        echo "********************************************************"
        case $choice in
            1)
                service_manager
                ;;
            2)
                configuration_manager
                ;;
            0)
                clear; break
                ;;
            *)
                echo_color "Invalid choice. Please enter again!\n" --color="red"
                ;;
        esac
    done
}

main