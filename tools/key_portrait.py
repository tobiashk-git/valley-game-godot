"""Key a Leonardo portrait bust (flat magenta-ish background) into a square
transparent PNG for the dialogue box.

  python tools/key_portrait.py <in.jpg> <out.png> [--size 192] [--top-air 0.05]

Technique (the one that worked for the Oliver illustration): fit a quadratic
colour field to the border pixels, key every pixel whose residual from that
field is small (global, not flood-filled - busts have no enclosed pockets but
hair strands do), then peel the JPEG's blended outline (absorb residual<60
pixels touching the keyed region, a few passes) with a soft alpha ring.
Framing: a square whose side is the bust's width, hung from just above the
head - so the bottom of the shoulders is cut like a real portrait bust and
every speaker's head sits at the same height in the frame.
"""
import sys
import numpy as np
from PIL import Image


def fit_background(rgb, mask):
    h, w, _ = rgb.shape
    ys, xs = np.mgrid[0:h, 0:w]
    xn = xs / w - 0.5
    yn = ys / h - 0.5
    basis = np.stack([np.ones_like(xn), xn, yn, xn * xn, yn * yn, xn * yn], axis=-1)
    a = basis[mask]
    field = np.zeros_like(rgb, dtype=np.float64)
    for c in range(3):
        coef, *_ = np.linalg.lstsq(a, rgb[..., c][mask], rcond=None)
        field[..., c] = basis @ coef
    return field


def dilate(m, r=1):
    out = m.copy()
    for _ in range(r):
        p = np.pad(out, 1)
        out = (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:] | out)
    return out


def largest_component(mask):
    try:
        from scipy import ndimage
        labels, n = ndimage.label(mask)
        if n <= 1:
            return mask
        sizes = ndimage.sum(mask, labels, range(1, n + 1))
        return labels == (int(np.argmax(sizes)) + 1)
    except ImportError:
        pass
    # fallback: grow from the biggest-looking seed (the mask's centre column)
    h, w = mask.shape
    seen = np.zeros_like(mask)
    best = None
    remaining = mask.copy()
    while remaining.any():
        ys, xs = np.where(remaining)
        comp = np.zeros_like(mask)
        comp[ys[0], xs[0]] = True
        while True:
            grown = dilate(comp, 1) & mask
            if grown.sum() == comp.sum():
                break
            comp = grown
        remaining &= ~comp
        if best is None or comp.sum() > best.sum():
            best = comp
    return best


def main():
    args = sys.argv[1:]
    size = 192
    top_air = 0.05
    if "--size" in args:
        i = args.index("--size"); size = int(args[i + 1]); del args[i:i + 2]
    if "--top-air" in args:
        i = args.index("--top-air"); top_air = float(args[i + 1]); del args[i:i + 2]
    src, dst = args
    im = Image.open(src).convert("RGB")
    rgb = np.asarray(im).astype(np.float64)
    h, w, _ = rgb.shape

    border = np.zeros((h, w), bool)
    b = max(4, min(h, w) // 40)
    border[:b, :] = border[-b:, :] = border[:, :b] = border[:, -b:] = True
    field = fit_background(rgb, border)
    resid = np.sqrt(((rgb - field) ** 2).sum(-1))
    # refit on everything that is clearly background, for a better field
    field = fit_background(rgb, resid < 18)
    resid = np.sqrt(((rgb - field) ** 2).sum(-1))

    bg = resid < 12
    # edge peel: blended outline pixels next to the background
    for _ in range(3):
        bg = bg | (dilate(bg, 3) & (resid < 60))
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    # soft ring just inside the figure
    ring = dilate(bg, 1) & ~bg
    alpha[ring] = 120

    # Keep only the largest opaque island: Leonardo sometimes adds a fake
    # signature scrawl or a stray fleck off to one side.
    fig = alpha > 0
    fig = largest_component(fig)
    alpha[~fig] = 0
    ys, xs = np.where(fig)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    # Square side = bust width, but never under 70% of its height - a narrow
    # bust (high collar, no shoulders) would otherwise crowd the frame.
    side = max(x1 - x0, int((y1 - y0) * 0.7))
    side = min(side, w, h)
    top = max(0, int(y0 - side * top_air))
    cx = (x0 + x1) // 2
    left = max(0, min(w - side, cx - side // 2))
    bottom = min(h, top + side)
    if bottom - top < side:  # image too short: grow the square upward
        top = max(0, bottom - side)
    out = np.dstack([rgb.astype(np.uint8), alpha])[top:bottom, left:left + side]
    img = Image.fromarray(out, "RGBA")
    if img.size[0] != img.size[1]:
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(img, (0, side - img.size[1]))
        img = sq
    img = img.resize((size, size), Image.LANCZOS)
    img.save(dst)
    print("keyed", src, "->", dst, "bbox", (x0, y0, x1, y1), "square", (left, top, side), "bg px", int(bg.sum()), "of", h * w)


if __name__ == "__main__":
    main()
