import axios from 'axios'
import type { User, ApiResponse, CreateUserRequest } from '@shared/types'
import { API_CONFIG } from '../config/environment'

// 创建axios实例 - 调试信息
console.log('API配置:', API_CONFIG)
console.log('当前连接地址:', API_CONFIG.baseURL)

const apiClient = axios.create({
  baseURL: API_CONFIG.baseURL,
  timeout: API_CONFIG.timeout,
  headers: {
    'Content-Type': 'application/json',
  },
})

// 响应拦截器
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error('API Error:', error)
    throw new Error(error.response?.data?.message || '网络请求失败')
  }
)

export const userApi = {
  // 获取所有用户
  async getUsers(): Promise<User[]> {
    const response = await apiClient.get<ApiResponse<User[]>>('/api/users')
    return response.data.data
  },

  // 根据ID获取用户
  async getUser(id: number): Promise<User> {
    const response = await apiClient.get<ApiResponse<User>>(`/api/users/${id}`)
    return response.data.data
  },

  // 创建新用户
  async createUser(userData: CreateUserRequest): Promise<User> {
    const response = await apiClient.post<ApiResponse<User>>('/api/users', userData)
    return response.data.data
  },

  // 更新用户
  async updateUser(id: number, userData: Partial<CreateUserRequest>): Promise<User> {
    const response = await apiClient.put<ApiResponse<User>>(`/api/users/${id}`, userData)
    return response.data.data
  },

  // 删除用户
  async deleteUser(id: number): Promise<void> {
    await apiClient.delete(`/api/users/${id}`)
  },
} 