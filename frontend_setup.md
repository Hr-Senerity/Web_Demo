# 前端Docker部署完整指南

本文档记录了从Docker安装到React前端应用成功部署的完整过程。

## 🛠️ 环境要求

- Windows 10/11 (版本 2004 或更高)
- WSL 2 支持
- 至少 4GB RAM
- 至少 20GB 可用磁盘空间

## 📦 第一步：Docker安装与配置

### 1.1 下载Docker Desktop

1. 访问 [Docker官网](https://www.docker.com/products/docker-desktop)
2. 下载 Docker Desktop for Windows
3. 运行安装程序并按照向导完成安装

### 1.2 启动Docker Desktop

1. 安装完成后启动 Docker Desktop
2. 等待 Docker 引擎启动完成
3. 确认系统托盘中显示 Docker 图标

### 1.3 配置镜像加速器

为了提高镜像下载速度，需要配置国内镜像源：

1. 打开 Docker Desktop
2. 点击右上角的设置图标 (⚙️)
3. 选择 "Docker Engine"
4. 在配置文件中添加以下内容：

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "registry-mirrors": [
    "https://docker.1panel.live",
    "https://hub.rat.dev",
    "https://docker.m.daocloud.io"
  ]
}
```

5. 点击 "Apply & Restart" 重启 Docker

### 1.4 验证Docker安装

在PowerShell中运行以下命令验证：

```powershell
# 检查Docker版本
docker --version

# 运行测试容器
docker run hello-world
```

## 🏗️ 第二步：项目结构准备

确保您的项目具有以下结构：

```
App_Demo/
├── frontend/
│   ├── src/
│   │   ├── api/
│   │   ├── components/
│   │   ├── config/
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── public/
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   └── tailwind.config.js
├── shared/
│   └── types.ts
└── backend/
```

## 🐳 第三步：Docker配置文件

### 3.1 创建 Dockerfile

在 `frontend/` 目录下创建 `Dockerfile`：

```dockerfile
# 多阶段构建
# 阶段1：构建阶段
FROM node:18-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制frontend的package文件
COPY frontend/package*.json ./

# 安装所有依赖（包括devDependencies，因为构建需要）
RUN npm install

# 复制shared目录
COPY shared/ ./shared/

# 复制frontend源代码
COPY frontend/ ./

# 构建应用
RUN npm run build

# 阶段2：生产阶段
FROM nginx:alpine

# 复制构建产物到nginx
COPY --from=builder /app/dist /usr/share/nginx/html

# 复制nginx server配置到sites-available
COPY --from=builder /app/nginx.conf /etc/nginx/conf.d/default.conf

# 暴露端口
EXPOSE 80

# 启动nginx
CMD ["nginx", "-g", "daemon off;"]
```

### 3.2 创建 docker-compose.yml

在 `frontend/` 目录下创建 `docker-compose.yml`：

```yaml
services:
  frontend:
    build:
      context: ..
      dockerfile: frontend/Dockerfile
    ports:
      - "3000:80"
    environment:
      - NODE_ENV=production
      - VITE_API_BASE_URL=http://localhost:8080
    restart: unless-stopped
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

### 3.3 创建 .dockerignore

在 `frontend/` 目录下创建 `.dockerignore`：

```
node_modules
npm-debug.log
Dockerfile
.dockerignore
.git
.gitignore
README.md
.env
.nyc_output
coverage
.tmp
.DS_Store
```

## ⚙️ 第四步：配置文件调整

### 4.1 修改 TypeScript 配置

修改 `frontend/tsconfig.json` 中的路径映射：

