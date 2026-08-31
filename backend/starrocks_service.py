import pymysql
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# ============================================================
# StarRocks 连接配置
# 与 Doris 同宗：均走 MySQL 协议、默认查询端口都是 9030，
# 因此 host/port/user 这一层几乎零改动。真正要改的是：
#   1) 外部湖仓 catalog（Paimon）需在 StarRocks 里用
#      CREATE EXTERNAL CATALOG ... TYPE=PAIMON 重新建；
#   2) 个别 Doris 独有函数需核对 StarRocks 方言。
# ============================================================
STARROCKS_CONFIG = {
    'host': 'localhost',
    'port': 9030,          # StarRocks FE 查询端口，默认即 9030
    'user': 'root',
    'password': '',
    'database': '',
    'charset': 'utf8mb4'
}

def get_starrocks_connection():
    """获取 StarRocks 数据库连接（MySQL 协议，pymysql 通用）"""
    return pymysql.connect(**STARROCKS_CONFIG)

# 允许的语句前缀白名单——这是 LLM 生成 SQL 的"最后一道闸"
ALLOWED_PREFIXES = ('SELECT', 'SHOW', 'DESC', 'EXPLAIN', 'WITH')

def _is_safe_sql(sql: str) -> bool:
    """
    安全校验：
    1) 只允许只读前缀（SELECT/SHOW/DESC/EXPLAIN/WITH）；
    2) 拒绝包含 ';' 的多语句，杜绝 "SELECT ...; DROP TABLE ..." 注入。
    pymysql 默认不执行多语句，但这里再做一层显式拦截，防御更稳。
    """
    stripped = sql.strip()
    if not stripped:
        return False
    upper = stripped.upper()
    if not upper.startswith(ALLOWED_PREFIXES):
        return False
    if ';' in stripped:
        return False
    return True

@app.route('/api/starrocks/query', methods=['POST'])
def query_starrocks():
    """
    执行 SQL 查询 StarRocks 数据。
    这是 AI 分析链路的"手"：Dify 生成的 SQL 最终在这里落地执行，
    所以本接口是防范破坏性 SQL / 数据泄露的最后一公里。
    """
    try:
        data = request.json
        sql = data.get('sql', '')

        if not sql:
            return jsonify({'success': False, 'error': 'SQL 语句不能为空'}), 400

        if not _is_safe_sql(sql):
            return jsonify({
                'success': False,
                'error': '仅支持只读查询（SELECT/SHOW/DESC/EXPLAIN/WITH），且不允许多语句'
            }), 403

        conn = get_starrocks_connection()
        try:
            with conn.cursor(pymysql.cursors.DictCursor) as cursor:
                cursor.execute(sql)

                if cursor.description is not None:
                    columns = [desc[0] for desc in cursor.description]
                    rows = cursor.fetchall()
                    result_data = [dict(row) for row in rows]
                    return jsonify({
                        'success': True,
                        'columns': columns,
                        'data': result_data,
                        'row_count': len(result_data)
                    })
                else:
                    conn.commit()
                    return jsonify({
                        'success': True,
                        'columns': [],
                        'data': [],
                        'row_count': 0,
                        'message': '查询执行成功，无返回数据'
                    })
        except pymysql.Error as e:
            return jsonify({'success': False, 'error': f'数据库错误: {str(e)}'}), 500
        finally:
            conn.close()

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/starrocks/databases', methods=['GET'])
def list_databases():
    """获取所有数据库列表"""
    try:
        conn = get_starrocks_connection()
        try:
            with conn.cursor(pymysql.cursors.DictCursor) as cursor:
                cursor.execute("SHOW DATABASES")
                databases = [row['Database'] for row in cursor.fetchall()]
                return jsonify({'success': True, 'databases': databases})
        finally:
            conn.close()
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/starrocks/tables', methods=['GET'])
def list_tables():
    """获取指定数据库的表列表"""
    try:
        database = request.args.get('database', '')
        if not database:
            return jsonify({'success': False, 'error': '请指定数据库名称'}), 400

        conn = get_starrocks_connection()
        try:
            with conn.cursor(pymysql.cursors.DictCursor) as cursor:
                cursor.execute(f"SHOW TABLES FROM `{database}`")
                tables = [list(row.values())[0] for row in cursor.fetchall()]
                return jsonify({'success': True, 'tables': tables, 'database': database})
        finally:
            conn.close()
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/starrocks/schema', methods=['GET'])
def get_table_schema():
    """获取表结构"""
    try:
        database = request.args.get('database', '')
        table = request.args.get('table', '')

        if not database or not table:
            return jsonify({'success': False, 'error': '请指定数据库名称和表名称'}), 400

        conn = get_starrocks_connection()
        try:
            with conn.cursor(pymysql.cursors.DictCursor) as cursor:
                cursor.execute(f"DESC `{database}`.`{table}`")
                schema = cursor.fetchall()
                return jsonify({'success': True, 'schema': schema, 'database': database, 'table': table})
        finally:
            conn.close()
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/starrocks/health', methods=['GET'])
def health():
    """健康检查"""
    try:
        conn = get_starrocks_connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1")
            return jsonify({'status': 'ok', 'message': 'StarRocks 连接正常'})
        finally:
            conn.close()
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

if __name__ == '__main__':
    print("StarRocks 查询服务启动中...")
    print(f"连接配置: {STARROCKS_CONFIG['host']}:{STARROCKS_CONFIG['port']}")
    app.run(host='0.0.0.0', port=5001, debug=True)
