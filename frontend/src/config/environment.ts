// 环境配置
export const config = {
  // 开发环境配置 - Web版本通过nginx代理访问API
  development: {
    apiBaseURL: '', // 使用相对路径，让nginx代理处理API请求
    timeout: 10000,
  },
  
  // 生产环境配置
  production: {
    // 支持构建时环境变量覆盖API地址
    // VITE_API_BASE_URL: 构建时指定API地址（用于前后端分离部署）
    // 未指定时使用相对路径（用于一体化部署）
    apiBaseURL: import.meta.env.VITE_API_BASE_URL || '',
    timeout: 15000,
  }
} as const;

// 环境检测 - 修复Tauri应用检测逻辑
// 在Tauri应用中，使用__TAURI__全局变量来检测是否在Tauri环境
// 如果在Tauri环境中，直接使用生产环境配置
export const isTauriApp = typeof (window as any).__TAURI__ !== 'undefined';
export const isDevelopment = !isTauriApp && window.location.protocol === 'http:' && window.location.hostname === 'localhost';
export const isProduction = !isDevelopment;

// 当前环境配置 - Tauri应用始终使用生产环境配置
export const currentConfig = isTauriApp ? config.production : (isDevelopment ? config.development : config.production);

// 导出当前API配置
export const API_CONFIG = {
  baseURL: currentConfig.apiBaseURL,
  timeout: currentConfig.timeout,
};

// 调试信息
console.log('环境检测结果:', {
  isTauriApp,
  isDevelopment,
  isProduction,
  currentConfig: currentConfig,
  windowLocation: window.location.href
});

// 辅助函数
export const getServerURL = () => currentConfig.apiBaseURL;
export const isConnectedToRemoteServer = () => !currentConfig.apiBaseURL.includes('localhost'); 