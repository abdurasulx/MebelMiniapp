# Hunyuan product quality audit — 2026-10-24

## Confirmed fault

The catalogue office-chair image and foreground mask both contain the base and
casters. Hunyuan's raw geometry also contains them. Applying the old plane filter
to **the same generated mesh** removes support/caster geometry. This isolates a
post-processing fault from random sampling differences.

The old filter searched all XYZ axes, removed a wide band of faces around its
selected plane, and retained only the largest component. The replacement limits
floor candidates to oversized low horizontal sheets reaching the normalized
extraction-box boundary and retains all remaining support components. This is
still a heuristic; unmodified raw geometry is archived for review.

| Same raw mesh comparison | Faces | Minimum Y |
|---|---:|---:|
| Raw, including generated floor | 1,685,782 | -0.744804 |
| Previous filter | 582,361 | -0.604425 |
| New conservative floor cleanup | 648,796 | -0.744804 |

The old result loses the lowest parts of the chair; the new cleanup preserves
its original Y extremes while removing the generated sheet. Rendered comparisons
show the casters preserved in the new result.

## Configuration and paint changes

- Full Hunyuan3D-Shape 2.1 checkpoint, not a turbo checkpoint. Source revision:
  `82920d643c0dc2f7bfd7255f45f62d386edfe60c`.
- Explicit steps 50, guidance 5, seed 1234; extraction resolution 384 → 512.
- Texture generation reference resolution 448 → 512; 6 selected views and 4K atlas.
- Disabled upstream paint's implicit 40,000-face remesh.
- Explicit texture preparation limit 200,000 faces with a bounds-loss guard.
- Full raw, cleaned and texture-input meshes/configuration retained privately.
- Result quality remains needs_review; a completed render is not automatic product approval.

## Live end-to-end PBR test

The same foreground image was submitted with AI/background removal disabled for
this controlled geometry comparison. The AI path was tested separately below.
Target height was 115 cm; width/depth inputs were reference checks, with uniform
scaling (fit_dimensions=0), so exact three-axis fitting was not requested.

- Job: `df6c4ff29b`; status done / 100%; textured=true.
- Download: HTTP 200, valid glTF header, 8,055,840 bytes.
- Actual GLB extents: 72.259 × 115.000 × 75.192 cm.
- 200,000 faces, 2 textures, 2 embedded images; floor Y=0.0.
- Bundled model-viewer loaded the actual textured GLB without JavaScript errors.
- Render inspection: base, supports and casters remain visible after texturing.
- Hardware: RTX 4070 Ti, 12 GB; observed paint GPU usage about 11.6 GB.
- A progress GET timed out during a heavy CPU/native step; later polling recovered
  and the job completed. Worker/process isolation for consistently responsive
  progress under CPU load remains an operational improvement.

## Intake and automated checks

35 tests passed in the actual Ubuntu conda environment: geometry/scale/texture
preservation, malformed dimensions, crop validation, disconnected supports,
floor cleanup, excessive simplification rejection, completed history and JSON
recovery/conflict handling.

Live AI test accepted the clear office-chair image. The covered top-down image
was rejected due to malformed/conflicting gateway JSON; this does **not** prove
that the model semantically rejected it as unsuitable. Explicit
reconstruction_ready=false rejection is covered by regression tests and the new
prompt requests that decision. Complete product visibility still needs review.

The gateway sometimes concatenates a truncated response with a final JSON
object. The parser can recover exactly one complete, unambiguous result and
records response_format_recovered. Conflicting complete objects are rejected.
No automatic extra paid request is made.

Ten completed/error jobs were preserved during the final module reload. Queued
and running jobs are still not durable across a restart. The queue was checked
idle before each reload. Credentials were not changed or committed.

## Limits

The test source photo is only 438 × 456 pixels and cannot establish unseen
geometry or real-world measurements. PBR can invent surface details. This patch
fixes demonstrated geometry destruction; it does not certify a CAD/measurement
reconstruction. Native iOS LiDAR quality is a separate unresolved issue.

Sources:

- [Hunyuan3D 2.1 and reference VRAM requirements](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1)
- [Upstream paint mesh simplification](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1/blob/main/hy3dpaint/utils/simplify_mesh_utils.py)
