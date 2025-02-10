# sing-box

自制 sing-box 工具箱。支持的功能：

```
**************************************************************
                   Sing-box Tools Menu
**************************************************************
Service version: Not installed (Latest version vx.xx.x)
Service status : Not running
**************************************************************
[System Management]
1. Install sing-box
2. Upgrade sing-box
3. Uninstall sing-box
-------------------------
[Service Management]
4. Start sing-box
5. Stop sing-box
6. Restart sing-box
-------------------------
[Configuration]
7. Show config
8. Reset config
-------------------------
[Protocol Management]
a. Add Protocol
b. Remove Protocol
c. Update Protocol
**************************************************************
0. Quit
```

## 一键脚本

```bash
bash <(curl -s https://raw.githubusercontent.com/sunnypuppy/sing-box/main/singbox_tools.sh)
```

## 保活配置

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
