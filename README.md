# Web应用项目

基于现代Web技术 + C++后端的前后端分离应用

## 🚀 技术栈

### 前端技术栈
- **React 18** - 现代化UI框架
- **TypeScript** - 类型安全的JavaScript超集
- **Tailwind CSS** - 原子化CSS框架
- **Vite** - 高性能前端构建工具
- **Axios** - HTTP客户端
- **Docker + Nginx** - 容器化部署

### 后端技术栈
- **C++17** - 核心业务逻辑
- **httplib** - 轻量级HTTP服务器库
- **nlohmann/json** - JSON解析库
- **CMake** - 构建系统
- **vcpkg** - C++包管理器

## 📋 环境要求

### 开发环境

#### 1. Node.js环境
```bash
Node.js >= 18.0.0
npm >= 9.0.0
```

#### 2. C++开发环境

**Linux (推荐):**
```bash
sudo apt update
sudo apt install build-essential cmake git curl
sudo apt install pkg-config libssl-dev
```

**Windows:**
```bash
Visual Studio 2019/2022 (含C++工具)
或 MinGW-w64
CMake >= 3.16
```

#### 3. Docker环境 (用于前端部署)
```bash
Docker Desktop >= 4.0
Docker Compose >= 2.0
```

#### 4. vcpkg (C++包管理)
```bash
# Linux
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.sh

# Windows
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat

# 安装C++依赖
./vcpkg install cpp-httplib nlohmann-json
```

## 🏗️ 项目结构

```
App_Demo/
├── frontend/                    # React前端应用
│   ├── src/
│   │   ├── components/         # 可复用组件
│   │   │   ├── AddUserForm.tsx # 添加用户表单
│   │   │   └── UserList.tsx    # 用户列表
│   │   ├── api/                # API调用封装
│   │   │   └── userApi.ts      # 用户API
│   │   ├── config/             # 配置文件
│   │   │   ├── api.ts          # API配置
│   │   │   └── environment.ts  # 环境配置
│   │   ├── App.tsx             # 主应用组件
│   │   └── main.tsx            # 应用入口
│   ├── public/                 # 静态资源
│   ├── Dockerfile              # 前端容器构建
│   ├── docker-compose.yml      # 前端容器编排
│   ├── nginx.conf              # Nginx配置
│   ├── package.json            # 前端依赖
│   ├── vite.config.ts          # Vite配置
│   └── tailwind.config.js      # Tailwind CSS配置
├── backend/                     # C++后端服务
│   ├── src/                    # C++源码
│   │   ├── main.cpp            # 程序入口
│   │   ├── http_server.cpp     # HTTP服务器实现
│   │   └── user_service.cpp    # 用户服务
│   ├── include/                # 头文件
│   │   ├── http_server.h       # HTTP服务器头文件
│   │   └── user_service.h      # 用户服务头文件
│   ├── CMakeLists.txt          # CMake构建配置
│   └── vcpkg.json              # C++依赖配置
├── shared/                      # 前后端共享类型
│   └── types.ts                # 共享接口定义
├── scripts/                     # 部署脚本
│   ├── deploy-frontend.sh      # 前端部署脚本
│   └── deploy-simple.sh        # 后端部署脚本
├── nginx/                       # Nginx反向代理配置
│   └── default.conf            # 默认配置
├── frontend_setup.md            # 前端部署说明
├── backend-deployment.md        # 后端部署说明
└── README.md                   # 项目说明文档
```

## 🚀 快速开始

> [!TIP]
> **部署前须知**：在开始部署前，请先搜索全文中的 `Server_IP` 变量，并替换为你的实际服务器IP地址。

### 本地开发

#### 1. 克隆并安装依赖
```bash
# 安装前端依赖
cd frontend
npm install
```

#### 2. 开发模式运行

**启动前端开发服务器:**
```bash
cd frontend
npm run dev
# 前端开发服务器运行在 http://localhost:5173
```

**编译C++后端:**
```bash
cd backend
mkdir build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=[vcpkg路径]/scripts/buildsystems/vcpkg.cmake
cmake --build .

# 启动后端服务
./bin/backend
# 后端API服务运行在 http://localhost:8080
```

