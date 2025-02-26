#!/bin/bash

# 🛠 默认参数
DEFAULT_START_PORT_SOCKS5=20000   # SOCKS5 代理起始端口
DEFAULT_START_PORT_HTTP=30000     # HTTP 代理起始端口
DEFAULT_SOCKS_USERNAME="user"     # SOCKS5 账号（默认）
DEFAULT_SOCKS_PASSWORD="pass"     # SOCKS5 密码（默认）
DEFAULT_HTTP_USERNAME="user"      # HTTP 账号（默认）
DEFAULT_HTTP_PASSWORD="pass"      # HTTP 密码（默认）

# 🛠 获取所有 IP 地址
read -p "请输入要绑定的 IP 地址（空格分隔多个 IP）: " -a IP_ADDRESSES
if [ ${#IP_ADDRESSES[@]} -eq 0 ]; then
    echo "⚠️ 未输入 IP 地址，默认使用主机所有公网 IP"
    IP_ADDRESSES=($(hostname -I))
fi

# 🛠 安装 Xray
install_xray() {
    echo "🚀 安装 Xray..."
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

# 🛠 生成 Xray 配置文件
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

# 🛠 配置 IP 分流
setup_ip_rules() {
    echo "⚡ 配置 IP 分流规则..."
    for ip in "${IP_ADDRESSES[@]}"; do
        table_id=$((RANDOM % 900 + 100))  # 生成随机路由表 ID（避免冲突）
        ip rule add from "$ip" table "$table_id"
        ip route add default via "$ip" dev eth0 table "$table_id"
        echo "🔹 绑定 $ip 到路由表 $table_id"
    done
    echo "✅ IP 分流规则已配置."
}

# 🛠 启动 Xray
restart_xray() {
    systemctl restart xray.service
    systemctl status xray.service --no-pager
    echo "✅ Xray 代理已启动."
}

# 🛠 显示代理信息
display_proxy_info() {
    echo "✅ 代理配置完成!"
    for ip in "${IP_ADDRESSES[@]}"; do
        echo "🔹 SOCKS5 代理: socks5://$DEFAULT_SOCKS_USERNAME:$DEFAULT_SOCKS_PASSWORD@$ip:$DEFAULT_START_PORT_SOCKS5"
        echo "🔹 HTTP  代理: http://$DEFAULT_HTTP_USERNAME:$DEFAULT_HTTP_PASSWORD@$ip:$DEFAULT_START_PORT_HTTP"
        ((DEFAULT_START_PORT_SOCKS5++))
        ((DEFAULT_START_PORT_HTTP++))
    done
}

# 🛠 主函数
main() {
    [ -x "$(command -v xray)" ] || install_xray
    generate_config
    setup_ip_rules
    restart_xray
    display_proxy_info
}

main
