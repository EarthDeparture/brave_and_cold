"""Preserve verified source, GPU reviews and a closed local package hash roster."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, hashlib, shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "tools/blender/generated/winter_tree_diversity_v1"
GAME = ROOT / "brave-and-cold"
REVIEW = GAME / "shots/tree_diversity"
DEST = GAME / "assets/environment_detail/tree_diversity"


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest = json.loads((OUT / "manifest.json").read_text())
    receipt = json.loads((DEST / "admission_receipt.json").read_text())
    assert sha(OUT / "winter_tree_library.blend") == manifest["native_sha256"]
    for name, digest in receipt["copied_hashes"].items():
        assert sha(DEST / name) == digest == sha(OUT / name), name
    for name, digest in receipt["preserved_original_tree_hashes"].items(): assert sha(ROOT / name) == digest
    previews = OUT / "previews"; previews.mkdir(exist_ok=True)
    gallery = json.loads((REVIEW / "gallery/engine_validation.json").read_text())
    assert gallery["live_shader"] == sha(GAME / "world/shaders/boreal_detail.gdshader")
    for capture in gallery["captures"]:
        name = Path(capture["file"]).name
        assert sha(REVIEW / "gallery" / name) == capture["sha256"]
        shutil.copy2(REVIEW / "gallery" / name, previews / name)
    comparisons = []
    for profile in ["baseline", "candidate"]:
        record = json.loads((REVIEW / profile / "manifest.json").read_text())
        for capture in record["captures"]:
            path = REVIEW / profile / Path(capture["file"]).name
            assert sha(path) == capture["sha256"]
            shutil.copy2(path, previews / (profile + "-" + path.name))
        shutil.copy2(REVIEW / profile / "manifest.json", OUT / (profile + "_world_review.json"))
        comparisons.append(record)
    base, candidate = comparisons
    measured = []
    for a in base["captures"]:
        b = next(c for c in candidate["captures"] if c["id"] == a["id"])
        assert a["eye"] == b["eye"] and a["target"] == b["target"] and a["hour"] == b["hour"] and a["fog_density"] == b["fog_density"]
        measured.append({"view": a["id"], "baseline_median_ms": a["median_ms"], "candidate_median_ms": b["median_ms"], "candidate_p99_ms": b["p99_ms"]})
    tests = {}
    for name, marker in [("runtime_test", "TREE_DIVERSITY_TEST failures=0"), ("environment_test", "ENVIRONMENT_DETAIL_TESTS failures=0"), ("log_gameplay_test", "RADIO_LOG_TEST failures=0")]:
        log = (OUT / (name + ".log")).read_text(encoding="utf-8")
        assert marker in log and "FAIL " not in log and "SCRIPT ERROR" not in log
        tests[name] = {"result": "passed", "checks": [line[5:] for line in log.splitlines() if line.startswith("PASS ")], "output_sha256": sha(OUT / (name + ".log"))}
    report = {"schema": 1, "actual_gpu_gallery": gallery, "runtime_contracts": tests, "world_population_with_exclusions": sum(candidate["tree_variants"].values()), "whole_map_population_without_exclusions": 115845, "world_tree_counts": candidate["tree_variants"], "world_lod_draw_groups": candidate["forest_lod_draw_groups"], "original_lod_draw_groups": base["forest_lod_draw_groups"], "timing_observations": measured, "timing_scope": "1600x900, Forward+ Vulkan on GTX 1080 Ti; isolated frozen world, AI disabled. Single final run per profile; these are render-review observations, not a gameplay FPS guarantee.", "native_verification": json.loads((OUT / "native_validation.json").read_text()), "admission_sha256": sha(DEST / "admission_receipt.json")}
    (OUT / "engine_validation.json").write_text(json.dumps(report, indent=2) + "\n", newline="\n")
    shutil.copy2(OUT / "engine_validation.json", DEST / "engine_validation.json")
    shutil.copy2(DEST / "admission_receipt.json", OUT / "admission_receipt.json")
    font_path = "C:/Windows/Fonts/segoeui.ttf"
    font = ImageFont.truetype(font_path, 24); title = ImageFont.truetype(font_path, 32)
    sheet = Image.new("RGB", (1600, 5 * 490 + 90), (17, 23, 29)); draw = ImageDraw.Draw(sheet)
    draw.text((24, 14), "WINTER FOREST / ORIGINAL AND DIVERSE", font=title, fill=(225, 237, 246))
    for row, pair in enumerate(measured):
        for col, profile in enumerate(["baseline", "candidate"]):
            image = Image.open(previews / (profile + "-" + pair["view"] + ".png")).convert("RGB")
            image = image.resize((800, 450), Image.Resampling.LANCZOS)
            sheet.paste(image, (col * 800, 90 + row * 490))
            draw.text((col * 800 + 18, 90 + row * 490 + 454), profile.upper() + " / " + pair["view"], font=font, fill=(215, 232, 242))
    sheet.save(previews / "world_comparison.png")
    rows = ["| Tree family | Near triangles | Far triangles |", "|---|---:|---:|"]
    for name in ["snow_pine_open", "snow_fir_full", "snow_spruce_wind", "snow_snag", "winter_birch"]:
        near = next(m for m in manifest["models"] if m["name"] == name)
        far = next(m for m in manifest["models"] if m["name"] == name + "_far")
        rows.append(f"| {name} | {near['triangles']} | {far['triangles']} |")
    timings = ["| View | Original median ms | Diverse median ms | Diverse p99 ms |", "|---|---:|---:|---:|"]
    for row in measured:
        timings.append(f"| {row['view']} | {row['baseline_median_ms']:.2f} | {row['candidate_median_ms']:.2f} | {row['candidate_p99_ms']:.2f} |")
    readme = """# Winter Tree Diversity v1

