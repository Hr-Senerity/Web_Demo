#!/bin/bash
set -e

echo "🐧 Linux系统 - C++后端一键部署"
echo "支持: Ubuntu, Debian, CentOS, RHEL, Fedora, Arch, Manjaro"

# ==========================================
# Linux 系统专用后端部署脚本
# ==========================================

# 自动修复Windows行结束符问题
fix_line_endings() {
    local file="$1"
    if [ -f "$file" ] && grep -q $'\r' "$file" 2>/dev/null; then
        echo "🔧 修复Windows行结束符: $file"
        cp "$file" "$file.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        sed -i 's/\r$//' "$file"
        echo "   ✅ $file 行结束符已修复"
    else
        echo "   ✅ $file 格式正常"
    fi
    return 0
}

# 检测Linux发行版
detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        DISTRO="centos"
        VERSION=$(grep -o '[0-9]\+' /etc/redhat-release | head -1)
    else
        DISTRO="unknown"
        VERSION="unknown"
    fi
    
    echo "🐧 检测到Linux发行版: $DISTRO $VERSION"
    
    # 确保变量被设置
    if [ -z "$DISTRO" ]; then
        echo "❌ 未能检测到Linux发行版"
        exit 1
    fi
}

# 设置包管理器
setup_package_manager() {
    echo "   检测发行版: $DISTRO"
    
    case $DISTRO in
        ubuntu|debian)
            PKG_UPDATE="apt-get update"
            PKG_INSTALL="apt-get install -y"
            CMAKE_PKG="cmake"
            BUILD_PKG="build-essential"
            GIT_PKG="git"
            CURL_PKG="curl"
            PKGCONFIG_PKG="pkg-config"
            JSON_PKG="nlohmann-json3-dev"
            NGINX_PKG="nginx"
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                PKG_UPDATE="dnf update -y"
                PKG_INSTALL="dnf install -y"
            else
                PKG_UPDATE="yum update -y"
                PKG_INSTALL="yum install -y"
            fi
            CMAKE_PKG="cmake"
            BUILD_PKG="gcc-c++ make"
            GIT_PKG="git"
            CURL_PKG="curl"
            PKGCONFIG_PKG="pkgconfig"
            JSON_PKG="nlohmann-json-devel"
            NGINX_PKG="nginx"
            ;;
        arch|manjaro)
            PKG_UPDATE="pacman -Sy"
            PKG_INSTALL="pacman -S --noconfirm"
            CMAKE_PKG="cmake"
            BUILD_PKG="base-devel"
            GIT_PKG="git"
            CURL_PKG="curl"
            PKGCONFIG_PKG="pkgconf"
            JSON_PKG="nlohmann-json"
            NGINX_PKG="nginx"
            ;;
        *)
            echo "❌ 不支持的Linux发行版: $DISTRO"
            echo "💡 支持的发行版: Ubuntu, Debian, CentOS, RHEL, Fedora, Arch, Manjaro"
            exit 1
            ;;
    esac
    
    echo "📦 使用包管理器: ${PKG_INSTALL%% *}"
}

# 初始化环境
echo "🔍 初始化Linux环境..."

# 修复可能的行结束符问题
echo "📝 检查脚本格式..."
fix_line_endings "$0" || true
for file in .env env-template; do
    [ -f "$file" ] && fix_line_endings "$file" || true
done

# 检测系统
echo "🕵️  检测Linux发行版..."
detect_linux_distro

echo "⚙️  配置包管理器..."
setup_package_manager

# 系统检查
echo "🔍 Linux环境检查..."

# 检查sudo权限
if ! sudo -n true 2>/dev/null; then
    echo "⚠️  需要sudo权限安装系统包，如提示请输入密码"
fi

# 检查网络连接
if ! curl -s --connect-timeout 5 http://www.baidu.com >/dev/null 2>&1; then
    echo "⚠️  网络连接较慢，安装可能需要更长时间"
fi

echo "✅ Linux环境检查完成"

# 检查并安装Linux系统依赖
echo "📋 检查Linux系统依赖..."

# 更新包管理器
echo "🔄 更新包管理器..."
sudo $PKG_UPDATE >/dev/null 2>&1 || true

# 安装函数
install_if_missing() {
    local cmd="$1"
    local package="$2"
    local display_name="$3"
    
    if ! command -v "$cmd" &> /dev/null; then
        echo "📦 安装 $display_name..."
        sudo $PKG_INSTALL $package
    else
        echo "✅ $display_name 已安装"
    fi
}

