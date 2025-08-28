#!/bin/bash
set -e

echo "🐳 Web Demo - Docker 一键部署"
echo "================================"

# 自动安装Docker和Docker Compose插件
install_docker() {
    echo "🔧 开始自动安装Docker..."
    
    # 检测操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ 无法检测操作系统"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            echo "📦 检测到 $OS 系统，开始安装..."
            
            # 更新包管理器
            apt-get update
            
            # 安装依赖包
            apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                apt-transport-https \
                software-properties-common
            
            # 尝试多个Docker源（国内优先）
            echo "🇨🇳 尝试使用阿里云Docker源..."
            if curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null; then
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            else
                # 备用：清华源
                echo "🇨🇳 尝试使用清华源..."
                if curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null; then
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                    apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                else
                    # 最后：使用官方便携包（无需网络下载）
                    echo "🌍 使用离线安装方式..."
                    apt-get install -y docker.io docker-compose-plugin || \
                    # 如果官方包也不行，提示手动安装
                    (echo "❌ 自动安装失败，请检查网络连接或手动安装"
                     echo "🔧 手动安装命令："
                     echo "   sudo apt update"
                     echo "   sudo apt install docker.io docker-compose-plugin"
                     exit 1)
                fi
            fi
            ;;
        centos|rhel|fedora)
            echo "📦 检测到 $OS 系统，开始安装..."
            
            # 安装依赖
            yum install -y yum-utils device-mapper-persistent-data lvm2
            
            # 添加Docker仓库（国内优先）
            echo "🇨🇳 尝试使用阿里云Docker源..."
            if yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo 2>/dev/null; then
                yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            else
                # 备用：使用系统默认源
                echo "🌍 使用系统默认源..."
                yum install -y docker docker-compose-plugin || \
                (echo "❌ 自动安装失败，请检查网络连接或手动安装"
                 exit 1)
            fi
            ;;
        *)
            echo "❌ 不支持的操作系统: $OS"
            echo "🔧 请手动安装Docker和Docker Compose插件"
            exit 1
            ;;
    esac
    
    # 启动Docker服务（处理systemctl可能失败的情况）
    echo "🔄 启动Docker服务..."
    if command -v systemctl &> /dev/null; then
        # 尝试使用systemctl
        if systemctl enable docker 2>/dev/null && systemctl start docker 2>/dev/null; then
            echo "✅ Docker服务启动成功"
        else
            echo "⚠️  systemctl启动失败，尝试其他方式..."
            # 尝试直接启动Docker守护进程
            if command -v dockerd &> /dev/null; then
                dockerd &> /dev/null &
                sleep 3
                echo "✅ Docker守护进程已在后台启动"
            else
                echo "⚠️  Docker服务启动失败，这可能在某些环境中是正常的"
                echo "   如果是容器环境或特殊平台，可能需要手动启动"
            fi
        fi
    else
        echo "⚠️  systemctl不可用，跳过服务启动"
        echo "   在某些环境中这是正常的（如容器内、WSL等）"
    fi
    
    # 验证Docker是否可用
    sleep 2
    if docker version &> /dev/null; then
        echo "✅ Docker命令可用"
    else
        echo "⚠️  Docker命令不可用，可能需要重新登录或手动启动服务"
        echo "🔧 故障排除："
        echo "   sudo systemctl status docker"
        echo "   sudo systemctl start docker"
        echo "   sudo dockerd"
    fi
    
    # 添加当前用户到docker组（如果不是root）
    if [ "$EUID" -ne 0 ] && [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        echo "⚠️  用户 $SUDO_USER 已添加到docker组，请重新登录后再运行脚本"
        exit 0
    fi
    
    echo "✅ Docker和Docker Compose插件安装完成"
}

