#!/usr/bin/env python3
"""Render any standalone narrative/guide page into the Forge USA pack chrome.

Usage:
  python scripts/render-doc-page.py <name> [--root DIR]
    reads  <name>.md       (markdown body; first paragraph becomes the lede)
    reads  <name>.page.json (hero/footer/cta config — optional; sensible defaults)
    writes <name>.html

  --root defaults to the pack root. Point it elsewhere to render, in place, a
  page that lives outside the pack — a setup guide or role supplement kept
  alongside other course material — so it regenerates from its markdown rather
  than being hand-maintained and silently drifting from its source.

This is the generic version of render-sop-page.py — use it for setup.html,
role-supplements.html, and any future standalone page so they all share one
look-and-feel and stay regeneratable as Forge USA grows.

<name>.page.json schema (all optional):
{
  "title": "Set up your <strong>workspace.</strong>",   // <strong> allowed
  "subtitle": "one-line hero subtitle",
  "eyebrow": "Setup · one-time, ~45-60 min",
  "breadcrumb": "<a href=\"index.html\">&larr; Forge USA Learning Pack</a>",
  "pills": ["VS Code", "GitHub Copilot", "Windows"],
  "lede_accent": "#00B294",            // left border of the lede paragraph
  "cta": {                              // optional closing call-to-action card
    "title": "...", "body": "...",
    "links": [{"href": "x.html", "label": "Open", "secondary": false}]
  },
  "footer": "<a href=\"index.html\">Forge USA Learning Pack</a>"
}
"""
import sys, json, argparse, re
from pathlib import Path
from markdown_it import MarkdownIt

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent

ap = argparse.ArgumentParser()
ap.add_argument("name", help="basename of the .md file (and .page.json), without extension")
ap.add_argument("--root", default=None,
                help="directory holding <name>.md; defaults to the pack root. Use this to render a "
                     "page that lives outside the pack (e.g. a setup guide kept with other course "
                     "material) in place, so it regenerates instead of being hand-maintained.")
args = ap.parse_args()

root = Path(args.root).resolve() if args.root else ROOT
if not root.is_dir():
    raise SystemExit(f"--root is not a directory: {root}")

md_path = root / f"{args.name}.md"
cfg_path = root / f"{args.name}.page.json"
out_path = root / f"{args.name}.html"

if not md_path.exists():
    raise SystemExit(f"no markdown source at {md_path}")

cfg = json.loads(cfg_path.read_text(encoding="utf-8")) if cfg_path.exists() else {}
title = cfg.get("title", args.name.replace("-", " ").title())
subtitle = cfg.get("subtitle", "")
eyebrow = cfg.get("eyebrow", "")
breadcrumb = cfg.get("breadcrumb", '<a href="index.html">&larr; Forge USA Learning Pack</a>')
pills = cfg.get("pills", [])
lede_accent = cfg.get("lede_accent", "#00B294")
footer = cfg.get("footer", 'Part of the <a href="index.html">Forge USA Learning Pack</a>')
cta = cfg.get("cta")

_FRONTMATTER = re.compile(r"\A---\r?\n.*?\r?\n---\r?\n", re.S)
_LEADING_H1 = re.compile(r"\A\s*#\s+[^\n]*\r?\n")


def prepare(text: str) -> str:
    """Strip YAML frontmatter, and the leading H1 when the page config supplies a title.

    Pack pages carry neither — their title lives in <name>.page.json. Documents that
    also stand alone as markdown (a setup guide read straight from the repo) carry
    both, and would otherwise render frontmatter as body text and repeat their title
    under the hero.
    """
    text = _FRONTMATTER.sub("", text, count=1)
    if cfg.get("drop_h1"):
        text = _LEADING_H1.sub("", text, count=1)
    return text


md = MarkdownIt("commonmark", {"html": False, "breaks": False, "linkify": True}).enable(
    ["table", "strikethrough"])
body = md.render(prepare(md_path.read_text(encoding="utf-8")))

# Optional dual-mode: if <name>.fast.md exists, render it as a "Fast track"
# alternate view and emit a hero toggle that switches between the two. Pages
# without a .fast.md render exactly as before (single body, no toggle).
fast_path = root / f"{args.name}.fast.md"
has_fast = fast_path.exists()
body_fast = md.render(prepare(fast_path.read_text(encoding="utf-8"))) if has_fast else ""

modes_cfg = cfg.get("modes", {})
guided_label = modes_cfg.get("guided", "Guided walkthrough")
fast_label = modes_cfg.get("fast", "Fast track")
default_mode = modes_cfg.get("default", "guided")

# Plain-title fallback for <title> tag (strip any HTML)
import re
plain_title = re.sub(r"<[^>]+>", "", title)

pills_html = "".join(f"<span>{p}</span>" for p in pills)
pills_block = f'<div class="hero-pills">{pills_html}</div>' if pills else ""
eyebrow_block = f'<div class="page-eyebrow"><span style="color: var(--yellow);">&#9733;</span> {eyebrow}</div>' if eyebrow else ""

