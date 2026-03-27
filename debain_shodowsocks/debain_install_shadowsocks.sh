#!/bin/bash

# 备份并替换 apt 源
cp /etc/apt/sources.list /etc/apt/sources.list_bak
sed -i 's/mirrors.tuna.tsinghua.edu.cn/mirrors.aliyun.com/g' /etc/apt/sources.list
apt-get update

# 安装 sudo 和 vim
for i in 'sudo' 'vim' 
do
	if ! type $i >/dev/null 2>&1;then
		echo "$i 未安装，开始安装..."
		apt-get install -y $i
		echo "$i 安装完成"
	else
		echo "$i 已安装"
	fi
done

# 更新并安装 snapd
sudo apt update
sudo apt-get install -y snapd

# 安装 snap 包（不加 --yes，避免参数错误）
sudo snap install core
sudo snap install shadowsocks-libev

# 验证 snap 安装是否成功
if ! snap list | grep -q shadowsocks-libev; then
    echo "错误：shadowsocks-libev 安装失败，请检查网络或手动安装。"
    exit 1
fi

# 创建配置文件目录
sudo mkdir -p /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev

# 写入 shadowsocks 配置
cat > /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/config.json <<EOF
{
    "server":["::0","0.0.0.0"],
    "server_port":8091,
    "local_port":1080,
    "password":"gys123456",
    "timeout":60,
    "method":"aes-256-gcm",
    "mode":"tcp_and_udp",
    "fast_open":false
}
EOF

# 写入 systemd 服务模板
cat > /etc/systemd/system/shadowsocks-libev-server@.service <<EOF
[Unit]
Description=Shadowsocks-Libev Custom Server Service for %I
After=network-online.target
 
[Service]
Type=simple
LimitNOFILE=65536
ExecStart=/usr/bin/snap run shadowsocks-libev.ss-server -c /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/%i.json
 
[Install]
WantedBy=multi-user.target
EOF

# 启动服务
sudo systemctl enable shadowsocks-libev-server@config
sudo systemctl start shadowsocks-libev-server@config
sudo systemctl status shadowsocks-libev-server@config

# 开启 BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
lsmod | grep bbr

echo "配置完成！"
