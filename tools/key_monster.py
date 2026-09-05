"""Key a Leonardo creature sprite (flat magenta-ish background, often with a
painted drop-shadow ellipse the prompt asked it not to draw) into a tight
transparent PNG for the battle stage and the overworld.

  python tools/key_monster.py <in.jpg> <out.png> [--max 256] [--mist]

--mist: the creature trails translucent white wisps (ghosts): pixels of the
background hue that are paler than it are a white-over-background blend,
so they become white with alpha = how far the saturation has dropped;
hole filling is skipped (a swirl can enclose background).

Background: a quadratic colour field fitted to the border, keyed on a
small residual (global, so pockets between legs go too).
Shadow: the ellipse is the background colour darkened, so it - and its
blend back into the background - lies on the RGB line through the origin
and the background colour; anything close to that line and no brighter
than the background is keyed. Fur, scales, eyes and claws sit well off
that line (a red eye is ~55 units away, a pink ear ~40).
Then the JPEG outline is peeled, stray islands (fake signatures) dropped,
and the result cropped to the creature's bounding box - tight, so the
overworld's grounding maths (feet at the texture's bottom) still holds -
and scaled to fit --max on its longer side.
"""
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else ".")
from key_portrait import fit_background, dilate, largest_component  # noqa: E402


def rgb_to_hsv(rgb):
    """Vectorised HSV: hue in degrees, sat and val 0..1."""
    r, g, b = rgb[..., 0] / 255.0, rgb[..., 1] / 255.0, rgb[..., 2] / 255.0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    d = mx - mn
    hue = np.zeros_like(mx)
    nz = d > 1e-6
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & ~rm & ~gm
    hue[rm] = ((g[rm] - b[rm]) / d[rm]) % 6.0
    hue[gm] = (b[gm] - r[gm]) / d[gm] + 2.0
    hue[bm] = (r[bm] - g[bm]) / d[bm] + 4.0
    hue = hue * 60.0
    sat = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return np.stack([hue, sat, mx], axis=-1)


def fill_holes(mask):
    try:
        from scipy import ndimage
        return ndimage.binary_fill_holes(mask)
    except ImportError:
        pass
    outside = np.zeros_like(mask)
    outside[0, :] = outside[-1, :] = outside[:, 0] = outside[:, -1] = True
    outside &= ~mask
    while True:
        grown = dilate(outside, 1) & ~mask
        if grown.sum() == outside.sum():
            break
        outside = grown
    return ~outside


def main():
    args = sys.argv[1:]
    max_side = 256
    mist = "--mist" in args
    if mist:
        args.remove("--mist")
    if "--max" in args:
        i = args.index("--max"); max_side = int(args[i + 1]); del args[i:i + 2]
    src, dst = args
    im = Image.open(src).convert("RGB")
    rgb = np.asarray(im).astype(np.float64)
    h, w, _ = rgb.shape

    border = np.zeros((h, w), bool)
    b = max(4, min(h, w) // 40)
    border[:b, :] = border[-b:, :] = border[:, :b] = border[:, -b:] = True
    field = fit_background(rgb, border)
    resid = np.sqrt(((rgb - field) ** 2).sum(-1))
    field = fit_background(rgb, resid < 18)
    resid = np.sqrt(((rgb - field) ** 2).sum(-1))
    bg = resid < 12

    # Shadow: the background colour darkened - same hue and saturation,
    # lower value (measured: bg hue 338 sat .61 val .78, shadow hue 336
    # sat .62 val .47; the rat's fur is hue ~2 sat .33-.46, its darkest
    # face pixels hue 334 but sat .46). Match on hue AND saturation so
    # dark fur that drifts toward the background hue survives.
    hsv = rgb_to_hsv(rgb)
    bg_hsv = rgb_to_hsv(field)
    hue_d = np.abs(hsv[..., 0] - bg_hsv[..., 0])
    hue_d = np.minimum(hue_d, 360.0 - hue_d)
    # (The ghost's shadow drifted 13 deg from its background; the rat's
    # darkest fur is 4 deg off but 0.15 lower in saturation - hence 15 / 0.09.)
    same_hue = (hue_d < 15.0) & (np.abs(hsv[..., 1] - bg_hsv[..., 1]) < 0.09)
    shadow = same_hue & (hsv[..., 2] <= bg_hsv[..., 2] + 0.05)
    keyed = bg | shadow

    # Edge peel: blended outline pixels next to the keyed region - toward
    # the background field, or toward the shadow (same hue/sat, any value).
    for _ in range(3):
        near = dilate(keyed, 3)
        keyed = keyed | (near & ((resid < 60) | same_hue))
    alpha = np.where(keyed, 0, 255).astype(np.uint8)
    ring = dilate(keyed, 1) & ~keyed
    alpha[ring] = 120
    out_rgb = rgb.astype(np.uint8)
    if mist:
        # Measured on the ghost: mist hue 273-331 (bg 334), sat .11-.52 (bg
        # .62), value about the background's; the ghost's own pale blue body
        # is 130 deg off in hue, so a wide hue window is safe.
        pale = (~keyed) & (hue_d < 65.0) & (hsv[..., 2] >= bg_hsv[..., 2] - 0.1) & (hsv[..., 1] < bg_hsv[..., 1] - 0.08)
        cover = np.clip(1.0 - hsv[..., 1] / np.maximum(bg_hsv[..., 1], 1e-6), 0.0, 1.0)
        alpha[pale] = (cover[pale] * 255.0).astype(np.uint8)
        out_rgb = out_rgb.copy()
        out_rgb[pale] = np.array([236, 242, 250], dtype=np.uint8)

    fig = largest_component(alpha > 0)
    if mist:
        alpha[~fig] = 0
    # Fill holes that are entirely inside the creature (a fleck of
    # background-hued colour in an eye or an ear): only transparent regions
    # that reach the image border stay transparent.
    if not mist:
        holes = fill_holes(fig) & ~fig
        alpha[holes] = 255
        fig = fig | holes
        alpha[~fig] = 0
    ys, xs = np.where(fig)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    out = np.dstack([out_rgb, alpha])[y0:y1, x0:x1]
    img = Image.fromarray(out, "RGBA")
    scale = min(1.0, max_side / max(img.size))
    if scale < 1.0:
        img = img.resize((max(1, round(img.size[0] * scale)), max(1, round(img.size[1] * scale))), Image.LANCZOS)
    img.save(dst)
    print("keyed", src, "->", dst, img.size, "bbox", (int(x0), int(y0), int(x1), int(y1)), "shadow px", int((shadow & ~bg).sum()))


if __name__ == "__main__":
    main()
