"""Builds media/qa/mco_vs_keyed.png: old keyed pose (top row) against the MoCap clip (bottom row) for idle, walk and crouch, floor-snapped
like the fight view. Usage: GODOT=<godot exe> python tools/mco_qa.py"""
import os, subprocess
from PIL import Image, ImageDraw
G = os.environ["GODOT"]
COLS = [("Idle", "--anim=Punch_Jab --t=0.0 --drop", "--anim=ext/Fight_Idle --t=1.0 --drop"),
        ("Idle (later)", "--anim=Punch_Jab --t=0.0 --drop", "--anim=ext/Fight_Idle --t=3.0 --drop"),
        ("Walk A", "--anim=Walk --t=0.15 --drop", "--anim=ext/Walk_F --t=0.25 --drop"),
        ("Walk B", "--anim=Walk --t=0.5 --drop", "--anim=ext/Walk_F --t=0.85 --drop"),
        ("Crouch", "--anim=Crouch_Idle --t=0.0 --key=crouch --drop", "--anim=ext/Crouch_Walk_F --t=0.6 --drop")]
out = "media/qa"
def shoot(extra, path):
    subprocess.run([G, "--path", ".", "--rendering-driver", "opengl3", "--resolution", "1280x720", "res://a0/a0_preview.tscn", "--",
                    "--shot=" + path] + extra.split(), check=True, capture_output=True, timeout=120)
rows = [[], []]
for name, old, new in COLS:
    for r, a in enumerate((old, new)):
        p = f"{out}/_t{r}.png"; shoot(a, p)
        im = Image.open(p).convert("RGB").crop((340, 120, 940, 660)); os.remove(p)
        ImageDraw.Draw(im).text((8, 8), f"{name}: {'keyed' if r == 0 else 'mocap'}", fill=(255, 240, 160))
        rows[r].append(im)
w, h = rows[0][0].size
sheet = Image.new("RGB", (w * len(COLS), h * 2))
for r in range(2):
    for c, im in enumerate(rows[r]): sheet.paste(im, (c * w, r * h))
sheet.save(f"{out}/mco_vs_keyed.png"); print("saved", sheet.size)
