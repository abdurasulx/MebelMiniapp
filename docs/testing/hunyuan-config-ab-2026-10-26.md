# Configuration and photo-count comparison

Status as of 2026-10-27: ten shape outputs inspected; five higher-memory paint
attempts failed as described below. Two 640-resolution paint tests were launched
on Ubuntu, but their final status has not been retrieved because the host is
offline. Do not label those tests passed or failed until the results are read.

## Method

Frozen RGBA masks, seed 1234, shape resolution 512, chunks 8000, unchanged
foreground extraction and cleanup. No measured dimensions supplied. Display
meshes were uniformly normalized to height 1 and simplified to 200,000 faces.
These extents are dimensionless ratios, not real-world measurements.

Current set uses job `4197cae4e1`; bed uses `0f1af337d7`; green settee uses
`ae428088c6`. Three shape baselines reuse stored raw meshes; seven were newly
generated. Both front and back views were rendered using the same camera,
lighting and neutral material. Masks and their SHA-256 hashes are in the local
experiment results. No AI intake was rerun, avoiding changing crops/prompts.

## Geometry

| Subject / model | Steps / guidance | X:Y:Z at Y=1 | Finding |
|---|---|---|---|
| Current set, 3 views, 2mv | 50 / 5 | 3.129:1:3.395 | Baseline; rear division represented |
| Current set, 3 views, 2mv | 50 / 3 | 3.099:1:3.404 | Small surface changes; proportion issue remains |
| Current set, 3 views, 2mv | 80 / 3 | 3.119:1:3.412 | No clear overall improvement |
| Current set, 1 view, 2.1 | 50 / 5 | 3.033:1:3.038 | More irregular pouf bases and arm geometry |
| Current set, 1 view, 2.1 | 80 / 3 | 2.977:1:2.969 | Smoother parts but still nearly square footprint |
| Bed, 1 view, 2.1 | 50 / 5 | 1.526:1:1.504 | Headboard and matching furniture retained |
| Bed, 1 view, 2.1 | 80 / 3 | 1.533:1:1.513 | Side details become softer; no clear gain |
| Green settee, 1 view, 2.1 | 50 / 5 | 0.988:1:2.059 | Baseline approximate shape |
| Green settee, 1 view, 2.1 | 80 / 3 | 1.007:1:2.121 | Leg/support changes; no demonstrated faithful reconstruction |
| Current set, 1 view, 2mv | 50 / 5 | 3.434:1:3.802 | Same-model photo-count control: rear falsely continuous |

The same-model control is important: 2.1 single-image versus 2mv multi-image
alone confounds architecture with photo count. With 2mv held constant, adding
the back/side images recovers the split rear structure visible in the original
photo. However, none of the tested settings restores the held-out 380:260
footprint ratio. View labels were approximate because the source photos are
oblique; camera geometry and occlusion remain limitations.

## Texture attempts on frozen geometry

Baseline paint was already verified on the current set and green settee:
6 views, 512 input resolution, 4096 texture atlas, 200,000 faces.

| Configuration | Subject | Result |
|---|---|---|
| 6 views, 768 | Current set | CUDA out of memory |
| 8 views, 512 | Current set | CUDA out of memory |
| 6 views, 768 | Green settee | CUDA out of memory |
| 6 views, 768, model CPU offload | Current set | CPU/CUDA device mismatch during custom VAE encode |
| 6 views, 768, model CPU offload | Green settee | Same device mismatch |
| 6 views, 640 | Current set and green settee | Launched; result not yet retrieved |

The stock `enable_model_cpu_offload()` method cannot be assumed compatible
with this custom Hunyuan pipeline. None of the failed settings was promoted
to production. Existing 50-step/guidance-5 geometry remains the default;
increased steps did not demonstrate a general quality improvement.

## Upload-role correction

Source now rejects missing, partial, duplicate or invalid roles for multiple
images instead of assigning roles from upload order. Web selectors start with
an explicit empty choice; single-image scanner requests remain compatible.
Ten new policy tests pass locally. Full local suite: 52 passed, two dependency
failures (`fast_simplification`, `rembg` missing on Windows). Previous unchanged
44-test suite passed on Ubuntu. New source has not yet been deployed to Ubuntu.
An isolated browser check also passed: blank and duplicate roles prevent
submission, and explicit front/back roles are sent in the selected order.

At 08:51 on 2026-10-27 (Asia/Tashkent), local Tailscale was Running/Online and
the VPS responded directly. Ubuntu was reported Offline, last seen 08:38:12;
Tailscale ping and TCP ports 22/5000 timed out. Domain port 2222 also timed out.
This does not distinguish power loss, suspend, LAN failure or a stopped
Tailscale daemon. No remote repair or deployment is claimed.

## Reproduction and evidence

`services/img3dconverter/benchmark_shapes.py` takes a manifest and resumes
finished outputs. `benchmark_textures.py` reproduces paint variants. These are
offline experiments for an idle GPU, not production queue workers. Do not run
them concurrently with live GPU jobs. They do not change production settings
or overwrite API history. An Ubuntu reboot interrupted the first batch;
finished meshes were reused on resume.

Local artifacts: `D:/MebelMiniapp/artifacts/config-ab-2026-10-26/`.
Remote output: `/home/banda/Desktop/imageto3d/3dfiles/Config_AB_20261026/`.
Viewer files have `-front.png` and `-back.png` suffixes.

References: [Hunyuan 2mv](https://huggingface.co/tencent/Hunyuan3D-2mv),
[Hunyuan 2.1](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1),
[Diffusers memory guidance](https://huggingface.co/docs/diffusers/optimization/memory).
