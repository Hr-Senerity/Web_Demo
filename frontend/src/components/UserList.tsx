import type { User } from '@shared/types'

interface UserListProps {
  users: User[]
  onDeleteUser: (id: number) => void
}

const UserList: React.FC<UserListProps> = ({ users, onDeleteUser }) => {
  if (users.length === 0) {
    return (
      <div className="text-center py-8 text-gray-500">
        暂无用户数据
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {users.map((user) => (
        <div
          key={user.id}
          className="bg-white p-4 rounded-lg shadow-sm border border-gray-200 hover:shadow-md transition-shadow"
        >
          <div className="flex justify-between items-start">
            <div className="flex-1">
              <h3 className="text-lg font-medium text-gray-900">{user.name}</h3>
              <p className="text-sm text-gray-600 mt-1">{user.email}</p>
              <p className="text-xs text-gray-400 mt-2">
                创建时间: {new Date(user.createdAt).toLocaleDateString('zh-CN')}
              </p>
            </div>
            <button
              onClick={() => onDeleteUser(user.id)}
              className="ml-4 px-3 py-1 text-sm bg-red-500 text-white rounded hover:bg-red-600 transition-colors"
            >
              删除
            </button>
          </div>
        </div>
      ))}
    </div>
  )
}

export default UserList 