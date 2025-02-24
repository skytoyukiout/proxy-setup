#!/bin/bash

# 获取传入的用户名、密码
USER=${1:-user}      # 默认用户名 user
PASS=${2:-pass}      # 默认密码 pass
START_PORT=${3:-30000}  # 默认起始端口 30000

# 检测系统类型 (Debian/Ubuntu 或 CentOS)
if [[ -f /etc/debian_version ]]; then
    OS="debian"
elif [[ -f /etc/redhat-release ]]; then
    OS="centos"
else
    echo "Unsupported OS"
    exit 1
fi

# 安装 3proxy 代理软件
install_3proxy() {
    if [[ "$OS" == "debian" ]]; then
        apt update && apt install -y 3proxy
    elif [[ "$OS" == "centos" ]]; then
        yum install -y epel-release && yum install -y 3proxy
    fi
}

install_3proxy

# 获取所有 IPv4 地址（去掉 IPv6）
IP_LIST=$(hostname -I | tr ' ' '\n' | grep -E "^[0-9]+\.[0-9]+")

# 初始化端口计数器
PORT=$START_PORT

# 创建 3proxy 配置文件
echo "daemon
maxconn 200
nserver 8.8.8.8
nserver 8.8.4.4
auth strong
users $USER:CL:$PASS" > /etc/3proxy.cfg

# 绑定每个 IP 到不同端口
for IP in $IP_LIST; do
    echo "proxy -n -a -p$PORT -i$IP -e$IP" >> /etc/3proxy.cfg
    ((PORT++))
done

# 允许端口访问
if [[ "$OS" == "debian" ]]; then
    for ((i=START_PORT; i<PORT; i++)); do
        ufw allow $i/tcp
    done
elif [[ "$OS" == "centos" ]]; then
    for ((i=START_PORT; i<PORT; i++)); do
        firewall-cmd --permanent --add-port=$i/tcp
    done
    firewall-cmd --reload
fi

# 启动 3proxy 代理服务
pkill 3proxy
nohup 3proxy /etc/3proxy.cfg > /dev/null 2>&1 &

echo "HTTP Proxy Setup Complete!"
echo "=========================="
echo "Proxy IPs:"
PORT=$START_PORT
for IP in $IP_LIST; do
    echo "http://$USER:$PASS@$IP:$PORT"
    ((PORT++))
done
echo "=========================="
