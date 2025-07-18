# ====================================
# 多阶段Docker构建 - 前后端一体化部署
# ====================================

# 阶段1: 后端构建
FROM gcc:10-bullseye as backend-builder

WORKDIR /app/backend

# 配置国内软件源加速
RUN sed -i 's@http://deb.debian.org@https://mirrors.aliyun.com@g' /etc/apt/sources.list && \
    sed -i 's@http://security.debian.org@https://mirrors.aliyun.com@g' /etc/apt/sources.list

# 安装系统依赖和C++库
RUN apt-get update && apt-get install -y \
    cmake \
    build-essential \
    pkg-config \
    git \
    curl \
    wget \
    unzip \
    zip \
    tar \
    libssl-dev \
    zlib1g-dev \
    nlohmann-json3-dev \
    && rm -rf /var/lib/apt/lists/*

# cpp-httplib (header-only库) 现在包含在项目源码中
# 文件位置: backend/include/httplib.h (通过COPY命令复制到容器)

# 复制后端源码并构建
COPY backend/ ./
RUN echo "🔧 编译后端..." && \
    rm -rf build && \
    mkdir build && cd build && \
    echo "配置CMake..." && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release && \
    echo "编译中..." && \
    make -j$(nproc) && \
    echo "✅ 编译完成"

# 阶段2: 前端构建  
FROM node:18-alpine as frontend-builder

WORKDIR /app/frontend

# 使用npm官方源
RUN npm config set registry https://registry.npmjs.org

# 复制package文件并安装依赖
COPY frontend/package*.json ./
RUN npm install

# 复制源码和共享类型
COPY frontend/ ./
COPY shared/ ../shared/

# 构建前端
RUN npm run build

# 阶段3: Nginx代理 + 生产环境
FROM nginx:bullseye

# 配置debian国内镜像源加速
RUN sed -i 's@http://deb.debian.org@https://mirrors.aliyun.com@g' /etc/apt/sources.list && \
    sed -i 's@http://security.debian.org@https://mirrors.aliyun.com@g' /etc/apt/sources.list

# 安装必要工具 - 使用镜像源加速和优化选项
RUN apt-get update -o Acquire::Retries=3 && \
    apt-get install -y --no-install-recommends \
    gettext \
    curl \
    openssl \
    bash \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y

# 复制后端可执行文件
COPY --from=backend-builder /app/backend/build/bin/backend /usr/local/bin/

# 复制前端构建产物
COPY --from=frontend-builder /app/frontend/dist /usr/share/nginx/html

# 复制nginx配置模板
COPY docker_all/nginx.conf.template /etc/nginx/templates/default.conf.template

# 复制启动脚本
COPY docker_all/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# 创建SSL证书目录
RUN mkdir -p /etc/nginx/ssl

# 暴露端口
EXPOSE 80 443 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# 启动脚本
ENTRYPOINT ["/docker-entrypoint.sh"] 