#!/bin/bash
# 在镜像构建过程中执行：把 apt 源和 pip 源换成 mirrors.cn.sh 里传入的地址。
set -euo pipefail

: "${APT_UBUNTU_MIRROR:=https://mirrors.aliyun.com/ubuntu}"
: "${APT_DEBIAN_MIRROR:=https://mirrors.aliyun.com/debian}"
: "${APT_DEBIAN_SECURITY_MIRROR:=https://mirrors.aliyun.com/debian-security}"
: "${PIP_INDEX_URL:=https://mirrors.aliyun.com/pypi/simple}"
: "${PIP_TRUSTED_HOST:=mirrors.aliyun.com}"

APT_UBUNTU_MIRROR="${APT_UBUNTU_MIRROR%/}"
APT_DEBIAN_MIRROR="${APT_DEBIAN_MIRROR%/}"
APT_DEBIAN_SECURITY_MIRROR="${APT_DEBIAN_SECURITY_MIRROR%/}"

rewrite_file() {
  local f="$1"
  sed -i \
    -e "s|https\\?://archive.ubuntu.com/ubuntu|${APT_UBUNTU_MIRROR}|g" \
    -e "s|https\\?://security.ubuntu.com/ubuntu|${APT_UBUNTU_MIRROR}|g" \
    -e "s|https\\?://mirrors.edge.ubuntu.com/ubuntu|${APT_UBUNTU_MIRROR}|g" \
    -e "s|https\\?://deb.debian.org/debian-security|${APT_DEBIAN_SECURITY_MIRROR}|g" \
    -e "s|https\\?://security.debian.org/debian-security|${APT_DEBIAN_SECURITY_MIRROR}|g" \
    -e "s|https\\?://deb.debian.org/debian|${APT_DEBIAN_MIRROR}|g" \
    -e "s|https\\?://ftp.debian.org/debian|${APT_DEBIAN_MIRROR}|g" \
    "$f"
}

shopt -s nullglob
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
  [ -f "$f" ] || continue
  case "$f" in
    *.sources|*.list|*/sources.list) rewrite_file "$f" ;;
  esac
done

cat >/etc/apt/apt.conf.d/99cn-timeout <<'EOF'
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::Retries "3";
EOF

python3 -m pip config set global.break-system-packages true
python3 -m pip config set global.index-url "${PIP_INDEX_URL}"
python3 -m pip config set global.trusted-host "${PIP_TRUSTED_HOST}"
python3 -m pip config set global.timeout 120

echo "apt ubuntu mirror: ${APT_UBUNTU_MIRROR}"
echo "pip index: ${PIP_INDEX_URL}"
