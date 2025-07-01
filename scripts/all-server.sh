#!/bin/bash
set -e

# =================================================================
# 🚀 Web项目服务器一键部署脚本 (Docker版本 + 智能SSL)
# 功能：前后端分离架构，通过Docker容器化部署
# 智能SSL：有域名用正式SSL，无域名用自签名SSL
# =================================================================

# 配置变量 - 请根据实际情况修改
SERVER_IP=""           # 服务器公网IP，例如: 123.45.67.89
DOMAIN_NAME=""         # 域名，例如: your-domain.com (可选，不填则使用IP+自签名SSL)
FRONTEND_PORT="3000"   # 前端对外端口
BACKEND_PORT="8080"    # 后端对外端口
NGINX_HTTP_PORT="80"   # nginx HTTP端口
NGINX_HTTPS_PORT="443" # nginx HTTPS端口
ENABLE_SSL="true"      # 是否启用SSL (true/false)

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必需的配置
check_config() {
    log_info "检查配置参数..."
    
    if [ -z "$SERVER_IP" ]; then
        log_error "请设置 SERVER_IP 变量（服务器公网IP）"
        exit 1
    fi
    
    # 判断SSL配置策略
    if [ -z "$DOMAIN_NAME" ]; then
        USE_DOMAIN_SSL="false"
        ACCESS_URL="$SERVER_IP"
        log_warning "未设置域名，将使用IP + 自签名SSL"
    else
        USE_DOMAIN_SSL="true"
        ACCESS_URL="$DOMAIN_NAME"
        log_info "检测到域名，将使用域名 + 正式SSL证书"
    fi
    
    # 检查SSL工具
    if [ "$ENABLE_SSL" = "true" ]; then
        if ! command -v openssl &> /dev/null; then
            log_error "OpenSSL未安装，请安装后重试"
            echo "Ubuntu/Debian: sudo apt install openssl"
            echo "CentOS/RHEL: sudo yum install openssl"
            exit 1
        fi
        
        if [ "$USE_DOMAIN_SSL" = "true" ] && ! command -v certbot &> /dev/null; then
            log_warning "Certbot未安装，将安装Let's Encrypt客户端"
        fi
    fi
    
    log_success "配置检查完成"
    echo "  服务器IP: $SERVER_IP"
    echo "  访问地址: $ACCESS_URL"
    echo "  SSL策略: $([ "$USE_DOMAIN_SSL" = "true" ] && echo "域名SSL" || echo "自签名SSL")"
    echo "  前端端口: $FRONTEND_PORT"
    echo "  后端端口: $BACKEND_PORT"
    echo "  HTTP端口: $NGINX_HTTP_PORT"
    echo "  HTTPS端口: $NGINX_HTTPS_PORT"
}

# 检查系统依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        echo "安装命令: curl -fsSL https://get.docker.com | sh"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    log_success "系统依赖检查完成"
}

# 备份原始配置文件
backup_configs() {
    log_info "备份原始配置文件..."
    
    BACKUP_DIR="./config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # 备份前端配置
    cp "../frontend/src/config/api.ts" "$BACKUP_DIR/" 2>/dev/null || true
    cp "../frontend/src/config/environment.ts" "$BACKUP_DIR/" 2>/dev/null || true
    cp "../frontend/nginx.conf" "$BACKUP_DIR/" 2>/dev/null || true
    cp "../frontend/docker-compose.yml" "$BACKUP_DIR/" 2>/dev/null || true
    
    # 备份nginx配置
    cp "../nginx/default.conf" "$BACKUP_DIR/" 2>/dev/null || true
    
    log_success "配置文件已备份到: $BACKUP_DIR"
}

# 配置SSL证书
setup_ssl_certificates() {
    if [ "$ENABLE_SSL" != "true" ]; then
        log_info "SSL已禁用，跳过证书配置"
        return
    fi
    
    log_info "配置SSL证书..."
    
    # 创建SSL目录
    SSL_DIR="../ssl"
    mkdir -p "$SSL_DIR"
    
    if [ "$USE_DOMAIN_SSL" = "true" ]; then
        setup_domain_ssl
    else
        setup_selfsigned_ssl
    fi
}

