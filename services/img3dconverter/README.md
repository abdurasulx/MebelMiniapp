# Product image → GLB converter

Source snapshot for the running service at `/home/banda/Desktop/imageto3d`, port 5000.
This folder contains our integration, not the Hunyuan model repositories or weights.
Use the existing `hunyuan` conda environment and keep `Hunyuan3D-2.1/`,
`Hunyuan3D-2/`, `estimate_height.py` and model caches in place.

## Confirmed causes of missing chair geometry

The input office-chair background mask contained the legs and wheels. Hunyuan's
raw mesh also contained them, together with a generated floor sheet.

The previous `strip_ground()` searched for planes on **all three axes**, cut a
wide band around the selected plane, split the result, and retained only its
largest connected component. This removed wheels/support geometry near or below
the floor. Applying it to the same new raw mesh reproduced that loss.

The previous paint call also used the upstream default `use_remesh=True`, which
internally decimated to **40,000 faces**. It was not a named game/product model
mode: these were destructive integration and mesh-processing settings.

The replacement only considers low horizontal sheets that reach the normalized
Hunyuan extraction box and are substantially wider than the object above them.
It never keeps only the largest component. This remains a conservative heuristic,
not semantic proof that a surface is a floor; raw geometry is retained for review.

## Current settings

`hunyuan_product.json` is the explicit, validated configuration:

| Setting | Before | Current |
|---|---:|---:|
| Shape inference steps | 50 implicitly | 50 explicitly |
| Shape guidance | 5 implicitly | 5 explicitly |
| Shape extraction resolution | 384 | 512 |
| Seed | random | 1234 |
| Arbitrary plane cut / largest component | enabled | removed |
| Paint reference resolution | 448 | 512 |
| Paint selected views | 6 | 6 |
| Texture atlas | 4096 | 4096 |
| Hidden paint remesh | 40,000 faces | disabled |
| Explicit texture mesh limit | — | 200,000 faces |

The full raw mesh is retained. UV/texture preparation uses an explicit bounded
mesh for GPU/atlas memory and rejects simplification that moves the bounds by
more than 1% of the original extents. It does not claim to detect every lost detail.

The RTX 4070 Ti has 12 GB VRAM. The upstream reference lists 10 GB for shape and
21 GB for paint, so this installation uses CPU offload and a restrained paint
profile. Raising the 4K atlas alone cannot recover missing geometry or details
not visible in the source photograph.

Sources:

- [Hunyuan3D 2.1 usage and GPU requirements](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1)
- [Upstream mesh simplification](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1/blob/main/hy3dpaint/utils/simplify_mesh_utils.py)

## Traceability and quality

Each new job retains private inputs, per-view foreground masks, `raw-shape.glb`,
`clean-shape.glb`, `texture-input.glb` when applicable, and `quality.json` below
`~/.local/share/imageto3d/jobs/<id>/`. API result `quality` reports the actual
configuration, mesh bounds/counts, cleanup and simplification metrics. Results
remain `needs_review`; completion is not automatic catalogue approval.

The AI prompt asks whether the complete product is visible. An explicit
`reconstruction_ready:false` stops generation rather than reconstructing a
guessed cloth-covered object. A truncated gateway prefix can be recovered only
if exactly one complete, unambiguous furniture JSON result follows; conflicting
complete results are rejected. Such recovery is recorded in the analysis.

Completed/error history is atomically saved in
`~/.local/share/imageto3d/completed-jobs.json`, mode 600. Existing completed jobs
were preserved before restarting. **Queued/running job recovery is still not
implemented.** Tailscale owner authentication is preserved; this is not a public
multi-user API.

AI credentials remain exclusively in `~/.config/imageto3d/ai.json` or the server
environment. No API key belongs in this folder or the mobile app.

## Checks and deployment

```sh
cd /home/banda/Desktop/imageto3d
/home/banda/miniconda3/envs/hunyuan/bin/python -m pytest -q \
  test_scale_model.py test_furniture_ai.py test_product_quality.py
```

44 tests passed on the actual Ubuntu environment. Live comparisons use the same
raw office-chair mesh before/after cleanup, so the support-loss finding is not
based on two unrelated random generations. See the audit report in
`../../docs/testing/hunyuan-product-quality-2026-10-24.md` for live results.

Copy integration sources/config into the existing service directory, compile/check
them, and restart the `imageto3d` tmux process only when its queue is idle. Keep
the private credential file, model repositories, model caches, original inputs
and `3dfiles/` results. The service starts with:

```sh
/home/banda/miniconda3/envs/hunyuan/bin/python -u app.py >> app.log 2>&1
```

## Showroom/set update — 2026-10-26

`POST /api/convert` now accepts `reconstruction_scope=single|set` (default single).
The web and iOS source provide that explicit selection. Set mode requests all
matching furniture pieces and preserves the complete frame before foreground
extraction. It is not a guarantee of a faithful multi-object reconstruction.

`hunyuan_product.json` selects `background_model=birefnet-general-lite`. The
214 MB ONNX model is downloaded by rembg on first use, so prewarm it before a
first production request. It runs on CPU and its session is released before
shape/paint. It fixed the tested headboard loss, but can retain plants/decor.

The private AI settings may specify `set_model` separately from `model`; this
installation uses sable-3.7 for sets. Both secrets and this private file remain
outside Git. Native `box_2d` coordinates are explicitly YXYX / 0–1000; legacy
normalized XYXY `bbox` is still supported. Unlabelled or conflicting coordinate
formats are rejected. See
`../../docs/testing/showroom-furniture-sets-2026-10-26.md` for six GLB tests and
remaining fidelity failures. New tests here were untextured geometry tests.

Shape pipelines now load lazily and are released before paint, including all
local and global references. Keeping the 2.1 and 2mv checkpoints offloaded on
CPU together caused a confirmed Linux OOM kill during paint initialization on
the 32 GB host. CPU offload frees VRAM but does not free system RAM. Each job
reloads its required shape checkpoint; this trades loading latency for memory.

Multiple-image requests must now specify one explicit role per image, without
duplicates and including `front`. Missing/partial roles return HTTP 400 instead
of being guessed from upload order. Single-image scanner requests still use
`front`. The web UI starts each multi-image selector at an empty choice.

See `../../docs/furniture-photo-submission.md` for the provisional capture
protocol and `../../docs/testing/hunyuan-config-ab-2026-10-26.md` for paired
configuration tests. The benchmark scripts run outside the production queue:
use only on an idle GPU. Failed high-memory settings are not production defaults.
