#!/bin/bash
set -e

echo "🐳 Web Demo - Docker 一键部署"
echo "================================"

# 检查Docker环境
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker未安装"
        echo "🔧 安装Docker (Ubuntu/Debian):"
        echo "   curl -fsSL https://get.docker.com | sh"
        echo "   sudo usermod -aG docker \$USER"
        exit 1
    fi

    if ! docker info &> /dev/null 2>&1; then
        echo "❌ Docker服务未运行，请启动Docker"
        exit 1
    fi

    echo "✅ Docker环境检查通过"
}

# 配置Docker镜像源
configure_mirrors() {
    echo "🚀 配置Docker镜像加速..."
    
    sudo mkdir -p /etc/docker
    
    # 备份现有配置
    if [ -f "/etc/docker/daemon.json" ]; then
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
    fi
    
    # 写入镜像源配置
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.1panel.live",
    "https://hub.rat.dev",
    "https://docker.m.daocloud.io"
  ]
}
EOF

    sudo systemctl restart docker
    echo "✅ Docker镜像源配置完成"
}

# 环境配置
setup_environment() {
    echo "📝 配置部署环境..."
    
    # 进入docker_all目录
    cd docker_all
    
    # 检查环境文件
    if [ ! -f ".env" ]; then
        if [ -f "env-template" ]; then
            cp env-template .env
            echo "📋 已创建 .env 文件，请根据需要修改配置"
        else
            # 创建基础.env文件
            cat > .env <<EOF
NGINX_HOST=localhost
API_BASE_URL=http://localhost
SSL_MODE=none
DEBUG=false
EOF
            echo "📋 已创建基础 .env 文件"
        fi
        
        # 询问用户配置
        echo ""
        echo "🛠️  请选择部署模式:"
        echo "1) HTTP访问 (开发测试)"
        echo "2) HTTPS + 自签名证书 (生产环境/IP访问)" 
        echo "3) HTTPS + Let's Encrypt (生产环境/域名访问)"
        echo "4) 手动配置 (跳过自动配置)"
        echo ""
        read -p "请选择 (1-4): " choice
        
        case $choice in
            1)
                echo "✅ 配置为HTTP模式"
                ;;
            2)
                read -p "请输入服务器IP地址: " server_ip
                sed -i "s/NGINX_HOST=localhost/NGINX_HOST=$server_ip/" .env
                sed -i "s|API_BASE_URL=http://localhost|API_BASE_URL=https://$server_ip|" .env
                sed -i "s/SSL_MODE=none/SSL_MODE=custom/" .env
                echo "✅ 配置为HTTPS+自签名证书模式"
                ;;
            3)
                read -p "请输入域名: " domain
                sed -i "s/NGINX_HOST=localhost/NGINX_HOST=$domain/" .env
                sed -i "s|API_BASE_URL=http://localhost|API_BASE_URL=https://$domain|" .env
                sed -i "s/SSL_MODE=none/SSL_MODE=letsencrypt/" .env
                echo "✅ 配置为HTTPS+Let's Encrypt模式"
                echo "💡 请确保域名已正确解析到此服务器"
                ;;
            4)
                echo "⚠️  请手动编辑 .env 文件进行配置"
                ;;
            *)
                echo "❌ 无效选择，使用默认HTTP配置"
                ;;
        esac
    else
        echo "✅ 使用现有 .env 配置"
    fi
    
    # 显示当前配置
    echo ""
    echo "📋 当前配置:"
    grep -E "^[A-Z]" .env | while read line; do
        echo "   $line"
    done
}

# SSL证书处理
handle_ssl_certificates() {
    source .env
    
    if [ "$SSL_MODE" = "letsencrypt" ]; then
        echo "🔒 准备Let's Encrypt证书目录..."
        mkdir -p ../ssl
        
        if [ ! -f "../ssl/fullchain.pem" ]; then
            echo "⚠️  Let's Encrypt证书未找到"
            echo "💡 请使用以下命令获取证书:"
            echo "   certbot certonly --standalone -d $NGINX_HOST"
            echo "   然后将证书复制到 ../ssl/ 目录"
            read -p "按Enter继续 (将使用自签名证书替代)..." 
            sed -i "s/SSL_MODE=letsencrypt/SSL_MODE=custom/" .env
        fi
    fi
}

# 部署应用
deploy_app() {
    echo ""
    echo "🚀 开始部署应用..."
    
    # 停止现有容器
    echo "🛑 停止现有容器..."
    docker compose down 2>/dev/null || true
    
    # 清理选项
    read -p "是否清理旧镜像? (y/N): " cleanup
    if [[ "$cleanup" =~ ^[Yy]$ ]]; then
        echo "🧹 清理旧镜像..."
        docker system prune -f
    fi
    
    # 构建镜像
    echo "🔨 构建Docker镜像..."
    docker compose build --no-cache
    
    # 启动服务
    echo "🚀 启动服务..."
    docker compose up -d
    
    # 等待启动
    echo "⏳ 等待服务启动..."
    sleep 15
    
    # 健康检查
    echo "🧪 服务健康检查..."
    if docker compose ps | grep -q "Up"; then
        echo "✅ 容器启动成功"
        
        # API测试
        if curl -f -s http://localhost:8080/health >/dev/null; then
            echo "✅ 后端API正常"
        else
            echo "⚠️  后端API可能还在启动中"
        fi
        
        # 前端测试
        source .env
        if [ "$SSL_MODE" = "none" ]; then
            TEST_URL="http://localhost/health"
        else
            TEST_URL="https://localhost/health"
        fi
        
        if curl -f -s -k "$TEST_URL" >/dev/null; then
            echo "✅ 前端代理正常"
        else
            echo "⚠️  前端代理可能还在配置中"
        fi
    else
        echo "❌ 容器启动失败"
        docker compose logs
        exit 1
    fi
}

# 显示部署结果
show_result() {
    source .env
    
    echo ""
    echo "🎉 部署完成！"
    echo "================================"
    
    if [ "$SSL_MODE" = "none" ]; then
        echo "🌐 访问地址: http://$NGINX_HOST"
        echo "📡 API地址: http://$NGINX_HOST/api/users"
        echo "🏥 健康检查: http://$NGINX_HOST/health"
    else
        echo "🔒 访问地址: https://$NGINX_HOST"
        echo "📡 API地址: https://$NGINX_HOST/api/users"
        echo "🏥 健康检查: https://$NGINX_HOST/health"
        
        if [ "$SSL_MODE" = "custom" ]; then
            echo ""
            echo "⚠️  注意: 使用自签名证书，浏览器会显示安全警告"
            echo "   点击"高级">"继续访问"即可"
        fi
    fi
    
    echo ""
    echo "📝 常用命令:"
    echo "   查看状态: docker compose ps"
    echo "   查看日志: docker compose logs -f"
    echo "   重启服务: docker compose restart"
    echo "   停止服务: docker compose down"
    echo "   更新重启: docker compose up -d --build"
    
    echo ""
    echo "📊 当前状态:"
    docker compose ps
}

# 主函数
main() {
    check_docker
    
    # 询问是否配置镜像源
    read -p "是否配置Docker镜像加速? (y/N): " mirrors
    if [[ "$mirrors" =~ ^[Yy]$ ]]; then
        configure_mirrors
    fi
    
    setup_environment
    handle_ssl_certificates
    deploy_app
    show_result
}

# 执行主函数
main "$@" 