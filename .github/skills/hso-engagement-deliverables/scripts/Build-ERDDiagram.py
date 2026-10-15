#!/usr/bin/env python
"""
Generic conceptual ERD (hub-and-spoke) — HSO-branded PNG for a client deliverable.

A full 100+ table ERD is unreadable; this renders ONE central entity with its key related entities
around it and labelled 1:N connectors — the right level for a current-state / overview guide.

Spec (JSON):
  { "title": "...", "out": "erd.png",
    "center": {"label": "Opportunity (Project)"},
    "spokes": [ {"label": "Account", "rel": "1:N"}, ... ],   # up to ~12 reads best
    "footer": "..." }                                         # optional

Usage:  python Build-ERDDiagram.py <spec.json>
"""
import sys, os, json, math
from PIL import Image, ImageDraw, ImageFont

NAVY = (0, 57, 95); TEAL = (7, 159, 195); GREEN = (0, 178, 148)
GREY = (90, 100, 110); LINE = (150, 160, 170); WHITE = (255, 255, 255); BG = (255, 255, 255)

def font(sz, bold=False):
    for nm in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arialbd.ttf" if bold else "arial.ttf"):
        try: return ImageFont.truetype(nm, sz)
        except Exception: pass
    return ImageFont.load_default()

def box(d, cx, cy, w, h, text, fill, fsz=18, bold=True, tcol=WHITE):
    d.rounded_rectangle([cx - w/2, cy - h/2, cx + w/2, cy + h/2], radius=10, fill=fill)
    f = font(fsz, bold)
    lines = wrap(d, text, f, w - 16)
    ty = cy - (len(lines) * (fsz + 4)) / 2
    for ln in lines:
        tw = d.textbbox((0, 0), ln, font=f)[2]
        d.text((cx - tw/2, ty), ln, font=f, fill=tcol); ty += fsz + 4

def wrap(d, text, f, maxw):
    words = text.split(); lines = []; cur = ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textbbox((0, 0), t, font=f)[2] <= maxw: cur = t
        else:
            if cur: lines.append(cur)
            cur = w
    if cur: lines.append(cur)
    return lines or [text]

def main():
    spec = json.load(open(sys.argv[1], encoding="utf-8"))
    title = spec.get("title", "Data model — conceptual")
    center = spec.get("center", {}).get("label", "Core")
    spokes = spec.get("spokes", [])
    footer = spec.get("footer", "")
    W, H = spec.get("width_px", 1500), spec.get("height_px", 1100)
    img = Image.new("RGB", (W, H), BG); d = ImageDraw.Draw(img)

    d.text((40, 28), title, font=font(30, True), fill=NAVY)
    d.line([40, 78, W - 40, 78], fill=NAVY, width=3)

    cx, cy = W / 2, H / 2 + 20
    R = min(W, H) * 0.40
    sw, sh = 212, 74
    n = max(1, len(spokes))
    # draw connectors first
    pts = []
    for i, s in enumerate(spokes):
        ang = -math.pi/2 + i * (2 * math.pi / n)
        sx, sy = cx + R * math.cos(ang), cy + R * math.sin(ang)
        pts.append((sx, sy, s))
        d.line([cx, cy, sx, sy], fill=LINE, width=2)
        # cardinality label at midpoint
        mx, my = (cx + sx) / 2, (cy + sy) / 2
        rel = s.get("rel", "1:N")
        f = font(14, True)
        tw = d.textbbox((0, 0), rel, font=f)[2]
        d.rectangle([mx - tw/2 - 4, my - 11, mx + tw/2 + 4, my + 11], fill=WHITE)
        d.text((mx - tw/2, my - 9), rel, font=f, fill=GREY)
    # spokes
    for sx, sy, s in pts:
        col = {"client": TEAL, "isv": GREEN, "ootb": GREY}.get(s.get("role", "client"), TEAL)
        box(d, sx, sy, sw, sh, s.get("label", "?"), col, fsz=16)
    # center on top
    box(d, cx, cy, 280, 100, center, NAVY, fsz=22)

    if footer:
        d.text((40, H - 36), footer, font=font(13), fill=GREY)
    # legend
    lx = W - 360; ly = 92
    for lbl, col in (("Client (contoso_)", TEAL), ("ISV / product", GREEN), ("Out-of-box", GREY)):
        d.rectangle([lx, ly, lx + 18, ly + 14], fill=col); d.text((lx + 26, ly - 1), lbl, font=font(13), fill=NAVY); lx += 120

    out = spec.get("out", "erd.png")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    img.save(out)
    print("SAVED:", out)

if __name__ == "__main__":
    main()
