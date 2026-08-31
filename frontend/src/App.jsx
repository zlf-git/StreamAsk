import React, { useState, useRef, useEffect } from 'react'
import { BrowserRouter, Routes, Route, useNavigate } from 'react-router-dom'
import MarkdownContent from './components/MarkdownContent'
import Typewriter from './components/Typewriter'
import AdminPage from './pages/AdminPage'

function ChatPage({ user, onLogout }) {
  const [messages, setMessages] = useState([])
  const [typingMessageId, setTypingMessageId] = useState(null)
  const [inputValue, setInputValue] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const messagesEndRef = useRef(null)
  const navigate = useNavigate()

  const welcomeMessage = '你好！我是 AI 智能分析助手，有什么可以帮助你的吗？'

  useEffect(() => {
    // 欢迎消息使用打字机效果
    const welcomeMsg = {
      id: 1,
      role: 'assistant',
      content: welcomeMessage
    }
    setMessages([welcomeMsg])
    setTypingMessageId(1)
  }, [])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, typingMessageId])

  const handleSend = async () => {
    if (!inputValue.trim() || isLoading) return

    const userMessage = {
      id: Date.now(),
      role: 'user',
      content: inputValue.trim()
    }

    setMessages(prev => [...prev, userMessage])
    setInputValue('')
    setIsLoading(true)

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ query: userMessage.content })
      })

      const data = await response.json()

      if (data.success) {
        const assistantMessage = {
          id: Date.now() + 1,
          role: 'assistant',
          content: data.answer || '抱歉，我没有收到有效的回复。',
          raw_outputs: data.raw_outputs  // 保留原始输出用于解析图表
        }
        // 先添加消息，但不显示完整内容
        setMessages(prev => [...prev, assistantMessage])
        // 设置当前正在打字的消息ID
        setTypingMessageId(assistantMessage.id)
      } else {
        const errorMessage = {
          id: Date.now() + 1,
          role: 'assistant',
          content: `错误: ${data.error || '未知错误'}`
        }
        setMessages(prev => [...prev, errorMessage])
      }
    } catch (error) {
      const errorMessage = {
        id: Date.now() + 1,
        role: 'assistant',
        content: `网络错误: ${error.message}`
      }
      setMessages(prev => [...prev, errorMessage])
    } finally {
      setIsLoading(false)
    }
  }

  const handleTypingComplete = (messageId) => {
    setTypingMessageId(null)
  }

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  return (
    <div className="app-container">
      <header className="header">
        <div className="header-content">
          <div className="logo">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M12 2L2 7L12 12L22 7L12 2Z" fill="white"/>
              <path d="M2 17L12 22L22 17" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              <path d="M2 12L12 17L22 12" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
          <h1>AI 问数与智能分析</h1>
        </div>
        <div className="user-info">
          <span className="welcome">欢迎</span>
          <span className="username">{user?.username}</span>
          <span className="allowed-tables">{user?.allowed_tables?.length > 0 ? user.allowed_tables.join(', ') : '暂无权限'}</span>
          {user?.is_admin && <button onClick={() => navigate('/admin')} className="admin-button">管理</button>}
          <button onClick={onLogout} className="logout-button">登出</button>
        </div>
      </header>

      <div className="chat-container">
        <div className="messages-list">
          {messages.map((message) => (
            <div key={message.id} className={`message ${message.role}`}>
              <div className="avatar">
                {message.role === 'user' ? '👤' : '🤖'}
              </div>
              <div className="message-content">
                {message.role === 'assistant' ? (
                  typingMessageId === message.id ? (
                    <Typewriter
                      content={message.content}
                      onComplete={() => handleTypingComplete(message.id)}
                      speed={20}
                      renderMarkdown={true}
                      rawOutputs={message.raw_outputs}
                    />
                  ) : (
                    <MarkdownContent content={message.content} rawOutputs={message.raw_outputs} />
                  )
                ) : (
                  message.content
                )}
              </div>
            </div>
          ))}

          {isLoading && !typingMessageId && (
            <div className="message assistant">
              <div className="avatar">🤖</div>
              <div className="loading-indicator">
                <span></span>
                <span></span>
                <span></span>
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        <div className="input-container">
          <input
            type="text"
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="输入你的问题..."
            disabled={isLoading}
          />
          <button onClick={handleSend} disabled={isLoading || !inputValue.trim()}>
            发送
          </button>
        </div>
      </div>
    </div>
  )
}

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [user, setUser] = useState(null)
  const [isRegisterMode, setIsRegisterMode] = useState(false)
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState('')
  const [successMessage, setSuccessMessage] = useState('')

  useEffect(() => {
    checkAuth()

    // 监听用户信息更新事件
    const handleUserUpdate = (event) => {
      setUser(event.detail)
    }
    window.addEventListener('user-updated', handleUserUpdate)

    return () => {
      window.removeEventListener('user-updated', handleUserUpdate)
    }
  }, [])

  const checkAuth = async () => {
    try {
      const response = await fetch('/api/check-auth', {
        credentials: 'include'
      })
      if (response.ok) {
        const data = await response.json()
        setIsAuthenticated(true)
        setUser(data.user)
      }
    } catch (error) {
      console.error('Auth check failed:', error)
    }
  }

  const handleLogin = async (e) => {
    e.preventDefault()
    setError('')

    try {
      const response = await fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ username, password })
      })

      const data = await response.json()

      if (data.success) {
        setIsAuthenticated(true)
        setUser(data.user)
      } else {
        setError(data.error)
      }
    } catch (error) {
      setError('登录失败: ' + error.message)
    }
  }

  const handleRegister = async (e) => {
    e.preventDefault()
    setError('')
    setSuccessMessage('')

    if (password !== confirmPassword) {
      setError('两次输入的密码不一致')
      return
    }

    if (password.length < 6) {
      setError('密码长度至少6位')
      return
    }

    try {
      const response = await fetch('/api/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ username, password })
      })

      const data = await response.json()

      if (data.success) {
        setSuccessMessage('注册成功，请登录')
        setIsRegisterMode(false)
        setPassword('')
        setConfirmPassword('')
      } else {
        setError(data.error)
      }
    } catch (error) {
      setError('注册失败: ' + error.message)
    }
  }

  const handleLogout = async () => {
    try {
      await fetch('/api/logout', {
        method: 'POST',
        credentials: 'include'
      })
    } catch (error) {
      console.error('Logout failed:', error)
    } finally {
      setIsAuthenticated(false)
      setUser(null)
      setUsername('')
      setPassword('')
      setConfirmPassword('')
      setError('')
      setSuccessMessage('')
    }
  }

  // 登录页面
  if (!isAuthenticated) {
    return (
      <div className="login-container">
        <div className="login-box">
          <div className="logo">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M12 2L2 7L12 12L22 7L12 2Z" fill="white"/>
              <path d="M2 17L12 22L22 17" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              <path d="M2 12L12 17L22 12" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
          <h1>AI 问数与智能分析</h1>
          <p className="subtitle">基于 Paimon 湖仓的智能数据分析平台</p>
          {isRegisterMode ? (
            <form onSubmit={handleRegister}>
              <div className="form-group">
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="用户名"
                  required
                />
              </div>
              <div className="form-group">
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="密码（至少6位）"
                  required
                />
              </div>
              <div className="form-group">
                <input
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="确认密码"
                  required
                />
              </div>
              {error && <div className="error-message">{error}</div>}
              <button type="submit" className="login-button">注册</button>
            </form>
          ) : (
            <form onSubmit={handleLogin}>
              <div className="form-group">
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="用户名"
                  required
                />
              </div>
              <div className="form-group">
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="密码"
                  required
                />
              </div>
              {error && <div className="error-message">{error}</div>}
              <button type="submit" className="login-button">登录</button>
            </form>
          )}
          <div className="login-switch">
            {isRegisterMode ? (
              <>
                <span>已有账号？</span>
                <button onClick={() => { setIsRegisterMode(false); setError(''); setSuccessMessage(''); }}>立即登录</button>
              </>
            ) : (
              <>
                <span>没有账号？</span>
                <button onClick={() => { setIsRegisterMode(true); setError(''); setSuccessMessage(''); }}>立即注册</button>
              </>
            )}
          </div>
          {successMessage && <div className="success-message">{successMessage}</div>}
        </div>
      </div>
    )
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<ChatPage user={user} onLogout={handleLogout} />} />
        <Route path="/admin" element={<AdminPage user={user} onLogout={handleLogout} />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
