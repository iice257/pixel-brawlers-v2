"""Builds media/qa/a0_contact.png (+ black-fill row) from a0_preview renders. Usage: python tools/a0_sheet.py
Needs GODOT env var. Poses: idle, punch impact, hit reaction, KO lying."""
import os, subprocess, sys
from PIL import Image, ImageDraw
G = os.environ["GODOT"]
POSES = [("Idle (guard)", "--anim=Punch_Jab --t=0.0"), ("Punch (impact)", "--anim=Punch_Cross --t=0.3"),
         ("Hit reaction", "--anim=Hit_Chest --t=0.17 --hit=1"), ("KO (grounded)", "--anim=Death01 --t=1.45 --ground"),
         ("Hit_Knockback", "--anim=Hit_Knockback --t=0.4"), ("Roll", "--anim=Roll --t=0.38 --ground")]
out = "media/qa"
os.makedirs(out, exist_ok=True)
def shoot(extra, path):
    subprocess.run([G, "--path", ".", "--rendering-driver", "opengl3", "--resolution", "1280x720", "res://a0/a0_preview.tscn", "--",
                    "--shot=" + path] + extra.split(), check=True, capture_output=True, timeout=120)
rows = []
for black in (False, True):
    row = []
    for i, (name, a) in enumerate(POSES):
        p = f"{out}/_t{int(black)}{i}.png"
        shoot(a + (" --black" if black else ""), p)
        im = Image.open(p).convert("RGB").crop((340, 120, 940, 660))
        if not black:
            ImageDraw.Draw(im).text((8, 8), name, fill=(255, 240, 160))
        row.append(im); os.remove(p)
    rows.append(row)
w, h = rows[0][0].size
sheet = Image.new("RGB", (w * len(POSES), h * 2))
for r, row in enumerate(rows):
    for c, im in enumerate(row): sheet.paste(im, (c * w, r * h))
sheet.save(f"{out}/a0_contact.png")
print("saved", sheet.size)
