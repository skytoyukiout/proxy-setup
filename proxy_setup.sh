#!/bin/bash
# 3X-UI 一键安装 SOCKS5 + HTTP 代理脚本
# 作者: skytoyukiout
# 适用于 Ubuntu / Debian / CentOS

set -e  # 遇到错误立即退出

# 代理默认端口
SOCKS5_PORT=20000
HTTP_PORT=30000

# 用户输入代理的用户名和密码
read -p "请输入代理用户名 (默认: userb): " PROXY_USER
PROXY_USER=${PROXY_USER:-userb}
read -s -p "请输入代理密码 (默认: passwordb): " PROXY_PASS
PROXY_PASS=${PROXY_PASS:-passwordb}
echo ""

# 安装 3x-ui
install_3x_ui() {
    echo "🔹 安装 3X-UI 面板..."
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
    echo "✅ 3X-UI 安装完成！"
}

# 添加 SOCKS5 代理
add_socks5_proxy() {
    echo "🔹 添加 SOCKS5 代理..."
    x-ui api add --protocol socks --port $SOCKS5_PORT --username $PROXY_USER --password $PROXY_PASS
    echo "✅ SOCKS5 代理已添加: socks5://$PROXY_USER:$PROXY_PASS@$(hostname -I | awk '{print $1}'):$SOCKS5_PORT"
}

# 添加 HTTP 代理
add_http_proxy() {
    echo "🔹 添加 HTTP 代理..."
    x-ui api add --protocol http --port $HTTP_PORT --username $PROXY_USER --password $PROXY_PASS
    echo "✅ HTTP 代理已添加: http://$PROXY_USER:$PROXY_PASS@$(hostname -I | awk '{print $1}'):$HTTP_PORT"
}

# 运行面板
start_3x_ui() {
    echo "🔹 启动 3X-UI 面板..."
    systemctl start x-ui
    echo "✅ 3X-UI 已启动，面板地址: http://$(hostname -I | awk '{print $1}'):2053"
}

# 主函数
main() {
    install_3x_ui
    add_socks5_proxy
    add_http_proxy
    start_3x_ui

    echo "======================================"
    echo "✅ 3X-UI SOCKS5 + HTTP 代理配置完成！"
    echo "📌 SOCKS5 代理: socks5://$PROXY_USER:$PROXY_PASS@$(hostname -I | awk '{print $1}'):$SOCKS5_PORT"
    echo "📌 HTTP 代理: http://$PROXY_USER:$PROXY_PASS@$(hostname -I | awk '{print $1}'):$HTTP_PORT"
    echo "======================================"
}

# 执行主函数
main