### 生产部署

#### 🐳 前端Docker部署
```bash
# 使用自动化部署脚本
chmod +x scripts/deploy-frontend.sh
./scripts/deploy-frontend.sh

# 或手动部署
cd frontend
docker-compose build
docker-compose up -d

# 详细部署说明请参考 frontend_setup.md
```

#### 🖥️ 后端Linux部署
```bash
# 使用一键部署脚本（Linux系统）
chmod +x scripts/deploy-simple.sh
./scripts/deploy-simple.sh

# 详细部署说明请参考 backend-deployment.md
```

### 构建发布版本
```bash
# 构建前端
cd frontend
npm run build

# 构建C++后端
cd ../backend/build
cmake --build . --config Release
```

## 📁 开发指南

### 前端开发
```typescript
// 示例：创建React组件
import { useState, useEffect } from 'react';
import type { User } from '../shared/types';

const UserList: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  
  useEffect(() => {
    // API调用示例
    fetchUsers().then(setUsers);
  }, []);
  
  return (
    <div className="p-4">
      {users.map(user => (
        <div key={user.id} className="bg-white p-4 rounded shadow mb-2">
          <h3 className="font-bold">{user.name}</h3>
          <p className="text-gray-600">{user.email}</p>
        </div>
      ))}
    </div>
  );
};
```

### C++后端开发
```cpp
// 示例：创建HTTP API端点
#include <httplib.h>
#include <nlohmann/json.hpp>

int main() {
    httplib::Server server;
    
    server.Get("/api/users", [](const httplib::Request&, httplib::Response& res) {
        nlohmann::json users = nlohmann::json::array({
            {{"id", 1}, {"name", "张三"}, {"email", "zhang@example.com"}},
            {{"id", 2}, {"name", "李四"}, {"email", "li@example.com"}}
        });
        
        res.set_content(users.dump(), "application/json");
        res.set_header("Access-Control-Allow-Origin", "*");
    });
    
    server.listen("localhost", 8080);
    return 0;
}
```

## 🔧 常用命令

```bash
# 前端相关
npm run dev          # 启动前端开发服务器
npm run build        # 构建前端生产版本
npm run preview      # 预览生产版本

# 后端相关
cmake --build .                    # 编译C++代码
cmake --build . --config Release   # 编译发布版本

# Docker相关
docker-compose build    # 构建前端镜像
docker-compose up -d    # 启动前端容器
docker-compose down     # 停止前端容器
```

## 📊 架构概览

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │    │   Nginx Proxy   │    │   C++ Backend   │
│                 │    │                 │    │                 │
│ React Frontend  ├────┤ Port 80/3000    ├────┤ Port 8080       │
│                 │    │                 │    │                 │
│ TypeScript/Vite │    │ Static + API    │    │ HTTP Server     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🌐 API接口

### 用户管理
- **GET** `/api/users` - 获取用户列表
- **POST** `/api/users` - 创建新用户
- **PUT** `/api/users/:id` - 更新用户信息
- **DELETE** `/api/users/:id` - 删除用户

### 健康检查
- **GET** `/health` - 服务健康状态

## 📖 详细文档

### 前端相关
- **前端部署说明**: [frontend_setup.md](./frontend_setup.md)
- **前端部署脚本**: [scripts/deploy-frontend.sh](./scripts/deploy-frontend.sh)

### 后端相关
- **后端部署说明**: [backend-deployment.md](./backend-deployment.md)
- **后端部署脚本**: [scripts/deploy-simple.sh](./scripts/deploy-simple.sh)

## 🔍 故障排查

### 前端问题
```bash
# 查看前端容器日志
docker-compose logs frontend

# 检查前端容器状态
docker-compose ps

# 重新构建前端
docker-compose down && docker-compose build && docker-compose up -d
```

### 后端问题
```bash
# 查看后端日志
tail -f backend/backend.log

# 检查后端进程
ps -p $(cat backend/backend.pid)

# 重启后端服务
kill $(cat backend/backend.pid)
cd backend/build && nohup ./bin/backend > ../backend.log 2>&1 &
```

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📜 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情 