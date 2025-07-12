#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$BASE_DIR/datagram"
PROJECT_NAME="datagram-node"

function menu() {
  echo "============================="
  echo " Datagram 容器部署菜单"
  echo "============================="
  echo "1. 部署节点"
  echo "2. 查看日志"
  echo "3. 删除节点和数据"
  echo "4. 退出"
  echo -n "请输入选项："
}

function check_docker() {
  if ! command -v docker &>/dev/null; then
    echo "[+] Docker 未安装，正在安装..."
    apt update && apt install -y docker.io
    systemctl enable docker
    systemctl start docker
  fi
}

function deploy_node() {
  mkdir -p "$WORK_DIR/logs"

  echo -n "[>] 请输入你的 key："
  read USER_KEY
  echo "$USER_KEY" > "$WORK_DIR/key.txt"

  cat > "$WORK_DIR/Dockerfile" <<EOF
FROM alpine:3.20
WORKDIR /app
RUN apk add --no-cache curl \
    && curl -L https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux -o /app/datagram-cli \
    && chmod +x /app/datagram-cli
COPY key.txt /app/key.txt
ENTRYPOINT ["/app/datagram-cli", "run", "--", "-key", "/app/key.txt"]
EOF

  echo "[+] 构建镜像..."
  docker build -t $PROJECT_NAME "$WORK_DIR"

  echo "[+] 启动容器..."
  docker run -d --name $PROJECT_NAME \
    --restart unless-stopped \
    -v "$WORK_DIR/key.txt:/app/key.txt" \
    -v "$WORK_DIR/logs/datagram.log:/app/datagram.log" \
    $PROJECT_NAME

  echo "[✔] 部署完成"
}

function view_logs() {
  if docker ps -a --format '{{.Names}}' | grep -q "^$PROJECT_NAME$"; then
    docker logs -f $PROJECT_NAME
  else
    echo "[!] 容器未运行"
  fi
}

function delete_all() {
  echo "[!] 正在删除所有节点数据和容器..."
  docker rm -f $PROJECT_NAME >/dev/null 2>&1 || true
  docker rmi -f $PROJECT_NAME >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
  echo "[✔] 删除完成"
}

check_docker

while true; do
  menu
  read opt
  case "$opt" in
    1) deploy_node ;;
    2) view_logs ;;
    3) delete_all ;;
    4) echo "已退出"; exit 0 ;;
    *) echo "[!] 无效选项" ;;
  esac
done

