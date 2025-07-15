#!/bin/bash

############################## global env ##############################
INSTALL_DIR="${INSTALL_DIR:-"$HOME/cloudflare-tunnel"}"

BIN_DIR="$INSTALL_DIR/bin"
CONFIG_DIR="$INSTALL_DIR/conf"
BIN_FILE="$BIN_DIR/cloudflared"
CONFIG_FILE="$CONFIG_DIR/config.json"

LOG_DIR="$INSTALL_DIR/logs"
LOG_OUTPUT="$LOG_DIR/cloudflared.log"

TUNNEL_URL="${TUNNEL_URL:-"https://localhost:8001"}"

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
    echo "OS         : $OS"
    echo "Arch       : $ARCH"
    echo "Hostname   : $HOSTNAME"
    echo "Local IPv4 : ${LOCAL_IPV4:-None}"
    echo "Local IPv6 : ${LOCAL_IPV6:-None}"
    echo "================================="
}

############################## DNS64 + NAT64 #############################
# Example usage:
set_dns64() {
    # 基本信息：
	# •	运营方：JSTUN（德国 Tübingen 大学相关人员维护的开源网络实验项目）
	# •	官网：https://nat64.net
	# •	DNS64 地址：2a00:1098:2b::1、2a00:1098:2b::2
    local dns_servers="2a00:1098:2b::1
2a00:1098:2b::2"

    echo -e "${dns_servers}" | tee /etc/resolv.conf > /dev/null
}

################################# github #################################
# Example usage:
# if check_github; then
#     echo "GitHub is reachable"
# else
#     echo "GitHub is not reachable"
# fi
check_github() {
    [ "$(curl -s -o /dev/null -w "%{http_code}" https://github.com)" = "200" ]
}

# Example usage:
# get_release_version "cloudflare/cloudflared"
# get_release_version "cloudflare/cloudflared" "beta"
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
# download_release "cloudflare/cloudflared" "2025.5.0" "cloudflared-linux-amd64"
# download_release "cloudflare/cloudflared" "2025.5.0" "cloudflared-linux-amd64" "/tmp"
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

############################## cloudflare tunnel manager ##############################

