# Showroom furniture-set tests — 2026-10-26

User target: one complete matching furniture set per GLB. The four source photographs show different sets; they were NOT treated as multiview images of one object. The fifth attachment is a screenshot of a previous result, not a new reconstruction input. Its actual stored original and mask were retrieved from job 2e83c9b723.

## Baseline findings

Current single-object AI intake accepted the bed and sectional-with-round-ottomans inputs, and rejected the table set and showroom set as ambiguous. A preliminary set prompt on sable-3.5 produced malformed/inconsistent responses in three of four cases. Native grounding protocol on sable-3.7 accepted all four and listed the expected set members, including the three ottomans in image 4. These small samples do not establish general model accuracy.

For controlled Hunyuan tests, original photographs were foreground-masked with the old model, then uploaded as alpha PNG with ai_prepare=0, remove_bg=0, textured=0. This isolates mask-to-geometry behavior. Manual target heights were 120 cm for the baseline bed and 95 cm for the other baselines, for visualization only; they are not measured dimensions.

| Image | Case / job | File size | Structural GLB check | Visual result |
|---|---|---:|---|---|
| 1 | bed / e520f63ef7 | 36.5 MB | valid, loads | Headboard removed by old foreground mask; absent in GLB. A generated floor remained. |
| 2 | sofa_round_poufs / d9f3af304a | 30.6 MB | valid, loads | Sectional and both round ottomans remain recognizable; large unwanted floor/sheet remains. |
| 3 | sofa_table / ed986df518 | 34.2 MB | valid, loads | Table and two ottomans appear, but sectional layout/back geometry differs; unwanted sheets/spikes remain. |
| 4 | sofa_showroom / bb25d7288c | 29.5 MB | valid, loads | Sofa, table and three ottomans appear; a plant and generated floor remain, with layout/shape differences. |

All four files downloaded with a glTF header, finite scene extents and Y floor placement, and loaded in bundled model-viewer. Multiple rendered angles were inspected. File validity is separate from product fidelity. No baseline was marked as catalogue-quality acceptance.

## Confirmed preprocessing faults

1. Old foreground extraction removed the entire bed headboard before Hunyuan saw it. BiRefNet General Lite retained it, along with the bed frame and bedside-table region.
2. AI group boxes could omit the full-width front bench. Set mode now keeps the full image until foreground extraction rather than clipping matching pieces.
3. Gemini grounding uses explicit box_2d YXYX coordinates scaled to 0–1000. The old parser required bbox XYXY in 0–1. The new parser accepts the explicitly labelled native field, converts it once, and rejects invalid/conflicting formats; it never guesses units from an unlabelled array.
4. General foreground extraction still retains salient decorations such as plants. A better foreground model is not semantic instance selection.
5. The conservative generated-floor remover does not remove every floor or vertical sheet in complex sets. It was not loosened to indiscriminately delete flat furniture surfaces.

## Corrected public-API tests

The service was updated while its queue was idle. Two complete requests used AI analysis and foreground extraction (not precomputed masks):

| Case | Scope | Job | Target height | Actual GLB AABB, cm | Size | Result |
|---|---|---|---:|---|---:|---|
| bed-corrected | set | 0f1af337d7 | 140.0 | 213.6 × 140.0 × 210.6 | 41.1 MB | Headboard returned; overall bed set recognizable. Hidden support details are still inferred. |
| yesterday-corrected | single | 9302d50926 | 78.9 | 78.0 × 78.9 × 162.5 | 19.6 MB | Large rectangular backdrop absent; curved sofa recognizable. Shape/leg details remain approximate. |

Both corrected files loaded without JavaScript errors. These tests intentionally used textured=0 because the failures being assessed are geometry/foreground failures. No new PBR fidelity or native iOS rendering result is claimed. The old green-sofa screenshot had textures; its corrected comparison is untextured.

For the green-sofa comparison, the previous height target 78.918 cm and the original width/depth reference values were retained with fit_dimensions=0. AABB X/Z are model axes and should not be treated as ground-truth semantic width/depth without orientation alignment. No tape measurements or calibration were provided.

## Changes deployed

- Explicit reconstruction_scope=single|set in the API and web form. Omitted scope remains single for backwards compatibility.
- Separate optional private set_model setting; this installation uses sable-3.7 for sets and retains its existing single-object model. API credentials remain private.
- Explicit native grounding coordinate parsing and group-aware prompt.
- Foreground model changed to birefnet-general-lite on CPU, loaded lazily and released before shape/paint to bound RAM. Very low alpha noise is removed; disconnected set pieces are preserved.
- iOS source has a shared Single furniture / Whole set selector and persists optional request scope without breaking old local history. A new iOS build is needed; no native Xcode/device build was available here.
- Existing shape settings (50 steps, guidance 5, seed 1234, extraction 512) and conservative geometry cleanup remain unchanged.

44 regression tests passed on the actual Ubuntu environment. Python compilation and Swift syntax parsing passed. The running API rejected an invalid scope before creating a job; the web form scope selector and successful set/single end-to-end requests were verified. Completed history was preserved during restart. Queue recovery across a restart is still not implemented.

## Remaining product blockers

Complex furniture sets from one image still show invented backs/planes, furniture-layout changes, missing/altered support details and unwanted decor. The corrective bed/sofa results are improvements, not evidence that every set is now a faithful product asset. Semantic instance masks, per-piece validation and additional views are needed for reliable matching-set reconstruction; simply raising polygon count or texture resolution does not resolve these observed errors.

Sources:

- [Gemini grounding coordinates](https://ai.google.dev/gemini-api/docs/image-understanding)
- [rembg supported foreground models](https://github.com/danielgatis/rembg)
