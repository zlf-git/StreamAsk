#!/bin/bash
# 快速启动 Flink SQL Client
# 已修复中文乱码（LC_ALL=C.UTF-8），并透传所有参数
#
# 用法：
#   bash flink_sql.sh                         # 交互模式，进入 Flink SQL> 提示符
#   bash flink_sql.sh -f /flink-init/x.sql    # 执行容器内 SQL 文件（执行完自动退出）
#   bash flink_sql.sh -e "SHOW CATALOGS;"     # 执行单条语句后退出
#
# 注意：-f 的文件必须放在宿主机 C:\Users\zlf\Desktop\AIDataAnalysis_StarRocks\docker\flink\init\
#       该目录已挂载到容器 /flink-init/，所以文件用 /flink-init/xxx.sql 引用
# 交互模式（有终端）用 -it；管道/-f 模式没有 TTY，改用 -i，否则报
# "cannot attach stdin to a TTY-enabled container because stdin is not a terminal"
if [ -t 0 ]; then
  TTY_FLAG="-it"
else
  TTY_FLAG="-i"
fi
docker exec -e LC_ALL=C.UTF-8 $TTY_FLAG flink-jobmanager ./bin/sql-client.sh -i /flink-init/catalogs.sql "$@"