# Example usage:
download_cloudflare_tunnel() {
    # Download the release file
    color_echo -blue ">>> Downloading Cloudflare Tunnel release..."
    local version="${APP_VERSION:-$(get_release_version 'cloudflare/cloudflared')}"
    [[ -z $version ]] && color_echo -red "Failed to fetch the latest version." && return 1
    [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
    local file_name="cloudflared-$OS-$ARCH" && [[ "$OS" == "darwin" ]] && file_name+=".tgz"
    local dest_dir="/tmp"
    download_release "cloudflare/cloudflared" "$version" "$file_name" "$dest_dir" || return 1

    # Extract the downloaded file
    color_echo -blue ">>> Extracting Cloudflare Tunnel binary..."
    color_echo -green "Extracting $dest_dir/$file_name to $BIN_DIR."
    if [[ "$file_name" == *.tgz ]]; then
        tar -xzf "$dest_dir/$file_name" -C "$BIN_DIR" || {
            color_echo -red "Failed to extract $dest_dir/$file_name."
            rm -f "$dest_dir/$file_name"
            return 1
        }
        rm -f "$dest_dir/$file_name"
    else
        mv "$dest_dir/$file_name" "$BIN_FILE" || {
            color_echo -red "Failed to move $dest_dir/$file_name to $BIN_FILE."
            return 1
        }
    fi
    chmod +x "$BIN_FILE"
}

# Example usage:
install_cloudflare_tunnel() {
    color_echo -blue ">>> Installing Cloudflare Tunnel..."

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
        color_echo -yellow "Reinstalling cloudflare tunnel..." && uninstall_cloudflare_tunnel
    fi

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$LOG_DIR"

    download_cloudflare_tunnel || return 1

    color_echo -green "Cloudflare Tunnel installed successfully."
}

# Example usage:
upgrade_cloudflare_tunnel() {
    color_echo -blue ">>> Upgrading Cloudflare Tunnel..."

    # Check if the install directory exists
    if [[ ! -d "$INSTALL_DIR" ]]; then
        color_echo -red "Install directory $INSTALL_DIR does not exist. Please install the application first."
        return 1
    fi

    # get the current version
    local current_version=$("$BIN_FILE" version | head -n 1 | awk '{print $3}')
    color_echo -yellow "Current version: $current_version"

    # get the latest version
    local latest_version=$(get_release_version 'cloudflare/cloudflared')
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
        color_echo -green "Cloudflare Tunnel is already at the target version ($target_version)."
        return 2
    fi
    color_echo -yellow "Upgrading Cloudflare Tunnel from $current_version to $target_version..."

    download_cloudflare_tunnel || return 1

    color_echo -green "Cloudflare Tunnel upgraded successfully."
}

# Example usage:
uninstall_cloudflare_tunnel() {
    color_echo -blue ">>> Uninstalling Cloudflare Tunnel..."

    # Check if the service is running
    if pgrep -f "$BIN_FILE" >/dev/null; then
        color_echo -yellow "Cloudflare Tunnel service is running. Please stop it before uninstalling."
        local prompt_info="Do you want to stop it now? (Y/n): "
        if [[ "$auto_confirm" == true ]]; then
            color_echo -n -yellow "$prompt_info" && color_echo -green "(Auto confirm)"
        else
            color_read -yellow "$prompt_info" -r
            [[ -n "$REPLY" && ! $REPLY =~ ^[Yy]$ ]] && color_echo -red "Canceled." && return 1
        fi
        stop_cloudflare_tunnel
    fi

    # Remove the install directory
    rm -rf "$INSTALL_DIR"

    color_echo -green "Cloudflare Tunnel service uninstalled successfully."
}

# Example usage:
config_cloudflare_tunnel() {
    color_echo -blue ">>> Configuring Cloudflare Tunnel..."

    # Check if the install directory exists
    [[ ! -d "$INSTALL_DIR" ]] && color_echo -red "Install directory $INSTALL_DIR does not exist. Please install the application first." && return 1

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
        color_echo -yellow "Overwriting config file..." && rm -f "$CONFIG_FILE"
    fi

    [[ -z "$TUNNEL_TOKEN" ]] && {
        color_echo -yellow "Cloudflare Tunnel Token not provided."
        local prompt_info="Enter your Cloudflare Tunnel Token (leave empty for quick tunnel): "
        if [[ "$auto_confirm" == true ]]; then
            color_echo -n -yellow "$prompt_info" && color_echo -green "(Auto confirm)"
        else
            color_read -yellow "$prompt_info" -r TUNNEL_TOKEN
        fi

        [[ -z "$TUNNEL_TOKEN" ]] && {
            color_echo -green "Using quick tunnel."
            local prompt_info="Enter the URL for the quick tunnel (default: $TUNNEL_URL): "
            if [[ "$auto_confirm" == true ]]; then
                color_echo -n -yellow "$prompt_info" && color_echo -green "(Auto confirm)"
            else
                color_read -yellow "$prompt_info" -r
                [[ -n "$REPLY" ]] && TUNNEL_URL="$REPLY"
            fi
        }
    }

    if [[ -z "$EDGE_IP_VERSION" ]]; then
        local prompt_info="Enter edge IP version (auto / 4 / 6, default: auto): "
        if [[ "$auto_confirm" == true ]]; then
            color_echo -n -yellow "$prompt_info" && color_echo -green "(Auto confirm)"
        else
            color_read -yellow "$prompt_info" -r EDGE_IP_VERSION
        fi
        EDGE_IP_VERSION="${EDGE_IP_VERSION:-auto}"
    fi

    # Write config
    if [[ -n "$TUNNEL_TOKEN" ]]; then
        jq -n --arg token "$TUNNEL_TOKEN" --arg edge_ip_version "$EDGE_IP_VERSION" \
            '{token: $token, edge_ip_version: $edge_ip_version}' >"$CONFIG_FILE"
    else
        jq -n --arg url "$TUNNEL_URL" --arg edge_ip_version "$EDGE_IP_VERSION" \
            '{url: $url, edge_ip_version: $edge_ip_version}' >"$CONFIG_FILE"
    fi

    color_echo -green "Cloudflare Tunnel configuration file created successfully."
}

# Example usage:
start_cloudflare_tunnel() {
    color_echo -blue ">>> Starting Cloudflare Tunnel..."

    # Check if the service is already running
    if pgrep -f "$BIN_FILE" >/dev/null; then
        color_echo -yellow "Cloudflare Tunnel service is already running."
        return 0
    fi

    # Check if the binary and config file exist
    [[ ! -f "$BIN_FILE" ]] && color_echo -red "Binary file $BIN_FILE does not exist." && return 1
    [[ ! -f "$CONFIG_FILE" ]] && color_echo -red "Config file $CONFIG_FILE does not exist." && return 1

    # Check tunnel token or URL
    TUNNEL_TOKEN=$(jq -r '.token // empty' "$CONFIG_FILE") && TUNNEL_URL=$(jq -r '.url // empty' "$CONFIG_FILE")
    [[ -z "$TUNNEL_TOKEN" && -z "$TUNNEL_URL" ]] && color_echo -red "No Cloudflare Tunnel Token or URL found in $CONFIG_FILE." && return 1

    # Start the Cloudflare Tunnel service
    EDGE_IP_VERSION="${EDGE_IP_VERSION:-$(jq -r '.edge_ip_version // empty' "$CONFIG_FILE")}"
    EDGE_IP_VERSION="${EDGE_IP_VERSION:-auto}"
    if [[ -n "$TUNNEL_TOKEN" ]]; then
        color_echo -green "Using Cloudflare Tunnel Token: " && color_echo -yellow "$TUNNEL_TOKEN"
        nohup "$BIN_FILE" tunnel --edge-ip-version "$EDGE_IP_VERSION" run --token "$TUNNEL_TOKEN" >$LOG_OUTPUT 2>&1 &
    else
        color_echo -green "Using quick tunnel URL: " && color_echo -yellow "$TUNNEL_URL"
        nohup "$BIN_FILE" tunnel --edge-ip-version "$EDGE_IP_VERSION" --no-autoupdate --no-tls-verify --url "$TUNNEL_URL" >$LOG_OUTPUT 2>&1 &
    fi
    # Wait for the service to start
    local wait_time=10
    while ! pgrep -f "$BIN_FILE" >/dev/null; do
        color_echo -yellow "Waiting for Cloudflare Tunnel service to start..."
        sleep 1
        wait_time=$((wait_time - 1))
        if [[ $wait_time -le 0 ]]; then
            color_echo -red "Failed to start Cloudflare Tunnel service within the timeout period."
            return 1
        fi
    done
    # Wait for the service to be ready, extract the tunnel info from the logs
    local tunnel_info
    if [[ -n "$TUNNEL_TOKEN" ]]; then
        local tunnel_id connector_id hostname service path
        local wait_time=10
        while [[ -z "$tunnel_id" || -z "$connector_id" || -z "$hostname" || -z "$service" ]]; do
            wait_time=$((wait_time - 1))
            if [[ $wait_time -lt 0 ]]; then
                color_echo -red "Failed to get tunnel information within the timeout period."
                return 1
            fi
            color_echo -yellow "Waiting for Cloudflare Tunnel to be ready..."
            sleep 1
            tunnel_id=$(grep -o 'tunnelID=[a-z0-9-]*' "$LOG_OUTPUT" | head -n 1 | cut -d'=' -f2)
            connector_id=$(grep -o 'Generated Connector ID: [a-z0-9-]*' "$LOG_OUTPUT" | head -n 1 | cut -d' ' -f4)
            local tunnel_config=$(grep -o 'Updated to new configuration config=.*' "$LOG_OUTPUT" | head -n1 | sed 's/^"//; s/"$//; s/\\"/"/g' | sed -n 's/.*config="\({.*}\)".*/\1/p')
            read -r hostname service path < <(echo "$tunnel_config" | jq -r '.ingress[0] | "\(.hostname // "") \(.service // "") \(.path // "*")"') 2>/dev/null || continue
        done
        tunnel_info=$(jq -n \
            --arg tunnel_id "$tunnel_id" \
            --arg connector_id "$connector_id" \
            --arg hostname "$hostname" \
            --arg service "$service" \
            --arg path "$path" \
            '{
                tunnel_id: $tunnel_id,
                connector_id: $connector_id,
                hostname: $hostname,
                service: $service,
                path: $path
            }')
    else
        local hostname connector_id
        local service="$TUNNEL_URL"
        local wait_time=10
        while [[ -z "$hostname" ]]; do
            color_echo -yellow "Waiting for quick tunnel URL to be available..."
            sleep 1
            hostname=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG_OUTPUT" | head -n 1 | sed 's|https://||')
            connector_id=$(grep -o 'Generated Connector ID: [a-z0-9-]*' "$LOG_OUTPUT" | head -n 1 | cut -d' ' -f4)
            wait_time=$((wait_time - 1))
            if [[ $wait_time -le 0 ]]; then
                color_echo -red "Failed to get quick tunnel URL within the timeout period."
                return 1
            fi
        done
        tunnel_info=$(jq -n \
            --arg hostname "$hostname" \
            --arg service "$service" \
            --arg connector_id "$connector_id" \
            '{
                hostname: $hostname,
                service: $service,
                connector_id: $connector_id
            }')
    fi
    # update the config file, add tunnel_info
    jq --argjson tunnel_info "$tunnel_info" '.tunnel_info = $tunnel_info' "$CONFIG_FILE" >"$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    color_echo -green "Cloudflare Tunnel started successfully."
}

# Example usage:
stop_cloudflare_tunnel() {
    color_echo -blue ">>> Stopping Cloudflare Tunnel..."

    # Check if the service is running
    if ! pgrep -f "$BIN_FILE" >/dev/null; then
        color_echo -yellow "Cloudflare Tunnel service is not running."
        return 0
    fi

    # Stop the Cloudflare Tunnel service
    local wait_time=10
    while pgrep -f "$BIN_FILE" >/dev/null; do
        pkill -f "$BIN_FILE"
        color_echo -yellow "Waiting for Cloudflare Tunnel service to stop..."
        sleep 1
        wait_time=$((wait_time - 1))
        if [[ $wait_time -le 0 ]]; then
            color_echo -red "Failed to stop Cloudflare Tunnel service within the timeout period."
            return 1
        fi
    done

    color_echo -green "Cloudflare Tunnel stopped successfully."
}

# Example usage:
restart_cloudflare_tunnel() {
    stop_cloudflare_tunnel || exit 1
    start_cloudflare_tunnel || exit 1
}

# Example usage:
status_cloudflare_tunnel() {
    echo -n "Application Status: "
    if [[ -x "$INSTALL_DIR" ]]; then
        if [[ -f "$BIN_FILE" ]]; then
            color_echo -green "Installed ("$("$BIN_FILE" version | head -n 1 | awk '{print $3}')")"
        else
            color_echo -red "Binary Missing"
        fi
    else
        color_echo -red "Uninstalled"
    fi

    echo -n "Config File Status: "
    if [[ -f "$CONFIG_FILE" ]]; then
        color_echo -green "Exists"
    else
        color_echo -red "Not Configured"
    fi

    echo -n "Service Status    : "
    if pgrep -f "$BIN_FILE" >/dev/null; then
        color_echo -green "Running (PID: $(pgrep -f "$BIN_FILE"))"

        [[ -f "$CONFIG_FILE" ]] && local tunnel_info=$(jq -r '.tunnel_info // empty' "$CONFIG_FILE")
        [[ -z "$tunnel_info" ]] && color_echo -red "No tunnel information found in $CONFIG_FILE." && return 0

        local hostname=$(echo "$tunnel_info" | jq -r '.hostname // empty') && [[ -n "$hostname" ]] && echo -n "Public Hostname   : " && color_echo -green "$hostname"
        local service=$(echo "$tunnel_info" | jq -r '.service // empty') && [[ -n "$service" ]] && echo -n "Local Server      : " && color_echo -green "$service"
        local path=$(echo "$tunnel_info" | jq -r '.path // empty') && [[ -n "$path" ]] && echo -n "Tunnel Path       : " && color_echo -green "$path"
        local tunnel_id=$(echo "$tunnel_info" | jq -r '.tunnel_id // empty') && [[ -n "$tunnel_id" ]] && echo -n "Tunnel ID         : " && color_echo -green "$tunnel_id"
        local connector_id=$(echo "$tunnel_info" | jq -r '.connector_id // empty') && [[ -n "$connector_id" ]] && echo -n "Connector ID      : " && color_echo -green "$connector_id"
    else
        color_echo -red "Stopped"
    fi
}

# Example usage:
setup() {
    install_cloudflare_tunnel || exit 1
    config_cloudflare_tunnel || exit 1
    start_cloudflare_tunnel || exit 1
    status_cloudflare_tunnel || exit 1
}

# Example usage:
reset() {
    uninstall_cloudflare_tunnel || exit 1
}

# Example usage:
config() {
    config_cloudflare_tunnel || exit 1
    restart_cloudflare_tunnel || exit 1
    status_cloudflare_tunnel || exit 1
}

# Example usage:
upgraded() {
    upgrade_cloudflare_tunnel || exit 1
    restart_cloudflare_tunnel || exit 1
    status_cloudflare_tunnel || exit 1
}

####################################### main #######################################

parse_parameters() {
    [[ $# -eq 0 ]] && set -- "-h"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        setup | reset | upgrade | start | stop | restart | status | config)
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
  setup                Setup the cloudflare tunnel
  reset                Reset the cloudflare tunnel
  status               Show the status of the cloudflare tunnel
  start|stop|restart   Control the cloudflare tunnel service
  config               Configure the cloudflare tunnel
EOF
}

main() {
    parse_parameters "$@" || exit 1
    check_and_install_deps curl pgrep jq || exit 1

    check_github || { color_echo -red "GitHub not reachable"; exit 1; }

    get_system_info --silent

    case "$main_action" in
    setup) setup ;;
    reset) reset ;;
    upgrade) upgraded ;;
    config) config ;;
    start) start_cloudflare_tunnel ;;
    stop) stop_cloudflare_tunnel ;;
    restart) restart_cloudflare_tunnel ;;
    status) status_cloudflare_tunnel ;;
    esac
}
main "$@"
