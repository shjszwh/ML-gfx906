# Strata gfx906

[Strata](https://github.com/Niko1221/Strata) inference image for AMD `gfx906`.
The engine and a picture reader are built from source into the image; model
weights are downloaded separately.

## Build

Requires Docker Buildx and a ROCm base image that still ships gfx906 kernels
(see [ROCm](../rocm/README.md)); the current image builds on
`docker.io/mixa3607/rocm-gfx906:10.1-complete`.

The recipe is the gfx906 source build of
[`docs/AMD_HIP.md`](https://github.com/Niko1221/Strata/blob/v0.2.16/docs/AMD_HIP.md):
`-DSTRATA_HIP_GFX906=ON` on `engine/`, a reader from `terminal/tools/vision`,
both packaged with `tools/packaging/package_engine.py`.
`build-context/patch/v0.2.16.patch` adds the two HIP stream-priority aliases the
compat layer still misses and `gfx906` to the architectures the Terminal accepts.

`STRATA_PICTURE_READER` picks the reader the component carries:

| Value | Reader in the package | Use |
| --- | --- | --- |
| `cpu` (default) | `strata-vision` | Pictures are read on the processor |
| `gpu` | `strata-vision-hip` | `terminal/tools/vision` with `STRATA_VISION_HIP` |
| `both` | both programs | Upstream's AMD package layout |

`cpu` is the default because the reader the Terminal picks is the CPU one on a
card under 24 GB of VRAM, and gfx906 cards are 16 GB (MI50, Radeon VII) or 32 GB
(MI60); upstream also checks pictures on no gfx906 card. A package with only
`strata-vision-hip` makes the Terminal turn pictures off on a 16 GB card (its
`Pictures could not be switched on` line), so the CPU reader is required, not
optional, and the build fails when the reader it was asked for is missing.

That first hunk is an upstream fix sent as a pull request (branch
`fix/gfx906-stream-priority` of the `shjszwh/mi50-Strata` fork). Once it is
merged, `v0.2.16.patch` stops applying and
`build-context/patch/v0.2.16-setup-only.patch` (the arch hunk alone) is used
instead; the build picks whichever of the two applies and fails when neither
does. After the merge, set `STRATA_PATCH` to the setup-only patch and delete the
combined one.

Log in to the destination registry and run from this directory:

```bash
export STRATA_IMAGE=registry.arkprojects.space/apps/strata-gfx906
export STRATA_CMAKE_HIP_FLAGS="-mllvm -amdgpu-sched-strategy=max-ilp"
./build-and-push.image.sh
```

## Run

[upstream Docker documentation](https://github.com/Niko1221/Strata/blob/v0.2.16/docs/DOCKER.md).

### Pictures

Pictures are on by default and read on the CPU: `strata-vision` needs nothing
from the ROCm runtime, takes no VRAM from the experts (the GPU reader keeps about
1-1.4 GB) and costs a few seconds per picture instead of a fraction of one.

- `VISION=cpu` (or `strata launch --vision cpu`) forces the CPU reader;
  `VISION=off` turns pictures off; `VISION=on` takes the Terminal's default.
- The reader weights (`mmproj`, about 0.9 GB) must be in the model folder given as
  `MODEL_PATH`, and their name must match the family: `qwen` reads
  `mmproj-Qwen3.8-Flash-Next-BF16.gguf`, `swift` reads
  `mmproj-Swift-Qwen3.8-Flash-Next-BF16.gguf`, and Unsloth's `mmproj-F16.gguf` is
  accepted as an alternative. Setup stops with `is missing` instead of
  downloading when the files are given (a read-only mount), so a
  `looks like swift ..., not qwen` warning at start means the family and the
  `mmproj` name disagree.
- The CPU reader is built for an AVX2 baseline (its kernels pick a tier at run
  time), so the machine must be Haswell or newer. An older CPU needs
  `-DSTRATA_PORTABLE=OFF -DSTRATA_ISA_FLOOR=avx` on the CPU build in the
  Dockerfile.
- A running container keeps its prepared settings: after this reader appears,
  the Terminal re-runs setup because the saved settings still say pictures are
  off. When it does not, start once with `VISION=cpu`.
