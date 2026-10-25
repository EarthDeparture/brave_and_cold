"""Validate actual GLB bytes, then copy only this original, verified tree family."""
from pathlib import Path
import argparse, hashlib, json, shutil
import numpy as np
from validate_field_survival_kit import read_glb, transform

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/blender/generated/winter_tree_diversity_v1"
DEST = ROOT / "brave-and-cold/assets/environment_detail/tree_diversity"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    manifest = json.loads((SOURCE / "manifest.json").read_text())
    assert sha(SOURCE / "winter_tree_library.blend") == manifest["native_sha256"]
    texture = json.loads((SOURCE / "texture_provenance.json").read_text())
    assert sha(SOURCE / "winter_twigs.png") == texture["sha256"]
    for name, digest in texture["bark_textures"].items(): assert sha(SOURCE / name) == digest
    assert sha(SOURCE / "winter_boughs_far.png") == texture["far_bough_sha256"]
    results = {}
    assert len(manifest["models"]) == 10
    for entry in manifest["models"]:
        path = SOURCE / (entry["name"] + ".glb")
        assert sha(path) == entry["sha256"], path
        raw, gltf, values = read_glb(path)
        assert len(gltf["meshes"]) == 1 and len(gltf["meshes"][0]["primitives"]) == 1
        assert not gltf.get("animations") and not gltf.get("skins")
        assert all(np.max(np.abs(transform(n) - np.eye(4))) < 1e-7 for n in gltf["nodes"])
        primitive = gltf["meshes"][0]["primitives"][0]
        attrs = primitive["attributes"]
        assert all(a in attrs for a in ["POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"])
        p, n, uv, color = (values(attrs[a]) for a in ["POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"])
        accessor = gltf["accessors"][attrs["COLOR_0"]]
        if accessor.get("normalized"):
            color = color.astype(float) / {5121: 255, 5123: 65535}[accessor["componentType"]]
        assert all(np.isfinite(a).all() for a in [p, n, uv, color])
        assert np.max(abs(np.linalg.norm(n, axis=1) - 1)) < .005
        needles = (color[:, 3] > .55) & (color[:, 3] < .8)
        assert abs(uv).max() <= 32 and (not needles.any() or (uv[needles].min() >= -1e-6 and uv[needles].max() <= 1.00001))
        assert p[:, 1].min() >= -1e-6 and .99 <= p[:, 1].max() <= 1.03
        root = p[abs(p[:, 1]) < 1e-7][:, [0, 2]]
        assert len(root) >= 4 and np.linalg.norm(root.mean(axis=0)) < .0001
        assert np.all(np.min(abs(color[:, 3, None] - np.array([.10, .18, .65, .72, 1])), axis=1) < .002)
        idx = values(primitive["indices"]).astype(int).ravel()
        assert len(idx) % 3 == 0 and 0 <= idx.min() and idx.max() < len(p)
        triangles = p[idx].reshape((-1, 3, 3))
        area = np.linalg.norm(np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0]), axis=1)
        assert np.min(area) > 1e-12, (entry["name"], "degenerate triangle", float(area.min()))
        count = len(triangles)
        assert count == entry["triangles"] and count <= (1100 if entry["lod"] else 4200)
        assert np.any(color[:, 3] < .25) and 1 in np.round(color[:, 3], 2)
        results[entry["name"]] = {"triangles": count, "dimensions_unit_m": list(p.max(axis=0) - p.min(axis=0)), "bounds_godot": [list(p.min(axis=0)), list(p.max(axis=0))], "one_identity_mesh": True, "finite_unit_normals": True, "degenerate_triangles": 0, "bytes": len(raw), "sha256": sha(path)}
    for family in {r["family"] for r in manifest["models"]}:
        a, b = results[family]["bounds_godot"], results[family + "_far"]["bounds_godot"]
        # Matched crown envelope; close branch sprays may extend slightly beyond
        # the coarse crossed boughs. A wholly different far silhouette fails.
        assert np.max(abs(np.array(a) - np.array(b))) < .035, (family, a, b)
    report = {"schema": 1, "static_glb_validation": "passed", "native_digest_verified": True, "original_atlas_digest_verified": True, "assets": results}
    (SOURCE / "validation.json").write_text(json.dumps(report, indent=2) + "\n", newline="\n")
    return report


def admit(report):
    DEST.mkdir(parents=True, exist_ok=True)
    files = ["winter_twigs.png", "winter_boughs_far.png", "winter_bark.png", "winter_bark_normal.png", "manifest.json", "texture_provenance.json", "validation.json"] + [name + ".glb" for name in report["assets"]]
    originals = list((ROOT / "brave-and-cold/assets/environment_detail/trees").glob("*.glb"))
    originals += list((ROOT / "brave-and-cold/assets/models/trees").glob("spruce*.glb"))
    unchanged = {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p) for p in originals}
    roster = {}
    for name in files:
        src, dest = SOURCE / name, DEST / name
        digest = sha(src)
        if dest.exists():
            # Re-authoring iterations are allowed only inside this named package.
            assert dest.resolve().is_relative_to(DEST.resolve())
        shutil.copy2(src, dest)
        assert sha(dest) == digest
        roster[name] = digest
    receipt = {"schema": 1, "origin": "Original local Blender/Pillow asset family, not an external provider package", "authoring_path": str(SOURCE.relative_to(ROOT)).replace("\\", "/"), "destination": str(DEST.relative_to(ROOT)).replace("\\", "/"), "policy": "10 single-mesh near/far GLBs, rooted 1m source scale, no colliders, <=4200/1100 triangles, original 1024px alpha atlas", "static_validation": "passed", "copied_hashes": roster, "preserved_original_tree_hashes": unchanged, "engine_import_and_art_review": "Recorded separately in engine_validation.json and review.md"}
    (DEST / "admission_receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", newline="\n")
    for name, digest in unchanged.items():
        assert sha(ROOT / name) == digest
    print("WINTER_TREE_ADMIT_VERIFIED", len(files), "files; original meshes retained")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--admit", action="store_true")
    args = parser.parse_args(); report = validate()
    print("WINTER_TREE_STATIC_PASS", len(report["assets"]), "actual GLBs")
    if args.admit:
        admit(report)
