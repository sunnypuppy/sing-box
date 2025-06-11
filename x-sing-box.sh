#!/bin/bash

############################## global env ##############################
INSTALL_DIR="${INSTALL_DIR:-"$HOME/sing-box"}"

BIN_DIR="$INSTALL_DIR/bin"
CONFIG_DIR="$INSTALL_DIR/conf"
SSL_DIR="$INSTALL_DIR/ssl"
BIN_FILE="$BIN_DIR/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"

LOG_DIR="$INSTALL_DIR/logs"
LOG_OUTPUT="$LOG_DIR/sing-box.log"
LOG_DISABLED="${LOG_DISABLED:-true}"
LOG_LEVEL="${LOG_LEVEL:-info}"

############################## common functions ##############################

# Example usage:
# color_echo -red "This is red text"
# color_echo -n -green "This is green text without newline"
color_echo() {
    local text=""
    local color_code="0"
    local newline=true
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        -n) newline=false ;;
        -black) color_code="30" ;;
        -red) color_code="31" ;;
        -green) color_code="32" ;;
        -yellow) color_code="33" ;;
        -blue) color_code="34" ;;
        -magenta) color_code="35" ;;
        -cyan) color_code="36" ;;
        -white) color_code="37" ;;
        *)
            break
            ;;
        esac
        shift
    done
    text="${@}"
    if [[ "$newline" == true ]]; then
        echo -e "\033[${color_code}m${text}\033[0m"
    else
        echo -n -e "\033[${color_code}m${text}\033[0m"
    fi
}

# Example usage:
# color_read -red "Enter your name: " name
color_read() {
    local prompt=""
    local color_code="0"
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        -black) color_code="30" ;;
        -red) color_code="31" ;;
        -green) color_code="32" ;;
        -yellow) color_code="33" ;;
        -blue) color_code="34" ;;
        -magenta) color_code="35" ;;
        -cyan) color_code="36" ;;
        -white) color_code="37" ;;
        *)
            break
            ;;
        esac
        shift
    done
    prompt="${1}"
    read -p $'\033['"${color_code}"'m'"${prompt}"$'\033[0m ' "${@:2}"
}