# 配置域名SSL证书 (Let's Encrypt)
setup_domain_ssl() {
    log_info "配置域名SSL证书 (Let's Encrypt)..."
    
    # 安装certbot
    if ! command -v certbot &> /dev/null; then
        log_info "安装Certbot..."
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y certbot python3-certbot-nginx
        elif command -v yum &> /dev/null; then
            sudo yum install -y certbot python3-certbot-nginx
        else
            log_error "无法自动安装Certbot，请手动安装"
            exit 1
        fi
    fi
    
    # 先创建基本nginx配置用于验证域名
    create_basic_nginx_config
    
    # 启动临时nginx用于域名验证
    log_info "启动临时nginx进行域名验证..."
    cd "../"
    docker run -d --name temp-nginx -p 80:80 -v $(pwd)/nginx/default.conf:/etc/nginx/conf.d/default.conf nginx:alpine
    
    # 申请SSL证书
    log_info "申请SSL证书..."
    sudo certbot certonly --standalone -d "$DOMAIN_NAME" --email admin@"$DOMAIN_NAME" --agree-tos --non-interactive
    
    # 复制证书到项目目录
    sudo cp "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" "../ssl/server.crt"
    sudo cp "/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem" "../ssl/server.key"
    sudo chown $(whoami):$(whoami) ../ssl/server.*
    
    # 停止临时nginx
    docker stop temp-nginx && docker rm temp-nginx
    
    cd "scripts"
    log_success "域名SSL证书配置完成"
}

# 配置自签名SSL证书
setup_selfsigned_ssl() {
    log_info "配置自签名SSL证书..."
    
    cd "$SSL_DIR"
    
    # 生成私钥
    openssl genrsa -out server.key 2048
    
    # 创建证书配置
    cat > server.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=CN
ST=Beijing
L=Beijing
O=MyCompany
OU=IT Department
CN=$SERVER_IP

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = $SERVER_IP
EOF
    
    # 生成证书
    openssl req -new -key server.key -out server.csr -config server.conf
    openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt -extensions v3_req -extfile server.conf
    
    cd "../scripts"
    log_success "自签名SSL证书配置完成"
    log_warning "浏览器会显示安全警告，点击'继续访问'即可"
}

# 创建基本nginx配置用于域名验证
create_basic_nginx_config() {
    cat > "../nginx/default.conf" << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    location /.well-known/acme-challenge/ {
        root /usr/share/nginx/html;
    }
    
    location / {
        return 200 'Preparing SSL...';
        add_header Content-Type text/plain;
    }
}
EOF
}

# 替换配置文件中的变量
replace_config_variables() {
    log_info "替换配置文件中的变量..."
    
    # 构建目标URL
    if [ "$ENABLE_SSL" = "true" ]; then
        TARGET_URL="https://$ACCESS_URL"
    else
        TARGET_URL="http://$ACCESS_URL"
    fi
    
    # 替换前端API配置
    log_info "更新前端API配置..."
    sed -i.bak "s|http://Server_IP|$TARGET_URL|g" "../frontend/src/config/api.ts"
    sed -i.bak "s|http://Server_IP|$TARGET_URL|g" "../frontend/src/config/environment.ts"
    sed -i.bak "s|Server_IP|$ACCESS_URL|g" "../frontend/nginx.conf"
    
    # 替换Docker Compose配置
    log_info "更新Docker Compose配置..."
    sed -i.bak "s|Server_IP|$ACCESS_URL|g" "../frontend/docker-compose.yml"
    
    log_success "配置变量替换完成"
}

