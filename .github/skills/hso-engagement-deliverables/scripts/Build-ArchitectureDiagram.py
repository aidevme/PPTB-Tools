#!/usr/bin/env python
"""
Build an HSO-branded layered architecture diagram (PNG) from a JSON spec — for embedding in a client
deliverable (see Build-WordDeliverable.py 'image' block). GENERIC: no client content in this file.

Usage:  python Build-ArchitectureDiagram.py <spec.json>

Spec:
{
  "title": "<Solution> - Architecture at a glance",
  "out":   "C:\\...\\diagrams\\architecture.png",
  "users": "Users - business teams",                 # optional caption above the stack
  "footer":"optional footer note",                   # optional
  "width_px": 1600,                                  # optional (default 1600)
  "layers": [                                        # top -> bottom
    {"title":"App", "subtitle":"...", "role":"app"},
    {"title":"Custom layer", "subtitle":"...", "role":"custom"},
    {"title":"ISV product", "subtitle":"...", "role":"isv"},
    {"title":"Platform", "subtitle":"...", "role":"platform"}
  ],
  "integrations": [ {"title":"SharePoint","subtitle":"docs"}, ... ]   # optional right-side panel
}
role -> colour: app=navy, custom=teal, isv/product=green, platform=gray, other=navy.
"""
import sys, json, os
from PIL import Image, ImageDraw, ImageFont

NAVY=(0,57,95); TEAL=(7,159,195); GREEN=(0,178,148); GRAY=(115,115,115); LT=(236,239,243); WHITE=(255,255,255); DK=(51,51,51)
ROLE={"app":NAVY, "custom":TEAL, "isv":GREEN, "product":GREEN, "platform":GRAY}

def font(sz, bold=False):
    for n in ((["segoeuib.ttf","arialbd.ttf"]) if bold else (["segoeui.ttf","arial.ttf"])):
        p=os.path.join(r"C:\Windows\Fonts", n)
        if os.path.exists(p):
            try: return ImageFont.truetype(p, sz)
            except Exception: pass
    return ImageFont.load_default()

def center(d, box, text, fnt, fill):
    x0,y0,x1,y1=box; tb=d.textbbox((0,0),text,font=fnt)
    d.text((x0+(x1-x0-(tb[2]-tb[0]))/2, y0+(y1-y0-(tb[3]-tb[1]))/2 - tb[1]), text, font=fnt, fill=fill)

def main():
    if len(sys.argv) < 2:
        print("usage: python Build-ArchitectureDiagram.py <spec.json>"); sys.exit(2)
    s = json.load(open(sys.argv[1], encoding="utf-8-sig"))
    layers = s.get("layers", []); integ = s.get("integrations", [])
    W = s.get("width_px", 1600)
    n = max(1, len(layers))
    top = 175; gap = 25; lh = 145
    stack_bottom = top + n*lh + (n-1)*gap
    H = stack_bottom + (120 if s.get("footer") else 60)
    img = Image.new("RGB", (W, H), WHITE); d = ImageDraw.Draw(img)
    LX0, LX1 = 60, (1090 if integ else W-60)

    d.text((60, 34), s.get("title","Architecture at a glance"), font=font(40, True), fill=NAVY)
    d.rectangle((60, 92, 60+min(620, len(s.get("title",""))*20), 98), fill=TEAL)
    if s.get("users"): center(d, (LX0, 120, LX1, 160), s["users"], font(22, True), GRAY)

    y = top
    for lr in layers:
        col = ROLE.get(str(lr.get("role","")).lower(), NAVY)
        d.rounded_rectangle((LX0, y, LX1, y+lh), radius=14, fill=col)
        center(d, (LX0, y+14, LX1, y+60), lr.get("title",""), font(30, True), WHITE)
        if lr.get("subtitle"): center(d, (LX0, y+62, LX1, y+lh-10), lr["subtitle"], font(20), WHITE)
        y += lh + gap

    if integ:
        IX0, IX1 = 1150, W-60
        d.rounded_rectangle((IX0, top, IX1, stack_bottom), radius=14, outline=NAVY, width=3, fill=LT)
        center(d, (IX0, top+10, IX1, top+55), "Integrations", font(28, True), NAVY)
        avail = stack_bottom - (top+70); each = min(150, max(80, avail//max(1,len(integ))))
        iy = top + 70
        for it in integ:
            d.rounded_rectangle((IX0+20, iy, IX1-20, iy+each-20), radius=10, fill=WHITE, outline=TEAL, width=2)
            center(d, (IX0+20, iy+10, IX1-20, iy+48), it.get("title",""), font(22, True), NAVY)
            if it.get("subtitle"): center(d, (IX0+20, iy+50, IX1-20, iy+each-26), it["subtitle"], font(17), DK)
            d.line((LX1, iy+(each-20)//2, IX0+20, iy+(each-20)//2), fill=TEAL, width=3)
            iy += each

    if s.get("footer"): d.text((60, H-60), s["footer"], font=font(18), fill=GRAY)
    os.makedirs(os.path.dirname(s["out"]) or ".", exist_ok=True)
    img.save(s["out"], "PNG"); print("SAVED:", s["out"])

if __name__ == "__main__":
    main()
