# sing-box-tools.sh

一个用于部署与管理 sing-box 的 Bash 工具脚本，支持一键安装、运行控制、配置管理与 Cloudflare 隧道支持。

### 功能特性

- 一键安装 sing-box 和 cloudflared
- 管理 sing-box 服务（启动、停止、重启、状态查看）
- 自动生成所需目录结构（如配置、日志、SSL 等）
- 支持 Cloudflare WARP 隧道集成
- 通过 -y 参数可跳过确认提示，适合自动化使用
- 提供帮助文档 -h

## 支持的协议

- Socks5
- Hysteria2
- VLESS
- Trojan
- VMess
- Tuic
- AnyTLS (1.12.0 版本以上)

## 一键脚本

### 初始化安装

#### 一键多协议

```bash
S5_PORT=1080 HY2_PORT=2080 VLESS_PORT=3080 TROJAN_PORT=4080 VMESS_PORT=5080 TUIC_PORT=6080 bash <(curl -s https://raw.githubusercontent.com/sunnypuppy/sing-box/main/sing-box-tools.sh) setup -y
```

#### 单协议

```bash
VLESS_PORT=3080 bash <(curl -s https://raw.githubusercontent.com/sunnypuppy/sing-box/main/sing-box-tools.sh) setup -y
```

#### VLESS 搭配 Cloudflare Tunnel (ARGO)

```bash
VLESS_PORT=3080 CLOUDFLARED_PORT=3080 bash <(curl -s https://raw.githubusercontent.com/sunnypuppy/sing-box/main/sing-box-tools.sh) setup -y
```

### 重启

```bash
bash <(curl -s https://raw.githubusercontent.com/sunnypuppy/sing-box/main/sing-box-tools.sh) restart
```

### 查看服务状态

```bash
bash <(curl -s https://raw.githubusercontent.com/sunnypuppy/sing-box/main/sing-box-tools.sh) status
```

### 查看节点信息

```bash
bash <(curl -s https://raw.githubusercontent.com/sunnypuppy/sing-box/main/sing-box-tools.sh) show_nodes
```

### 重置

```bash
bash <(curl -s https://raw.githubusercontent.com/sunnypuppy/sing-box/main/sing-box-tools.sh) reset -y
```

## 更多使用方法

```
Usage: ./sing-box-tools.sh [COMMAND] [OPTIONS]

Options:
  -y                   Automatically execute commands without prompts.
  -h                   Show this help message.

Commands:
  setup                Setup the sing-box.
  reset                Reset the sing-box.
  status               Show the current status.
  start                Start the sing-box service.
  stop                 Stop th sing-box service.
  restart              Restart the sing-box service.

  tunnel enable        Enable the cloudflare tunnel.
  tunnel disable       Disable the cloudflare tunnel.
  tunnel start         Start the cloudflare tunnel service.
  tunnel stop          Stop the cloudflare tunnel service.
  tunnel restart       Restart the cloudflare tunnel service.
```

## 保活配置（可选）

新增一个名为 `SERVICE_KEEPALIVE_ACCOUNTS_JSON` 的 Action Repository secrets，值格式示例：

```
[
    {"username": "uname_1", "password": "passwd_1", "host":"your.host_1.com","home":"/home/uname_1"},
    {"username": "uname_2", "password": "passwd_2", "host":"your.host_2.com","home":"/home/uname_2"},
    {"username": "uname_3", "password": "passwd_3", "host":"your.host_3.com","home":"/home/uname_3"}
]
```

字段解释：

- username 和 password 填写 VPS SSH 登录时的用户名和密码
- host 填写 VPS 的域名或者 IP 地址
- home 填写 sing-box 的安装目录，脚本默认安装在 $HOME 路径下
