"""Offline paired shape experiment; run on an idle converter GPU.

Uses frozen RGBA masks and explicit parameters, without changing production
settings, calling intake AI, scaling to real dimensions or writing job history.
Manifest: {output_dir, cases: [{name, job_dir, roles, baseline?, variants}]}.
Each variant contains name, steps, guidance; seed/resolution remain fixed.
"""
import argparse
import hashlib
import json
import time
import traceback
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    out = Path(manifest["output_dir"])
    out.mkdir(parents=True, exist_ok=True)
    import app as runtime
    import trimesh
    from PIL import Image

    results_path = out / "results.json"
    previous = json.loads(results_path.read_text()) if results_path.exists() else []
    results = [r for r in previous if r["status"] == "done"
               and (out / (r["name"] + ".glb")).exists()]
    completed = {r["name"] for r in results}

    def save():
        temporary = out / "results.tmp"
        temporary.write_text(json.dumps(results, indent=2))
        temporary.replace(out / "results.json")

    for case in manifest["cases"]:
        folder = Path(case["job_dir"])
        images = {r: Image.open(folder / (r + "-mask.png")).convert("RGBA")
                  for r in case["roles"]}
        hashes = {r: hashlib.sha256((folder / (r + "-mask.png")).read_bytes()).hexdigest()
                  for r in images}
        multi = case.get("model") == "2mv" or len(images) > 1
        pipe = None
        variants = list(case["variants"])
        if case.get("baseline"):
            variants.insert(0, {"name": "baseline", "steps": 50, "guidance": 5.0,
                                "existing": case["baseline"]})
        for variant in variants:
            name = case["name"] + "-" + variant["name"]
            if name in completed:
                continue
            row = {"name": name, "status": "running", "variant": variant,
                   "masks_sha256": hashes, "roles": list(images), "seed": 1234,
                   "resolution": 512, "model": "2mv" if multi else "2.1"}
            results.append(row)
            save()
            start = time.time()
            print("START", name, flush=True)
            try:
                if variant.get("existing"):
                    mesh = trimesh.load(variant["existing"], force="mesh")
                else:
                    if pipe is None:
                        pipe = (runtime.get_mv_pipe() if multi else
                                runtime.Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(
                                    "tencent/Hunyuan3D-2.1"))
                        pipe.to("cuda")
                    mesh = pipe(image=images if multi else images["front"],
                                num_inference_steps=variant["steps"],
                                guidance_scale=variant["guidance"],
                                generator=runtime.torch.Generator().manual_seed(1234),
                                octree_resolution=512, num_chunks=8000)[0]
                row["raw"] = runtime.product_quality.mesh_info(mesh)
                mesh.export(str(out / (name + "-raw.glb")))
                mesh, row["cleanup"] = runtime.product_quality.remove_generated_floor(mesh)
                mesh, row["simplification"] = runtime.product_quality.texture_mesh(mesh, 200000)
                # Equal display height, not a claim of a real-world measurement.
                mesh.apply_scale(1.0 / mesh.extents[1])
                mesh.apply_translation([0, -mesh.bounds[0, 1], 0])
                mesh.export(str(out / (name + ".glb")))
                row.update(status="done", seconds=time.time()-start,
                           normalized_extents=mesh.extents.tolist())
            except Exception as exc:
                row.update(status="error", error=str(exc))
                traceback.print_exc()
            save()
            print("END", name, row["status"], flush=True)
        pipe = None
        runtime.mv_pipe = None
        runtime.shape_pipe = None
        runtime.free_gpu()


if __name__ == "__main__":
    main()
