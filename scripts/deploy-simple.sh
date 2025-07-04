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

if ! command -v pkg-config &> /dev/null; then
    echo "安装pkg-config..."
    sudo apt update && sudo apt install -y pkg-config
fi

echo "✅ 系统依赖检查完成"

# 检查并修复可能存在的Windows行结束符问题
echo "🔍 检查配置文件格式..."
if [ -f ".env" ] && grep -q $'\r' ".env" 2>/dev/null; then
    echo "🔧 检测到Windows行结束符，正在修复..."
    cp ".env" ".env.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    sed -i 's/\r$//' ".env"
    echo "✅ 行结束符已修复"
fi

# 安装C++依赖库
echo "📦 安装C++依赖库..."

# 检查并安装nlohmann-json
if ! pkg-config --exists nlohmann_json; then
    echo "安装nlohmann-json..."
    sudo apt update && sudo apt install -y nlohmann-json3-dev
else
    echo "✅ nlohmann-json已安装"
fi

# 检查cpp-httplib (header-only) - 现在使用项目本地文件
# 注意：脚本从scripts目录运行，所以使用相对路径
if [ -f "../backend/include/httplib.h" ]; then
    echo "✅ cpp-httplib (使用项目本地文件: backend/include/httplib.h)"
else
    echo "❌ 未找到cpp-httplib header文件"
    echo "💡 请确保 httplib.h 文件存在于 backend/include/ 目录中"
    echo "   可以从以下地址下载:"
    echo "   curl -L -o ../backend/include/httplib.h https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.18.7/httplib.h"
    exit 1
fi

echo "✅ C++依赖库安装完成"

# 编译后端
echo "🔧 编译后端..."
cd ../backend

# 清理旧构建
rm -rf build
mkdir build && cd build

# 配置CMake - 不再需要vcpkg工具链
echo "配置CMake..."
cmake .. \
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

# 获取服务器IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')

echo ""
echo "🎉 后端部署完成！"
echo "================================"
echo "🔒 HTTPS地址: https://$SERVER_IP (推荐)"
echo "🌐 HTTP地址: http://$SERVER_IP (备用)"
echo "🔍 健康检查: https://$SERVER_IP/health"
echo "📡 API地址: https://$SERVER_IP/api/users"
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
echo ""
echo "💡 前端连接配置:"
echo "================================"
echo "如需本地运行前端连接此后端，请在前端目录执行:"
echo ""
echo "# 方法1: 使用环境变量构建"
echo "cd frontend"
echo "VITE_API_BASE_URL=https://$SERVER_IP npm run build"
echo "npm run preview"
echo ""
echo "# 方法2: 使用部署脚本自动配置"
echo "./scripts/deploy-frontend.sh"
echo "# 选择选项1，输入IP：$SERVER_IP"
echo ""
echo "# 方法3: 创建环境配置文件"
echo "cd frontend"
echo "echo 'VITE_API_BASE_URL=https://$SERVER_IP' > .env.local"
echo "npm run dev  # 开发模式"
echo "# 或"
echo "npm run build && npm run preview  # 生产模式"
echo "================================" 