# 检查Docker环境
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker未安装"
        read -p "🤔 是否自动安装Docker和Docker Compose插件？(Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            install_docker
        else
            echo "🔧 请手动安装Docker和Docker Compose插件:"
            echo "   # 阿里云源（推荐）"
            echo "   curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -"
            echo "   sudo add-apt-repository \"deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \$(lsb_release -cs) stable\""
            echo "   sudo apt update && sudo apt install docker-ce docker-compose-plugin"
            echo ""
            echo "   # 或者系统包"
            echo "   sudo apt update && sudo apt install docker.io docker-compose-plugin"
            exit 1
        fi
    fi

    if ! docker info &> /dev/null 2>&1; then
        echo "❌ Docker服务未运行，请启动Docker"
        exit 1
    fi

    # 检测Docker Compose插件
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        echo "✅ 检测到Docker Compose插件"
    else
        echo "❌ Docker Compose插件未安装"
        echo "🔧 安装Docker Compose插件:"
        echo "   # 方法1: 使用包管理器安装插件版本（推荐）"
        echo "   sudo apt update && sudo apt install docker-compose-plugin"
        echo ""
        echo "   # 方法2: 手动安装Compose插件"
        echo "   DOCKER_CONFIG=\${DOCKER_CONFIG:-\$HOME/.docker}"
        echo "   mkdir -p \$DOCKER_CONFIG/cli-plugins"
        echo "   curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o \$DOCKER_CONFIG/cli-plugins/docker-compose"
        echo "   chmod +x \$DOCKER_CONFIG/cli-plugins/docker-compose"
        echo ""
        echo "   # 方法3: 安装最新版Docker (自带Compose插件)"
        echo "   curl -fsSL https://get.docker.com | sudo sh"
        exit 1
    fi

    echo "✅ Docker环境检查通过，使用命令: $DOCKER_COMPOSE_CMD"
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
    
    # 首先检查并修复可能存在的Windows行结束符问题
    fix_line_endings() {
        local file="$1"
        if [ -f "$file" ]; then
            # 检查是否包含Windows行结束符
            if grep -q $'\r' "$file" 2>/dev/null; then
                echo "🔧 检测到Windows行结束符，正在修复 $file..."
                # 创建备份并修复
                cp "$file" "$file.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
                sed -i 's/\r$//' "$file"
                echo "✅ 行结束符已修复"
                return 0
            fi
        fi
        return 1
    }
    
    # 修复相关文件的行结束符
    echo "🔍 检查行结束符格式..."
    FIXED_ANY=false
    
    for file in .env env-template; do
        if fix_line_endings "$file"; then
            FIXED_ANY=true
        fi || true  # 避免函数返回值导致脚本退出
    done
    
    if [ "$FIXED_ANY" = "true" ]; then
        echo "✅ 行结束符修复完成"
    else
        echo "✅ 文件格式检查通过"
    fi
    
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
        # 使用现有配置时也要确保格式正确
        fix_line_endings ".env" || true
    fi
    
    # 显示当前配置
    echo ""
    echo "📋 当前配置:"
    if [ -f ".env" ]; then
        # 避免管道操作导致的退出问题
        ENV_CONTENT=$(grep -E "^[A-Z]" .env 2>/dev/null || echo "")
        if [ -n "$ENV_CONTENT" ]; then
            # 使用while read避免子shell问题
            while IFS= read -r line; do
                echo "   $line"
            done <<< "$ENV_CONTENT"
        else
            echo "   (暂无配置项显示)"
        fi
    else
        echo "   ❌ .env文件不存在"
    fi
    echo ""
    echo "✅ 环境配置完成，继续部署..."
    echo "🔄 准备进入下一阶段: SSL证书配置..."
}