Five original winter tree families augment the existing three spruce models. The supplied image guides silhouette, age and snow treatment; no reference pixels, downloaded trees, paid generation or external meshes are included. This uses the project's existing local Blender/Python pipeline. Hash verification and project admission are local receipts, not a claim that the unavailable game-dev CLI ran.

## Edit and reuse

Open **winter_tree_library.blend**. **Export_UnitHeight** contains ten editable single-mesh near/far objects at a 1 metre upright export height and identity transforms. **Preview_18m_RealScale** contains five linked near-mesh instances at actual 18 metre display height. Editing those linked meshes updates the corresponding export geometry. Four original 1024px textures and the preview material are packed into the Blender file. No plugins or downloads are needed.

The live forest scales these unit meshes to the existing lidar canopy heights, retaining every root, height, girth, yaw and trunk circle. The image does not establish absolute dimensions; the existing canopy scale supplies them. Blender is Z-up; GLB is Godot Y-up, rooted at the ground plane. Meshes export without collision or a glTF material because the live MultiMesh applies the shared boreal shader. A generic GLB viewer will not reproduce the foliage automatically.

Vertex alpha is a surface tag: .10 dark bark, .18 pale birch bark, .65 near needle atlas, .72 distant full-bough atlas, 1 solid snow. These are not material opacity values. The provided project shader uses UVs and the four texture bindings to supply cutout foliage, rough bark, tangent normal detail and solid snow. Native Blender materials implement the same tags for editing previews.

## Geometry

""" + "\n".join(rows) + """

Near crowns use irregular primary branches, secondary sprays and closed resting snow caps. Distant conifers use an original composed full-bough atlas to preserve coverage on fewer planes; only the larger snow caps retain physical thickness. Deadwood and birch retain geometric branches. Source files, binary GLB validation and native reopening are independently checked.

## Live forest behavior

Pine and fir form smoothly varying stands. Wind-worn spruce favours upper slopes; leafless birch favours sheltered low patches; deadwood appears in pockets. Original spruce variants remain the majority. The habitat mask is derived independently from the same map seed, consuming no extra placement RNG calls. This is visual habitat selection, not a new ecological simulation or species-specific wood system.

