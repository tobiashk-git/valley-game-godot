import sys, numpy as np
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float64)
h, w, _ = im.shape
# 1. fit a quadratic background field to the border ring
ring = np.zeros((h, w), bool); ring[:12,:]=ring[-12:,:]=ring[:,:12]=ring[:,-12:]=True
ys, xs = np.mgrid[0:h, 0:w]; X = xs/w-0.5; Y = ys/h-0.5
A = np.stack([np.ones_like(X), X, Y, X*X, Y*Y, X*Y], -1)
bg = np.zeros_like(im)
for c in range(3):
    coef, *_ = np.linalg.lstsq(A[ring], im[...,c][ring], rcond=None)
    bg[...,c] = A @ coef
resid = np.linalg.norm(im-bg, axis=-1)
noise = np.percentile(resid[ring], 99.5)
print("bg ~", bg[h//2, w//2].round(), "ring p99.5 resid", round(noise,1))
tol = max(11.0, noise*2.5)
keyed = resid < tol
# 2. shadow key: cast shadows are the bg hue, darker. Strip them by
# scanning each column UP from the bottom, keying shadow-hued pixels until
# the first pixel that isn't one (the object's dark outline stops the scan),
# so interior colours near the bg hue (a red potion) are never touched.
import colorsys
bgc = bg[h//2, w//2] / 255.0
bh, bs, bv = colorsys.rgb_to_hsv(*bgc)
hsv = np.zeros_like(im)
mx = im.max(-1); mn = im.min(-1); v = mx / 255.0; sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0)
r, g, b = im[...,0], im[...,1], im[...,2]
d = np.maximum(mx - mn, 1e-6)
hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
hue_diff = np.minimum(np.abs(hue - bh), 1 - np.abs(hue - bh))
shadow_like = (hue_diff < 0.06) & (sat > 0.25) & (v < bv * 1.03) & (v > bv * 0.55) & (resid < 130)
for x in range(w):
    col_keyed = keyed[:, x]
    for y in range(h - 1, -1, -1):
        if col_keyed[y]:
            continue
        if shadow_like[y, x]:
            keyed[y, x] = True
        else:
            break
# 2b. detached shadow islands: any connected blob of unkeyed pixels lying
# entirely below the main object's bottom edge is a floating shadow (crystal,
# fireball, sparkle) whatever its darkness - key it.
lab = np.zeros((h, w), np.int32); n = 0
unk = ~keyed
for sy in range(h):
    for sx in range(w):
        if unk[sy, sx] and lab[sy, sx] == 0:
            n += 1; stack = [(sy, sx)]; lab[sy, sx] = n
            while stack:
                y0_, x0_ = stack.pop()
                for ny, nx in ((y0_-1,x0_),(y0_+1,x0_),(y0_,x0_-1),(y0_,x0_+1)):
                    if 0 <= ny < h and 0 <= nx < w and unk[ny, nx] and lab[ny, nx] == 0:
                        lab[ny, nx] = n; stack.append((ny, nx))
if n > 1:
    sizes = [(lab == i).sum() for i in range(1, n+1)]
    main = 1 + int(np.argmax(sizes))
    main_bottom = np.where(lab == main)[0].max()
    for i in range(1, n+1):
        if i == main: continue
        rows = np.where(lab == i)[0]
        if rows.min() > main_bottom:
            keyed[lab == i] = True
# 3. edge peel: absorb resid<60 pixels adjacent to keyed region, 3 passes
def binary_dilation(m, iterations=1):
    m = m.copy()
    for _ in range(iterations):
        n = m.copy()
        n[1:,:] |= m[:-1,:]; n[:-1,:] |= m[1:,:]; n[:,1:] |= m[:,:-1]; n[:,:-1] |= m[:,1:]
        m = n
    return m
for _ in range(3):
    grow = binary_dilation(keyed, iterations=3) & (resid < 60) & ~keyed
    # only peel toward bg-ish pixels (avoid eating the object)
    keyed |= grow & (hue_diff < 0.1)
alpha = np.where(keyed, 0, 255).astype(np.uint8)
# soft ring
edge = binary_dilation(~keyed, iterations=1) & keyed
alpha[edge] = 120
rgba = np.dstack([im.astype(np.uint8), alpha])
img = Image.fromarray(rgba, "RGBA")
# crop to content bbox with 4% padding, square
a = np.asarray(img)[...,3] > 0
ys_, xs_ = np.where(a)
y0,y1,x0,x1 = ys_.min(), ys_.max(), xs_.min(), xs_.max()
side = int(max(y1-y0, x1-x0) * 1.08)
cy, cx = (y0+y1)//2, (x0+x1)//2
box = (cx-side//2, cy-side//2, cx-side//2+side, cy-side//2+side)
crop = img.crop(box)
print("content bbox", (x0,y0,x1,y1), "crop side", side)
crop.resize((64,64), Image.LANCZOS).save(out)
crop.save(out.replace(".png","_full.png"))
# preview strip: on dark slot colour and on parchment
for name, colr in [("dark",(41,36,28)),("parch",(230,214,173))]:
    bgim = Image.new("RGBA",(200,90),colr+(255,))
    ic = Image.open(out)
    bgim.paste(ic,(12,13),ic); 
    ic2 = crop.resize((24,24), Image.LANCZOS); bgim.paste(ic2,(100,33),ic2)
    bgim.save(out.replace(".png",f"_on_{name}.png"))
print("saved", out)
