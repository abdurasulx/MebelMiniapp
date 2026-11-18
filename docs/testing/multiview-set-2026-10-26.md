# Three-view furniture set test — 2026-10-26

User requested one textured GLB from three photographs, without supplying the
known 260 / 380 / 99 cm dimensions to the API. Those values were held out.

## Request and evidence

- API: `/api/convert`, `reconstruction_scope=set`, `roles=front,back,right`.
- Photograph order: second image as front, first as back, third as right.
  These are oblique photographs; the view labels are approximate.
- `ai_prepare=1`, `remove_bg=1`, `textured=1`, `fit_dimensions=0`.
- No height, width or depth fields were sent.
- Shape: Hunyuan3D-2mv, 50 steps, seed 1234, resolution 512.
- Texture: Hunyuan3D-2.1 paint, front image only; additional images condition
  geometry, not texture directly. Mesh reduced to 200,000 faces before paint.
- Successful job: `4197cae4e1`.
- Output: `http://100.90.116.106:5000/files/Multiview_test_20261026/multiview-set.glb`.
- GLB: 7,675,036 bytes, two embedded images and two textures, base-color texture
  present. Model-viewer loaded successfully with no JavaScript errors.
- Actual GLB XYZ extents: 265.92 × 85.00 × 288.54 cm; minimum Y is zero.
  Intake AI declined to estimate dimensions. The existing fallback height
  estimator supplied 85 cm with confidence 0.27. These are not measurements.

Local evidence is under `D:/MebelMiniapp/artifacts/multiview-set-2026-10-26/`:
request/status JSON, GLB, front/back previews and viewer validation JSON.

## Visual result

The L-shaped sofa, rectangular table and two round ottomans are recognizable
in one scene. The back view also resembles the reference arrangement. No large
room-floor sheet is visible in the inspected views. However, fabric becomes
smooth and glossy, cushions/backrests have texture artifacts, table veining
is exaggerated, flowers are retained, and sofa proportions differ. The two
horizontal extents are nearly equal despite the supplied reference dimensions
having a substantially longer side. Axis swapping alone cannot explain this.
This is a useful preview, not a faithful catalogue asset. There was no matched
single-view control of this exact set, so this test does not establish a
quantitative improvement from multiple views alone.

## Memory failure and fix

First attempt `24dc84dbbe` completed shape but the kernel killed Python at paint
initialization (2026-10-26 11:58:27 server clock). Kernel log confirmed global
OOM; Python anonymous RSS was approximately 26.7 GB on a 32 GB machine.
Both shape checkpoints had remained resident on CPU.

Shape pipelines now load lazily and all local/global pipeline references are
released before paint and on job cleanup. The retry completed with textures.
The service was restored in its existing tmux session. All 44 existing remote
tests passed; Python compilation and `git diff --check` passed. This is one
successful live memory regression check, not a prolonged concurrency test.
Interrupted running jobs are still not durably recovered by the API.

## Provisional capture protocol, not an approved production standard

1. Keep the whole set stationary, with all intended pieces visible. Remove
   unrelated furniture/decor where practical; foreground extraction is not
   reliable semantic instance selection.
2. Capture front, back, left and right at similar height, distance and lighting;
   avoid tilted ultra-wide views and cropped edges. The official 2mv API uses
   named view roles: https://huggingface.co/tencent/Hunyuan3D-2mv .
3. Preserve source photos and inspect extracted masks before generation.
4. Review GLB from all sides for missing pieces, merged geometry, artifacts,
   material appearance and layout. Completion alone does not pass quality.
5. Add measured dimensions only after this blind geometry assessment; scaling
   must not be used to conceal incorrect shape. Compare several different sets
   and a single-view control before adopting a production standard.