Road, trail, building, water and lookout clearings remain governed by the existing exclusions. No new foliage/twig collision is introduced. Both detail levels disappear when chopped. Existing falling-tree, log, fuel, plank and saved-cut behavior stays intact. Tests compare all 115,845 potential map trees by coordinate and transform, all collision radii, all five new-family falls, duplicate cuts and fresh generation/save replay. The complete world has fewer trees after existing exclusions.

## Review and rendering cost

**previews/family-near.png**, **family-far.png**, **family-back.png** and branch close-ups are actual Godot renders. **world_comparison.png** compares matched lookout, route and weather views. The full corresponding images and capture manifests are preserved. Clear, overcast and dusk use matching camera/weather inputs.

Iterations corrected overly sparse tiered crowns, inadequate far birch spread, coarse snow stitching, missing bark detail, excess crown width and excessive distant conifer geometry. Far coverage uses its own atlas rather than a heavily thinned copy of near foliage. The shared shader avoids sampling an unused old twig texture on new foliage or any twig texture on opaque bark/snow.

The richer crowns and additional species groups still cost more to render than the original bank. These measured observations use a frozen 1600x900 world, AI disabled, Vulkan Forward+ on the GTX 1080 Ti; they do not establish full gameplay frame rates.

""" + "\n".join(timings) + """

The existing near/far visibility overlap is retained. This package does not claim to solve all forest LOD transitions, terrain presentation or whole-game performance. Tests use the real Vulkan renderer: Godot's dummy headless renderer cannot supply the MultiMesh transform storage required by this contract. Existing editor/runtime shutdown RID leak diagnostics remain in the project; no gameplay script error is accepted in the contract reports.

## Rebuild and rollback

Use the existing Python environment for gen_winter_tree_atlas.py, Blender 5.2 for gen_winter_tree_diversity.py with --python-exit-code 1, then validate_winter_trees.py --admit. Reopen with verify_winter_tree_native.py. Import the Godot project; run tests/visual/tree_diversity_review.gd, test_tree_diversity.gd, test_environment_detail.gd and test_lookout_radio_logs.gd with the real renderer. Capture matching worlds with forest_diversity=baseline and default diversity using capture_atmosphere.gd, then package_winter_tree_review.py.

The live launch option **forest_diversity=baseline** selects the previous three-spruce presentation without changing terrain or saves. The scoped tree-diversity commit can be reverted independently; the parent checkpoint is **42f6b97**. Original tree mesh hashes are retained and verified in admission_receipt.json. No push is made.

package_hashes.json records every delivered source/package file except itself and disposable logs/Blender backups. Live copied-byte integrity is separately recorded in the project admission receipt. Engine rendering, geometry validation and artistic approval are separate evidence stages; user playtest/art approval remains the next review.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8", newline="\n")
    sources = ["gen_winter_tree_atlas.py", "gen_winter_tree_diversity.py", "validate_winter_trees.py", "verify_winter_tree_native.py", "package_winter_tree_review.py"]
    (OUT / "build_sources.json").write_text(json.dumps({"source_scripts": {"tools/blender/" + name: sha(ROOT / "tools/blender" / name) for name in sources}, "runtime_sources": {name: sha(GAME / name) for name in ["world/forest_scatter.gd", "world/game_world.gd", "world/shaders/boreal_detail.gdshader", "tests/test_tree_diversity.gd", "tests/visual/tree_diversity_review.gd"]}}, indent=2) + "\n", newline="\n")
    files = sorted(p for p in OUT.rglob("*") if p.is_file() and p.name != "package_hashes.json" and p.suffix != ".log" and not p.suffix.startswith(".blend1"))
    roster = {p.relative_to(OUT).as_posix(): sha(p) for p in files}
    (OUT / "package_hashes.json").write_text(json.dumps({"schema": 1, "files": roster}, indent=2) + "\n", newline="\n")
    for name, digest in roster.items(): assert sha(OUT / name) == digest
    print("WINTER_TREE_PACKAGE_HASHES_VERIFIED", len(roster), "files")
    print("RENDER_TIMINGS", json.dumps(measured))


if __name__ == "__main__": main()