cta_block = ""
if cta:
    links = "".join(
        f'<a class="{"secondary" if l.get("secondary") else ""}" href="{l["href"]}">{l["label"]}</a>'
        for l in cta.get("links", [])
    )
    cta_block = f'''<div class="closing"><div class="cta-card">
    <h3>{cta.get("title","")}</h3>
    <p>{cta.get("body","")}</p>
    {links}
  </div></div>'''

# ── Dual-mode toggle assets (emitted only when a .fast.md exists) ──
if has_fast:
    body_attr = f' data-mode="{default_mode}"'
    toggle_block = f'''
    <div class="mode-toggle" role="group" aria-label="Choose reading depth">
      <button type="button" data-mode="guided">{guided_label}</button>
      <button type="button" data-mode="fast">{fast_label}</button>
    </div>'''
    content_block = (
        f'<div class="doc mode-guided">\n{body}\n  </div>\n'
        f'  <div class="doc mode-fast">\n{body_fast}\n  </div>'
    )
    toggle_css = """
  .mode-toggle { margin-top: 22px; display: inline-flex; background: rgba(7,159,195,0.15); border: 1px solid rgba(7,159,195,0.45); border-radius: 999px; padding: 4px; gap: 4px; }
  .mode-toggle button { font-family: inherit; font-size: 13px; font-weight: 600; letter-spacing: .3px; color: rgba(255,255,255,0.85); background: transparent; border: none; padding: 8px 18px; border-radius: 999px; cursor: pointer; transition: background .15s, color .15s; }
  .mode-toggle button:hover { color: #fff; }
  .mode-toggle button[aria-pressed="true"] { background: var(--cyan); color: #fff; }
  .mode-fast { display: none; }
  body[data-mode="fast"] .mode-guided { display: none; }
  body[data-mode="fast"] .mode-fast { display: block; }
"""
    toggle_script = """
<script>
(function(){
  var KEY='forgeSetupMode', root=document.body, saved;
  try { saved = localStorage.getItem(KEY); } catch(e){}
  if (saved==='fast' || saved==='guided') root.setAttribute('data-mode', saved);
  function wire(){
    var btns = document.querySelectorAll('.mode-toggle button');
    function apply(m){
      root.setAttribute('data-mode', m);
      try { localStorage.setItem(KEY, m); } catch(e){}
      btns.forEach(function(b){ b.setAttribute('aria-pressed', b.dataset.mode===m ? 'true' : 'false'); });
    }
    btns.forEach(function(b){ b.addEventListener('click', function(){ apply(b.dataset.mode); }); });
    apply(root.getAttribute('data-mode') || 'guided');
  }
  if (document.readyState==='loading') document.addEventListener('DOMContentLoaded', wire); else wire();
})();
</script>"""
else:
    body_attr = ""
    toggle_block = ""
    content_block = f'<div class="doc">\n{body}\n  </div>'
    toggle_css = ""
    toggle_script = ""