# 安装必要的系统依赖
install_if_missing "cmake" "$CMAKE_PKG" "CMake"
install_if_missing "make" "$BUILD_PKG" "构建工具"
install_if_missing "git" "$GIT_PKG" "Git"
install_if_missing "curl" "$CURL_PKG" "Curl"
install_if_missing "pkg-config" "$PKGCONFIG_PKG" "pkg-config"

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

# 安装nlohmann-json
if ! pkg-config --exists nlohmann_json 2>/dev/null; then
    echo "📦 安装nlohmann-json JSON库..."
    sudo $PKG_INSTALL $JSON_PKG
    
    # 验证安装（某些发行版包名可能不同）
    if ! pkg-config --exists nlohmann_json 2>/dev/null; then
        echo "⚠️  pkg-config未检测到nlohmann-json，检查系统头文件..."
        # 检查常见的头文件位置
        if [ -f "/usr/include/nlohmann/json.hpp" ] || [ -f "/usr/local/include/nlohmann/json.hpp" ]; then
            echo "✅ 在系统路径找到nlohmann-json头文件"
        else
            echo "❌ 未找到nlohmann-json，请手动安装"
            exit 1
        fi
    fi
else
    echo "✅ nlohmann-json已安装"
fi

# 检查cpp-httplib (header-only) - 现在使用项目本地文件
# 自动检测脚本运行路径
if [ -f "../backend/include/httplib.h" ]; then
    # 从scripts目录运行
    HTTPLIB_PATH="../backend/include/httplib.h"
    echo "✅ cpp-httplib (使用项目本地文件: backend/include/httplib.h)"
elif [ -f "./backend/include/httplib.h" ]; then
    # 从项目根目录运行
    HTTPLIB_PATH="./backend/include/httplib.h" 
    echo "✅ cpp-httplib (使用项目本地文件: backend/include/httplib.h)"
else
    echo "❌ 未找到cpp-httplib header文件"
    echo "💡 当前目录: $(pwd)"
    echo "💡 查找路径: ../backend/include/httplib.h 和 ./backend/include/httplib.h"
    
    # 尝试自动下载到合适的位置
    if [ -d "./backend/include" ]; then
        DOWNLOAD_PATH="./backend/include/httplib.h"
    elif [ -d "../backend/include" ]; then
        DOWNLOAD_PATH="../backend/include/httplib.h"
    else
        echo "❌ 未找到backend/include目录"
        exit 1
    fi
    
    echo "🔄 尝试自动下载 httplib.h 到 $DOWNLOAD_PATH..."
    if curl -L -o "$DOWNLOAD_PATH" "https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.18.7/httplib.h" 2>/dev/null; then
        echo "✅ httplib.h 下载成功"
    else
        echo "❌ 自动下载失败，请手动下载:"
        echo "   curl -L -o $DOWNLOAD_PATH https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.18.7/httplib.h"
        exit 1
    fi
fi

echo "✅ C++依赖库安装完成"

# 编译后端
echo "🔧 编译后端..."
# 根据检测到的路径进入后端目录
if [ -d "../backend" ]; then
    cd ../backend
elif [ -d "./backend" ]; then
    cd ./backend
else
    echo "❌ 未找到backend目录"
    exit 1
fi

# 清理旧构建
rm -rf build
mkdir build && cd build

# 配置CMake - 不再需要vcpkg工具链
echo "配置CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release

# 编译
echo "编译中..."
# Linux系统获取CPU核心数
CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "2")
echo "使用 $CORES 个核心并行编译..."
make -j$CORES

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

# 返回项目根目录
if [ "$(basename $(pwd))" = "build" ]; then
    cd ../..  # 从 backend/build 返回项目根目录
else
    cd ..     # 从 backend 返回项目根目录  
fi

# 配置Nginx反向代理
echo "🌐 配置Nginx反向代理..."

# 安装nginx
if ! command -v nginx &> /dev/null; then
    echo "📦 安装Nginx..."
    sudo $PKG_INSTALL $NGINX_PKG
    sudo systemctl enable nginx
else
    echo "✅ Nginx已安装"
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
echo "🧪 测试Nginx配置..."
if sudo nginx -t; then
    echo "✅ Nginx配置语法正确"
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    echo "✅ Nginx服务已重启并设置开机自启"
else
    echo "❌ Nginx配置有误，请检查"
    exit 1
fi

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
echo ""
echo "🐧 Linux系统说明:"
echo "   后端已在Linux服务器部署完成"
echo "   前端可在任意环境连接此后端API"
echo "   支持的前端环境: Linux桌面、Windows、macOS"
echo "   推荐使用HTTPS连接保证安全性"
echo "================================" 