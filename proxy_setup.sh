#!/bin/bash

DEFAULT_START_PORT_SOCKS5=20000  # 默认 SOCKS5 代理起始端口
DEFAULT_START_PORT_HTTP=30000    # 默认 HTTP 代理起始端口
DEFAULT_SOCKS_USERNAME="userb"   # 默认 SOCKS5 账号
DEFAULT_SOCKS_PASSWORD="passwordb" # 默认 SOCKS5 密码
DEFAULT_HTTP_USERNAME="userb"    # 默认 HTTP 账号
DEFAULT_HTTP_PASSWORD="passwordb" # 默认 HTTP 密码

IP_ADDRESSES=($(hostname -I)) # 获取所有 IP 地址

install_xray() {
    echo "安装 Xray..."
    apt-get update -y
    apt-get install unzip -y || yum install unzip -y
    wget -qO /tmp/Xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    unzip -o /tmp/Xray.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/xray
    rm -f /tmp/Xray.zip
    mkdir -p /etc/xray
    cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray Proxy Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
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

generate_config() {
    echo "🛠 生成 Xray 配置..."
    cat <<EOF > /etc/xray/config.json
{
  "inbounds": [
EOF

    PORT_SOCKS5=$DEFAULT_START_PORT_SOCKS5
    PORT_HTTP=$DEFAULT_START_PORT_HTTP

    for ip in "${IP_ADDRESSES[@]}"; do
        cat <<EOF >> /etc/xray/config.json
    {
      "listen": "$ip",
      "port": $PORT_SOCKS5,
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "$DEFAULT_SOCKS_USERNAME",
            "pass": "$DEFAULT_SOCKS_PASSWORD"
          }
        ],
        "udp": true
      }
    },
    {
      "listen": "$ip",
      "port": $PORT_HTTP,
      "protocol": "http",
      "settings": {
        "accounts": [
          {
            "user": "$DEFAULT_HTTP_USERNAME",
            "pass": "$DEFAULT_HTTP_PASSWORD"
          }
        ],
        "allowTransparent": false
      }
    },
EOF
        ((PORT_SOCKS5++))
        ((PORT_HTTP++))
    done

    # 删除最后一个逗号
    sed -i '$ s/,$//' /etc/xray/config.json

    cat <<EOF >> /etc/xray/config.json
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
    echo "✅ Xray 配置文件已生成."
}

restart_xray() {
    systemctl restart xray.service
    systemctl status xray.service --no-pager
    echo "✅ Xray 代理已启动."
}

display_proxy_info() {
    echo "✅ 代理配置完成!"
    for ip in "${IP_ADDRESSES[@]}"; do
        echo "🔹 SOCKS5 代理: socks5://$DEFAULT_SOCKS_USERNAME:$DEFAULT_SOCKS_PASSWORD@$ip:$DEFAULT_START_PORT_SOCKS5"
        echo "🔹 HTTP  代理: http://$DEFAULT_HTTP_USERNAME:$DEFAULT_HTTP_PASSWORD@$ip:$DEFAULT_START_PORT_HTTP"
        ((DEFAULT_START_PORT_SOCKS5++))
        ((DEFAULT_START_PORT_HTTP++))
    done
}

main() {
    [ -x "$(command -v xray)" ] || install_xray
    generate_config
    restart_xray
    display_proxy_info
}

main
