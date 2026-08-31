"""
初始化 ODS 层 Kafka Topics
运行前请确保 Docker 容器已启动：docker compose up -d
"""
import sys
import os

# 把 mock 目录加入 Python 路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mock"))

from common.kafka_utils import create_topics


if __name__ == "__main__":
    create_topics()
    print("[Done] Kafka topics 初始化完成")
