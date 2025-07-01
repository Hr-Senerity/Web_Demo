# 🚀 Web项目服务器部署指南 (Docker版本 + 智能SSL)

## 📋 概述

本指南将帮助您通过Docker容器化方式，将前后端分离的Web项目部署到服务器上，**智能SSL功能**：
- **有域名**：自动配置Let's Encrypt正式SSL证书
- **无域名**：自动配置自签名SSL证书

## 🏗️ 架构说明

```
互联网用户 → 域名(your-domain.com) → 服务器(公网IP) → Docker容器
                                                    ├── Nginx反向代理 (80端口)
                                                    ├── 前端容器 (3000端口)
                                                    └── 后端容器 (8080端口)
```

## 📦 部署组件

- **前端**: React + TypeScript + Vite (容器化)
- **后端**: C++ + httplib (容器化)
- **反向代理**: Nginx (容器化)
- **容器编排**: Docker Compose

## 🔧 使用前准备

### 1. 服务器要求
- ✅ Ubuntu 18.04+ 或 CentOS 7+
- ✅ 2GB+ 内存
- ✅ 10GB+ 存储空间
- ✅ 公网IP地址
- ✅ 开放端口: 80, 443, 3000, 8080

### 2. 域名配置 (可选)
- 购买域名 (如: your-domain.com)
- 配置A记录指向服务器公网IP
- 等待DNS解析生效 (通常5-30分钟)

### 3. 安装Docker环境

```bash
# 安装Docker
curl -fsSL https://get.docker.com | sh

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 安装Docker Compose (如果需要)
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

## 🚀 部署步骤

### 步骤1: 上传项目代码

```bash
# 方式1: 使用Git (推荐)
git clone your-project-repo
cd Web_Demo

# 方式2: 使用scp上传
scp -r ./Web_Demo user@server_ip:/home/user/
```

### 步骤2: 配置部署参数

编辑 `scripts/all-server.sh` 文件，修改配置变量：

```bash
# 必须配置
SERVER_IP="123.45.67.89"        # 您的服务器公网IP
DOMAIN_NAME="your-domain.com"   # 您的域名 (可选，不填则使用IP+自签名SSL)

# 可选配置 (通常保持默认)
FRONTEND_PORT="3000"     # 前端对外端口
BACKEND_PORT="8080"      # 后端对外端口
NGINX_HTTP_PORT="80"     # nginx HTTP端口
NGINX_HTTPS_PORT="443"   # nginx HTTPS端口
ENABLE_SSL="true"        # 是否启用SSL (true/false)
```

### 步骤3: 执行一键部署

```bash
# 进入脚本目录
cd scripts

# 给脚本执行权限
chmod +x all-server.sh

# 执行部署
./all-server.sh
```

### 步骤4: 验证部署结果

部署完成后，访问以下地址验证：

```bash
# 主站 (通过nginx代理)
http://your-domain.com

# 前端直接访问
http://your-domain.com:3000

# 后端API测试
http://your-domain.com:8080/health
http://your-domain.com:8080/api/users
```

## 📊 部署脚本功能详解

### 🔍 脚本执行流程

1. **配置检查**: 验证必需的配置参数
2. **依赖检查**: 确保Docker和Docker Compose已安装
3. **配置备份**: 备份原始配置文件
4. **变量替换**: 自动替换配置文件中的变量
5. **构建后端**: 创建并构建后端Docker镜像
6. **容器编排**: 生成Docker Compose配置
7. **服务部署**: 启动所有Docker容器
8. **健康检查**: 验证服务启动状态

### 🛠️ 自动化配置替换

脚本会自动替换以下文件中的变量：

| 文件路径 | 替换内容 |
|---------|----------|
| `frontend/src/config/api.ts` | `Server_IP` → 您的域名/IP |
| `frontend/src/config/environment.ts` | `Server_IP` → 您的域名/IP |
| `frontend/nginx.conf` | `Server_IP` → 您的域名/IP |
| `frontend/docker-compose.yml` | `Server_IP` → 您的域名/IP |
| `nginx/default.conf` | `Server_IP` → 您的域名/IP |

### 🐳 Docker容器说明

| 容器名称 | 镜像 | 端口映射 | 功能 |
|---------|------|---------|------|
| web-nginx | nginx:alpine | 80:80 | 反向代理和负载均衡 |
| web-frontend | 自构建 | 3000:80 | React前端应用 |
| web-backend | 自构建 | 8080:8080 | C++后端API |

## 🔧 常用管理命令

### Docker容器管理

```bash
# 查看容器状态
docker ps

