"""Estimates what goes into the web pck: per top-level folder and per file type, from the project files and their imported outputs.
Usage: python tools/pck_report.py     (run a headless --import first). Honours exclude_filter in export_presets.cfg."""
import os, re, fnmatch, collections
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cfg = open(os.path.join(root, "export_presets.cfg"), encoding="utf-8").read()
excl = [p.strip() for p in re.search(r'exclude_filter="([^"]*)"', cfg).group(1).split(",") if p.strip()]
by_dir, by_ext, big = collections.Counter(), collections.Counter(), []
def excluded(rel): return any(fnmatch.fnmatch(rel, p) for p in excl)
for dp, dn, fn in os.walk(root):
    rel_dir = os.path.relpath(dp, root).replace("\\", "/")
    if rel_dir.startswith((".git", ".godot", "build", ".github")): dn[:] = []; continue
    for f in fn:
        rel = (rel_dir + "/" + f if rel_dir != "." else f)
        if excluded(rel) or f.endswith((".import", ".uid")) or f.startswith("."): continue
        path = os.path.join(dp, f)
        size = os.path.getsize(path)
        imp = path + ".import"
        if os.path.exists(imp):
            txt = open(imp, encoding="utf-8").read()
            dests = re.findall(r'"res://(\.godot/imported/[^"]+)"', txt)
            size = sum(os.path.getsize(os.path.join(root, d)) for d in dests if os.path.exists(os.path.join(root, d)))
        top = rel.split("/")[0] if "/" in rel else "(root)"
        by_dir[top] += size; by_ext[os.path.splitext(f)[1] or "(none)"] += size; big.append((size, rel))
tot = sum(by_dir.values())
print(f"total {tot/1e6:.2f} MB")
print("by folder:"); [print(f"  {k:14s}{v/1e6:7.2f} MB") for k, v in by_dir.most_common()]
print("by type:");   [print(f"  {k:14s}{v/1e6:7.2f} MB") for k, v in by_ext.most_common(8)]
print("largest:");   [print(f"  {s/1e6:6.2f} MB  {r}") for s, r in sorted(big, reverse=True)[:12]]
