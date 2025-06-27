# 多阶段构建
# 阶段1：构建阶段
FROM node:18-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制frontend的package文件
COPY frontend/package*.json ./

# 安装所有依赖（包括devDependencies，因为构建需要）
RUN npm install

# 复制frontend源代码（不包括node_modules）
COPY frontend/src ./src/
COPY frontend/public ./public/
COPY frontend/index.html ./
COPY frontend/vite.config.ts ./
COPY frontend/tsconfig.json ./
COPY frontend/tsconfig.node.json ./
COPY frontend/tailwind.config.js ./
COPY frontend/postcss.config.js ./
COPY frontend/nginx.conf ./

# 复制shared目录到正确的位置
COPY shared/ ../shared/

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