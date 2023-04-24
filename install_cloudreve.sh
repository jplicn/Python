#!/bin/bash

# 下载并安装Cloudreve
wget https://github.com/cloudreve/Cloudreve/releases/download/3.7.1/cloudreve_3.7.1_linux_amd64.tar.gz
sudo dpkg -i cloudreve_3.7.1_linux_amd64.tar.gz
tar -zxvf cloudreve_3.7.1_linux_amd64.tar.gz
chmod +x ./cloudreve
./cloudreve

# 设置Cloudreve为系统服务
cat > /usr/lib/systemd/system/cloudreve.service <<EOF 
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

sudo systemctl daemon-reload
sudo systemctl start cloudreve
sudo systemctl enable cloudreve

# 安装SSL证书 
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d cloud.520105.xyz

# 配置nginx反向代理
cat > /etc/nginx/sites-available/cloudreve <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name cloud.520105.xyz;
    return 301 https://$server_name$request_uri; 
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name cloud.520105.xyz;

    ssl_certificate /etc/letsencrypt/live/cloud.520105.xyz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cloud.520105.xyz/privkey.pem;

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

ln -s /etc/nginx/sites-available/cloudreve /etc/nginx/sites-enabled/ 
systemctl restart nginx
