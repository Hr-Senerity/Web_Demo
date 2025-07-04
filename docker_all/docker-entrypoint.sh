#!/bin/bash
set -e

echo "🚀 启动 Web Demo 服务..."
echo "================================"

# 环境变量默认值
export NGINX_HOST=${NGINX_HOST:-localhost}
export SSL_MODE=${SSL_MODE:-none}
export DEBUG=${DEBUG:-false}

echo "📋 配置信息:"
echo "   主机名: $NGINX_HOST"
echo "   SSL模式: $SSL_MODE"
echo "   调试模式: $DEBUG"

# 创建必要目录
mkdir -p /app/data /app/logs /etc/nginx/ssl

# 处理SSL配置
handle_ssl() {
    case "$SSL_MODE" in
        "custom"|"self-signed")
            echo "🔒 配置自签名SSL证书..."
            if [ ! -f "/etc/nginx/ssl/cert.pem" ] || [ ! -f "/etc/nginx/ssl/key.pem" ]; then
                echo "🔧 生成自签名证书..."
                openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -keyout /etc/nginx/ssl/key.pem \
                    -out /etc/nginx/ssl/cert.pem \
                    -subj "/C=CN/ST=State/L=City/O=Web-Demo/CN=$NGINX_HOST" \
                    -addext "subjectAltName=IP:$NGINX_HOST,DNS:$NGINX_HOST"
                echo "✅ 自签名证书已生成"
            fi
            ;;
        "letsencrypt"|"standard")
            echo "🌐 使用Let's Encrypt证书..."
            if [ ! -f "/etc/nginx/ssl/fullchain.pem" ] || [ ! -f "/etc/nginx/ssl/privkey.pem" ]; then
                echo "❌ 未找到Let's Encrypt证书，请手动获取或使用自签名模式"
                echo "💡 提示: 将证书文件放在 ./ssl/ 目录下"
                exit 1
            fi
            ;;
        "none"|*)
            echo "🔓 使用HTTP模式，跳过SSL配置"
            ;;
    esac
}

# 配置Nginx
configure_nginx() {
    echo "🔧 配置Nginx..."
    
    # 复制模板
    cp /etc/nginx/templates/default.conf.template /tmp/nginx.conf
    
    # 替换环境变量
    envsubst '${NGINX_HOST} ${SSL_MODE}' < /tmp/nginx.conf > /tmp/nginx_env.conf
    
    # 根据SSL模式处理配置
    if [ "$SSL_MODE" != "none" ]; then
        # 启用HTTPS重定向
        sed -i 's|#SSL_REDIRECT_PLACEHOLDER#|return 301 https://\$server_name\$request_uri;|' /tmp/nginx_env.conf
        
        # 创建SSL服务器配置文件
        cat > /tmp/ssl_server.conf << 'EOF'
server {
    listen 443 ssl http2;
    server_name NGINX_HOST_PLACEHOLDER;
    
    # SSL证书配置
SSL_CERT_PLACEHOLDER
    
    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 5m;

    # 前端静态文件
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # API代理
    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # CORS配置
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;

        # 处理预检请求
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }

    # 健康检查
    location /health {
        return 200 '{"status":"healthy","service":"web-demo-ssl","timestamp":"$time_iso8601"}';
        add_header Content-Type application/json;
        access_log off;
    }
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF
        
        # 替换占位符
        sed -i "s/NGINX_HOST_PLACEHOLDER/${NGINX_HOST}/" /tmp/ssl_server.conf
        
        if [ "$SSL_MODE" = "custom" ] || [ "$SSL_MODE" = "self-signed" ]; then
            sed -i "s|SSL_CERT_PLACEHOLDER|    ssl_certificate /etc/nginx/ssl/cert.pem;\n    ssl_certificate_key /etc/nginx/ssl/key.pem;|" /tmp/ssl_server.conf
        else
            sed -i "s|SSL_CERT_PLACEHOLDER|    ssl_certificate /etc/nginx/ssl/fullchain.pem;\n    ssl_certificate_key /etc/nginx/ssl/privkey.pem;|" /tmp/ssl_server.conf
        fi
        
        # 将SSL配置插入到主配置文件中
        sed -i "/#SSL_SERVER_PLACEHOLDER#/r /tmp/ssl_server.conf" /tmp/nginx_env.conf
        sed -i '/#SSL_SERVER_PLACEHOLDER#/d' /tmp/nginx_env.conf
    else
        # 移除SSL占位符
        sed -i '/#SSL_REDIRECT_PLACEHOLDER#/d' /tmp/nginx_env.conf
        sed -i '/#SSL_SERVER_PLACEHOLDER#/d' /tmp/nginx_env.conf
    fi
    
    # 应用最终配置
    cp /tmp/nginx_env.conf /etc/nginx/conf.d/default.conf
    
    echo "✅ Nginx配置完成"
    
    # 调试模式显示配置
    if [ "$DEBUG" = "true" ]; then
        echo "📋 生成的Nginx配置:"
        cat /etc/nginx/conf.d/default.conf
    fi
}

# 启动后端服务
start_backend() {
    echo "🔄 启动后端服务..."
    nohup /usr/local/bin/backend > /app/logs/backend.log 2>&1 &
    echo $! > /app/backend.pid
    echo "✅ 后端服务已启动 (PID: $(cat /app/backend.pid))"
}

# 启动Nginx
start_nginx() {
    echo "🌐 启动Nginx..."
    # 测试配置
    nginx -t
    # 启动nginx
    nginx -g "daemon off;" &
    echo $! > /app/nginx.pid
    echo "✅ Nginx已启动 (PID: $(cat /app/nginx.pid))"
}

# 主启动流程
main() {
    # 处理SSL
    handle_ssl
    
    # 配置Nginx
    configure_nginx
    
    # 启动后端
    start_backend
    
    # 等待后端启动
    sleep 5
    
    # 启动Nginx
    start_nginx
    
    echo ""
    echo "🎉 服务启动完成！"
    echo "================================"
    
    if [ "$SSL_MODE" = "none" ]; then
        echo "🌐 HTTP访问: http://$NGINX_HOST"
    else
        echo "🔒 HTTPS访问: https://$NGINX_HOST"
    fi
    
    echo "📡 API地址: /api/users"
    echo "🏥 健康检查: /health"
    
    # 保持容器运行
    tail -f /app/logs/backend.log &
    wait
}

# 捕获信号处理
trap 'echo "🛑 正在关闭服务..."; kill $(cat /app/backend.pid 2>/dev/null) $(cat /app/nginx.pid 2>/dev/null) 2>/dev/null; exit 0' SIGTERM SIGINT

# 执行主函数
main 