# 查看所有容器 (包括停止的)
docker ps -a

# 查看容器日志
docker-compose logs -f

# 查看特定容器日志
docker logs web-frontend
docker logs web-backend
docker logs web-nginx

# 重启服务
docker-compose restart

# 停止服务
docker-compose down

# 重新构建并启动
docker-compose up -d --build
```

### 服务状态监控

```bash
# 检查端口占用
netstat -tulpn | grep :80
netstat -tulpn | grep :3000
netstat -tulpn | grep :8080

# 测试服务响应
curl http://localhost:80
curl http://localhost:3000
curl http://localhost:8080/health

# 查看资源使用
docker stats
```

## 🔧 故障排查

### 常见问题及解决方案

#### 1. 端口被占用
```bash
# 查看占用进程
sudo lsof -i :80
sudo lsof -i :3000
sudo lsof -i :8080

# 停止占用进程
sudo kill -9 <PID>
```

#### 2. Docker镜像构建失败
```bash
# 清理Docker缓存
docker system prune -a

# 重新构建
docker-compose build --no-cache
```

#### 3. 配置文件错误
```bash
# 恢复备份配置
cd scripts
cp config_backup_*/api.ts ../frontend/src/config/
cp config_backup_*/environment.ts ../frontend/src/config/
```

#### 4. 网络连接问题
```bash
# 检查防火墙
sudo ufw status
sudo firewall-cmd --list-all

# 开放端口
sudo ufw allow 80
sudo ufw allow 3000
sudo ufw allow 8080
```

## 🌐 域名和SSL配置

### 配置HTTPS (可选)

1. **安装Certbot**:
```bash
sudo apt install certbot python3-certbot-nginx
```

2. **获取SSL证书**:
```bash
sudo certbot --nginx -d your-domain.com
```

3. **自动续期**:
```bash
sudo crontab -e
# 添加: 0 12 * * * /usr/bin/certbot renew --quiet
```

## 📈 性能优化建议

### 1. 前端优化
- 启用Gzip压缩
- 配置静态资源缓存
- 使用CDN加速

### 2. 后端优化
- 配置连接池
- 启用API缓存
- 添加监控告警

### 3. 系统优化
- 调整内核参数
- 配置日志轮转
- 定期清理Docker镜像

## 📂 备份和恢复

### 自动备份配置
脚本执行时会自动创建配置备份：
- 备份目录: `scripts/config_backup_YYYYMMDD_HHMMSS/`
- 包含所有修改前的原始配置文件

### 手动备份
```bash
# 备份整个项目
tar -czf web-project-backup-$(date +%Y%m%d).tar.gz /path/to/Web_Demo

# 备份Docker数据
docker run --rm -v web_backend-data:/data -v $(pwd):/backup alpine tar czf /backup/data-backup.tar.gz /data
```

## 📞 技术支持

如果在部署过程中遇到问题：

1. 查看容器日志: `docker-compose logs -f`
2. 检查系统资源: `htop` 或 `docker stats`
3. 验证网络连接: `ping` 和 `curl` 测试
4. 查看备份配置: `scripts/config_backup_*/`

---

🎉 **部署完成后，您的Web应用将通过域名提供服务，支持高并发访问和容器化管理！** 