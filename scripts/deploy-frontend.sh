#!/bin/bash
set -e

echo "🚀 前端Docker部署脚本"
echo "基于React + TypeScript + Vite + Docker + Nginx"

# 检查环境要求
echo "📋 检查环境要求..."

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker Desktop"
    echo "下载地址: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# 检查Docker是否运行
if ! docker info &> /dev/null; then
    echo "❌ Docker服务未运行，请启动Docker Desktop"
    exit 1
fi

echo "✅ Docker环境检查通过"

# 检查Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose未安装"
    exit 1
fi

echo "✅ Docker Compose检查通过"

# 检查项目结构
echo "📁 检查项目结构..."

if [ ! -d "frontend" ]; then
    echo "❌ frontend目录不存在，请在项目根目录运行此脚本"
    exit 1
fi

if [ ! -d "shared" ]; then
    echo "❌ shared目录不存在"
    exit 1
fi

if [ ! -f "frontend/package.json" ]; then
    echo "❌ frontend/package.json文件不存在"
    exit 1
fi

echo "✅ 项目结构检查通过"

# 进入前端目录
cd frontend

# 检查必要的配置文件
echo "📋 检查配置文件..."

required_files=("Dockerfile" "docker-compose.yml" "nginx.conf" ".dockerignore")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ 缺少配置文件: $file"
        echo "请确保前端目录包含所有必要的Docker配置文件"
        exit 1
    fi
done

echo "✅ 配置文件检查通过"

# 配置前端API地址
echo ""
echo "⚙️ 配置后端API地址..."
echo "前端分离部署模式需要指定后端服务器地址"
echo ""

# 提供默认选项
echo "请选择后端API地址配置:"
echo "1) 输入服务器IP地址"
echo "2) 使用本地后端 (http://localhost:8080)"
echo ""

read -p "请选择 (1-2): " api_choice

case $api_choice in
    1)
        read -p "请输入服务器IP地址 (如 115.29.168.115): " server_ip
        API_BASE_URL="https://$server_ip"
        echo "✅ 使用服务器地址: $API_BASE_URL"
        ;;
    2)
        API_BASE_URL="http://localhost:8080"
        echo "✅ 使用本地后端地址: $API_BASE_URL"
        ;;
    *)
        echo "❌ 无效选择，使用本地后端地址"
        API_BASE_URL="http://localhost:8080"
        ;;
esac

# 创建生产环境配置
echo "📝 创建前端环境配置..."
cat > .env.production << EOF
# 前端分离部署模式 - 连接独立后端服务器
VITE_API_BASE_URL=$API_BASE_URL
EOF

# 动态替换配置文件中的Server_IP占位符
echo "🔧 替换配置文件中的Server_IP占位符..."

# 备份原始文件
cp nginx.conf nginx.conf.backup
cp src/config/api.ts src/config/api.ts.backup
cp docker-compose.yml docker-compose.yml.backup

# 根据选择的API地址提取IP或使用localhost
if [[ "$API_BASE_URL" =~ ^https?://([^:/]+) ]]; then
    SERVER_IP="${BASH_REMATCH[1]}"
    PROXY_PROTOCOL="http"
    PROXY_PORT="80"
    if [[ "$API_BASE_URL" =~ ^https:// ]]; then
        PROXY_PORT="443"
        PROXY_PROTOCOL="https"
    fi
else
    SERVER_IP="localhost"
    PROXY_PROTOCOL="http"
    PROXY_PORT="8080"
fi

echo "   替换目标: Server_IP -> $SERVER_IP"

# 替换nginx.conf中的Server_IP
sed -i "s/Server_IP:80/$SERVER_IP:$PROXY_PORT/g" nginx.conf
sed -i "s/proxy_set_header Host Server_IP/proxy_set_header Host $SERVER_IP/g" nginx.conf

# 替换api.ts中的Server_IP
sed -i "s|http://Server_IP|$API_BASE_URL|g" src/config/api.ts

# 替换docker-compose.yml中的Server_IP
sed -i "s|VITE_API_BASE_URL=http://Server_IP|VITE_API_BASE_URL=$API_BASE_URL|g" docker-compose.yml

echo "✅ 前端API配置完成: $API_BASE_URL"
echo "✅ 配置文件占位符替换完成"

# 清理旧容器
echo "🧹 清理旧容器和镜像..."
docker-compose down 2>/dev/null || true
docker system prune -f

# 构建Docker镜像
echo "🔧 构建Docker镜像..."
echo "这可能需要几分钟时间，请耐心等待..."

if ! docker-compose build; then
    echo "❌ Docker镜像构建失败"
    echo "请检查Docker配置和网络连接"
    exit 1
fi

echo "✅ Docker镜像构建成功"

# 启动容器
echo "🚀 启动前端容器..."
if ! docker-compose up -d; then
    echo "❌ 容器启动失败"
    exit 1
fi

# 等待容器启动
echo "⏱️ 等待容器启动..."
sleep 5

# 检查容器状态
echo "📊 检查容器状态..."
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ 容器未正常启动"
    echo "查看日志:"
    docker-compose logs
    exit 1
fi

echo "✅ 容器启动成功"

# 测试应用
echo "🧪 测试前端应用..."
sleep 3

# 测试健康检查
if curl -s http://localhost:3000/health >/dev/null 2>&1; then
    echo "✅ 健康检查通过"
else
    echo "⚠️ 健康检查失败，但应用可能仍在启动中"
fi

# 测试主页
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ 前端应用访问正常"
else
    echo "❌ 前端应用访问失败"
    echo "查看容器日志:"
    docker-compose logs frontend
    exit 1
fi

# 显示部署信息
echo ""
echo "🎉 前端部署成功！"
echo "================================"
echo "🌐 应用地址: http://localhost:3000"
echo "🏥 健康检查: http://localhost:3000/health"
echo "📊 容器状态:"
docker-compose ps

echo ""
echo "🔧 管理命令:"
echo "   查看日志: docker-compose logs frontend"
echo "   停止服务: docker-compose down"
echo "   重启服务: docker-compose restart"
echo "   重新构建: docker-compose down && docker-compose build && docker-compose up -d"
echo "   进入容器: docker-compose exec frontend sh"
echo ""
echo "📝 注意事项:"
echo "   - 前端应用运行在端口 3000"
echo "   - 配置文件已自动替换Server_IP占位符"
echo "   - 原始文件已备份为 *.backup"
echo ""
echo "🔄 配置恢复:"
echo "   如需恢复原始配置:"
echo "   cd frontend"
echo "   mv nginx.conf.backup nginx.conf"
echo "   mv src/config/api.ts.backup src/config/api.ts"
echo "   mv docker-compose.yml.backup docker-compose.yml"
echo "================================"

cd .. 