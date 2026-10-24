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

## GLB generation — blocked, not tested in this run

GET /v1/models with the supplied key returned HTTP 200. The AI Gateway returns analysis JSON; actual GLB generation belongs to the separate GPU converter at 100.90.116.106:5000. No public /v1 GLB generation endpoint was established by this test.

Ubuntu TCP 22 and 5000 timed out. Local Windows Tailscale is Running as a service but CLI reports NoState. Restart-Service failed due to insufficient service privileges. The fallback SSH proxy port 2222 also timed out; domain port 22 belongs to the VPS, not Ubuntu. No new GPU generation jobs were submitted, and no new GLB files were produced or validated in this run.

To finish: restore Tailscale, submit each original image set to /api/convert (multi-view roles front,right,back), monitor /api/jobs, download result GLB, and independently verify glTF header, scene extents, floor placement and viewer loading. Supply measured dimensions if physical size matters.
