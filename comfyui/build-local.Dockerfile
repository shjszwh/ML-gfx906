# 用本地解压好的 ComfyUI 源码构建，不在构建时访问 GitHub。
# 构建上下文由 comfyui-build.sh 组装：apply-cn-mirrors.sh + comfy/
ARG BASE_PYTORCH_IMAGE="docker.io/mixa3607/pytorch-gfx906:v2.13.0-rocm-7.14"

FROM ${BASE_PYTORCH_IMAGE}

ARG APT_UBUNTU_MIRROR="https://mirrors.aliyun.com/ubuntu"
ARG APT_DEBIAN_MIRROR="https://mirrors.aliyun.com/debian"
ARG APT_DEBIAN_SECURITY_MIRROR="https://mirrors.aliyun.com/debian-security"
ARG PIP_INDEX_URL="https://mirrors.aliyun.com/pypi/simple"
ARG PIP_TRUSTED_HOST="mirrors.aliyun.com"
ARG HF_ENDPOINT="https://hf-mirror.com"

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_INDEX_URL=${PIP_INDEX_URL} \
    PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST} \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_ENDPOINT=${HF_ENDPOINT}

COPY apply-cn-mirrors.sh /tmp/apply-cn-mirrors.sh
RUN chmod +x /tmp/apply-cn-mirrors.sh \
    && APT_UBUNTU_MIRROR="${APT_UBUNTU_MIRROR}" \
       APT_DEBIAN_MIRROR="${APT_DEBIAN_MIRROR}" \
       APT_DEBIAN_SECURITY_MIRROR="${APT_DEBIAN_SECURITY_MIRROR}" \
       PIP_INDEX_URL="${PIP_INDEX_URL}" \
       PIP_TRUSTED_HOST="${PIP_TRUSTED_HOST}" \
       /tmp/apply-cn-mirrors.sh \
    && rm -f /tmp/apply-cn-mirrors.sh \
    && if ! apt-get update; then \
         echo "apt-get update failed, disable gfx906 repo and retry"; \
         if [ -f /etc/apt/sources.list.d/gfx906.sources ]; then \
           mv /etc/apt/sources.list.d/gfx906.sources /etc/apt/sources.list.d/gfx906.sources.disabled; \
         fi; \
         apt-get update; \
       fi \
    && apt-get install -y --no-install-recommends \
         ca-certificates \
         git \
         curl \
         wget \
         jq \
         aria2 \
         python3-venv \
         libglib2.0-0 \
         libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /comfyui
COPY comfy/ /comfyui/
COPY extra-pip.sh /tmp/extra-pip.sh

RUN chmod +x /comfyui/entrypoint.sh /tmp/extra-pip.sh \
    && python3 -m pip install huggingface_hub modelscope yq -r /comfyui/requirements.txt \
    && if [ -f /comfyui/manager_requirements.txt ]; then \
         python3 -m pip install -r /comfyui/manager_requirements.txt; \
       fi \
    && bash /tmp/extra-pip.sh \
    && rm -f /tmp/extra-pip.sh

ENTRYPOINT ["/comfyui/entrypoint.sh"]
