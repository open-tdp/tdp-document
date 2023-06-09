#!/bin/sh
#

set -e
set -o noglob

# --- system check ---

case "$(uname -s)" in
  Linux)
    TDP_PLATFORM=linux
    ;;
  Darwin)
    TDP_PLATFORM=darwin
    ;;
  *)
    echo "Unknown, unsupported platform" >&2
    exit 2
esac

case "$(uname -m)" in
  x86_64*|i?86_64*|amd64*)
    TDP_ARCHITECTURE=amd64
    ;;
  aarch64*|arm64*)
    TDP_ARCHITECTURE=arm64
    ;;
  *)
    echo "Unknown, unsupported architecture" >&2
    exit 3
    ;;
esac

# --- set global env ---

if [ -z "$TDP_SERVICE" ]; then
    TDP_SERVICE=install
fi

if [ -z "$TDP_BINARY" ]; then
    TDP_BINARY=/usr/local/bin/tdp-aiart
fi

if [ -z "$TDP_PACKAGE" ]; then
    TDP_PACKAGE=https://get.opentdp.org/aiart/tdp-aiart-${TDP_PLATFORM}-${TDP_ARCHITECTURE}.gz
fi

# --- download binary ---

download() {

    rm -rf $TDP_BINARY

    echo "[TDP] Download ..."

    if type curl >/dev/null 2>&1; then
        curl -sfL $TDP_PACKAGE | gunzip > $TDP_BINARY
    elif type wget >/dev/null 2>&1; then
        wget -qO- $TDP_PACKAGE | gunzip > $TDP_BINARY
    fi

    if [ ! -e $TDP_BINARY ]; then
        echo "[TDP] Can't download ${TDP_PACKAGE}"
        exit 1
    fi

    chmod +x $TDP_BINARY

}

# --- install service ---

install() {

    echo "[TDP] Install ..."

    mkdir -p /etc/tdp-aiart
    config=/etc/tdp-aiart/server.yml

    cat <<EOF >$config
dataset:
    dir: /var/lib/tdp-aiart
logger:
    dir: /var/log/tdp-aiart
    level: info
    target: file
server:
    listen: :7700
EOF

    $TDP_BINARY server -s install -c $config

    if [ $? -ne 0 ]; then
        echo "[TDP] Install failed"
        exit 1
    fi

    echo "[TDP] Install completed"

}

# --- uninstall service ---

uninstall() {

    echo "[TDP] Uninstall ..."

    $TDP_BINARY server -s uninstall

    rm -rf /var/*/tdp-aiart
    rm -rf /etc/tdp-aiart
    rm -rf $TDP_BINARY

    echo "[TDP] Uninstall completed"

}

# --- start service ---

start () {

    echo "[TDP] Start ..."

    $TDP_BINARY server -s start
    $TDP_BINARY server -s status

}

stop () {

    echo "[TDP] Stop ..."

    $TDP_BINARY server -s stop
    $TDP_BINARY server -s status

}

# --- run task ---

case "$TDP_SERVICE" in
  install)
    download
    install
    start
    ;;
  update)
    stop
    download
    start
    ;;
  uninstall)
    stop
    uninstall
    ;;
esac
