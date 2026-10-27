"""Paired paint settings on frozen geometry; follows benchmark_shapes output."""
import json
import argparse
import tempfile
import time
import traceback
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cpu-offload", action="store_true")
    parser.add_argument("--balanced", action="store_true")
    args = parser.parse_args()
    import app as runtime
    import trimesh

    root = Path(runtime.OUT_DIR) / "Config_AB_20261026"
    jobs = Path.home() / ".local/share/imageto3d/jobs"
    while True:
        rows = json.loads((root / "results.json").read_text())
        if len(rows) >= (10 if args.cpu_offload else 9) and all(r["status"] != "running" for r in rows):
            break
        time.sleep(20)
    results = []
    experiments = [
        ("current-detail768", "4197cae4e1", 6, 768),
        ("current-coverage8", "4197cae4e1", 8, 512),
        ("green-detail768", "ae428088c6", 6, 768),
    ]
    if args.cpu_offload:
        experiments = [("current-offload768", "4197cae4e1", 6, 768),
                       ("green-offload768", "ae428088c6", 6, 768)]
    if args.balanced:
        experiments = [("current-detail640", "4197cae4e1", 6, 640),
                       ("green-detail640", "ae428088c6", 6, 640)]
    result_file = root / ("texture-balanced-results.json" if args.balanced else
                          "texture-offload-results.json" if args.cpu_offload else "texture-results.json")
    for name, job, views, resolution in experiments:
        cfg = runtime.product_quality.settings()
        cfg.update(texture_views=views, texture_resolution=resolution)
        row = {"name": name, "status": "running", "profile": cfg,
               "source_job": job, "paint_seed": 0, "cpu_offload": args.cpu_offload}
        results.append(row)
        result_file.write_text(json.dumps(results, indent=2))
        start = time.time()
        print("START", name, flush=True)
        try:
            mesh = trimesh.load(jobs / job / "raw-shape.glb", force="mesh")
            mesh, _ = runtime.product_quality.remove_generated_floor(mesh)
            mesh, row["simplification"] = runtime.product_quality.texture_mesh(mesh, 200000)
            with tempfile.TemporaryDirectory() as temporary:
                work = Path(temporary)
                source = work / "input.obj"
                target = work / "textured.obj"
                mesh.export(str(source))
                runtime.get_paint_pipe(cfg)
                if args.cpu_offload:
                    runtime.paint_pipe.models["multiview_model"].pipeline.enable_model_cpu_offload()
                    runtime.free_gpu()
                runtime.paint_pipe(mesh_path=str(source), image_path=str(jobs / job / "front-mask.png"),
                                   output_mesh_path=str(target), use_remesh=False, save_glb=False)
                runtime.create_glb_with_pbr_materials(str(target), {
                    "albedo": str(work / "textured.jpg"),
                    "metallic": str(work / "textured_metallic.jpg"),
                    "roughness": str(work / "textured_roughness.jpg")},
                    str(root / (name + ".glb")))
            row.update(status="done", seconds=time.time()-start)
        except Exception as exc:
            traceback.print_exc()
            row.update(status="error", error=str(exc), seconds=time.time()-start)
        finally:
            runtime.unload_paint_pipe()
        result_file.write_text(json.dumps(results, indent=2))
        print("END", name, row["status"], flush=True)


if __name__ == "__main__":
    main()
