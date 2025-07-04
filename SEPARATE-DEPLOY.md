# 🔗 前后端分离部署指南

本指南适用于需要将后端部署到云服务器，前端在本地开发或部署的场景。

## 📋 部署概述

**前后端分离部署模式：**
- 🌐 **后端**: 部署到云服务器 (Linux)
- 💻 **前端**: 本地开发环境或独立容器
- 🔗 **连接**: 前端通过HTTPS连接云端后端API

## 🎯 适用场景

- ✅ 前端开发调试
- ✅ 后端API测试
- ✅ 团队协作开发
- ✅ 前端独立部署

## 📋 前置条件

### 云服务器要求
- **操作系统**: Ubuntu 18.04+ / CentOS 7+
- **CPU**: 1核心+
- **内存**: 1GB+
- **磁盘**: 5GB+
- **网络**: 公网IP + 端口80/443开放

### 本地环境要求
- **Node.js**: 16+
- **npm**: 8+
- **Docker**: 20.10+ (可选)

## 🚀 部署步骤

### 第一步：部署后端到云服务器

#### 1.1 连接云服务器

```bash
# SSH连接到云服务器
ssh root@your-server-ip

# 或使用密钥文件
ssh -i your-key.pem ubuntu@your-server-ip
```

#### 1.2 上传项目代码

```bash
# 方法1: 使用git克隆
git clone <your-repository-url>
cd Web_Demo

# 方法2: 使用scp上传本地代码
# (在本地执行)
scp -r ./Web_Demo root@your-server-ip:/root/
```

#### 1.3 一键部署后端

```bash
# 在云服务器执行
cd Web_Demo
./scripts/deploy-simple.sh
```

**脚本执行过程：**
1. 自动安装系统依赖 (CMake, GCC等)
2. 安装C++库 (nlohmann-json, cpp-httplib)
3. 编译后端应用
4. 启动后端服务 (端口8080)
5. 配置Nginx反向代理 (端口80/443)

#### 1.4 验证后端部署

```bash
# 检查后端服务状态
curl http://localhost:8080/api/users

# 检查Nginx代理
curl http://your-server-ip/api/users

# 检查进程状态
ps aux | grep backend
systemctl status nginx
```

**部署成功标志：**
```bash
🎉 后端部署完成！
================================
🔒 HTTPS地址: https://your-server-ip (推荐)
🌐 HTTP地址: http://your-server-ip (备用)
🔍 健康检查: https://your-server-ip/health
📡 API地址: https://your-server-ip/api/users
```

### 第二步：配置前端连接后端

回到本地环境，配置前端连接云端后端API。

#### 2.1 方法一：使用部署脚本自动配置

```bash
# 在本地项目根目录执行
./scripts/deploy-frontend.sh

# 选择配置选项
请选择后端API地址配置:
1) 输入服务器IP地址
2) 使用本地后端 (http://localhost:8080)

请选择 (1-2): 1
请输入服务器IP地址 (如 115.29.168.115): your-server-ip
✅ 使用服务器地址: https://your-server-ip
```

