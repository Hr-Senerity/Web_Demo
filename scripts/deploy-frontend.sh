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
echo "   - 如需连接后端API，请先部署后端服务"
echo "   - 修改 nginx.conf 中的API代理配置以连接后端"
echo "================================"

cd .. 