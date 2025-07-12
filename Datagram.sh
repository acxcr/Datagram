#!/bin/bash

set -e

WORKDIR="$(pwd)/datagram"
CONTAINER_NAME="datagram-node"
IMAGE_NAME="datagram-cli:latest"

function build_image() {
  mkdir -p "$WORKDIR"
  cat > "$WORKDIR/Dockerfile" <<EOF
FROM ubuntu:24.04

WORKDIR /app
RUN apt-get update && apt-get install -y curl unzip && \
    curl -L https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux -o /app/datagram-cli && \
    chmod +x /app/datagram-cli

ENTRYPOINT ["/app/datagram-cli", "run", "--"]
EOF

  docker build -t $IMAGE_NAME "$WORKDIR"
}

function deploy_node() {
  read -p "请输入 Datagram key: " dkey

  build_image

  docker rm -f $CONTAINER_NAME >/dev/null 2>&1 || true

  docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -v "$WORKDIR:/app/data" \
    $IMAGE_NAME \
    -key "$dkey"

  echo "[✔] 节点已启动"
}

function show_logs() {
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    docker logs -f $CONTAINER_NAME
  else
    echo "[!] 找不到运行中的节点容器"
  fi
}

function delete_all() {
  echo "[!] 正在删除所有相关内容..."
  docker rm -f $CONTAINER_NAME >/dev/null 2>&1 || true
  docker volume prune -f >/dev/null 2>&1 || true
  docker network prune -f >/dev/null 2>&1 || true
  docker rmi $IMAGE_NAME >/dev/null 2>&1 || true
  rm -rf "$WORKDIR"
  echo "[✔] 所有内容已清除"
}

while true; do
  echo "============================="
  echo " Datagram 节点管理菜单"
  echo "============================="
  echo "1. 部署节点"
  echo "2. 查看日志"
  echo "3. 删除节点"
  echo "4. 退出"
  read -p "请输入选项：" choice

  case "$choice" in
    1) deploy_node ;;
    2) show_logs ;;
    3) delete_all ;;
    4) exit 0 ;;
    *) echo "无效选项，请重新输入" ;;
  esac
done


