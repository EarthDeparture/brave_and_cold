"""Verify original first-week runtime assets against retained Blender sources."""
from pathlib import Path
import hashlib
import json
import wave

ROOT = Path(__file__).resolve().parents[1]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def source_matches(path, expected):
    # Receipts preserve generated source hashes; Git may convert LF/CRLF.
    lf = path.read_text(encoding="utf-8").encode("utf-8")
    variants = (path.read_bytes(), lf, lf.replace(b"\n", b"\r\n"))
    return any(hashlib.sha256(data).hexdigest() == expected for data in variants)

def validate():
    packages = {}
    for package in ("first_week", "clinic", "infected", "maintenance", "wristwatch", "city_letter"):
        folder = ROOT / "brave-and-cold/assets" / package
        manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        assets = {}
        for name, entry in manifest.items():
            if not isinstance(entry, dict) or "triangles" not in entry:
                continue
            filename = "winter_infected_proxy.glb" if name == "proxy" else name + ".glb"
            path = folder / filename
            assert sha(path) == entry["sha256"], str(path)
            if "source" in entry:
                native = ROOT / entry["source"]
                assert sha(native) == entry["source_sha256"], str(native)
            assets[name] = dict(entry, file=path.relative_to(ROOT).as_posix())
            if name == "proxy":
                assets[name]["derived_from"] = manifest["winter_infected"]["source"]
        for name, expected in manifest.get("graphics", {}).items():
            path = ROOT / "tools/blender/generated" / package / name
            assert sha(path) == expected, str(path)
        generator = ROOT / "tools/blender" / ("gen_first_week.py" if package == "first_week" else "gen_" + package + ".py")
        # Two packages use descriptive generator names.
        if package == "infected": generator = ROOT / "tools/blender/gen_infected.py"
        if package == "wristwatch": generator = ROOT / "tools/blender/gen_wristwatch.py"
        assert source_matches(generator, manifest["provenance"]["generator_sha256"]), str(generator)
        packages[package] = {"assets": assets, "provenance": manifest["provenance"], "graphics_verified": len(manifest.get("graphics", {}))}
    folder = ROOT / "brave-and-cold/assets/audio/sfx"
    foley = json.loads((folder / "first_week_foley.json").read_text(encoding="utf-8"))
    assert source_matches(ROOT / "tools/audio/gen_first_week_foley.py", foley["generator_sha256"])
    for name, entry in foley["clips"].items():
        path = folder / (name + ".wav")
        assert sha(path) == entry["sha256"], str(path)
        with wave.open(str(path), "rb") as audio:
            assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (1, 2, foley["sample_rate"])
            assert abs(audio.getnframes()/audio.getframerate() - entry["seconds"]) < 1/audio.getframerate()
    return {"packages": packages, "foley": foley}

if __name__ == "__main__":
    result = validate()
    print("FIRST_WEEK_ASSETS_PASS packages=%d models=%d foley=%d" % (len(result["packages"]), sum(len(p["assets"]) for p in result["packages"].values()), len(result["foley"]["clips"])))