# SSL证书处理
handle_ssl_certificates() {
    echo "🔒 开始SSL证书配置检查..."
    
    # 确保.env文件格式正确后再source
    if [ -f ".env" ]; then
        source .env
    else
        echo "❌ .env文件不存在"
        exit 1
    fi
    
    if [ "$SSL_MODE" = "letsencrypt" ]; then
        echo "🔒 准备 Let's Encrypt 证书目录..."
        mkdir -p ../ssl
    
        if [ ! -f "../ssl/fullchain.pem" ] || [ ! -f "../ssl/privkey.pem" ]; then
            echo "⚠️  未找到现有的 Let's Encrypt 证书，尝试自动申请..."
    
            # 安装 certbot（如果没有）
            if ! command -v certbot >/dev/null 2>&1; then
                echo "📦 正在安装 certbot..."
                sudo apt-get update -y
                sudo apt-get install -y certbot
            fi
    
            # 让用户输入邮箱
            read -p "📧 请输入你的邮箱 (用于注册 Let's Encrypt 账号): " user_email
            if [ -z "$user_email" ]; then
                echo "❌ 邮箱不能为空，请重新运行脚本。"
                exit 1
            fi
    
            # 自动申请证书
            sudo certbot certonly --standalone --non-interactive --agree-tos -m "$user_email" -d "$NGINX_HOST"
    
            # 拷贝证书到项目目录
            if [ -f "/etc/letsencrypt/live/$NGINX_HOST/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$NGINX_HOST/privkey.pem" ]; then
                echo "✅ 证书申请成功，复制到 ../ssl/"
                cp "/etc/letsencrypt/live/$NGINX_HOST/fullchain.pem" ../ssl/
                cp "/etc/letsencrypt/live/$NGINX_HOST/privkey.pem" ../ssl/
            else
                echo "❌ 自动申请证书失败，请检查域名解析是否正确。"
                exit 1
            fi
        else
            echo "✅ 已找到现有证书，继续使用。"
        fi
    fi


}

# 配置前端API地址
configure_frontend_api() {
    echo "⚙️ 配置前端API地址 (一体化部署模式)..."
    
    # 从docker_all目录进入前端目录配置环境变量
    cd ../frontend
    
    # 创建生产环境配置 - 一体化部署使用nginx代理
    cat > .env.production << 'EOF'
# 一体化部署模式 - 通过nginx代理访问API
# 空值表示使用相对路径，避免HTTPS混合内容错误
VITE_API_BASE_URL=
EOF
    
    echo "✅ 前端API配置完成 (使用nginx代理)"
    
    # 返回docker_all目录
    cd ../docker_all
}

# 部署应用
deploy_app() {
    echo ""
    echo "🚀 开始部署应用..."
    
    # 配置前端API
    configure_frontend_api
    
    # 停止现有容器
    echo "🛑 停止现有容器..."
    $DOCKER_COMPOSE_CMD down 2>/dev/null || true
    
    # 清理选项
    read -p "是否清理旧镜像? (y/N): " cleanup
    if [[ "$cleanup" =~ ^[Yy]$ ]]; then
        echo "🧹 清理旧镜像..."
        docker system prune -f
    fi
    
    # 构建镜像
    echo "🔨 构建Docker镜像..."
    echo "💡 提示: 如果网络较慢，构建可能需要10-20分钟，请耐心等待..."
    
    # 检测网络速度并选择构建策略
    echo "🌐 检测网络状况..."
    if timeout 10 curl -s http://mirrors.aliyun.com > /dev/null 2>&1; then
        echo "✅ 网络连接正常，开始构建..."
        $DOCKER_COMPOSE_CMD build --no-cache
    else
        echo "⚠️  网络较慢，使用优化构建..."
        # 使用缓存和并行构建
        $DOCKER_COMPOSE_CMD build --progress=plain
    fi
    
    # 启动服务
    echo "🚀 启动服务..."
    $DOCKER_COMPOSE_CMD up -d
    
    # 等待启动
    echo "⏳ 等待服务启动..."
    sleep 15
    
    # 健康检查
    echo "🧪 服务健康检查..."
    if $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
        echo "✅ 容器启动成功"
        
        # API测试
        if curl -f -s http://localhost:8080/health >/dev/null; then
            echo "✅ 后端API正常"
        else
            echo "⚠️  后端API可能还在启动中"
        fi
        
        # 前端测试 - 重新读取.env文件
        if [ -f ".env" ]; then
            source .env
        fi
        
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
        $DOCKER_COMPOSE_CMD logs
        exit 1
    fi
}

# 显示部署结果
show_result() {
    # 重新读取.env文件
    if [ -f ".env" ]; then
        source .env
    fi
    
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
    echo "   查看状态: $DOCKER_COMPOSE_CMD ps"
    echo "   查看日志: $DOCKER_COMPOSE_CMD logs -f"
    echo "   重启服务: $DOCKER_COMPOSE_CMD restart"
    echo "   停止服务: $DOCKER_COMPOSE_CMD down"
    echo "   更新重启: $DOCKER_COMPOSE_CMD up -d --build"
    
    echo ""
    echo "📊 当前状态:"
    $DOCKER_COMPOSE_CMD ps
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
