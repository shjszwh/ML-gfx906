#!/usr/bin/env bash
# 国内构建用的镜像地址。comfyui-build.sh 以及其他 *-build.sh 都 source 这个文件。
# 需要换源时只改这里，或在执行脚本前 export 同名变量。

# Ubuntu 24.04（ROCm / PyTorch 基础镜像）的 apt
export APT_UBUNTU_MIRROR="${APT_UBUNTU_MIRROR:-https://mirrors.aliyun.com/ubuntu}"

# Debian 12 的 apt。当前 ComfyUI 基础镜像是 Ubuntu，这里留给后续 Debian 镜像使用。
export APT_DEBIAN_MIRROR="${APT_DEBIAN_MIRROR:-https://mirrors.aliyun.com/debian}"
export APT_DEBIAN_SECURITY_MIRROR="${APT_DEBIAN_SECURITY_MIRROR:-https://mirrors.aliyun.com/debian-security}"

# PyPI
export PIP_INDEX_URL="${PIP_INDEX_URL:-https://mirrors.aliyun.com/pypi/simple}"
export PIP_TRUSTED_HOST="${PIP_TRUSTED_HOST:-mirrors.aliyun.com}"

# Hugging Face。运行时可用 docker run -e HF_ENDPOINT=... 覆盖。
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
