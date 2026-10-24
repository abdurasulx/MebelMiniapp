# Furniture AI live API tests — 2026-10-24

Model: `sable-3.5`. API: `https://api.burchaksoft.uz/v1/chat/completions`. Authentication succeeded; no key is included in this report.

The existing furniture_ai.py analyze_and_prepare pipeline and deployed-copy system prompt were used. Four real requests, six image attachments total: three single-image tests and one three-view test.

| Test | Images | Success | Width × height × depth, cm | Estimated outer volume, m³ | Time, sec |
|---|---:|---|---|---:|---:|
| chair | 1 | Yes | 45 × 85 × 50 | 0.191250 | 82.77 |
| sofa | 1 | Yes | 90 × 85 × 85 | 0.650250 | 19.36 |
| editor-armchair | 1 | Yes | 75 × 85 × 75 | 0.478125 | 67.56 |
| sofa-multiview | 3 | Yes | 90 × 85 × 90 | 0.688500 | 27.27 |

All successful responses parsed as strict JSON; role lists and normalized bounding boxes validated. All dimensions were labeled low confidence and ai_estimate. Crops were saved as PNG. The three-view sample preserved front/right/back roles and each view was cropped.

## Accuracy check

The sofa supplier lists 105 × 95 × 83 cm: outer volume 0.827925 m³. This reference was NOT provided in AI requests. Single-image prediction: 0.650250 m³ (21.46% below the listing). Three-view prediction: 0.688500 m³ (16.84% below the listing). Three views did not establish real-world scale. These are category estimates, not measured material volumes.

[Sofa source and dimensions](https://pascalfurniture.com/products/euro-single-seater-couch)
[Chair image source](https://cozylant.com/products/thor-oak-wood-chair)

## Live GPU converter tests after Tailscale recovery

The four original jobs finished without resubmission. An additional request used the iOS multipart format: one JPEG, 105 cm width, 83 cm height, 95 cm depth, ai_prepare=1, remove_bg=1, fit_dimensions=0, textured=1. All other jobs were textured=0.

| Case | Server state | GLB size | Actual GLB width × height × depth, cm | Viewer loaded |
|---|---|---:|---|---|
| chair | done | 3.61 MB | 116.0 × 85.0 × 113.4 | Yes |
| sofa | done | 18.10 MB | 117.6 × 85.0 × 103.8 | Yes |
| editor-armchair | done | 7.72 MB | 122.1 × 85.0 × 129.9 | Yes |
| sofa-multiview | done | 20.06 MB | 114.2 × 85.0 × 109.1 | Yes |
| ios-textured-flow | done | 2.82 MB | 115.1 × 83.0 × 94.4 | Yes |

Structural checks: HTTP 200 download, glTF magic, nonzero finite scene extents, Y floor placement, GLB extents matching server metadata within its 0.1 cm rounding precision. Sampled progress was monotonic; some polling was paused during the user-requested restart, so this is not a complete per-frame trace. Viewer tests use bundled model-viewer in Chromium, not an iPhone WKWebView build.

### Quality findings

File validity is not reconstruction accuracy. The wooden chair lost visible leg geometry; the editor screenshot also produced incomplete geometry. The sofa shapes were recognizable, but output dimensions differ from AI estimates. Uniform fitting matches only height and preserves generated aspect ratio; width/depth discrepancies are reported by the converter. These models are not validated for manufacturing measurements. All volumes here are outer bounding-box volumes, not material volumes.

### iOS-format textured request

Server state: done; stage: Tayyor.

Result note: AI: kreslo

### iOS button fix

The scan screen now captures a camera image before adding the marker. Create 3D immediately submits that image and scan dimensions, opens the new job detail, and prevents duplicate taps. Progress polling stays active when the detail destination is open. Swift syntax passed parser checks; native Xcode/device build remains unverified. API contract testing does not establish that LiDAR measurements are accurate.

Textured output verification: 2 embedded images, 2 textures, 1 material, baseColorTexture present. The rendered preview has visible texture artifacts on one armrest; file/viewer success is not production-quality acceptance.

Automatic scan submission fix pushed as fcac684. No native iOS build was available in this Windows environment.
