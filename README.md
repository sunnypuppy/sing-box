# sing-box

自制 sing-box 工具箱。

```
Usage: ./sing-box-tools.sh [options] [action]

Options:
  -h, --help : Display this help message.
  -y, --yes  : Auto-confirm without prompting for user input.

Actions:
  install    : Install the application.
  uninstall  : Uninstall the application.
  start      : Start the service.
  stop       : Stop the service.
  restart    : Restart the service.
  status     : Display the status of the application and service.
  gen_config : Generate the configuration file.
  show_config: Show the configuration file content.
  show_nodes : Show the parsed nodes from configuration file content.
  setup      : Setup the application.
```

## 一键脚本

```bash
S5_PORT=1080 bash <(curl -s https://raw.githubusercontent.com/sunnypuppy/sing-box/main/sing-box-tools.sh) setup -y
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