# 构建后端Docker镜像
build_backend() {
    log_info "构建后端Docker镜像..."
    
    cd "../backend"
    
    # 创建后端Dockerfile（如果不存在）
    if [ ! -f "Dockerfile" ]; then
        log_info "创建后端Dockerfile..."
        cat > Dockerfile << 'EOF'
# 多阶段构建后端
FROM ubuntu:22.04 as builder

# 设置时区和语言环境
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 配置apt使用国内镜像源
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.aliyun.com@g' /etc/apt/sources.list && \
    sed -i 's@//.*security.ubuntu.com@//mirrors.aliyun.com@g' /etc/apt/sources.list

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    pkg-config \
    libcurl4-openssl-dev \
    libjsoncpp-dev \
    && rm -rf /var/lib/apt/lists/*

# 配置git使用国内镜像
RUN git config --global url."https://gitee.com/mirrors/vcpkg.git".insteadOf "https://github.com/Microsoft/vcpkg.git" || \
    git config --global url."https://hub.fastgit.xyz/Microsoft/vcpkg.git".insteadOf "https://github.com/Microsoft/vcpkg.git"

# 安装vcpkg (使用国内镜像)
WORKDIR /vcpkg
RUN git clone https://gitee.com/mirrors/vcpkg.git . 2>/dev/null || \
    git clone https://hub.fastgit.xyz/Microsoft/vcpkg.git . 2>/dev/null || \
    git clone https://github.com/Microsoft/vcpkg.git . && \
    ./bootstrap-vcpkg.sh

# 安装C++依赖 (如果vcpkg安装失败，使用系统包)
RUN ./vcpkg install cpp-httplib nlohmann-json 2>/dev/null || \
    (echo "vcpkg安装失败，使用系统包..." && \
     apt-get update && \
     apt-get install -y nlohmann-json3-dev && \
     rm -rf /var/lib/apt/lists/*)

# 复制源代码
WORKDIR /app
COPY . .

# 创建简化的CMakeLists.txt (如果vcpkg失败则使用系统库)
RUN if [ ! -d "/vcpkg/installed" ]; then \
        echo "使用系统库构建..." && \
        cat > CMakeLists.txt << 'CMAKEEOF'
cmake_minimum_required(VERSION 3.16)
project(backend)

set(CMAKE_CXX_STANDARD 17)

# 查找系统库
find_package(PkgConfig REQUIRED)
pkg_check_modules(JSONCPP jsoncpp)

# 包含目录
include_directories(include)

# 源文件
file(GLOB_RECURSE SOURCES "src/*.cpp")

# 创建可执行文件
add_executable(backend ${SOURCES})

# 链接库
target_link_libraries(backend ${JSONCPP_LIBRARIES} pthread)

# 设置输出目录
set_target_properties(backend PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)
CMAKEEOF
    fi

# 构建项目
RUN mkdir -p build && cd build && \
    (cmake .. -DCMAKE_TOOLCHAIN_FILE=/vcpkg/scripts/buildsystems/vcpkg.cmake 2>/dev/null || cmake ..) && \
    make -j$(nproc)

# 生产阶段
FROM ubuntu:22.04

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libjsoncpp25 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 复制构建产物
COPY --from=builder /app/build/bin/backend /usr/local/bin/

# 设置工作目录
WORKDIR /app

# 暴露端口
EXPOSE 8080

# 启动命令
CMD ["backend"]
EOF
    fi
    
    # 构建镜像
    docker build -t web-backend:latest .
    
    cd "../scripts"
    log_success "后端Docker镜像构建完成"
}

# 创建最终的nginx配置
create_nginx_config() {
    log_info "创建nginx配置..."
    
    if [ "$ENABLE_SSL" = "true" ]; then
        create_nginx_ssl_config
    else
        create_nginx_http_config
    fi
}

# 创建HTTP nginx配置
create_nginx_http_config() {
    cat > "../nginx/default.conf" << EOF
server {
    listen 80;
    server_name _;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # API代理到后端
    location /api/ {
        proxy_pass http://$SERVER_IP:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;

        # CORS配置
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;

        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }

    # 前端代理
    location / {
        proxy_pass http://$SERVER_IP:$FRONTEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # 健康检查
    location /health {
        proxy_pass http://$SERVER_IP:$BACKEND_PORT/health;
        access_log off;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
}
EOF
}

# 创建HTTPS nginx配置
create_nginx_ssl_config() {
    cat > "../nginx/default.conf" << EOF
# HTTP重定向到HTTPS
server {
    listen 80;
    server_name _;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS服务器
server {
    listen 443 ssl http2;
    server_name _;

    # SSL证书配置
    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # API代理到后端
    location /api/ {
        proxy_pass http://$SERVER_IP:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;

        # CORS配置
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;

        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*';
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }

    # 前端代理
    location / {
        proxy_pass http://$SERVER_IP:$FRONTEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # 健康检查
    location /health {
        proxy_pass http://$SERVER_IP:$BACKEND_PORT/health;
        access_log off;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
}
EOF
}

# 创建Docker Compose文件
create_docker_compose() {
    log_info "创建完整的Docker Compose配置..."
    
    cd ".."
    
    if [ "$ENABLE_SSL" = "true" ]; then
        # SSL版本的Docker Compose
        cat > docker-compose.yml << EOF
version: '3.8'

services:
  # 后端服务
  backend:
    image: web-backend:latest
    container_name: web-backend
    ports:
      - "$BACKEND_PORT:8080"
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    networks:
      - web-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # 前端服务
  frontend:
    build:
      context: .
      dockerfile: frontend/Dockerfile
    container_name: web-frontend
    ports:
      - "$FRONTEND_PORT:80"
    environment:
      - NODE_ENV=production
      - VITE_API_BASE_URL=$TARGET_URL
    restart: unless-stopped
    networks:
      - web-network
    depends_on:
      - backend

  # Nginx HTTPS反向代理
  nginx:
    image: nginx:alpine
    container_name: web-nginx
    ports:
      - "$NGINX_HTTP_PORT:80"
      - "$NGINX_HTTPS_PORT:443"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./ssl:/etc/nginx/ssl
    restart: unless-stopped
    networks:
      - web-network
    depends_on:
      - frontend
      - backend

networks:
  web-network:
    driver: bridge

volumes:
  backend-data:
EOF
    else
        # HTTP版本的Docker Compose
        cat > docker-compose.yml << EOF
version: '3.8'

services:
  # 后端服务
  backend:
    image: web-backend:latest
    container_name: web-backend
    ports:
      - "$BACKEND_PORT:8080"
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    networks:
      - web-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # 前端服务
  frontend:
    build:
      context: .
      dockerfile: frontend/Dockerfile
    container_name: web-frontend
    ports:
      - "$FRONTEND_PORT:80"
    environment:
      - NODE_ENV=production
      - VITE_API_BASE_URL=$TARGET_URL
    restart: unless-stopped
    networks:
      - web-network
    depends_on:
      - backend

  # Nginx HTTP反向代理
  nginx:
    image: nginx:alpine
    container_name: web-nginx
    ports:
      - "$NGINX_HTTP_PORT:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
    restart: unless-stopped
    networks:
      - web-network
    depends_on:
      - frontend
      - backend

networks:
  web-network:
    driver: bridge

volumes:
  backend-data:
EOF
    fi
    
    cd "scripts"
    log_success "Docker Compose配置创建完成"
}

# 部署服务
deploy_services() {
    log_info "部署Docker服务..."
    
    cd ".."
    
    # 停止现有服务
    log_info "停止现有服务..."
    docker-compose down 2>/dev/null || true
    
    # 启动服务
    log_info "启动新服务..."
    docker-compose up -d --build
    
    cd "scripts"
    log_success "服务部署完成"
}

# 等待服务启动
wait_for_services() {
    log_info "等待服务启动..."
    
    sleep 10
    
    # 检查后端服务
    if curl -s "http://localhost:$BACKEND_PORT/health" >/dev/null 2>&1; then
        log_success "后端服务启动成功"
    else
        log_warning "后端服务可能还在启动中..."
    fi
    
    # 检查前端服务
    if curl -s "http://localhost:$FRONTEND_PORT" >/dev/null 2>&1; then
        log_success "前端服务启动成功"
    else
        log_warning "前端服务可能还在启动中..."
    fi
    
    # 检查nginx服务
    if [ "$ENABLE_SSL" = "true" ]; then
        if curl -k -s "https://localhost:$NGINX_HTTPS_PORT" >/dev/null 2>&1; then
            log_success "Nginx HTTPS服务启动成功"
        else
            log_warning "Nginx HTTPS服务可能还在启动中..."
        fi
    else
        if curl -s "http://localhost:$NGINX_HTTP_PORT" >/dev/null 2>&1; then
            log_success "Nginx HTTP服务启动成功"
        else
            log_warning "Nginx HTTP服务可能还在启动中..."
        fi
    fi
}

# 显示部署结果
show_deployment_info() {
    echo ""
    echo "🎉 部署完成！"
    echo "================================"
    
    if [ "$ENABLE_SSL" = "true" ]; then
        echo "🌐 网站地址 (HTTPS):"
        echo "   主站: https://$ACCESS_URL"
        echo "   前端: http://$ACCESS_URL:$FRONTEND_PORT"
        echo "   后端: http://$ACCESS_URL:$BACKEND_PORT"
        echo ""
        echo "📡 API测试:"
        echo "   健康检查: https://$ACCESS_URL/health"
        echo "   用户API: https://$ACCESS_URL/api/users"
        echo ""
        if [ "$USE_DOMAIN_SSL" = "false" ]; then
            echo "⚠️  SSL提醒:"
            echo "   使用自签名证书，浏览器会显示安全警告"
            echo "   请点击'高级设置' → '继续访问'"
        fi
    else
        echo "🌐 网站地址 (HTTP):"
        echo "   主站: http://$ACCESS_URL"
        echo "   前端: http://$ACCESS_URL:$FRONTEND_PORT"
        echo "   后端: http://$ACCESS_URL:$BACKEND_PORT"
        echo ""
        echo "📡 API测试:"
        echo "   健康检查: http://$ACCESS_URL/health"
        echo "   用户API: http://$ACCESS_URL/api/users"
    fi
    
    echo ""
    echo "🐳 Docker管理:"
    echo "   查看容器: docker ps"
    echo "   查看日志: docker-compose logs -f"
    echo "   停止服务: docker-compose down"
    echo "   重启服务: docker-compose restart"
    echo ""
    echo "📁 配置备份:"
    find . -name "config_backup_*" -type d 2>/dev/null | head -1
    echo ""
    
    if [ "$ENABLE_SSL" = "true" ] && [ "$USE_DOMAIN_SSL" = "true" ]; then
        echo "🔄 SSL证书续期:"
        echo "   手动续期: sudo certbot renew"
        echo "   自动续期: 已配置crontab定时任务"
        echo ""
    fi
}

# 主函数
main() {
    echo "🚀 开始Web项目服务器部署..."
    echo "================================"
    
    check_config
    check_dependencies
    backup_configs
    setup_ssl_certificates
    replace_config_variables
    build_backend
    create_nginx_config
    create_docker_compose
    deploy_services
    wait_for_services
    show_deployment_info
}

# 脚本入口
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi 