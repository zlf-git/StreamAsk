#!/bin/bash
set -e

# 兼容官方 flink 镜像的 FLINK_PROPERTIES（分号分隔的 key:value）
if [ -n "$FLINK_PROPERTIES" ]; then
  IFS=';' read -ra PROPS <<< "$FLINK_PROPERTIES"
  for p in "${PROPS[@]}"; do
    [ -n "$p" ] && echo "$p" >> "${FLINK_HOME}/conf/flink-conf.yaml"
  done
fi

case "$1" in
  jobmanager)
    exec "${FLINK_HOME}/bin/jobmanager.sh" start-foreground
    ;;
  taskmanager)
    exec "${FLINK_HOME}/bin/taskmanager.sh" start-foreground
    ;;
  *)
    exec "$@"
    ;;
esac
