#!/bin/bash
set -e

echo "🚀 一键部署C++后端服务"

# 检查并安装系统依赖
echo "📋 检查系统依赖..."
if ! command -v cmake &> /dev/null; then
    echo "安装CMake..."
    sudo apt update && sudo apt install -y cmake
fi

if ! command -v make &> /dev/null; then
    echo "安装构建工具..."
    sudo apt update && sudo apt install -y build-essential
fi

if ! command -v git &> /dev/null; then
    echo "安装Git..."
    sudo apt update && sudo apt install -y git
fi

if ! command -v curl &> /dev/null; then
    echo "安装Curl..."
    sudo apt update && sudo apt install -y curl
fi

echo "✅ 系统依赖检查完成"

# 安装配置vcpkg
echo "📦 配置vcpkg包管理器..."
if [ ! -d "vcpkg" ]; then
    echo "克隆vcpkg..."
    git clone https://github.com/Microsoft/vcpkg.git
    cd vcpkg
    ./bootstrap-vcpkg.sh
    cd ..
else
    echo "vcpkg已存在，更新中..."
    cd vcpkg
    git pull
    cd ..
fi

# 安装C++依赖包
echo "📦 安装C++依赖包..."
cd vcpkg
./vcpkg install cpp-httplib nlohmann-json
cd ..

echo "✅ 依赖包安装完成"

# 编译后端
echo "🔧 编译后端..."
cd ../backend

# 清理旧构建
rm -rf build
mkdir build && cd build

# 配置CMake - 使用vcpkg工具链
echo "配置CMake..."
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=../../scripts/vcpkg/scripts/buildsystems/vcpkg.cmake \
    -DCMAKE_BUILD_TYPE=Release

# 编译
echo "编译中..."
make -j$(nproc)

echo "✅ 编译完成"

# 启动后端服务
echo "🚀 启动后端服务..."

# 停止现有服务
if [ -f "../backend.pid" ]; then
    OLD_PID=$(cat ../backend.pid)
    if ps -p $OLD_PID > /dev/null 2>&1; then
        echo "停止现有服务 (PID: $OLD_PID)"
        kill $OLD_PID
        sleep 2
    fi
fi

# 启动新服务 - 完全脱离终端会话
nohup ./bin/backend > ../backend.log 2>&1 &
NEW_PID=$!
echo $NEW_PID > ../backend.pid

# 让进程完全脱离当前shell会话
disown $NEW_PID

echo "✅ 后端服务已启动 (PID: $NEW_PID)"
echo "📊 服务信息:"
echo "   监听端口: 8080"
echo "   日志文件: backend/backend.log"

# 等待服务启动
sleep 3

# 测试服务
echo "🧪 测试后端服务..."
if curl -s http://localhost:8080/api/users >/dev/null 2>&1; then
    echo "✅ 后端服务运行正常"
else
    echo "⚠️  服务可能还在启动，查看日志:"
    tail -n 5 ../backend.log
fi

cd ../..

# 配置Nginx
echo "🌐 配置Nginx..."

# 安装nginx
if ! command -v nginx &> /dev/null; then
    echo "安装Nginx..."
    sudo apt update && sudo apt install -y nginx
fi

# 备份原配置
if [ -f "/etc/nginx/sites-available/default" ]; then
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)
fi

# 配置反向代理
sudo tee /etc/nginx/sites-available/default > /dev/null <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    # API代理到后端
    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # CORS配置
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
        
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
            return 204;
        }
    }
    
    # 健康检查
    location /health {
        proxy_pass http://localhost:8080;
    }
    
    location / {
        return 200 'Backend Server is running!';
        add_header Content-Type text/plain;
    }
}
EOF

# 测试并重启nginx
echo "测试Nginx配置..."
sudo nginx -t && sudo systemctl restart nginx
sudo systemctl enable nginx

echo "✅ Nginx配置完成"

# 最终测试
echo "🧪 最终测试..."
sleep 2

# 测试直接连接
if curl -s http://localhost:8080/api/users >/dev/null 2>&1; then
    echo "✅ 后端直接连接正常"
else
    echo "❌ 后端直接连接失败"
fi

# 测试Nginx代理
if curl -s http://localhost/api/users >/dev/null 2>&1; then
    echo "✅ Nginx代理正常"
else
    echo "❌ Nginx代理失败"
fi

echo ""
echo "🎉 部署完成！"
echo "================================"
echo "🌐 服务器地址: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo "🔍 健康检查: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')/health"
echo "📡 API地址: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')/api/users"
echo ""
echo "📊 服务状态:"
echo "   后端PID: $(cat backend/backend.pid 2>/dev/null || echo '未知')"
echo "   日志文件: backend/backend.log"
echo "   Nginx状态: $(sudo systemctl is-active nginx 2>/dev/null || echo '未知')"
echo ""
echo "🔧 管理命令:"
echo "   查看日志: tail -f backend/backend.log"
echo "   停止后端: kill \$(cat backend/backend.pid)"
echo "   重启后端: cd backend/build && nohup ./bin/backend > ../backend.log 2>&1 & echo \$! > ../backend.pid && disown \$!"
echo "   Nginx重启: sudo systemctl restart nginx"
echo "================================" 