**脚本自动处理：**
- 创建环境配置文件
- 替换所有配置文件中的Server_IP占位符
- 构建前端Docker容器
- 启动前端服务 (http://localhost:3000)

#### 2.2 方法二：手动配置环境变量

```bash
cd frontend

# 创建环境配置文件
echo "VITE_API_BASE_URL=https://your-server-ip" > .env.local

# 开发模式
npm install
npm run dev     # http://localhost:5173

# 或生产模式
npm run build
npm run preview # http://localhost:4173
```

#### 2.3 方法三：直接构建部署

```bash
cd frontend

# 使用环境变量构建
VITE_API_BASE_URL=https://your-server-ip npm run build

# 启动预览服务
npm run preview
```

### 第三步：验证前后端连接

#### 3.1 检查API连接

访问前端应用，测试功能：
- **前端地址**: http://localhost:3000 (或5173/4173)
- **功能测试**: 添加用户、查看用户列表、编辑删除用户

#### 3.2 网络调试

如果遇到连接问题：

```bash
# 测试API可达性
curl https://your-server-ip/api/users

# 检查防火墙
# 在云服务器执行
sudo ufw status
sudo ufw allow 80
sudo ufw allow 443

# 检查SSL证书 (如果使用HTTPS)
openssl s_client -connect your-server-ip:443 -servername your-server-ip
```

## 🔧 管理操作

### 后端服务管理

```bash
# 在云服务器执行

# 查看服务状态
ps aux | grep backend
cat backend/backend.pid

# 查看日志
tail -f backend/backend.log

# 重启服务
kill $(cat backend/backend.pid)
cd backend/build && nohup ./bin/backend > ../backend.log 2>&1 &
echo $! > ../backend.pid && disown $!

# Nginx管理
sudo systemctl status nginx
sudo systemctl restart nginx
sudo nginx -t  # 测试配置
```

### 前端服务管理

```bash
# 在本地执行

# 容器模式管理
cd frontend
docker-compose ps
docker-compose logs -f
docker-compose restart

# 开发模式管理
npm run dev     # 开发服务器
npm run build   # 重新构建
npm run preview # 预览服务器
```

## 🔍 故障排查

### 常见问题

#### 1. API连接失败

**问题**: 前端无法连接后端API
```
Network Error: Failed to fetch
```

**解决方案**:
```bash
# 检查后端服务状态
curl https://your-server-ip/api/users

# 检查防火墙设置
sudo ufw allow 80
sudo ufw allow 443

# 检查API地址配置
cat frontend/.env.local
```

#### 2. CORS跨域错误

**问题**: 浏览器控制台显示CORS错误

**解决方案**: 后端已配置CORS，检查Nginx配置：
```bash
sudo nginx -t
sudo systemctl reload nginx
```

#### 3. SSL证书问题

**问题**: HTTPS连接失败

**解决方案**:
```bash
# 检查证书配置
openssl s_client -connect your-server-ip:443

# 临时使用HTTP (开发环境)
echo "VITE_API_BASE_URL=http://your-server-ip" > frontend/.env.local
```

#### 4. 端口冲突

**问题**: 前端端口被占用

**解决方案**:
```bash
# 查找占用端口的进程
lsof -i :3000
lsof -i :5173

# 停止冲突的服务
kill -9 <PID>

# 或指定其他端口
npm run dev -- --port 3001
```

### 日志检查

```bash
# 后端日志 (云服务器)
tail -f backend/backend.log

# Nginx日志 (云服务器)
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# 前端日志 (本地)
# 开发模式直接显示在终端
# 容器模式
docker-compose logs -f
```

## 📈 性能优化

### 后端优化

```bash
# 启用Nginx gzip压缩已配置
# 可根据需要调整worker进程数
sudo nano /etc/nginx/nginx.conf
sudo systemctl reload nginx
```

### 前端优化

```bash
# 生产构建优化
npm run build

# 分析构建包大小
npm install -g webpack-bundle-analyzer
npx webpack-bundle-analyzer frontend/dist
```

## 🔒 安全配置

### SSL/HTTPS配置

```bash
# 在云服务器配置Let's Encrypt证书
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com

# 或使用自签名证书 (测试环境)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/selfsigned.key \
  -out /etc/ssl/certs/selfsigned.crt
```

### 防火墙配置

```bash
# 配置基础防火墙
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw status
```

## 📋 部署检查清单

### ✅ 后端部署检查

- [ ] 云服务器可正常SSH连接
- [ ] 项目代码已上传到服务器
- [ ] `deploy-simple.sh` 执行成功
- [ ] 后端服务正常运行 (端口8080)
- [ ] Nginx代理配置正确 (端口80/443)
- [ ] API接口可正常访问
- [ ] 防火墙端口已开放

### ✅ 前端配置检查

- [ ] 本地Node.js环境正常
- [ ] API地址配置正确
- [ ] 前端应用可正常启动
- [ ] 可成功连接后端API
- [ ] 用户界面功能正常

### ✅ 连接测试检查

- [ ] 前端可获取用户列表
- [ ] 可成功创建新用户
- [ ] 可正常编辑用户信息
- [ ] 可正常删除用户
- [ ] 网络请求无CORS错误

---

**🎉 部署完成！** 您现在拥有一个云端后端 + 本地前端的灵活开发环境。

**📞 需要帮助？** 请参考故障排查部分或查看项目README.md。 