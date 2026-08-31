from flask import Flask, request, jsonify, session
from flask_cors import CORS
import requests
import json
from database import init_database, verify_user, get_user_by_username, register_user, get_all_users, update_user_tables, delete_user

app = Flask(__name__)
app.secret_key = 'xxx'  # 生产环境请使用更安全的密钥
CORS(app, supports_credentials=True, origins=["http://localhost:3000"])

# Dify工作流API配置
DIFY_API_URL = "http://localhost/v1/workflows/run"
DIFY_API_KEY = "xxx"

# 初始化数据库
init_database()

@app.route('/api/login', methods=['POST'])
def login():
    """
    处理登录请求
    """
    try:
        data = request.json
        username = data.get('username', '')
        password = data.get('password', '')

        if not username or not password:
            return jsonify({'success': False, 'error': '用户名和密码不能为空'}), 400

        # 验证用户
        user = verify_user(username, password)
        if not user:
            return jsonify({'success': False, 'error': '用户名或密码错误'}), 401

        # 登录成功，存储用户信息到session
        session['user'] = user

        return jsonify({
            'success': True,
            'user': user
        })

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/register', methods=['POST'])
def register():
    """
    处理用户注册请求
    """
    try:
        data = request.json
        username = data.get('username', '')
        password = data.get('password', '')
        allowed_tables = data.get('allowed_tables', [])

        if not username or not password:
            return jsonify({'success': False, 'error': '用户名和密码不能为空'}), 400

        if len(password) < 6:
            return jsonify({'success': False, 'error': '密码长度至少6位'}), 400

        # 注册用户
        success, message = register_user(username, password, allowed_tables)
        if success:
            return jsonify({'success': True, 'message': message})
        else:
            return jsonify({'success': False, 'error': message}), 400

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/logout', methods=['POST'])
def logout():
    """
    处理登出请求
    """
    session.pop('user', None)
    return jsonify({'success': True})

@app.route('/api/check-auth', methods=['GET'])
def check_auth():
    """
    检查用户登录状态
    """
    user = session.get('user')
    if user:
        return jsonify({'success': True, 'user': user})
    return jsonify({'success': False, 'authenticated': False}), 401

# ==================== 管理员接口 ====================

@app.route('/api/admin/users', methods=['GET'])
def admin_get_users():
    """
    获取所有用户列表（仅管理员可访问）
    """
    try:
        user = session.get('user')
        if not user:
            return jsonify({'success': False, 'error': '请先登录'}), 401

        # 这里可以添加管理员角色检查，暂时简单处理
        users = get_all_users()
        return jsonify({'success': True, 'users': users})

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/admin/users/<username>', methods=['PUT'])
def admin_update_user(username):
    """
    更新用户权限（仅管理员可访问）
    """
    try:
        user = session.get('user')
        if not user:
            return jsonify({'success': False, 'error': '请先登录'}), 401

        data = request.json
        allowed_tables = data.get('allowed_tables', [])

        success, message = update_user_tables(username, allowed_tables)
        if success:
            # 如果更新的是当前用户，需要刷新session
            if user['username'] == username:
                updated_user = get_user_by_username(username)
                if updated_user:
                    session['user'] = updated_user
            return jsonify({'success': True, 'message': message, 'updated_session': user['username'] == username})
        else:
            return jsonify({'success': False, 'error': message}), 400

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/admin/users/<username>', methods=['DELETE'])
def admin_delete_user(username):
    """
    删除用户（仅管理员可访问）
    """
    try:
        user = session.get('user')
        if not user:
            return jsonify({'success': False, 'error': '请先登录'}), 401

        # 不能删除自己
        if user['username'] == username:
            return jsonify({'success': False, 'error': '不能删除当前登录用户'}), 400

        success, message = delete_user(username)
        if success:
            return jsonify({'success': True, 'message': message})
        else:
            return jsonify({'success': False, 'error': message}), 400

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/chat', methods=['POST'])
def chat():
    """
    处理聊天请求，调用Dify工作流API
    """
    try:
        # 检查用户是否登录
        user = session.get('user')
        if not user:
            return jsonify({'success': False, 'error': '请先登录'}), 401

        data = request.json
        query = data.get('query', '')

        if not query:
            return jsonify({'error': 'Query is required'}), 400

        # 构建Dify API请求，传递用户信息和权限表
        headers = {
            "Authorization": f"Bearer {DIFY_API_KEY}",
            "Content-Type": "application/json"
        }

        payload = {
            "inputs": {
                "input": query,
                "user_name": user['username'],
                "allowed_tables": ",".join(user['allowed_tables']),
                "user_id": str(user['id'])
            },
            "response_mode": "blocking",
            "user": user['username']
        }

        # 调用Dify工作流API
        response = requests.post(DIFY_API_URL, headers=headers, json=payload, timeout=60)

        if response.status_code == 200:
            result = response.json()
            outputs = result.get("data", {}).get("outputs", {})

            # 获取完整的输出（包含 result1 和 result2）
            answer = outputs.get("result") or outputs.get("output") or ""

            # 如果是对象格式（包含 result1/result2），直接返回字符串形式
            if isinstance(answer, dict):
                answer = json.dumps(answer, ensure_ascii=False)
            elif isinstance(answer, str):
                # 检查是否是 JSON 字符串
                try:
                    parsed = json.loads(answer)
                    if isinstance(parsed, dict):
                        answer = json.dumps(parsed, ensure_ascii=False)
                except:
                    pass

            return jsonify({
                'success': True,
                'answer': answer,
                'raw_outputs': outputs,  # 返回原始 outputs 方便前端解析
                'task_id': result.get("data", {}).get("task_id", "")
            })
        else:
            return jsonify({
                'success': False,
                'error': f'Dify API error: {response.status_code}',
                'details': response.text
            }), response.status_code

    except requests.exceptions.Timeout:
        return jsonify({'success': False, 'error': 'Request timeout'}), 504
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
