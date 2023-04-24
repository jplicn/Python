#!/bin/bash

# 获取用户输入的域名或IP地址
read -p "请输入您的Cloudreve实例的域名或IP地址: " CLOUDREVE_DOMAIN

# 安装必要的软件包
sudo apt update
sudo apt install -y wget dpkg systemd nginx certbot python3-certbot-nginx

# 安装Cloudreve
wget https://github.com/cloudreve/Cloudreve/releases/download/3.7.1/cloudreve_3.7.1_linux_amd64.tar.gz
sudo dpkg -i cloudreve_3.7.1_linux_amd64.tar.gz
tar -zxvf cloudreve_3.7.1_linux_amd64.tar.gz
chmod +x ./cloudreve

# 设置Cloudreve为系统服务
sudo tee /etc/systemd/system/cloudreve.service <<-'EOF'
[Unit]
Description=Cloudreve  
Documentation=https://docs.cloudreve.org
After=network.target
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
sudo systemctl daemon-reload
sudo systemctl start cloudreve
sudo systemctl enable cloudreve

# 安装SSL证书 
sudo certbot --nginx -d "$CLOUDREVE_DOMAIN"

# 配置nginx反向代理
sudo tee /etc/nginx/sites-available/cloudreve <<-'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name '$CLOUDREVE_DOMAIN';
    return 301 https://$server_name$request_uri; 
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name '$CLOUDREVE_DOMAIN';

    ssl_certificate /etc/letsencrypt/live/'$CLOUDREVE_DOMAIN'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'$CLOUDREVE_DOMAIN'/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:5212;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_redirect off;
    } 
}
EOF
sudo ln -s /etc/nginx/sites-available/cloudreve /etc/nginx/sites-enabled/
sudo systemctl restart nginx
