# Web Demo - Docker 部署指南

🐳 **一体化Docker部署方案** - 前后端一键部署，支持HTTP/HTTPS，自动SSL配置

## 📋 项目结构

```
Web_Demo/
├── docker_all/
│   ├── Dockerfile              # 多阶段构建文件
│   ├── docker-compose.yml      # 服务编排文件
│   ├── nginx.conf.template     # Nginx配置模板
│   ├── docker-entrypoint.sh    # 容器启动脚本
│   └── env-template            # 环境变量模板
├── scripts/
│   └── docker-deploy.sh        # 一键部署脚本
└── Docker-README.md            # 本文档
```

## 🚀 快速开始

### 1. 一键部署（推荐）

```bash
# 执行部署脚本
chmod +x scripts/docker-deploy.sh
./scripts/docker-deploy.sh
```

脚本会自动：
- 检查Docker环境
- 配置镜像加速（可选）
- 生成环境配置
- 构建和启动服务
- 执行健康检查

### 2. 手动部署

```bash
# 1. 进入docker目录
cd docker_all

# 2. 复制环境配置
cp env-template .env

# 3. 编辑配置（可选）
vi .env

# 4. 启动服务
docker compose up -d --build
```

## ⚙️ 配置选项

### 环境变量配置

编辑 `.env` 文件：

```bash
# 基础配置
NGINX_HOST=localhost          # 主机名或IP
API_BASE_URL=http://localhost # API基础URL
SSL_MODE=none                 # SSL模式
DEBUG=false                   # 调试模式
```

### SSL 模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `none` | 仅HTTP | 开发环境 |
| `custom` | 自签名证书 | 生产环境（仅IP访问） |
| `letsencrypt` | Let's Encrypt证书 | 生产环境（域名访问） |

## 📚 部署示例

### 示例1：开发环境（HTTP）

```bash
NGINX_HOST=localhost
API_BASE_URL=http://localhost
SSL_MODE=none
```

访问地址：`http://localhost`

### 示例2：生产环境（IP + 自签名SSL）

```bash
NGINX_HOST=192.168.1.100
API_BASE_URL=https://192.168.1.100
SSL_MODE=custom
```

访问地址：`https://192.168.1.100` （会显示证书警告）

### 示例3：生产环境（域名 + Let's Encrypt）

```bash
NGINX_HOST=example.com
API_BASE_URL=https://example.com
SSL_MODE=letsencrypt
```

访问地址：`https://example.com`

> 注意：需要预先获取Let's Encrypt证书并放置在 `ssl/` 目录下

## 🔒 SSL 证书管理

### 自签名证书

容器启动时自动生成，无需手动操作。

### Let's Encrypt证书

1. 停止容器（避免端口冲突）：
   ```bash
   docker compose down
   ```

2. 获取证书：
   ```bash
   sudo certbot certonly --standalone -d your-domain.com
   ```

3. 复制证书到项目目录：
   ```bash
   mkdir -p ssl
   sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl/
   sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl/
   sudo chown $USER:$USER ssl/*.pem
   ```

4. 重启容器：
   ```bash
   docker compose up -d
   ```

## 📝 常用命令

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 重新构建并启动
docker compose up -d --build

# 清理系统
docker system prune -f
```

## 🔍 故障排查

### 1. 容器启动失败

```bash
# 查看详细日志
docker compose logs

# 查看具体容器日志
docker logs web-demo
```

### 2. SSL证书问题

```bash
# 检查证书文件
ls -la ssl/

# 验证证书
openssl x509 -in ssl/cert.pem -text -noout
```

### 3. 网络连接问题

```bash
# 检查端口占用
netstat -tlnp | grep -E ":(80|443|8080)"

# 测试API连接
curl -f http://localhost:8080/health
```

## 🏗️ 架构说明

### 多阶段构建

1. **后端构建阶段**：编译C++后端
2. **前端构建阶段**：构建React应用
3. **运行阶段**：Nginx代理 + 后端服务

### 服务架构

```
Internet → Nginx (80/443) → Frontend (静态文件)
                         → Backend (8080) API
```

### 特性

- ✅ 前后端一体化部署
- ✅ 自动SSL证书配置
- ✅ 国内镜像加速支持
- ✅ 智能环境检测
- ✅ 健康检查机制
- ✅ 数据持久化
- ✅ 零停机更新

## 🆘 获取帮助

1. 查看日志：`docker compose logs -f`
2. 健康检查：访问 `/health` 端点
3. 检查配置：`cat .env`
4. 重置环境：删除 `.env` 文件重新运行部署脚本

## 📄 许可证

本项目采用 MIT 许可证。 