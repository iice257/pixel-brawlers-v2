"""Stage art importer: python tools/import_stage_art.py [src_dir] [stage_id]
Takes sky/deck/front images (png/jpg/webp) from src_dir (default ~/Downloads/redline-art), keys out #00FF00 green to transparent on deck and
front, downsizes to the layer's max width, and writes assets/stages/<stage_id>/<name>.png. data/stages/<id>.json lists the layers; no code change."""
import sys, os, json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MAX_W = {"sky": 2048, "deck": 4096, "front": 3072}
KEY = (0, 255, 0)

def key_green(im: Image.Image, tol=90) -> Image.Image:
    im = im.convert("RGBA"); px = im.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d = ((r - KEY[0]) ** 2 + (g - KEY[1]) ** 2 + (b - KEY[2]) ** 2) ** 0.5
            if d < tol: px[x, y] = (r, g, b, 0)
            elif d < tol * 1.6 and g > r and g > b:      # despill the fringe: pull green down to the larger of red/blue
                px[x, y] = (r, max(r, b), b, int(255 * (d - tol) / (tol * 0.6)))
    return im

def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Downloads" / "redline-art"
    sid = sys.argv[2] if len(sys.argv) > 2 else "stage1"
    cfg = json.loads((ROOT / "data" / "stages" / f"{sid}.json").read_text())
    out = ROOT / cfg["art_dir"].replace("res://", "")
    out.mkdir(parents=True, exist_ok=True)
    for layer in cfg["layers"]:
        name = layer["name"]
        hit = next((p for ext in (".png", ".jpg", ".jpeg", ".webp") for p in [src / f"{name}{ext}"] if p.exists()), None)
        if hit is None: print(f"skip {name}: no file in {src}"); continue
        im = Image.open(hit)
        im = im.convert("RGB") if name == "sky" else key_green(im)
        if im.width > MAX_W[name]: im = im.resize((MAX_W[name], round(im.height * MAX_W[name] / im.width)), Image.LANCZOS)
        im.save(out / f"{name}.png", optimize=True); print(f"{name}: {hit.name} -> {out / (name + '.png')} {im.size}")

if __name__ == "__main__": main()