# Example usage:
# check_and_install_deps curl
# check_and_install_deps curl jq pgrep
check_and_install_deps() {
    local dependencies=("$@")
    local missing_dependencies=()
    local dep pkg_name

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            pkg_name="$dep"
            case "$dep" in # map package names to install
            ifconfig) pkg_name="net-tools" ;;
            pgrep) pkg_name="procps" ;;
            esac
            missing_dependencies+=("$pkg_name")
        fi
    done

    [[ ${#missing_dependencies[@]} -eq 0 ]] && return 0

    color_echo -yellow "Missing dependencies: ${missing_dependencies[*]}"
    local prompt_info="Do you want to install them now? (Y/n): "
    if [[ "$auto_confirm" == true ]]; then
        color_echo -n -yellow "$prompt_info" && color_echo -green "(Auto confirm)"
    else
        color_read -yellow "$prompt_info" -r
        [[ -n $REPLY && ! $REPLY =~ ^[Yy]$ ]] && color_echo -red "Canceled." && return 1
    fi

    local pkg_manager=""
    local update_cmd=""
    if command -v apt-get &>/dev/null; then
        pkg_manager="apt-get install -y"
        update_cmd="apt-get update"
    elif command -v yum &>/dev/null; then
        pkg_manager="yum install -y"
    elif command -v brew &>/dev/null; then
        pkg_manager="brew install"
        update_cmd="brew update"
    elif command -v apk &>/dev/null; then
        pkg_manager="apk add"
        update_cmd="apk update"
    else
        color_echo -red "No supported package manager found. Please install dependencies manually."
        return 1
    fi

    [[ -n "$update_cmd" ]] && $update_cmd

    for dep in "${missing_dependencies[@]}"; do
        color_echo -yellow "Installing $dep..."
        if ! $pkg_manager "$dep"; then
            color_echo -red "Failed to install $dep. Please install it manually."
            return 1
        fi
        color_echo -green "Successfully installed $dep."
    done

    color_echo -green "All dependencies installed successfully."
}

# Example usage:
# get_system_info
# get_system_info --silent
get_system_info() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    HOSTNAME=$(hostname)

    if command -v ip &>/dev/null; then
        LOCAL_IPV4=$(ip -4 addr show | awk '/inet/ && $2 !~ /^127/ {sub(/\/.*/, "", $2); print $2; exit}')
        LOCAL_IPV6=$(ip -6 addr show | awk '/inet6/ && $2 !~ /^::1/ {sub(/\/.*/, "", $2); print $2; exit}')
    elif command -v ifconfig &>/dev/null; then
        LOCAL_IPV4=$(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')
        LOCAL_IPV6=$(ifconfig | awk '/inet6 / && $2 !~ /^::1/ && $2 !~ /^fe80:/ {print $2; exit}')
    fi

    [[ "$1" == "--silent" ]] && return 0

    echo "========== System Info =========="
    echo "OS          : $OS"
    echo "Arch        : $ARCH"
    echo "Hostname    : $HOSTNAME"
    echo "Local IPv4  : ${LOCAL_IPV4:-None}"
    echo "Local IPv6  : ${LOCAL_IPV6:-None}"
    echo "================================="
}

# Example usage:
is_port_in_use() {
    local port="$1"
    if command -v ss &>/dev/null; then
        ss -tuln | grep -q ":$port\b"
    elif command -v lsof &>/dev/null; then
        lsof -iTCP:"$port" -sTCP:LISTEN &>/dev/null
    elif command -v netstat &>/dev/null; then
        netstat -tuln | grep -q ":$port\b"
    else
        echo "No suitable tool found to check port." >&2
        return 1
    fi
}

# Example usage:
# get_random_available_port 1024 65535
get_random_available_port() {
    local min_port=${1:-10240}
    local max_port=${2:-65535}
    local port

    local max_try=10
    while true; do
        port=$((RANDOM % (max_port - min_port + 1) + min_port))
        if ! is_port_in_use "$port"; then
            echo "$port"
            return 0
        fi
        max_try=$((max_try - 1))
        if [[ $max_try -le 0 ]]; then
            echo "No available port found in the range $min_port-$max_port after 10 tries." >&2
            return 1
        fi
    done
}
get_random_available_ports() {
    local count=${1:-1}        # Number of ports to get (default: 1)
    local min_port=${2:-10240} # Minimum port
    local max_port=${3:-65535} # Maximum port
    local ports=()
    local port
    local try_limit=10 # Max total attempts to avoid infinite loop

    while ((${#ports[@]} < count && try_limit-- > 0)); do
        port=$(get_random_available_port "$min_port" "$max_port") || continue
        if [[ ! " ${ports[*]} " =~ " $port " ]]; then
            ports+=("$port")
        fi
    done

    if ((${#ports[@]} < count)); then
        echo "Failed to acquire $count unique available ports." >&2
        return 1
    fi

    echo "${ports[@]}"
}

# Example usage:
# gen_random_string
# gen_random_string --charset='A-Za-z0-9!@#$%^&*()_+' --length=8
# gen_random_string --charset='A-Za-z'\''0-9' --length=8
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

# Example usage:
# gen_uuid_v4
gen_uuid_v4() {
    local part1=$(gen_random_string --charset="abcdef0-9" --length=8)                                                 # First part (8 characters)
    local part2=$(gen_random_string --charset="abcdef0-9" --length=4)                                                 # Second part (4 characters)
    local part3="4$(gen_random_string --charset="abcdef0-9" --length=3)"                                              # Third part (4 characters, version is 4)
    local part4=$(gen_random_string --charset="89ab" --length=1)$(gen_random_string --charset="abcdef0-9" --length=3) # Fourth part (4 characters, 8-9-a-b for variant)
    local part5=$(gen_random_string --charset="abcdef0-9" --length=12)                                                # Fifth part (12 characters)
    echo "$part1-$part2-$part3-$part4-$part5"
}

# Example usage:
# generate_ssl_cert
# generate_ssl_cert --domain=example.com --days=365 --key_path=./example.key --cert_path=./example.crt
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
        color_echo -red "Failed to generate SSL certificate."
        return 1
    fi
}

################################# github #################################
# Example usage:
# get_release_version "SagerNet/sing-box"
# get_release_version "SagerNet/sing-box" "beta"
get_release_version() {
    local repo="$1"
    local type="${2:-latest}"

    local url="https://github.com/$repo/releases/"
    if [[ "$type" == "latest" ]]; then
        url+="latest"
    fi
    local version=$(curl -LsS "$url" |
        grep -oE "$repo/releases/tag/[^\"]+" |
        head -1 |
        awk -F'/' '{print $NF}')

    if [ -z "$version" ]; then
        return 1
    fi

    echo "$version"
}

# Example usage:
# download_release "SagerNet/sing-box" "v0.1.0" "sing-box-linux-amd64.tar.gz"
# download_release "SagerNet/sing-box" "v0.1.0" "sing-box-linux-amd64.tar.gz" "/tmp"
download_release() {
    local repo="$1"
    local version="$2"
    local file_name="$3"
    local dest_dir="${4:-/tmp}"

    local url="https://github.com/$repo/releases/download/$version/$file_name"
    color_echo -green "Downloading $file_name from $url"

    local dest_file="${dest_dir}/${file_name}"
    if [[ -f "$dest_file" ]]; then
        color_echo -yellow "File $dest_file already exists."
        local prompt_info="Do you want to skip the download? (Y/n): "
        if [[ "$auto_confirm" == true ]]; then
            color_echo -n -yellow "$prompt_info" && color_echo -green "(Auto confirm)"
            color_echo -green "Skipping download." && return 0
        else
            color_read -yellow "$prompt_info" -r
            [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]] && color_echo -green "Skipping download." && return 0
        fi
    fi

    tmp_file="${dest_file}.part"
    curl -L -o "$tmp_file" "$url" --fail || {
        color_echo -red "Failed to download $file_name from $url."
        rm -f "$tmp_file"
        return 1
    }
    mv "$tmp_file" "$dest_file"

    color_echo -green "Downloaded $file_name to $dest_file."
}

############################## sing-box manager ##############################

# Example usage:
download_sing-box_binary() {
    # Download the release file
    local version="${APP_VERSION:-$(get_release_version 'SagerNet/sing-box')}"
    [[ -z $version ]] && color_echo -red "Failed to fetch the latest version." && return 1
    [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
    local file_name="sing-box-${version#v}-$OS-$ARCH.tar.gz"
    local dest_dir="/tmp"
    download_release "SagerNet/sing-box" "$version" "$file_name" "$dest_dir" || return 1

    # Extract the downloaded file
    color_echo -green "Extracting $dest_dir/$file_name to $BIN_DIR."
    tar -xzf "$dest_dir/$file_name" -C "$BIN_DIR" --strip-components=1 || {
        color_echo -red "Failed to extract $dest_dir/$file_name."
        rm -f "$dest_dir/$file_name"
        return 1
    }
    rm -f "$dest_dir/$file_name"
    chmod +x "$BIN_FILE"
}

# Example usage:
install_sing-box() {
    color_echo -blue ">>> Installing sing-box..."

    # Check if the install directory exists
    if [[ -d "$INSTALL_DIR" ]]; then
        color_echo -yellow "Install directory $INSTALL_DIR already exists."
        local prompt_info="Reinstall the application? (Y/n): "
        if [[ "$auto_confirm" == true ]]; then
            color_echo -n -yellow "$prompt_info" && color_echo -green "(Auto confirm)"
        else
            color_read -yellow "$prompt_info" -r
            [[ -n "$REPLY" && ! $REPLY =~ ^[Yy]$ ]] && color_echo -red "Canceled." && return 1
        fi
        color_echo -yellow "Reinstalling sing-box..." && uninstall_sing-box
    fi

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$SSL_DIR" "$LOG_DIR"

    download_sing-box_binary || return 1

    color_echo -green "sing-box installed successfully."
}

# Example usage:
upgrade_sing-box() {
    color_echo -blue ">>> Upgrading sing-box..."

    # Check if the install directory exists
    if [[ ! -d "$INSTALL_DIR" ]]; then
        color_echo -red "Install directory $INSTALL_DIR does not exist. Please install sing-box first."
        return 1
    fi

    # get the current version
    local current_version="v$("$BIN_FILE" version | head -n 1 | awk '{print $3}')"
    color_echo -yellow "Current version: $current_version"

    # get the latest version
    local latest_version="$(get_release_version 'SagerNet/sing-box')"
    [[ -z "$latest_version" ]] && color_echo -red "Failed to fetch the latest version." && return 1
    color_echo -yellow "Latest  version: $latest_version"

    # get target version from APP_VERSION, default is the same as latest version
    local target_version="${APP_VERSION:-$latest_version}"
    if [[ -z "$target_version" ]]; then
        color_echo -red "Failed to determine the target version."
        return 1
    fi
    color_echo -yellow "Target  version: $target_version"

    if [[ "$current_version" == "$target_version" ]]; then
        color_echo -green "sing-box is already at the target version $target_version."
        return 2
    fi
    color_echo -yellow "Upgrading sing-box from $current_version to $target_version..."

    download_sing-box_binary || return 1

    color_echo -green "sing-box upgraded successfully."
}

# Example usage:
uninstall_sing-box() {
    color_echo -blue ">>> Uninstalling sing-box..."

    # Check if the sing-box service is running
    if pgrep -f "$BIN_FILE" >/dev/null; then
        color_echo -yellow "sing-box service is running. Please stop it before uninstalling."
        local prompt_info="Do you want to stop it now? (Y/n): "
        if [[ "$auto_confirm" == true ]]; then
            color_echo -n -yellow "$prompt_info" && color_echo -green "(Auto confirm)"
        else
            color_read -yellow "$prompt_info" -r
            [[ -n "$REPLY" && ! $REPLY =~ ^[Yy]$ ]] && color_echo -red "Canceled." && return 1
        fi
        stop_sing-box
    fi

    # Remove the install directory
    rm -rf "$INSTALL_DIR"

    color_echo -green "sing-box uninstalled successfully."
}

# Example usage:
config_sing-box() {
    color_echo -blue ">>> Configuring sing-box..."

    # Check if the config file exists
    if [[ -f "$CONFIG_FILE" ]]; then
        color_echo -yellow "Config file $CONFIG_FILE already exists."
        local prompt_info="Do you want to overwrite it? (Y/n): "
        if [[ "$auto_confirm" == true ]]; then
            color_echo -n -yellow "$prompt_info" && color_echo -green "(Auto confirm)"
        else
            color_read -yellow "$prompt_info" -r
            [[ -n "$REPLY" && ! $REPLY =~ ^[Yy]$ ]] && color_echo -red "Canceled." && return 1
        fi
        color_echo -yellow "Overwriting config file..."
    fi

    # Check ports
    local ports=("$S5_PORT" "$HY2_PORT" "$TUIC_PORT" "$VLESS_PORT" "$VMESS_PORT" "$TROJAN_PORT" "$ANYTLS_PORT" "$REALITY_PORT")
    # If any ports are in use, report and return error
    local used_ports=()
    for port in "${ports[@]}"; do
        [[ -n "$port" ]] && is_port_in_use "$port" && used_ports+=("$port")
    done
    if [[ ${#used_ports[@]} -gt 0 ]]; then
        color_echo -red "The following ports are already in use: ${used_ports[*]}"
        return 1
    fi
    # If no ports are defined, assign random ports
    if ! printf '%s\n' "${ports[@]}" | grep -q '[0-9]'; then
        read -r S5_PORT HY2_PORT VLESS_PORT <<<"$(get_random_available_ports 3)"
        [[ -n "$S5_PORT" && -n "$HY2_PORT" && -n "$VLESS_PORT" ]] || return 1
    fi

    echo -e "$(gen_sing-box_config_content)" >"$CONFIG_FILE"
    color_echo -green "sing-box config file created successfully."
}
gen_sing-box_config_content() {
    config_content='{
    "log": {
        "disabled": '$LOG_DISABLED',
        "level": "'$LOG_LEVEL'",
        "output": "'$LOG_OUTPUT'",
        "timestamp": true
    },
    "inbounds": ['

    [[ -n "$S5_PORT" ]] && config_content+=$(generate_socks5_inbound)","
    [[ -n "$HY2_PORT" ]] && config_content+=$(generate_hysteria2_inbound)","
    [[ -n "$TUIC_PORT" ]] && config_content+=$(generate_tuic_inbound)","
    [[ -n "$VLESS_PORT" ]] && config_content+=$(generate_vless_inbound)","
    [[ -n "$REALITY_PORT" ]] && config_content+=$(generate_reality_inbound)","
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
generate_reality_inbound() {
    local port="${REALITY_PORT:-10240}"
    local uuid="${REALITY_UUID:-${UUID:-$(gen_uuid_v4)}}"
    local server_name="${REALITY_SERVER_NAME:-${SERVER_NAME:-www.cloudflare.com}}"
    local public_key="${REALITY_PUB_KEY:-}"
    local private_key="${REALITY_PRI_KEY:-}"
    local short_id="${REALITY_SHORT_ID:-$(gen_random_string --charset="abcdef0-9" --length=8)}"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --port=*) port="${1#--port=}" ;;
        --uuid=*) uuid="${1#--uuid=}" ;;
        --server_name=*) server_name="${1#--server_name=}" ;;
        --public_key=*) public_key="${1#--pub_key=}" ;;
        --private_key=*) private_key="${1#--pri_key=}" ;;
        --short_id=*) short_id="${1#--short_id=}" ;;
        esac
        shift
    done

    if [[ -z "$public_key" || -z "$private_key" ]]; then
        local output=$("$BIN_FILE" generate reality-keypair)
        private_key=$(echo "$output" | grep "PrivateKey" | cut -d ' ' -f 2)
        public_key=$(echo "$output" | grep "PublicKey" | cut -d ' ' -f 2)
    fi
    mkdir -p "$SSL_DIR" && echo "$public_key" >"$SSL_DIR/reality_public_key"

    echo '{
        "type": "vless",
        "listen": "::",
        "listen_port": '"$port"',
        "users": [
            {
                "uuid": "'"$uuid"'",
                "flow": "xtls-rprx-vision"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "'"$server_name"'",
            "reality": {
                "enabled": true,
                "handshake": {
                    "server": "'"$server_name"'",
                    "server_port": 443
                },
                "private_key": "'"$private_key"'",
                "short_id": [
                    "'"$short_id"'"
                ]
            }
        }
    }'
}
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

# Example usage:
start_sing-box() {
    color_echo -blue ">>> Starting sing-box..."

    # Check if the sing-box service is already running
    if pgrep -f "$BIN_FILE" >/dev/null; then
        color_echo -yellow "sing-box service is already running."
        return 0
    fi

    [[ ! -f "$BIN_FILE" ]] && color_echo -red "Binary file $BIN_FILE does not exist." && return 1
    [[ ! -f "$CONFIG_FILE" ]] && color_echo -red "Config file $CONFIG_FILE does not exist." && return 1

    # Start the sing-box service
    nohup "$BIN_FILE" run -c "$CONFIG_FILE" >/dev/null 2>&1 &
    local wait_time=10
    while ! pgrep -f "$BIN_FILE" >/dev/null; do
        color_echo -yellow "Waiting for sing-box service to start..."
        sleep 1
        wait_time=$((wait_time - 1))
        if [[ $wait_time -le 0 ]]; then
            color_echo -red "Failed to start sing-box service."
            return 1
        fi
    done

    color_echo -green "sing-box service started successfully."
    color_echo -green "sing-box service is running with PID: $(pgrep -f "$BIN_FILE")"
}

# Example usage:
stop_sing-box() {
    color_echo -blue ">>> Stopping sing-box..."

    # Check if the sing-box service is running
    if ! pgrep -f "$BIN_FILE" >/dev/null; then
        color_echo -yellow "sing-box service is not running."
        return 0
    fi

    # Stop the sing-box service
    pkill -f "$BIN_FILE"
    local wait_time=10
    while pgrep -f "$BIN_FILE" >/dev/null; do
        color_echo -yellow "Waiting for sing-box service to stop..."
        sleep 1
        wait_time=$((wait_time - 1))
        if [[ $wait_time -le 0 ]]; then
            color_echo -red "Failed to stop sing-box service."
            return 1
        fi
    done

    color_echo -green "sing-box service stopped successfully."
}

# Example usage:
restart_sing-box() {
    stop_sing-box || exit 1
    start_sing-box || exit 1
}

# Example usage:
status_sing-box() {
    echo -n "Application Status : "
    if [[ -x "$INSTALL_DIR" ]]; then
        if [[ -f "$BIN_FILE" ]]; then
            color_echo -green "Installed (v"$("$BIN_FILE" version | head -n 1 | awk '{print $3}')")"
        else
            color_echo -red "Binary Missing"
        fi
    else
        color_echo -red "Uninstalled"
    fi

    echo -n "Config File Status : "
    if [[ -f "$CONFIG_FILE" ]]; then
        color_echo -green "Exists"
    else
        color_echo -red "Missing"
    fi

    echo -n "Service Status     : "
    if pgrep -f "$BIN_FILE" >/dev/null; then
        color_echo -green "Running (PID: $(pgrep -f "$BIN_FILE"))"
    else
        color_echo -red "Stopped"
    fi
}

# Example usage:
nodes_sing-box() {
    color_echo -blue ">>> Displaying sing-box nodes..."

    [[ ! -f "$CONFIG_FILE" ]] && color_echo -red "Config file $CONFIG_FILE does not exist." && return 1

    local inbounds_cnt=$(jq '.inbounds | length' "$CONFIG_FILE")

    color_echo -cyan "Config File Path : $CONFIG_FILE"
    color_echo -cyan "Last Modified    : $(date -r "$CONFIG_FILE" "+%Y-%m-%d %H:%M:%S")"
    color_echo -cyan "Inbounds Count   : $inbounds_cnt"
    [[ $inbounds_cnt -eq 0 ]] && return 1

    local ip4=$(curl -s -4 ip.sb)
    local ip6=$(curl -s -6 ip.sb)
    [[ "$ip6" == *:* ]] && ip6="[$ip6]" || ip6=""
    color_echo -cyan "Public IPv4      : ${ip4:-None}"
    color_echo -cyan "Public IPv6      : ${ip6:-None}"

    [[ -n "$ip4" ]] && color_echo -green "IPv4 Node List :" && output_nodes "$ip4" "$HOSTNAME"
    [[ -n "$ip6" ]] && color_echo -green "IPv6 Node List :" && output_nodes "$ip6" "$HOSTNAME"

    return 0
}
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
            if echo "$inbound" | jq -e '.tls.reality.enabled' >/dev/null; then
                local pbk=$(cat "$SSL_DIR/reality_public_key")
                local sid=$(echo "$inbound" | jq -r '.tls.reality.short_id[0] // empty')
                echo "vless://$uuid@$ip:$port?security=reality&sni=$sni&fp=chrome&flow=xtls-rprx-vision&pbk=$pbk&sid=$sid#$node_name"
            else
                echo "vless://$uuid@$ip:$port?security=tls&sni=$sni&fp=chrome&allowInsecure=1&type=ws&host=$host&path=$path#$node_name"
            fi
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

# Example usage:
setup() {
    install_sing-box || exit 1
    config_sing-box || exit 1
    start_sing-box || exit 1
    nodes_sing-box || exit 1
}

# Example usage:
reset() {
    uninstall_sing-box || exit 1
}

# Example usage:
upgrade() {
    upgrade_sing-box || exit 1
    restart_sing-box || exit 1
    nodes_sing-box || exit 1
}

####################################### main #######################################

parse_parameters() {
    [[ $# -eq 0 ]] && set -- "-h"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        setup | reset | upgrade | start | stop | restart | status | nodes)
            main_action="$1"
            ;;
        -y | --yes)
            auto_confirm=true
            ;;
        -h | --help)
            show_help
            return 1
            ;;
        *)
            color_echo -red "Unknown parameter: $1"
            color_echo -green "Use -h or --help for usage."
            return 1
            ;;
        esac
        shift
    done

    if [[ -z "$main_action" ]]; then
        color_echo -red "No command specified."
        color_echo -green "Use -h or --help for usage."
        return 1
    fi
}

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Options:
  -y                   Automatically confirm all prompts
  -h, --help           Show this help message

Commands:
  setup                Setup the sing-box
  reset                Reset the sing-box
  status               Show current status
  start|stop|restart   Control sing-box service
  nodes                Display node info
EOF
}

main() {
    parse_parameters "$@" || exit 1
    check_and_install_deps curl pgrep openssl jq || exit 1
    get_system_info --silent

    case "$main_action" in
    setup) setup ;;
    reset) reset ;;
    upgrade) upgrade ;;
    start) start_sing-box ;;
    stop) stop_sing-box ;;
    restart) restart_sing-box ;;
    status) status_sing-box ;;
    nodes) nodes_sing-box ;;
    esac
}
main "$@"
