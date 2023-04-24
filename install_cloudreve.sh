#!/bin/bash

##!/bin/bash

# 安装 Cloudreve
wget https://github.com/cloudreve/Cloudreve/releases/download/3.7.1/cloudreve_3.7.1_linux_amd64.tar.gz
tar -zxvf cloudreve_3.7.1_linux_amd64.tar.gz
chmod +x ./cloudreve

# 配置 Cloudreve 为系统服务
cat <<EOF > /etc/systemd/system/cloudreve.service
[Unit]
Description=Cloudreve
Documentation=https://docs.cloudreve.org
After=network.target
After=mysqld.service
Wants=network.target

[Service]
WorkingDirectory=/root
ExecStart=/root/cloudreve
Restart=on-abnormal
RestartSec=5s
KillMode=mixed

StandardOutput=null
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start cloudreve
systemctl enable cloudreve

# 安装 Let's Encrypt 免费证书
apt update
apt install certbot python3-certbot-nginx -y
certbot --nginx -d cl.520105.xyz

# 配置 Nginx 反向代理
cat <<EOF > /etc/nginx/sites-available/cloudreve
server {
    listen 80;
    listen [::]:80;
    server_name cl.520105.xyz;
    return 301 https://\$server_name\$request_uri; 
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name cl.520105.xyz;

    ssl_certificate /etc/letsencrypt/live/cl.520105.xyz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cl.520105.xyz/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:5212;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_redirect off;
    }
}
EOF

ln -s /etc/nginx/sites-available/cloudreve /etc/nginx/sites-enabled/
systemctl restart nginx

echo "Cloudreve 安装及配置完成"