```json
{
  "compilerOptions": {
    // ... 其他配置
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@shared/*": ["./shared/*"]
    }
  },
  "include": ["src", "./shared"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

### 4.2 创建 nginx.conf

在 `frontend/` 目录下创建 `nginx.conf`：

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # React路由支持 - SPA路由
    location / {
        try_files $uri $uri/ /index.html;
        
        # 禁用缓存HTML文件
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # API代理到后端服务器 (临时注释掉，避免启动错误)
    # 当您的后端服务器准备好后，取消注释并修改为实际的后端地址
    # location /api/ {
    #     # 替换为您的后端服务器地址，例如: http://192.168.1.100:8080
    #     proxy_pass http://YOUR_BACKEND_SERVER_IP:8080;
    #     
    #     proxy_http_version 1.1;
    #     proxy_set_header Upgrade $http_upgrade;
    #     proxy_set_header Connection 'upgrade';
    #     proxy_set_header Host $host;
    #     proxy_set_header X-Real-IP $remote_addr;
    #     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    #     proxy_set_header X-Forwarded-Proto $scheme;
    #     proxy_cache_bypass $http_upgrade;
    #
    #     # CORS处理
    #     add_header 'Access-Control-Allow-Origin' '*' always;
    #     add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    #     add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
    #
    #     # 处理预检请求
    #     if ($request_method = 'OPTIONS') {
    #         add_header 'Access-Control-Allow-Origin' '*';
    #         add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
    #         add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization';
    #         add_header 'Access-Control-Max-Age' 1728000;
    #         add_header 'Content-Type' 'text/plain; charset=utf-8';
    #         add_header 'Content-Length' 0;
    #         return 204;
    #     }
    # }

    # 健康检查
    location /health {
        return 200 'Frontend is healthy';
        add_header Content-Type text/plain;
    }

    # 压缩配置
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # 错误页面
    error_page 404 /index.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

## 🚀 第五步：构建和部署

### 5.1 进入前端目录

```powershell
cd C:\Users\your-username\Desktop\App_Demo\frontend
```

### 5.2 构建Docker镜像

```powershell
docker-compose build
```

构建过程包括：
- 下载Node.js Alpine镜像
- 安装npm依赖
- 复制shared目录和frontend源码
- 运行TypeScript编译和Vite构建
- 创建Nginx生产镜像
- 复制构建产物到Nginx容器

### 5.3 启动容器

```powershell
docker-compose up -d
```

### 5.4 验证部署

检查容器状态：
```powershell
docker-compose ps
```

预期输出：
```
NAME                  IMAGE               COMMAND                   SERVICE    CREATED          STATUS          PORTS
frontend-frontend-1   frontend-frontend   "/docker-entrypoint.…"   frontend   xx seconds ago   Up xx seconds   0.0.0.0:3000->80/tcp
```

## 🌐 第六步：访问应用

打开浏览器访问：`http://localhost:3000`

您应该能看到React前端应用正常运行。

## 🔧 常见问题与解决方案

### 问题1：npm ci 失败

**错误信息**：`npm ci` command can only install with an existing package-lock.json

**解决方案**：将Dockerfile中的 `npm ci` 改为 `npm install`

### 问题2：找不到@shared模块

**错误信息**：Cannot find module '@shared/types'

**解决方案**：
1. 确保docker-compose.yml中的context设置为 `..`
2. 修改tsconfig.json中的路径映射为 `"@shared/*": ["./shared/*"]`

### 问题3：nginx启动失败

**错误信息**：`"server" directive is not allowed here`

**解决方案**：将nginx配置复制到 `/etc/nginx/conf.d/default.conf` 而不是 `/etc/nginx/nginx.conf`

### 问题4：后端API代理错误

**错误信息**：`host not found in upstream "YOUR_BACKEND_SERVER_IP"`

**解决方案**：暂时注释掉nginx.conf中的API代理部分，等后端部署完成后再配置

## 🛠️ 管理命令

### 查看容器日志
```powershell
docker-compose logs frontend
```

### 停止容器
```powershell
docker-compose down
```

### 重新构建并启动
```powershell
docker-compose down && docker-compose build && docker-compose up -d
```

### 进入容器调试
```powershell
docker-compose exec frontend sh
```

### 查看镜像大小
```powershell
docker images
```

## 📊 部署架构

```
┌─────────────────┐    ┌─────────────────┐
│   Browser       │    │   Docker Host   │
│                 │    │                 │
│ localhost:3000  ├────┤ Container:80    │
└─────────────────┘    │                 │
                       │ ┌─────────────┐ │
                       │ │   Nginx     │ │
                       │ │   Serving   │ │
                       │ │ React SPA   │ │
                       │ └─────────────┘ │
                       └─────────────────┘
```

## ✅ 成功指标

部署成功的标志：
- [x] Docker容器状态为 "Up"
- [x] 浏览器能正常访问 `http://localhost:3000`
- [x] React应用界面正常显示
- [x] 健康检查端点 `http://localhost:3000/health` 返回正常

## 🔮 后续步骤

1. **后端部署** - 将C++后端部署到服务器
2. **API连接** - 配置nginx反向代理到后端
3. **生产部署** - 将镜像推送到生产环境
4. **监控配置** - 添加日志和监控

---

**完成时间**：约15-30分钟（取决于网络速度）  
**资源占用**：镜像大小约 50MB，运行时内存约 20MB 