HTML = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{plain_title} — Forge USA Learning Pack</title>
<style>
  :root {{
    --navy: #00395F; --navy-dark: #00253D; --navy-light: #1A5A8A;
    --cyan: #079FC3; --cyan-light: #4AB9D4; --teal: #00B294;
    --red: #F1554B; --yellow: #F2B949; --slate: #44546A; --mute: #737373;
    --bg: #FAFBFC; --card-bg: #FFFFFF; --border: #E5E9EE;
  }}
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html {{ scroll-behavior: smooth; }}
  body {{ font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif; color: var(--navy); background: var(--bg); line-height: 1.6; -webkit-font-smoothing: antialiased; }}

  .arch-hero {{ background: linear-gradient(135deg, var(--navy-dark) 0%, var(--navy) 50%, var(--navy-light) 100%); color: white; padding: 56px 40px 64px; position: relative; overflow: hidden; }}
  .arch-hero::before {{ content: ''; position: absolute; top: -40%; right: -10%; width: 600px; height: 600px; background: radial-gradient(circle, rgba(7,159,195,0.22) 0%, transparent 65%); pointer-events: none; }}
  .arch-hero::after {{ content: ''; position: absolute; bottom: 0; left: 0; right: 0; height: 4px; background: linear-gradient(90deg, var(--cyan) 0%, var(--teal) 50%, var(--cyan) 100%); }}
  .arch-hero-inner {{ max-width: 1000px; margin: 0 auto; position: relative; }}
  .breadcrumb {{ color: var(--cyan-light); font-size: 13px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 12px; }}
  .breadcrumb a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74,185,212,0.5); padding-bottom: 2px; }}
  .page-eyebrow {{ color: var(--cyan-light); font-size: 13px; font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 14px; }}
  .arch-hero h1 {{ font-size: 50px; font-weight: 300; letter-spacing: -1px; line-height: 1.06; margin-bottom: 14px; }}
  .arch-hero h1 strong {{ font-weight: 600; color: var(--cyan-light); }}
  .arch-hero .subtitle {{ font-size: 19px; font-weight: 300; color: rgba(255,255,255,0.85); max-width: 820px; }}
  .hero-pills {{ margin-top: 22px; display: flex; gap: 10px; flex-wrap: wrap; }}
  .hero-pills span {{ font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.2px; padding: 5px 12px; border-radius: 999px; background: rgba(7,159,195,0.22); border: 1px solid rgba(7,159,195,0.55); }}

  main {{ max-width: 1000px; margin: 0 auto; padding: 48px 40px 40px; }}
  .doc h2 {{ font-size: 27px; color: var(--navy); font-weight: 600; margin: 44px 0 14px; padding-left: 14px; border-left: 4px solid var(--cyan); }}
  .doc h2:first-child {{ margin-top: 0; }}
  .doc h3 {{ font-size: 19px; color: var(--navy); font-weight: 600; margin: 24px 0 10px; }}
  .doc > p, .doc li {{ font-size: 16px; color: #1F2D3D; line-height: 1.72; }}
  .doc > p {{ margin-bottom: 16px; }}
  .doc ul, .doc ol {{ margin: 0 0 16px 1.5em; }}
  .doc li {{ margin-bottom: 9px; }}
  .doc strong {{ color: var(--navy); font-weight: 600; }}
  .doc em {{ color: var(--slate); }}
  .doc a {{ color: var(--cyan); text-decoration: none; border-bottom: 1px solid rgba(7,159,195,0.3); }}
  .doc a:hover {{ color: var(--navy); border-color: var(--navy); }}
  .doc code {{ background: #F4F7FA; color: var(--navy); padding: 1px 6px; border-radius: 4px; font-family: 'Cascadia Code', 'Consolas', monospace; font-size: 0.88em; border: 1px solid #DCE3EB; }}
  .doc pre {{ background: #00253D; color: #E6F4F9; padding: 16px 18px; border-radius: 8px; overflow-x: auto; margin: 0 0 16px; border: 1px solid #0a3a5c; }}
  .doc pre code {{ background: none; border: none; color: inherit; padding: 0; font-size: 13px; }}
  .doc table {{ border-collapse: collapse; width: 100%; margin: 0 0 18px; font-size: 14.5px; }}
  .doc th, .doc td {{ border: 1px solid var(--border); padding: 9px 12px; text-align: left; vertical-align: top; }}
  .doc th {{ background: #F0F6FB; color: var(--navy); font-weight: 600; }}
  .doc blockquote {{ border-left: 4px solid var(--yellow); background: rgba(242,185,73,0.10); padding: 12px 18px; border-radius: 0 8px 8px 0; margin: 0 0 16px; color: var(--slate); }}
  .doc blockquote p {{ margin: 0; }}
  .doc img {{ display: block; width: 100%; height: auto; margin: 22px 0 6px; border: 1px solid var(--border); border-radius: 12px; padding: 18px; background: #fff; box-shadow: 0 10px 30px rgba(0,57,95,0.07); }}
  .doc p:has(> img) {{ margin-bottom: 4px; }}
  .doc p:has(> img) + p {{ text-align: center; font-size: 13.5px; color: var(--mute); margin-top: 0; }}
  .doc > p:first-child {{ font-size: 19px; color: var(--slate); line-height: 1.7; border-left: 4px solid {lede_accent}; padding-left: 18px; }}

  .closing {{ max-width: 1000px; margin: 8px auto 0; padding: 0 40px 80px; }}
  .cta-card {{ background: linear-gradient(135deg, #E5F8F3 0%, #D1F2EA 100%); border-left: 4px solid var(--teal); border-radius: 0 12px 12px 0; padding: 26px 30px; }}
  .cta-card h3 {{ color: var(--navy); font-size: 20px; margin-bottom: 8px; }}
  .cta-card p {{ color: var(--navy); font-size: 16px; margin-bottom: 14px; }}
  .cta-card a {{ display: inline-block; background: var(--navy); color: white; text-decoration: none; font-weight: 600; font-size: 14px; padding: 9px 18px; border-radius: 6px; margin-right: 8px; margin-bottom: 6px; }}
  .cta-card a.secondary {{ background: transparent; color: var(--navy); border: 1px solid var(--navy); }}
  .cta-card a:hover {{ background: var(--cyan); color: white; border-color: var(--cyan); }}

  footer {{ background: var(--navy-dark); color: rgba(255,255,255,0.7); padding: 24px 40px; text-align: center; font-size: 13px; }}
  footer a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74,185,212,0.5); }}
  @media (max-width: 720px) {{ .arch-hero h1 {{ font-size: 34px; }} main {{ padding: 32px 22px 24px; }} .closing {{ padding: 0 22px 56px; }} }}
{toggle_css}</style>
</head>
<body{body_attr}>

<header class="arch-hero">
  <div class="arch-hero-inner">
    <div class="breadcrumb">{breadcrumb}</div>
    {eyebrow_block}
    <h1>{title}</h1>
    <p class="subtitle">{subtitle}</p>
    {pills_block}{toggle_block}
  </div>
</header>

<main>
  {content_block}
</main>

{cta_block}

<footer>
  {footer}
</footer>
{toggle_script}
</body>
</html>
"""

out_path.write_text(HTML, encoding="utf-8")
print(f"  wrote {out_path.name} (body {len(body):,} chars)")
