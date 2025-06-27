import { useState, useEffect } from 'react'
import type { User } from '@shared/types'
import UserList from './components/UserList'
import AddUserForm from './components/AddUserForm'
import { userApi } from './api/userApi'

function App() {
  const [users, setUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    loadUsers()
  }, [])

  const loadUsers = async () => {
    try {
      setLoading(true)
      setError(null)
      const userData = await userApi.getUsers()
      setUsers(userData)
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载用户失败')
    } finally {
      setLoading(false)
    }
  }

  const handleAddUser = async (name: string, email: string) => {
    try {
      const newUser = await userApi.createUser({ name, email })
      setUsers(prev => [...prev, newUser])
    } catch (err) {
      setError(err instanceof Error ? err.message : '添加用户失败')
    }
  }

  const handleDeleteUser = async (id: number) => {
    try {
      await userApi.deleteUser(id)
      setUsers(prev => prev.filter(user => user.id !== id))
    } catch (err) {
      setError(err instanceof Error ? err.message : '删除用户失败')
    }
  }

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-4xl mx-auto px-4">
        <h1 className="text-3xl font-bold text-gray-900 mb-8 text-center">
          用户管理系统
        </h1>
        
        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
            错误: {error}
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <div>
            <h2 className="text-xl font-semibold text-gray-800 mb-4">添加新用户</h2>
            <AddUserForm onAddUser={handleAddUser} />
          </div>
          
          <div>
            <h2 className="text-xl font-semibold text-gray-800 mb-4">用户列表</h2>
            {loading ? (
              <div className="text-center py-8">
                <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                <p className="mt-2 text-gray-600">加载中...</p>
              </div>
            ) : (
              <UserList users={users} onDeleteUser={handleDeleteUser} />
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

export default App 