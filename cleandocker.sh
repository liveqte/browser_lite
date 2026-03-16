#!/bin/bash

# 检查 /分区的磁盘使用率
usage=$(df -h /| awk 'NR==2 {print $5}' | sed 's/%//')

echo "当前 / 分区磁盘使用率: ${usage}%"

if [ "$usage" -ge 40 ]; then
  echo "磁盘使用率超过 40%，开始清理 Docker 资源..."

  # 停止所有容器
  docker stop $(docker ps -aq)

  # 删除所有容器
  docker rm $(docker ps -aq)

  # 清理镜像
  docker image prune -a -f

  # 清理构建缓存
  docker builder prune -a -f

  # 清理卷
  docker volume prune -f

  echo "清理完成 ✅"
else
  echo "磁盘使用率低于 80%，无需清理。"
fi
