#!/bin/bash

# 默认起始端口
DEFAULT_SOCKS_PORT=20000
DEFAULT_HTTP_PORT=30000

# 读取用户输入的用户名 & 密码
read -p "请输入 SOCKS5 代理的用户名 (默认: userb): " SOCKS_USERNAME
SOCKS_USERNAME=${SOCKS_USERNAME:-userb}

read -p "请输入 SOCKS5 代理的密码 (默认: passwordb): " SOCKS_PASSWORD
SOCKS_PASSWORD=${SOCKS_PASSWORD:-passwordb}

read -p "请输入 HTTP 代理的用户名 (默认: userb): " HTTP_USERNAME
HTTP_USERNAME=${HTTP_USERNAME:-userb}

read -p "请输入 HTTP 代理的密码 (默认: passwordb): " HTTP_PASSWORD
HTTP_PASSWORD=${HTTP_PASSWORD:-passwordb}

# 获取当前 VPS 绑定的所有 IPv4 地址
IP_ADDRESSES=($(hostname -I))

install_xray() {
    echo "🔹 安装 Xray..."
    apt-get update -y && apt-get install unzip -y || yum install unzip -y
    wget -O /tmp/Xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    unzip /tmp/Xray.zip -d /usr/local/bin
    chmod +x /usr/local/bin/xray
    cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray Proxy Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -c /etc/xray/config.json
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xray.service
    echo "✅ Xray 安装完成."
}

config_xray() {
    echo "🔹 生成 Xray 配置..."
    mkdir -p /etc/xray

    # 生成 SOCKS5 和 HTTP 代理配置
    cat <<EOF >/etc/xray/config.json
{
  "inbounds": [
    {
      "port": $DEFAULT_SOCKS_PORT,
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "udp": true,
        "accounts": [
          {
            "user": "$SOCKS_USERNAME",
            "pass": "$SOCKS_PASSWORD"
          }
        ]
      }
    },
    {
      "port": $DEFAULT_HTTP_PORT,
      "protocol": "http",
      "settings": {
        "accounts": [
          {
            "user": "$HTTP_USERNAME",
            "pass": "$HTTP_PASSWORD"
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

    # 重新启动 Xray
    systemctl restart xray.service
    systemctl --no-pager status xray.service

    echo "✅ 代理配置完成!"
    echo "🔹 SOCKS5 代理: socks5://$SOCKS_USERNAME:$SOCKS_PASSWORD@$(hostname -I | awk '{print $1}'):$DEFAULT_SOCKS_PORT"
    echo "🔹 HTTP 代理: http://$HTTP_USERNAME:$HTTP_PASSWORD@$(hostname -I | awk '{print $1}'):$DEFAULT_HTTP_PORT"
}

# 确保 Xray 已安装
[ -x "$(command -v xray)" ] || install_xray

# 生成配置并启动 Xray
config_xray
