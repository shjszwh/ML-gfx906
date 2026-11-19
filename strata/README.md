# Strata gfx906

[Strata](https://github.com/Niko1221/Strata) inference image for AMD `gfx906`.
The engine and the GPU picture reader (`strata-vision-hip`) are built from
source into the image; model weights are downloaded separately.

## Build

Requires Docker Buildx and a ROCm base image that still ships gfx906 kernels
(see [ROCm](../rocm/README.md)); the current image builds on
`docker.io/mixa3607/rocm-gfx906:10.1-complete`.

The recipe is the gfx906 source build of
[`docs/AMD_HIP.md`](https://github.com/Niko1221/Strata/blob/v0.2.16/docs/AMD_HIP.md):
`-DSTRATA_HIP_GFX906=ON` on `engine/`, the HIP reader from
`terminal/tools/vision`, both packaged with `tools/packaging/package_engine.py`.
`build-context/patch/v0.2.16.patch` adds the two HIP stream-priority aliases the
compat layer still misses and `gfx906` to the architectures the Terminal accepts.

Log in to the destination registry and run from this directory:

```bash
export STRATA_IMAGE=registry.arkprojects.space/apps/strata-gfx906
export STRATA_CMAKE_HIP_FLAGS="-mllvm -amdgpu-sched-strategy=max-ilp"
./build-and-push.image.sh
```

## Run

[upstream Docker documentation](https://github.com/Niko1221/Strata/blob/v0.2.16/docs/DOCKER.md).
