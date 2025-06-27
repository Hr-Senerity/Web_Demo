// 共享的数据类型定义

export interface User {
  id: number;
  name: string;
  email: string;
  createdAt: string;
  updatedAt: string;
}

export interface ApiResponse<T> {
  success: boolean;
  data: T;
  message?: string;
  error?: string;
}

export interface CreateUserRequest {
  name: string;
  email: string;
}

export interface UpdateUserRequest {
  name?: string;
  email?: string;
}

// 应用状态类型
export interface AppState {
  users: User[];
  loading: boolean;
  error: string | null;
}

// API端点类型
export type ApiEndpoints = {
  '/api/users': {
    GET: ApiResponse<User[]>;
    POST: ApiResponse<User>;
  };
  '/api/users/:id': {
    GET: ApiResponse<User>;
    PUT: ApiResponse<User>;
    DELETE: ApiResponse<void>;
  };
}; 