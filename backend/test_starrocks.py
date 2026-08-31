import requests
import json

# StarRocks 服务地址
STARROCKS_BASE_URL = "http://localhost:5001"

def test_health():
    """测试健康检查"""
    print("=" * 50)
    print("测试: 健康检查")
    print("=" * 50)

    response = requests.get(f"{STARROCKS_BASE_URL}/api/starrocks/health")
    print(f"状态码: {response.status_code}")
    print(f"响应: {response.json()}")
    print()

def test_list_databases():
    """测试获取数据库列表"""
    print("=" * 50)
    print("测试: 获取数据库列表")
    print("=" * 50)

    response = requests.get(f"{STARROCKS_BASE_URL}/api/starrocks/databases")
    data = response.json()
    print(f"状态码: {response.status_code}")
    print(f"响应: {json.dumps(data, ensure_ascii=False, indent=2)}")
    print()

def test_list_tables(database):
    """测试获取表列表"""
    print("=" * 50)
    print(f"测试: 获取 {database} 数据库的表列表")
    print("=" * 50)

    response = requests.get(f"{STARROCKS_BASE_URL}/api/starrocks/tables", params={"database": database})
    data = response.json()
    print(f"状态码: {response.status_code}")
    print(f"响应: {json.dumps(data, ensure_ascii=False, indent=2)}")
    print()

def test_query(sql, description=""):
    """测试执行 SQL 查询"""
    print("=" * 50)
    print(f"测试: 执行查询 - {description}")
    print(f"SQL: {sql}")
    print("=" * 50)

    response = requests.post(
        f"{STARROCKS_BASE_URL}/api/starrocks/query",
        headers={"Content-Type": "application/json"},
        json={"sql": sql}
    )

    data = response.json()
    print(f"状态码: {response.status_code}")

    if data.get("success"):
        print(f"列: {data.get('columns')}")
        print(f"行数: {data.get('row_count')}")
        print(f"数据: {json.dumps(data.get('data'), ensure_ascii=False, indent=2)}")
    else:
        print(f"错误: {data.get('error')}")

    print()
    return data

def test_query_invalid_sql():
    """测试无效 SQL（应该被拒绝）"""
    print("=" * 50)
    print("测试: 执行无效 SQL (INSERT - 应该被拒绝)")
    print("=" * 50)

    response = requests.post(
        f"{STARROCKS_BASE_URL}/api/starrocks/query",
        headers={"Content-Type": "application/json"},
        json={"sql": "INSERT INTO test VALUES (1)"}
    )

    data = response.json()
    print(f"状态码: {response.status_code}")
    print(f"响应: {json.dumps(data, ensure_ascii=False, indent=2)}")
    print()

def run_all_tests():
    """运行所有测试"""
    print("\n" + "=" * 60)
    print("StarRocks 服务测试开始")
    print("=" * 60 + "\n")

    # 1. 健康检查
    # test_health()

    # 2. 获取数据库列表
    # test_list_databases()

    # 3. 测试无效 SQL（应该被拒绝）
    # test_query_invalid_sql()

    # 4. 测试 SHOW 查询
    # test_query("SHOW DATABASES", "显示所有数据库")

    # 5. 测试 SELECT 查询
    # 根据实际数据库修改
    # test_query("SELECT 1 as test", "简单查询")
    # test_query("SELECT * from paimon_catalog1.mall_dw.ads_channel_conversion_di", "简单查询")
    # test_query("SELECT dt, total_gmv, paid_user_cnt FROM  paimon_catalog1.mall_dw.ads_trade_overview_di WHERE dt >= REPLACE(CAST(DATE_SUB(CURRENT_DATE(), 6) AS STRING), '-', '') AND dt <= REPLACE(CAST(CURRENT_DATE() AS STRING), '-', '') ORDER BY dt ASC LIMIT 200", "简单查询")
    # test_query("SELECT dt, total_gmv, paid_user_cnt FROM  paimon_catalog1.mall_dw.ads_trade_overview_di WHERE dt >= '20260301' AND dt <= '20260311' ORDER BY dt ASC LIMIT 200", "简单查询")
    test_query("SELECT dt, total_gmv, paid_user_cnt FROM mall_dw.ads_trade_overview_di ORDER BY dt ASC LIMIT 200", "简单查询")
    # 6. 测试 LIMIT 查询
    # test_query("SELECT 1 as id, 'test' as name, 100 as value LIMIT 5", "带 LIMIT 查询")

    print("=" * 60)
    print("测试完成")
    print("=" * 60)

if __name__ == "__main__":
    run_all_tests()
