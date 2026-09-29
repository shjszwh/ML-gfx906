#!/usr/bin/env bash
# 在 Debian 12 上交互式构建 ComfyUI gfx906 镜像。
#
#   ./comfyui-build.sh
#   按提示输入 zip 路径、额外 pip 命令、镜像名称。
#
# 基础镜像默认 docker.io/mixa3607/pytorch-gfx906:v2.13.0-rocm-7.14
# 可用 COMFYUI_BASE_IMAGE 覆盖。镜像地址见 ./mirrors.cn.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/mirrors.cn.sh"

BASE="${COMFYUI_BASE_IMAGE:-docker.io/mixa3607/pytorch-gfx906:v2.13.0-rocm-7.14}"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

prompt_zip() {
  local input
  while true; do
    read -r -p "最新版的zip包地址为：" input
    input="$(trim "${input}")"
    if [ -z "${input}" ]; then
      echo "请输入 zip 路径。" >&2
      continue
    fi
    if [ ! -f "${input}" ]; then
      echo "文件不存在: ${input}" >&2
      continue
    fi
    ZIP="$(cd "$(dirname "${input}")" && pwd)/$(basename "${input}")"
    return 0
  done
}

prompt_extra() {
  local input
  read -r -p "需要额外安装的扩展：" input
  EXTRA_PIP="$(trim "${input}")"
}

prompt_image() {
  local input
  while true; do
    read -r -p "镜像名称：" input
    input="$(trim "${input}")"
    if [ -z "${input}" ]; then
      echo "请输入镜像名称。" >&2
      continue
    fi
    IMAGE="${input}"
    return 0
  done
}

if ! command -v docker >/dev/null 2>&1; then
  echo "未找到 docker。请在 Debian 12 服务器上安装 Docker 后再执行。" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "未找到 python3。请先执行: sudo apt-get install -y python3" >&2
  exit 1
fi

prompt_zip
prompt_extra
prompt_image

STAGE="$(mktemp -d /tmp/comfyui-build.XXXXXX)"
cleanup() {
  rm -rf "${STAGE}"
}
trap cleanup EXIT

python3 - "${ZIP}" "${STAGE}" <<'PY'
import os
import sys
import zipfile
from pathlib import Path

zip_path, stage = Path(sys.argv[1]), Path(sys.argv[2])
raw = stage / "raw"
raw.mkdir(parents=True)
with zipfile.ZipFile(zip_path) as zf:
    zf.extractall(raw)

entries = [p for p in raw.iterdir() if p.name != "__MACOSX"]
if len(entries) == 1 and entries[0].is_dir() and not (raw / "requirements.txt").is_file():
    src = entries[0]
else:
    src = raw

dest = stage / "comfy"
os.rename(src, dest)
if raw.exists() and raw != dest:
    import shutil
    shutil.rmtree(raw, ignore_errors=True)

req = dest / "requirements.txt"
if not req.is_file():
    raise SystemExit("解压后的目录里没有 requirements.txt，请确认这是 ComfyUI 的 GitHub 源码 zip。")
PY

cp "${ROOT}/scripts/apply-cn-mirrors.sh" "${STAGE}/apply-cn-mirrors.sh"
cp "${ROOT}/comfyui/build-context/entrypoint.sh" "${STAGE}/comfy/entrypoint.sh"
cp "${ROOT}/comfyui/build-context/sitecustomize.py" "${STAGE}/comfy/sitecustomize.py"
{
  printf '%s\n' '#!/bin/bash'
  printf '%s\n' 'set -eo pipefail'
  printf '%s\n' 'pip() { python3 -m pip "$@"; }'
  if [ -n "${EXTRA_PIP}" ]; then
    printf '%s\n' "${EXTRA_PIP}"
  fi
} > "${STAGE}/extra-pip.sh"
chmod +x "${STAGE}/apply-cn-mirrors.sh" "${STAGE}/comfy/entrypoint.sh" "${STAGE}/extra-pip.sh"

cat >"${STAGE}/.dockerignore" <<'EOF'
**/.git
**/__pycache__
**/*.pyc
EOF

VERSION=$(python3 - "${STAGE}/comfy" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
patterns = (
    ("pyproject.toml", r"(?m)^version\s*=\s*['\"]([^'\"]+)['\"]"),
    ("comfyui_version.py", r"__version__\s*=\s*['\"]([^'\"]+)['\"]"),
)
for name, pattern in patterns:
    path = root / name
    if not path.is_file():
        continue
    match = re.search(pattern, path.read_text(encoding="utf-8", errors="replace"))
    if match:
        print(match.group(1))
        raise SystemExit(0)
print("")
PY
)

mkdir -p "${ROOT}/comfyui/logs"
LOG="${ROOT}/comfyui/logs/build_$(date +%Y%m%d%H%M%S).log"

echo "源码包:   ${ZIP}"
if [ -n "${VERSION}" ]; then
  echo "包内版本: ${VERSION}"
fi
if [ -n "${EXTRA_PIP}" ]; then
  echo "额外扩展: ${EXTRA_PIP}"
else
  echo "额外扩展: 无"
fi
echo "基础镜像: ${BASE}"
echo "目标镜像: ${IMAGE}"
echo "apt:      ${APT_UBUNTU_MIRROR}"
echo "pip:      ${PIP_INDEX_URL}"
echo "hf:       ${HF_ENDPOINT}"
echo "日志:     ${LOG}"

docker build \
  --progress plain \
  --build-arg "BASE_PYTORCH_IMAGE=${BASE}" \
  --build-arg "APT_UBUNTU_MIRROR=${APT_UBUNTU_MIRROR}" \
  --build-arg "APT_DEBIAN_MIRROR=${APT_DEBIAN_MIRROR}" \
  --build-arg "APT_DEBIAN_SECURITY_MIRROR=${APT_DEBIAN_SECURITY_MIRROR}" \
  --build-arg "PIP_INDEX_URL=${PIP_INDEX_URL}" \
  --build-arg "PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST}" \
  --build-arg "HF_ENDPOINT=${HF_ENDPOINT}" \
  --file "${ROOT}/comfyui/build-local.Dockerfile" \
  --tag "${IMAGE}" \
  "${STAGE}" 2>&1 | tee "${LOG}"

echo "构建完成: ${IMAGE}"
