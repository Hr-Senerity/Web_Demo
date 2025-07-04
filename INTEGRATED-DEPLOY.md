# ☁️ 一体化云端部署指南

本指南适用于将前后端一起部署到云服务器的生产环境场景，提供完整的HTTPS服务。

## 📋 部署概述

**一体化云端部署模式：**
- 🌐 **前端**: Docker容器化，Nginx静态文件服务
- ⚙️ **后端**: Docker容器化，C++应用服务
- 🔄 **代理**: Nginx反向代理，统一入口
- 🔒 **安全**: 自动HTTPS配置，SSL证书

## 🎯 适用场景

- ✅ 生产环境部署
- ✅ 完整服务部署
- ✅ HTTPS安全要求
- ✅ 一键部署需求
- ✅ 容器化管理

## 📋 前置条件

### 云服务器要求
- **操作系统**: Ubuntu 18.04+ / CentOS 7+
- **CPU**: 2核心+ (推荐)
- **内存**: 2GB+ (推荐4GB)
- **磁盘**: 10GB+ 可用空间
- **网络**: 公网IP + 端口80/443开放

### 域名配置 (可选)
- **域名**: 已解析到服务器IP (用于Let's Encrypt证书)
- **DNS**: A记录指向服务器公网IP

## 🚀 一键部署

### 快速部署命令

```bash
# 1. 连接云服务器
ssh root@your-server-ip

# 2. 克隆项目 (或上传代码)
git clone <your-repository-url>
cd Web_Demo

# 3. 一键部署
./scripts/docker-deploy.sh
```

### 部署过程详解

#### 第一步：环境检查与配置

脚本会自动检查并安装：
- Docker和Docker Compose
- 配置Docker镜像加速
- 检查系统资源

#### 第二步：部署模式选择

```bash
🛠️  请选择部署模式:
1) HTTP访问 (开发测试)
2) HTTPS + 自签名证书 (生产环境/IP访问)
3) HTTPS + Let's Encrypt (生产环境/域名访问)
4) 手动配置 (跳过自动配置)

请选择 (1-4):
```

**选择建议：**
- **选项1**: 快速测试，不推荐生产环境
- **选项2**: IP访问，浏览器会显示安全警告但可继续
- **选项3**: 域名访问，完全可信的SSL证书
- **选项4**: 高级用户手动配置

#### 第三步：自动构建部署

脚本会自动：
1. 配置前端API为nginx代理模式
2. 多阶段Docker构建（前端+后端）
3. 启动容器服务
4. 配置SSL证书（如选择HTTPS）
5. 健康检查和验证

## 📋 部署模式详解

### 🌐 HTTP模式部署

**适用场景**: 开发测试、内网部署

```bash
# 选择选项1
请选择 (1-4): 1
✅ 配置为HTTP模式

# 部署完成后访问
🌐 访问地址: http://your-server-ip
📡 API地址: http://your-server-ip/api/users
🏥 健康检查: http://your-server-ip/health
```

### 🔒 HTTPS + 自签名证书模式

**适用场景**: IP访问的生产环境

```bash
# 选择选项2
请选择 (1-4): 2
请输入服务器IP地址: 115.29.168.115
✅ 配置为HTTPS+自签名证书模式

# 部署完成后访问
🔒 访问地址: https://115.29.168.115
📡 API地址: https://115.29.168.115/api/users
🏥 健康检查: https://115.29.168.115/health

⚠️  注意: 使用自签名证书，浏览器会显示安全警告
   点击"高级">"继续访问"即可
```

### 🏆 HTTPS + Let's Encrypt模式

**适用场景**: 域名访问的生产环境（推荐）

```bash
# 选择选项3
请选择 (1-4): 3
请输入域名: yourdomain.com
✅ 配置为HTTPS+Let's Encrypt模式
💡 请确保域名已正确解析到此服务器

# 部署完成后访问
🔒 访问地址: https://yourdomain.com
📡 API地址: https://yourdomain.com/api/users
🏥 健康检查: https://yourdomain.com/health
```

## 🔧 部署后管理

### 服务状态检查

```bash
# 进入项目目录
cd Web_Demo/docker_all

# 查看容器状态
docker-compose ps

# 查看服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f frontend
docker-compose logs -f backend
```

### 服务管理命令

```bash
# 在 Web_Demo/docker_all 目录执行

# 重启服务
docker-compose restart

# 停止服务
docker-compose down

# 重新构建并启动
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# 更新代码后重新部署
git pull
docker-compose up -d --build
```

### 系统资源监控

```bash
# 查看Docker资源使用
docker stats

# 查看磁盘使用
df -h
docker system df

# 查看内存使用
free -h

# 查看CPU使用
top
htop  # 如果已安装
```

## 🔍 故障排查

### 常见问题解决

#### 1. 容器启动失败

**问题**: 容器无法启动
```bash
# 查看详细错误日志
docker-compose logs

# 检查端口占用
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# 清理并重试
docker-compose down
docker system prune -f
docker-compose up -d
```

#### 2. SSL证书问题

**问题**: HTTPS访问失败

**自签名证书问题**:
```bash
# 重新生成自签名证书
cd docker_all
docker-compose exec frontend openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/cert.key \
  -out /etc/nginx/ssl/cert.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=your-server-ip"

docker-compose restart frontend
```

**Let's Encrypt证书问题**:
```bash
# 检查域名解析
nslookup yourdomain.com

# 手动获取证书
sudo apt install certbot
sudo certbot certonly --standalone -d yourdomain.com

# 复制证书到项目目录
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ../ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ../ssl/

docker-compose restart
```

#### 3. API连接问题

**问题**: 前端无法连接后端API

```bash
# 检查后端容器状态
docker-compose ps | grep backend

# 测试后端API
curl http://localhost:8080/api/users

# 检查nginx代理配置
docker-compose exec frontend nginx -t

# 重启服务
docker-compose restart
```

#### 4. 内存不足

**问题**: 服务因内存不足崩溃

```bash
# 查看内存使用
free -h
docker stats

# 清理Docker缓存
docker system prune -f
docker image prune -f

# 重启服务
docker-compose restart
```

### 日志分析

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定时间段的日志
docker-compose logs --since="2024-01-01T00:00:00"

# 查看最近的错误日志
docker-compose logs --tail=50 | grep -i error

# 导出日志到文件
docker-compose logs > deployment.log
```

## 📈 性能优化

### Docker优化

```bash
# 清理未使用的资源
docker system prune -f

# 优化镜像大小
# 在Dockerfile中已实现多阶段构建

# 限制容器资源使用
# 编辑 docker-compose.yml 添加资源限制
nano docker-compose.yml
```

### Nginx优化

```bash
# 进入前端容器
docker-compose exec frontend bash

# 查看nginx配置
cat /etc/nginx/nginx.conf

# 优化已在模板中配置：
# - Gzip压缩
# - 静态资源缓存
# - 安全头设置
```

### 系统优化

```bash
# 增加文件描述符限制
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# 优化系统内核参数
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p
```

## 🔒 安全配置

### 防火墙配置

```bash
# 安装并配置ufw
sudo apt install ufw

# 配置基础规则
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status verbose
```

### SSL证书自动续期

```bash
# 对于Let's Encrypt证书，设置自动续期
sudo crontab -e

# 添加以下行（每月1号凌晨2点检查续期）
0 2 1 * * /usr/bin/certbot renew --quiet && systemctl reload nginx
```

### 安全头设置

nginx配置中已包含安全头设置：
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`

## 📊 监控和维护

### 健康检查

```bash
# 应用健康检查
curl -f https://your-domain.com/health

# 容器健康检查
docker-compose ps

# 自动健康检查已配置在docker-compose.yml中
```

### 备份策略

```bash
# 备份容器数据
docker run --rm -v web-demo_data:/data -v $(pwd):/backup ubuntu tar czf /backup/backup.tar.gz /data

# 备份配置文件
tar -czf config-backup.tar.gz docker_all/ scripts/

# 定期备份脚本
cat > backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf "backup_${DATE}.tar.gz" docker_all/ backend/ frontend/ shared/
EOF

chmod +x backup.sh
```

### 更新部署

```bash
# 更新代码
git pull

# 重新构建和部署
cd docker_all
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# 验证更新
curl -f https://your-domain.com/health
```

## 📋 部署检查清单

### ✅ 服务器准备

- [ ] 云服务器已创建并可SSH连接
- [ ] 系统资源满足最低要求 (2GB内存, 10GB磁盘)
- [ ] 防火墙端口80和443已开放
- [ ] 域名已解析到服务器IP (如使用Let's Encrypt)

### ✅ 部署执行

- [ ] 项目代码已上传到服务器
- [ ] `docker-deploy.sh` 脚本执行成功
- [ ] Docker容器正常启动
- [ ] SSL证书配置成功 (如选择HTTPS)

### ✅ 功能验证

- [ ] 网站首页可正常访问
- [ ] API接口响应正常
- [ ] 前端功能完整 (用户增删改查)
- [ ] HTTPS证书有效 (如配置)
- [ ] 健康检查端点正常

### ✅ 安全检查

- [ ] 防火墙规则配置正确
- [ ] SSL证书有效期检查
- [ ] 安全头设置验证
- [ ] 敏感信息无暴露

---

**🎉 恭喜！** 您已成功部署一个完整的生产级Web应用到云服务器。

**📞 需要支持？** 请参考故障排查章节或查看项目README.md。

**🔄 定期维护**: 建议定期更新系统、检查证书有效期、清理Docker缓存。 