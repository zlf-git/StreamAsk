import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'

function AdminPage({ user, onLogout }) {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [editingUser, setEditingUser] = useState(null)
  const [selectedTables, setSelectedTables] = useState([])
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const navigate = useNavigate()

  // 检查是否是管理员
  useEffect(() => {
    if (!user?.is_admin) {
      navigate('/')
    }
  }, [user, navigate])

  // 可分配的表列表（可以根据实际情况配置）
  const availableTables = ['ads_trade_overview_di', 'ads_channel_conversion_di', 'ads_region_gmv_di', 'ads_product_sales_rank_di', 'ads_user_growth_di']

  useEffect(() => {
    if (user?.is_admin) {
      fetchUsers()
    }
  }, [user])

  // 刷新用户信息（当在管理页面修改了自己的权限时调用）
  const refreshUserInfo = async () => {
    try {
      const response = await fetch('/api/check-auth', {
        credentials: 'include'
      })
      if (response.ok) {
        const data = await response.json()
        if (data.user) {
          // 触发父组件更新用户信息
          window.dispatchEvent(new CustomEvent('user-updated', { detail: data.user }))
        }
      }
    } catch (err) {
      console.error('Failed to refresh user info:', err)
    }
  }

  const fetchUsers = async () => {
    try {
      const response = await fetch('/api/admin/users', {
        credentials: 'include'
      })
      const data = await response.json()
      if (data.success) {
        setUsers(data.users)
      } else {
        setError(data.error || '获取用户列表失败')
      }
    } catch (err) {
      setError('网络错误')
    } finally {
      setLoading(false)
    }
  }

  const handleEdit = (user) => {
    setEditingUser(user.username)
    setSelectedTables(user.allowed_tables || [])
    setError('')
    setSuccess('')
  }

  const handleCancel = () => {
    setEditingUser(null)
    setSelectedTables([])
    setError('')
    setSuccess('')
  }

  const handleSave = async (username) => {
    try {
      const response = await fetch(`/api/admin/users/${username}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ allowed_tables: selectedTables })
      })
      const data = await response.json()
      if (data.success) {
        setSuccess('权限更新成功')
        setEditingUser(null)
        fetchUsers()
        // 如果更新的是当前用户，刷新用户信息
        if (data.updated_session) {
          await refreshUserInfo()
        }
      } else {
        setError(data.error || '更新失败')
      }
    } catch (err) {
      setError('网络错误')
    }
  }

  const handleDelete = async (username) => {
    if (!confirm(`确定要删除用户 "${username}" 吗？`)) {
      return
    }

    try {
      const response = await fetch(`/api/admin/users/${username}`, {
        method: 'DELETE',
        credentials: 'include'
      })
      const data = await response.json()
      if (data.success) {
        setSuccess('用户删除成功')
        fetchUsers()
      } else {
        setError(data.error || '删除失败')
      }
    } catch (err) {
      setError('网络错误')
    }
  }

  const toggleTable = (table) => {
    setSelectedTables(prev =>
      prev.includes(table)
        ? prev.filter(t => t !== table)
        : [...prev, table]
    )
  }

  if (loading) {
    return (
      <div className="admin-loading">
        <div className="loading-spinner"></div>
        <p>加载中...</p>
      </div>
    )
  }

  return (
    <div className="admin-container">
      <header className="admin-header">
        <div className="header-left">
          <div className="logo">
            <svg viewBox="0 0 24 24" fill="none">
              <path d="M12 2L2 7L12 12L22 7L12 2Z" fill="white"/>
              <path d="M2 17L12 22L22 17" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              <path d="M2 12L12 17L22 12" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
          <h1>用户权限管理</h1>
        </div>
        <div className="header-right">
          <button onClick={() => window.location.href = '/'} className="nav-button">返回聊天</button>
          <button onClick={onLogout} className="logout-button">登出</button>
        </div>
      </header>

      <main className="admin-main">
        <div className="admin-card">
          <div className="card-header">
            <h2>用户列表</h2>
            <span className="user-count">{users.length} 个用户</span>
          </div>

          {error && <div className="alert error">{error}</div>}
          {success && <div className="alert success">{success}</div>}

          <div className="users-table">
            <div className="table-header">
              <div className="col-username">用户名</div>
              <div className="col-tables">可访问表</div>
              <div className="col-actions">操作</div>
            </div>

            <div className="table-body">
              {users.map(u => (
                <div key={u.id} className="table-row">
                  <div className="col-username">
                    <span className="username">{u.username}</span>
                    {user.username === u.username && <span className="self-badge">当前</span>}
                  </div>

                  <div className="col-tables">
                    {editingUser === u.username ? (
                      <div className="tables-edit">
                        <div className="tables-checkboxes">
                          {availableTables.map(table => (
                            <label key={table} className="checkbox-label">
                              <input
                                type="checkbox"
                                checked={selectedTables.includes(table)}
                                onChange={() => toggleTable(table)}
                              />
                              <span>{table}</span>
                            </label>
                          ))}
                        </div>
                        <div className="edit-actions">
                          <button onClick={() => handleSave(u.username)} className="btn-save">保存</button>
                          <button onClick={handleCancel} className="btn-cancel">取消</button>
                        </div>
                      </div>
                    ) : (
                      <div className="tables-display">
                        {u.allowed_tables && u.allowed_tables.length > 0 ? (
                          u.allowed_tables.map(table => (
                            <span key={table} className="table-tag">{table}</span>
                          ))
                        ) : (
                          <span className="no-tables">暂无权限</span>
                        )}
                      </div>
                    )}
                  </div>

                  <div className="col-actions">
                    {editingUser !== u.username && (
                      <>
                        <button onClick={() => handleEdit(u)} className="btn-edit">编辑</button>
                        {user.username !== u.username && (
                          <button onClick={() => handleDelete(u.username)} className="btn-delete">删除</button>
                        )}
                      </>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}

export default AdminPage
