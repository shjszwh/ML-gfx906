#!/usr/bin/env bash
# DeepSeek-V4.1-Flash for gfx906. Upstream Strata does not build strata-dsv41
# on this architecture until https://github.com/Niko1221/Strata/pull/5739 is
# merged, so this preset clones that branch. No commit is pinned: the build
# clones the head of STRATA_BRANCH, so it always picks up the latest code.
# llama.cpp is vendored in the branch tree (third_party/strata-ggml and
# third_party/strata-llama); nothing is downloaded.

export STRATA_ROCM_VERSION="10.1"
export STRATA_REPO="https://github.com/shjszwh/mi50-Strata.git"
export STRATA_BRANCH="gfx906-dsv41"
export STRATA_PATCH="empty.patch"
export STRATA_BUILD_DSV41="1"
export STRATA_PRESET_NAME="deepseek41-rocm-${STRATA_ROCM_VERSION}"
