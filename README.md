# 🚀 Web Demo - 全栈用户管理系统

一个现代化的全栈Web应用，展示前后端分离架构和容器化部署的最佳实践。

## 📋 项目概述

本项目是一个用户管理系统，提供用户增删改查功能，支持多种灵活的部署模式，适合学习现代Web开发和DevOps实践。

### ✨ 主要特性

- 🎯 **现代化技术栈**: React + TypeScript + C++ 后端
- 🐳 **容器化部署**: Docker + Docker Compose
- 🔒 **HTTPS安全**: 自动SSL证书配置
- 🌐 **反向代理**: Nginx负载均衡和静态文件服务
- 📱 **响应式设计**: 移动端友好的用户界面
- 🔄 **前后端分离**: 灵活的部署架构

## 🏗️ 项目架构

```
Web_Demo/
├── 🌐 frontend/          # React + TypeScript 前端
│   ├── src/
│   │   ├── components/   # React组件
│   │   ├── api/         # API调用封装
│   │   └── config/      # 配置文件
│   ├── Dockerfile       # 前端Docker配置
│   └── nginx.conf       # 前端Nginx配置
│
├── ⚙️ backend/           # C++ HTTP服务器后端
│   ├── src/             # C++源代码
│   ├── include/         # 头文件和第三方库
│   └── CMakeLists.txt   # CMake构建配置
│
├── 🐳 docker_all/       # 一体化Docker部署
│   ├── Dockerfile       # 多阶段构建配置
│   ├── docker-compose.yml
│   └── nginx.conf.template
│
├── 📜 scripts/          # 自动化部署脚本
│   ├── deploy-frontend.sh    # 前端分离部署
│   ├── deploy-simple.sh      # 后端独立部署
│   └── docker-deploy.sh      # 一体化部署
│
└── 🔗 shared/          # 前后端共享类型定义
    └── types.ts
```

## 💻 技术栈

### 前端技术
- **React 18** - 现代化UI框架
- **TypeScript** - 类型安全的JavaScript
- **Vite** - 快速构建工具
- **Tailwind CSS** - 原子化CSS框架
- **Axios** - HTTP客户端库

### 后端技术
- **C++20** - 高性能编程语言
- **cpp-httplib** - 轻量级HTTP服务器库
- **nlohmann/json** - JSON解析库
- **CMake** - 跨平台构建系统

### 部署技术
- **Docker** - 容器化平台
- **Docker Compose** - 多容器编排
- **Nginx** - Web服务器和反向代理
- **SSL/TLS** - HTTPS安全连接

## 🚀 快速开始

### 系统要求

- **操作系统**: Linux (Ubuntu 18.04+推荐) / Windows / macOS
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **内存**: 2GB+ 可用
- **磁盘**: 5GB+ 可用空间

### 🎯 选择部署模式

本项目支持两种主要部署模式：

| 部署模式 | 适用场景 | 部署文档 |
|----------|----------|----------|
| **🔗 前后端分离部署** | 开发调试、前端本地后端云端 | [SEPARATE-DEPLOY.md](./SEPARATE-DEPLOY.md) |
| **☁️ 一体化云端部署** | 生产环境、完整HTTPS服务 | [INTEGRATED-DEPLOY.md](./INTEGRATED-DEPLOY.md) |

### ⚡ 一键部署 (推荐)

如果您有云服务器且希望完整部署：

```bash
# 克隆项目
git clone <repository-url>
cd Web_Demo

# 一键部署到云服务器
./scripts/docker-deploy.sh
```

## 📚 详细文档

- **🔗 [前后端分离部署指南](./SEPARATE-DEPLOY.md)** - 前端本地 + 后端云端
- **☁️ [一体化云端部署指南](./INTEGRATED-DEPLOY.md)** - 完整生产环境部署

## 🔧 开发调试

### 本地开发环境

```bash
# 前端开发
cd frontend
npm install
npm run dev          # 开发模式 (http://localhost:5173)
npm run build        # 生产构建
npm run preview      # 预览构建结果

# 后端开发 (Linux环境)
cd backend
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
make
./bin/backend        # 启动后端 (http://localhost:8080)
```

### API接口测试

```bash
# 健康检查
curl http://localhost:8080/health

# 获取用户列表
curl http://localhost:8080/api/users

# 创建用户
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"张三","email":"zhang@example.com","age":25}'
```

## 🔍 故障排查

### 常见问题

1. **混合内容错误** (HTTPS页面请求HTTP API)
   - 解决：使用一体化部署模式，自动配置HTTPS

2. **Docker构建失败**
   - 检查Docker服务是否运行
   - 确保有足够的磁盘空间
   - 尝试清理Docker缓存：`docker system prune -f`

3. **端口冲突**
   - 前端默认端口：3000, 5173
   - 后端默认端口：8080
   - Nginx默认端口：80, 443

4. **API连接失败**
   - 检查后端服务是否运行
   - 确认防火墙设置
   - 验证API地址配置

### 日志查看

```bash
# Docker一体化部署日志
cd docker_all
docker-compose logs -f

# 后端独立部署日志
tail -f backend/backend.log

# 前端容器日志
cd frontend
docker-compose logs -f
```

## 🤝 贡献指南

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [cpp-httplib](https://github.com/yhirose/cpp-httplib) - C++ HTTP库
- [React](https://reactjs.org/) - 前端框架
- [Docker](https://www.docker.com/) - 容器化平台
- [Nginx](https://nginx.org/) - Web服务器

---

**📞 需要帮助？** 请查看详细部署文档或提交Issue。 