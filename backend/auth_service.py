from flask import Flask, request, jsonify
from flask_cors import CORS
import pymysql

app = Flask(__name__)
CORS(app)

# MySQL 数据库配置
DB_CONFIG = {
    'host': 'localhost',
    'port': 3307,
    'user': 'root',
    'password': '123456',
    'database': 'ai_data_analysis',
    'charset': 'utf8mb4'
}

def get_connection():
    """获取数据库连接"""
    return pymysql.connect(**DB_CONFIG)

@app.route('/api/auth/check', methods=['POST'])
def check_table_permission():
    """
    检查用户是否有权限查询指定表
    请求体: {"user_id": "用户名", "tables": ["table1", "table2"]}
    返回: {"allowed": true/false, "authorized_tables": ["table1"], "unauthorized_tables": ["table2"]}
    """
    try:
        data = request.json
        user_id = data.get('user_id', '')
        tables = data.get('tables', [])

        if not user_id:
            return jsonify({'success': False, 'error': '用户ID不能为空'}), 400

        if not tables:
            return jsonify({'success': False, 'error': '表列表不能为空'}), 400

        conn = get_connection()
        try:
            with conn.cursor(pymysql.cursors.DictCursor) as cursor:
                # 获取用户的允许表权限
                cursor.execute(
                    "SELECT allowed_tables FROM users WHERE username = %s",
                    (user_id,)
                )
                user = cursor.fetchone()

                if not user:
                    return jsonify({
                        'success': False,
                        'error': '用户不存在'
                    }), 404

                # 解析用户允许的表
                allowed_tables_str = user.get('allowed_tables', '')
                user_allowed_tables = set()
                if allowed_tables_str:
                    user_allowed_tables = set(t.strip() for t in allowed_tables_str.split(',') if t.strip())

                # 检查每个表是否有权限
                authorized_tables = []
                unauthorized_tables = []

                for table in tables:
                    table = table.strip()
                    if table in user_allowed_tables or not user_allowed_tables:
                        # 用户有权限（允许表为空表示有全部权限）
                        authorized_tables.append(table)
                    else:
                        unauthorized_tables.append(table)

                is_allowed = len(unauthorized_tables) == 0

                return jsonify({
                    'success': True,
                    'allowed': is_allowed,
                    'user_id': user_id,
                    'authorized_tables': authorized_tables,
                    'unauthorized_tables': unauthorized_tables
                })

        finally:
            conn.close()

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/auth/filter', methods=['POST'])
def filter_authorized_tables():
    """
    过滤出用户有权限的表
    请求体: {"user_id": "用户名", "tables": ["table1", "table2"]}
    返回: {"success": true, "tables": ["table1"]}
    """
    try:
        data = request.json
        user_id = data.get('user_id', '')
        tables = data.get('tables', [])

        if not user_id:
            return jsonify({'success': False, 'error': '用户ID不能为空'}), 400

        if not tables:
            return jsonify({'success': True, 'tables': []})

        conn = get_connection()
        try:
            with conn.cursor(pymysql.cursors.DictCursor) as cursor:
                cursor.execute(
                    "SELECT allowed_tables FROM users WHERE username = %s",
                    (user_id,)
                )
                user = cursor.fetchone()

                if not user:
                    return jsonify({'success': True, 'tables': []})

                allowed_tables_str = user.get('allowed_tables', '')
                user_allowed_tables = set()
                if allowed_tables_str:
                    user_allowed_tables = set(t.strip() for t in allowed_tables_str.split(',') if t.strip())

                # 过滤出有权限的表
                authorized_tables = [t for t in tables if t.strip() in user_allowed_tables or not user_allowed_tables]

                return jsonify({
                    'success': True,
                    'tables': authorized_tables
                })

        finally:
            conn.close()

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/auth/user/tables', methods=['GET'])
def get_user_allowed_tables():
    """
    获取用户的允许表权限
    请求参数: ?user_id=用户名
    """
    try:
        user_id = request.args.get('user_id', '')

        if not user_id:
            return jsonify({'success': False, 'error': '用户ID不能为空'}), 400

        conn = get_connection()
        try:
            with conn.cursor(pymysql.cursors.DictCursor) as cursor:
                cursor.execute(
                    "SELECT username, allowed_tables, is_admin FROM users WHERE username = %s",
                    (user_id,)
                )
                user = cursor.fetchone()

                if not user:
                    return jsonify({'success': False, 'error': '用户不存在'}), 404

                allowed_tables = []
                if user.get('allowed_tables'):
                    allowed_tables = [t.strip() for t in user['allowed_tables'].split(',') if t.strip()]

                return jsonify({
                    'success': True,
                    'user_id': user['username'],
                    'is_admin': bool(user['is_admin']),
                    'allowed_tables': allowed_tables
                })

        finally:
            conn.close()

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/auth/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    print("用户鉴权服务启动中...")
    app.run(host='0.0.0.0', port=5002, debug=True)
