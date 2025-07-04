# C++ 依赖库说明

本项目使用系统包管理器安装C++依赖库，替代了之前的vcpkg方案。

## 依赖库列表

### 必需依赖

1. **nlohmann-json** (JSON处理库)
   - 版本要求: >= 3.7.0
   - Ubuntu/Debian安装: `sudo apt install nlohmann-json3-dev`
   - 包名: `nlohmann_json` (pkg-config)

2. **cpp-httplib** (HTTP客户端/服务器库)
   - 版本要求: >= 0.18.0
   - Header-only库，已包含在项目中
   - 文件位置: `backend/include/httplib.h`
   - 无需额外安装

### 系统依赖

- **CMake** >= 3.16
- **GCC** >= 5.4 (推荐 >= 11)
- **pkg-config** (用于查找系统包)
- **libssl-dev** (SSL支持)
- **zlib1g-dev** (压缩支持)

## 安装脚本

### 自动安装 (Ubuntu/Debian)
```bash
# 运行项目提供的脚本
./scripts/deploy-simple.sh
```

### 手动安装
```bash
# 安装系统依赖
sudo apt update && sudo apt install -y \
    cmake \
    build-essential \
    pkg-config \
    nlohmann-json3-dev \
    libssl-dev \
    zlib1g-dev

# cpp-httplib已包含在项目中，无需安装
# 文件位置: backend/include/httplib.h
```

## Docker 支持

Docker环境中会自动安装所有依赖，无需手动配置。

## 与vcpkg的区别

- ✅ 更快的Docker构建速度
- ✅ 更小的镜像体积
- ✅ 更好的缓存支持
- ✅ 减少网络依赖问题
- ✅ 与系统包管理器集成

## 故障排除

### 找不到nlohmann_json
```bash
# 检查安装
pkg-config --exists nlohmann_json && echo "已安装" || echo "未安装"

# 重新安装
sudo apt update && sudo apt install nlohmann-json3-dev
```

### 找不到httplib.h
```bash
# 检查项目文件是否存在
ls -la backend/include/httplib.h

# 如果文件不存在，从官方仓库下载
curl -L -o backend/include/httplib.h \
    https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.18.7/httplib.h
``` 