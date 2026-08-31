import pymysql
import hashlib

# MySQL数据库配置
DB_CONFIG = {
    'host': 'localhost',
    'port': 3307,
    'user': 'root',
    'password': '123456',  # 请修改为你的MySQL密码
    'database': 'ai_data_analysis',
    'charset': 'utf8mb4'
}

def get_connection():
    """获取数据库连接"""
    return pymysql.connect(**DB_CONFIG)

def init_database():
    """初始化数据库和表"""
    # 先连接不带数据库，创建数据库
    config = DB_CONFIG.copy()
    config.pop('database')
    conn = pymysql.connect(**config)
    try:
        with conn.cursor() as cursor:
            cursor.execute("CREATE DATABASE IF NOT EXISTS ai_data_analysis CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
        conn.commit()
    finally:
        conn.close()

    # 连接数据库，创建用户表
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(50) UNIQUE NOT NULL,
                    password VARCHAR(128) NOT NULL,
                    allowed_tables VARCHAR(500) DEFAULT '',
                    is_admin TINYINT(1) DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_username (username)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)

            # 如果表已存在但没有 is_admin 字段，则添加
            cursor.execute("SHOW COLUMNS FROM users LIKE 'is_admin'")
            if not cursor.fetchone():
                cursor.execute("ALTER TABLE users ADD COLUMN is_admin TINYINT(1) DEFAULT 0")

            # 检查是否需要创建管理员账号
            cursor.execute("SELECT id FROM users WHERE username = 'admin'")
            if not cursor.fetchone():
                # 创建管理员账号，密码为 123456 的 SHA256 哈希
                admin_password_hash = hashlib.sha256('123456'.encode()).hexdigest()
                cursor.execute(
                    "INSERT INTO users (username, password, allowed_tables, is_admin) VALUES (%s, %s, %s, %s)",
                    ('admin', admin_password_hash, 'ads_realtime_overview,ads_top_spu_daily,ads_shop_rank_daily,dws_shop_daily_gmv,dws_spu_daily_sales,dws_category_daily_sales,dws_user_daily_activity', 1)
                )
                print("已创建管理员账号: admin / 123456")
        conn.commit()
    finally:
        conn.close()

def verify_user(username, password):
    """验证用户登录"""
    conn = get_connection()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            password_hash = hashlib.sha256(password.encode()).hexdigest()
            cursor.execute(
                "SELECT id, username, allowed_tables, is_admin FROM users WHERE username = %s AND password = %s",
                (username, password_hash)
            )
            user = cursor.fetchone()
            if user:
                return {
                    'id': user['id'],
                    'username': user['username'],
                    'allowed_tables': user['allowed_tables'].split(',') if user['allowed_tables'] else [],
                    'is_admin': bool(user['is_admin'])
                }
            return None
    finally:
        conn.close()

def get_user_by_username(username):
    """根据用户名获取用户信息"""
    conn = get_connection()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            cursor.execute(
                "SELECT id, username, allowed_tables, is_admin FROM users WHERE username = %s",
                (username,)
            )
            user = cursor.fetchone()
            if user:
                return {
                    'id': user['id'],
                    'username': user['username'],
                    'allowed_tables': user['allowed_tables'].split(',') if user['allowed_tables'] else [],
                    'is_admin': bool(user['is_admin'])
                }
            return None
    finally:
        conn.close()

def register_user(username, password, allowed_tables=None):
    """注册新用户"""
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            # 检查用户名是否已存在
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            if cursor.fetchone():
                return False, "用户名已存在"

            # 插入新用户
            password_hash = hashlib.sha256(password.encode()).hexdigest()
            tables_str = ','.join(allowed_tables) if allowed_tables else ''
            cursor.execute(
                "INSERT INTO users (username, password, allowed_tables) VALUES (%s, %s, %s)",
                (username, password_hash, tables_str)
            )
        conn.commit()
        return True, "注册成功"
    except Exception as e:
        return False, str(e)
    finally:
        conn.close()

def get_all_users():
    """获取所有用户"""
    conn = get_connection()
    try:
        with conn.cursor(pymysql.cursors.DictCursor) as cursor:
            cursor.execute("SELECT id, username, allowed_tables, created_at FROM users ORDER BY created_at DESC")
            users = cursor.fetchall()
            for user in users:
                user['allowed_tables'] = user['allowed_tables'].split(',') if user['allowed_tables'] else []
            return users
    finally:
        conn.close()

def update_user_tables(username, allowed_tables):
    """更新用户可访问的表"""
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            tables_str = ','.join(allowed_tables) if allowed_tables else ''
            cursor.execute(
                "UPDATE users SET allowed_tables = %s WHERE username = %s",
                (tables_str, username)
            )
        conn.commit()
        return True, "更新成功"
    except Exception as e:
        return False, str(e)
    finally:
        conn.close()

def delete_user(username):
    """删除用户"""
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("DELETE FROM users WHERE username = %s", (username,))
        conn.commit()
        return True, "删除成功"
    except Exception as e:
        return False, str(e)
    finally:
        conn.close()
