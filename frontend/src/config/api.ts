// API配置文件
interface ApiConfig {
  baseURL: string;
  timeout: number;
}

// 环境配置
const config = {
  development: {
    baseURL: 'http://localhost:8080',
    timeout: 10000,
  },
  production: {
    baseURL: 'http://Server_IP', // 修正为正确的服务器地址
    timeout: 15000,
  }
};

// 检测环境 - 修复Tauri环境检测
const getEnvironment = (): 'development' | 'production' => {
  // 在Tauri中直接使用生产环境配置
  if (typeof window !== 'undefined' && (window as any).__TAURI__) {
    return 'production';
  }
  // 浏览器环境中的检测
  const isDev = window.location.protocol === 'http:' && window.location.hostname === 'localhost';
  return isDev ? 'development' : 'production';
};

export const apiConfig: ApiConfig = config[getEnvironment()];

// 导出服务器配置
export const SERVER_CONFIG = {
  // 开发环境 - 本地服务器
  DEV_SERVER: 'http://localhost:8080',
  
  // 生产环境 - 远程服务器
  PROD_SERVER: 'http://Server_IP', // 修正为正确的服务器地址
  
  // 获取当前使用的服务器地址
  getCurrentServer: () => apiConfig.baseURL,
}; 