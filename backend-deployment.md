# 后端部署说明

C++后端服务一键部署指南

## 🛠️ 环境要求

### 系统要求
- Linux 系统 (Ubuntu 18.04+ 推荐)
- 至少 2GB RAM
- 至少 10GB 可用磁盘空间

### 必需软件
- CMake >= 3.16
- GCC/G++ 编译器
- Git
- Curl
- Make

## 📦 自动安装依赖

部署脚本会自动检查和安装以下依赖：

### 系统包
```bash
# 自动安装的系统依赖
sudo apt update
sudo apt install -y cmake build-essential git curl make
```

### C++包管理器 (vcpkg)
```bash
# 克隆vcpkg
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.sh

# 安装C++依赖包
./vcpkg install cpp-httplib nlohmann-json
```

## 🚀 部署步骤

### 1. 系统依赖检查
脚本会自动检查并安装必要的系统依赖：
- **CMake** - 构建系统
- **Build Essential** - 编译工具链
- **Git** - 版本控制
- **Curl** - HTTP客户端工具

### 2. vcpkg包管理器配置
- 克隆Microsoft vcpkg仓库
- 运行bootstrap脚本初始化
- 安装C++依赖包：
  - `cpp-httplib` - HTTP服务器库
  - `nlohmann-json` - JSON解析库

### 3. 后端编译
```bash
cd backend
rm -rf build         # 清理旧构建
mkdir build && cd build

# 配置CMake（使用vcpkg工具链）
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=../../scripts/vcpkg/scripts/buildsystems/vcpkg.cmake \
    -DCMAKE_BUILD_TYPE=Release

# 编译
make -j$(nproc)
```

### 4. 服务启动
- 停止现有服务（如果存在）
- 后台启动新服务
- 记录进程ID到 `backend.pid` 文件
- 输出日志到 `backend.log` 文件

服务启动命令：
```bash
nohup ./bin/backend > ../backend.log 2>&1 &
```

### 5. Nginx反向代理配置
- 自动安装Nginx
- 备份原有配置
- 配置API反向代理
- 启用CORS支持
- 设置健康检查端点

### 6. 服务测试
- 测试后端直接连接 (`http://localhost:8080/api/users`)
- 测试Nginx代理 (`http://localhost/api/users`)
- 验证健康检查 (`http://localhost/health`)

## 📊 服务信息

### 端口配置
- **后端服务**: 8080
- **Nginx代理**: 80 (HTTP)

### 文件位置
- **可执行文件**: `backend/build/bin/backend`
- **进程ID文件**: `backend/backend.pid`
- **日志文件**: `backend/backend.log`
- **Nginx配置**: `/etc/nginx/sites-available/default`

### API端点
- **用户列表**: `GET /api/users`
- **健康检查**: `GET /health`

## 🔧 服务管理

### 查看服务状态
```bash
# 查看进程状态
ps -p $(cat backend/backend.pid)

# 查看日志
tail -f backend/backend.log

# 检查Nginx状态
sudo systemctl status nginx
```

### 停止服务
```bash
# 停止后端服务
kill $(cat backend/backend.pid)

# 停止Nginx
sudo systemctl stop nginx
```

### 重启服务
```bash
# 重启后端
cd backend/build
nohup ./bin/backend > ../backend.log 2>&1 &
echo $! > ../backend.pid
disown $!

# 重启Nginx
sudo systemctl restart nginx
```

## 🌐 网络配置

### API代理配置
Nginx配置包含以下API代理规则：
```nginx
location /api/ {
    proxy_pass http://localhost:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    
    # CORS配置
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
}
```

### 健康检查
```nginx
location /health {
    proxy_pass http://localhost:8080;
}
```

## 🧪 部署验证

### 自动测试
部署脚本会自动执行以下测试：
1. **直接连接测试**: `curl http://localhost:8080/api/users`
2. **代理测试**: `curl http://localhost/api/users`
3. **健康检查**: `curl http://localhost/health`

### 手动验证
```bash
# 检查服务响应
curl -i http://localhost/api/users

# 检查健康状态
curl http://localhost/health

# 查看服务器信息
curl http://localhost/
```

## 🔍 故障排查

### 常见问题

#### 1. 编译失败
```bash
# 检查CMake配置
cd backend/build
cmake .. -DCMAKE_TOOLCHAIN_FILE=../../scripts/vcpkg/scripts/buildsystems/vcpkg.cmake

# 查看详细编译信息
make VERBOSE=1
```

#### 2. 服务启动失败
```bash
# 查看日志
tail -n 50 backend/backend.log

# 检查端口占用
netstat -tulpn | grep 8080

# 手动启动测试
cd backend/build
./bin/backend
```

#### 3. Nginx代理失败
```bash
# 测试Nginx配置
sudo nginx -t

# 查看Nginx日志
sudo tail -f /var/log/nginx/error.log

# 重载配置
sudo systemctl reload nginx
```

#### 4. 权限问题
```bash
# 设置可执行权限
chmod +x backend/build/bin/backend

# 检查文件所有者
ls -la backend/build/bin/backend
```

## 🎯 性能优化

### 编译优化
- 使用 Release 模式编译
- 启用多核并行编译 (`make -j$(nproc)`)

### 服务优化
- 使用 nohup 实现后台运行
- 进程与终端会话分离 (`disown`)

### Nginx优化
- 启用GZIP压缩
- 配置静态资源缓存
- 优化代理缓冲

## 📈 监控建议

### 日志监控
```bash
# 实时查看应用日志
tail -f backend/backend.log

# 监控Nginx访问日志
sudo tail -f /var/log/nginx/access.log
```

### 性能监控
```bash
# 监控资源使用
top -p $(cat backend/backend.pid)

# 监控网络连接
netstat -an | grep :8080
```

## 🔄 更新部署

### 更新代码
```bash
# 拉取最新代码
git pull origin main

# 停止旧服务
kill $(cat backend/backend.pid)

# 重新编译
cd backend/build
make -j$(nproc)

# 启动新服务
nohup ./bin/backend > ../backend.log 2>&1 &
echo $! > ../backend.pid
disown $!
```

### 零停机更新
建议使用负载均衡器实现零停机更新，或者在低峰期进行服务更新。 