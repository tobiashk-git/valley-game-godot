"""Re-key every creature listed in tools/monster_art_manifest.txt (source
file in the Art folder | species id | key_monster.py flags) into
assets/enemies/art/<id>.png, then write a green contact sheet
verify_monster_all_green.png. --crop L,T,R,B in the flags crops the source
first (a white torn-paper border would fool the background fit)."""
import os, subprocess, sys, tempfile
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = r"C:\Users\tobia\Valley Game\Art"
os.chdir(ROOT)
ids = []
for line in open("tools/monster_art_manifest.txt", encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    src, sid, flags = line.split("|")
    flags = flags.split()
    path = os.path.join(ART, src)
    if "--crop" in flags:
        i = flags.index("--crop")
        box = tuple(int(v) for v in flags[i + 1].split(","))
        del flags[i:i + 2]
        tmp = os.path.join(tempfile.gettempdir(), sid + "_cropped.jpg")
        Image.open(path).crop(box).save(tmp, quality=97)
        path = tmp
    out = subprocess.run([sys.executable, "tools/key_monster.py", *flags, path, f"assets/enemies/art/{sid}.png"], capture_output=True, text=True)
    last = out.stdout.strip().splitlines()[-1] if out.stdout.strip() else out.stderr.strip()[-200:]
    print(sid, "|", last.split("->")[-1].strip()[:70])
    ids.append(sid)
cols = 7
rows = (len(ids) + cols - 1) // cols
sheet = Image.new("RGBA", (276 * cols, 276 * rows), (70, 140, 60, 255))
for i, sid in enumerate(ids):
    im = Image.open(f"assets/enemies/art/{sid}.png")
    w, h = im.size
    sheet.alpha_composite(im, (276 * (i % cols) + (276 - w) // 2, 276 * (i // cols) + (276 - h) // 2))
sheet.save("verify_monster_all_green.png")
print("sheet: verify_monster_all_green.png", len(ids), "creatures")
