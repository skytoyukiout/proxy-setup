#!/bin/bash

# 让用户输入 SOCKS5 和 HTTP 代理的用户名和密码
read -p "请输入 SOCKS5 代理用户名 (默认: userb): " SOCKS_USERNAME
SOCKS_USERNAME=${SOCKS_USERNAME:-userb}

read -p "请输入 SOCKS5 代理密码 (默认: passwordb): " SOCKS_PASSWORD
SOCKS_PASSWORD=${SOCKS_PASSWORD:-passwordb}

read -p "请输入 HTTP 代理用户名 (默认: userb): " HTTP_USERNAME
HTTP_USERNAME=${HTTP_USERNAME:-userb}

read -p "请输入 HTTP 代理密码 (默认: passwordb): " HTTP_PASSWORD
HTTP_PASSWORD=${HTTP_PASSWORD:-passwordb}

# 端口设置
SOCKS5_PORT=20000
HTTP_PORT=30000

# 下载并安装 Xray
echo "安装 Xray..."
apt-get install unzip -y
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip -O /tmp/Xray.zip
unzip /tmp/Xray.zip -d /usr/local/bin/
chmod +x /usr/local/bin/xray

# 生成 Xray 配置文件
cat <<EOF >/etc/xray/config.json
{
  "inbounds": [
    {
      "port": $SOCKS5_PORT,
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "$SOCKS_USERNAME",
            "pass": "$SOCKS_PASSWORD"
          }
        ],
        "udp": true
      }
    },
    {
      "port": $HTTP_PORT,
      "protocol": "http",
      "settings": {
        "accounts": [
          {
            "user": "$HTTP_USERNAME",
            "pass": "$HTTP_PASSWORD"
          }
        ],
        "allowTransparent": false
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# 创建 systemd 服务
cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray Proxy Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=always
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 启动 Xray
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

echo "✅ Xray 代理已安装"
echo "SOCKS5 代理: socks5://$SOCKS_USERNAME:$SOCKS_PASSWORD@$(hostname -I | awk '{print $1}'):$SOCKS5_PORT"
echo "HTTP 代理: http://$HTTP_USERNAME:$HTTP_PASSWORD@$(hostname -I | awk '{print $1}'):$HTTP_PORT"
