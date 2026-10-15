#!/usr/bin/env python3
"""generate-screen-guide.py — render a single screen's learning guide as HSO-themed HTML.

Reads metadata from a JSON file (one entry per screen) and renders each entry
to a standalone HTML page using the HSO theme. Also produces a library index.

Usage:
    python3 generate-screen-guide.py screens-metadata.json --out-dir ../screens-guides/
"""
import argparse
import json
import re
from pathlib import Path
from markdown_it import MarkdownIt

# Singleton markdown renderer
_MD = MarkdownIt('commonmark', {'html': False, 'breaks': False, 'linkify': True}).enable('strikethrough')


def md_inline(text: str) -> str:
    """Render markdown for text that lives inside an inline context (like an <li>) — strips outer <p> tags."""
    if not text:
        return ''
    rendered = _MD.render(text).strip()
    if rendered.startswith('<p>') and rendered.endswith('</p>') and rendered.count('<p>') == 1:
        rendered = rendered[3:-4]
    return rendered


def md_block(text: str) -> str:
    """Render markdown for text that lives in a block context — keeps <p> wrappers."""
    if not text:
        return ''
    return _MD.render(text).strip()

HSO_GUIDE_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} — ERP Unite Screen Guide</title>
<style>
  :root {{
    --navy: #00395F; --navy-dark: #00253D; --navy-light: #1A5A8A;
    --cyan: #079FC3; --cyan-light: #4AB9D4;
    --teal: #00B294; --red: #F1554B; --yellow: #F2B949;
    --slate: #44546A; --mute: #737373;
    --bg: #FAFBFC; --card-bg: #FFFFFF; --border: #E5E9EE;
  }}
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html {{ scroll-behavior: smooth; }}
  body {{ font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif; color: var(--navy); background: var(--bg); line-height: 1.6; -webkit-font-smoothing: antialiased; }}
  .guide-hero {{ background: linear-gradient(135deg, var(--navy-dark) 0%, var(--navy) 50%, var(--navy-light) 100%); color: white; padding: 48px 40px 56px; position: relative; overflow: hidden; }}
  .guide-hero::before {{ content: ''; position: absolute; top: -40%; right: -10%; width: 500px; height: 500px; background: radial-gradient(circle, rgba(7, 159, 195, 0.22) 0%, transparent 65%); pointer-events: none; }}
  .guide-hero::after {{ content: ''; position: absolute; bottom: 0; left: 0; right: 0; height: 4px; background: linear-gradient(90deg, var(--cyan) 0%, var(--teal) 50%, var(--cyan) 100%); }}
  .guide-hero-inner {{ max-width: 1100px; margin: 0 auto; position: relative; }}
  .breadcrumb {{ color: var(--cyan-light); font-size: 13px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 12px; }}
  .breadcrumb a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74, 185, 212, 0.5); padding-bottom: 2px; }}
  .breadcrumb a:hover {{ border-color: var(--cyan-light); }}
  .breadcrumb .sep {{ opacity: 0.5; margin: 0 8px; }}
  .guide-hero h1 {{ font-size: 44px; font-weight: 400; letter-spacing: -0.5px; line-height: 1.1; margin-bottom: 12px; }}
  .guide-hero .subtitle {{ font-size: 18px; font-weight: 300; color: rgba(255, 255, 255, 0.82); max-width: 720px; }}
  .guide-hero .pill-row {{ margin-top: 24px; display: flex; gap: 12px; flex-wrap: wrap; }}
  .pill {{ font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px; padding: 5px 12px; border-radius: 999px; }}
  .pill-app {{ background: rgba(7, 159, 195, 0.25); color: white; border: 1px solid rgba(7, 159, 195, 0.55); }}
  .pill-route {{ background: rgba(0, 0, 0, 0.25); color: var(--cyan-light); border: 1px solid rgba(74, 185, 212, 0.35); font-family: 'Cascadia Code', 'Consolas', monospace; letter-spacing: 0.5px; }}
  main {{ max-width: 1100px; margin: 0 auto; padding: 48px 40px 80px; }}
  .screenshot-frame {{ background: white; border: 1px solid var(--border); border-radius: 14px; padding: 14px; box-shadow: 0 14px 36px rgba(0, 57, 95, 0.10); margin-bottom: 48px; overflow: hidden; }}
  .screenshot-frame img {{ width: 100%; height: auto; border-radius: 8px; display: block; border: 1px solid var(--border); }}
  .screenshot-caption {{ display: flex; align-items: center; justify-content: space-between; padding: 14px 6px 4px; font-size: 13px; color: var(--mute); }}
  .screenshot-caption a {{ color: var(--cyan); text-decoration: none; font-weight: 600; }}
  .screenshot-caption a:hover {{ color: var(--navy); }}
  section.guide-block {{ margin-bottom: 36px; }}
  section.guide-block h2 {{ font-size: 22px; color: var(--navy); font-weight: 600; margin-bottom: 12px; padding-left: 14px; border-left: 4px solid var(--cyan); }}
  section.guide-block p {{ font-size: 16px; color: #1F2D3D; line-height: 1.7; margin-bottom: 12px; }}
  section.guide-block ul {{ margin-left: 1.4em; margin-bottom: 8px; }}
  section.guide-block ul li {{ margin-bottom: 6px; font-size: 15.5px; color: #1F2D3D; }}
  section.guide-block strong {{ color: var(--navy); font-weight: 600; }}
  section.guide-block em {{ color: var(--slate); }}
  .vocab-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; }}
  .vocab-card {{ background: white; border: 1px solid var(--border); border-radius: 8px; padding: 14px 16px; border-left: 3px solid var(--cyan); }}
  .vocab-term {{ font-weight: 600; color: var(--navy); font-size: 14.5px; }}
  .vocab-defn {{ color: var(--slate); font-size: 13.5px; margin-top: 4px; line-height: 1.5; }}
  .qa-list {{ list-style: none; margin-left: 0 !important; }}
  .qa-list li {{ background: white; border: 1px solid var(--border); border-radius: 8px; padding: 14px 18px; margin-bottom: 10px; border-left: 3px solid var(--yellow); }}
  .qa-q {{ font-weight: 600; color: var(--navy); font-size: 15px; margin-bottom: 6px; display: block; }}
  .qa-a {{ color: var(--slate); font-size: 14px; line-height: 1.6; }}
  .related-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 10px; }}
  .related-card {{ background: white; border: 1px solid var(--border); border-radius: 6px; padding: 10px 14px; text-decoration: none; color: var(--navy); font-size: 14px; font-weight: 600; transition: border-color 0.15s ease, background 0.15s ease; }}
  .related-card:hover {{ border-color: var(--cyan); background: #F0F6FB; }}
  .data-note {{ background: rgba(242, 185, 73, 0.13); border-left: 4px solid var(--yellow); padding: 14px 20px; border-radius: 0 8px 8px 0; font-size: 14px; color: var(--slate); margin-top: 16px; }}
  .data-note strong {{ color: var(--navy); }}
  /* Guide-block inline elements rendered from markdown */
  section.guide-block code {{ background: #F4F7FA; color: var(--navy); padding: 1px 6px; border-radius: 4px; font-family: 'Cascadia Code', 'Consolas', monospace; font-size: 0.92em; border: 1px solid #DCE3EB; }}
  section.guide-block a {{ color: var(--cyan); text-decoration: none; border-bottom: 1px solid rgba(7, 159, 195, 0.3); transition: border-color 0.15s ease; }}
  section.guide-block a:hover {{ color: var(--navy); border-color: var(--navy); }}
  section.guide-block img {{ display: block; max-width: 100%; height: auto; border-radius: 8px; border: 1px solid var(--border); margin: 16px auto; box-shadow: 0 6px 18px rgba(0, 57, 95, 0.08); }}
  section.guide-block p > img {{ margin-top: 12px; margin-bottom: 12px; }}
  section.guide-block h3 {{ font-size: 18px; color: var(--navy); margin-top: 24px; margin-bottom: 10px; font-weight: 600; }}
  section.guide-block ol {{ margin-left: 1.4em; margin-bottom: 8px; }}
  section.guide-block ol li {{ margin-bottom: 6px; font-size: 15.5px; color: #1F2D3D; }}
  section.guide-block strong {{ color: var(--navy); font-weight: 600; }}
  section.guide-block em {{ color: var(--slate); }}
  /* Prev / Next nav */
  .guide-nav {{ display: grid; grid-template-columns: 1fr auto 1fr; gap: 12px; align-items: stretch; margin: 24px 0; }}
  .guide-nav-top {{ margin-top: 0; margin-bottom: 36px; }}
  .guide-nav-bottom {{ margin-top: 48px; margin-bottom: 0; }}
  .guide-nav-btn {{ background: white; border: 1px solid var(--border); border-radius: 10px; padding: 12px 18px; text-decoration: none; color: var(--navy); display: flex; flex-direction: column; gap: 4px; transition: border-color 0.15s ease, background 0.15s ease, transform 0.15s ease; min-width: 0; }}
  .guide-nav-btn:hover:not(.disabled) {{ border-color: var(--cyan); background: #F0F6FB; transform: translateY(-1px); }}
  .guide-nav-btn.next {{ text-align: right; }}
  .guide-nav-btn.disabled {{ opacity: 0.45; cursor: default; }}
  .guide-nav-label {{ font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: var(--cyan); }}
  .guide-nav-btn.disabled .guide-nav-label {{ color: var(--mute); }}
  .guide-nav-title {{ font-size: 14px; font-weight: 600; color: var(--navy); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
  .guide-nav-pos {{ display: flex; flex-direction: column; align-items: center; justify-content: center; background: white; border: 1px solid var(--border); border-radius: 10px; padding: 12px 22px; text-decoration: none; color: var(--slate); font-size: 12px; letter-spacing: 0.5px; white-space: nowrap; transition: border-color 0.15s ease, color 0.15s ease; }}
  .guide-nav-pos strong {{ color: var(--navy); font-size: 17px; font-weight: 700; line-height: 1; margin-bottom: 4px; }}
  .guide-nav-pos:hover {{ border-color: var(--cyan); color: var(--cyan); }}
  @media (max-width: 720px) {{ .guide-nav {{ grid-template-columns: 1fr; }} .guide-nav-pos {{ order: -1; }} .guide-nav-btn.next {{ text-align: left; }} }}
  footer {{ background: var(--navy-dark); color: rgba(255, 255, 255, 0.7); padding: 24px 40px; text-align: center; font-size: 13px; }}
  footer a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74, 185, 212, 0.5); }}
  footer a:hover {{ color: white; border-color: white; }}
  @media (max-width: 720px) {{ .guide-hero {{ padding: 36px 22px 44px; }} .guide-hero h1 {{ font-size: 32px; }} main {{ padding: 32px 22px 56px; }} }}
</style>
</head>
<body>

<header class="guide-hero">
  <div class="guide-hero-inner">
    <div class="breadcrumb">
      <a href="index.html">← ERP Unite Learning Pack</a>
      <span class="sep">/</span>
      <a href="screens-library.html">Screens library</a>
    </div>
    <h1>{title}</h1>
    <p class="subtitle">{subtitle}</p>
    <div class="pill-row">
      <span class="pill pill-app">{app}</span>
      <span class="pill pill-route">{route}</span>
    </div>
  </div>
</header>

<main>

{nav_top}
  <div class="screenshot-frame">
    <img loading="lazy" src="{screenshot}" alt="{title} screen">
    <div class="screenshot-caption">
      <span>Captured {captured_at}</span>
      <a href="{screenshot}" target="_blank" rel="noopener">Open full-size →</a>
    </div>
  </div>
{data_note_html}
  <section class="guide-block">
    <h2>What this screen is</h2>
    {what_it_is_html}
  </section>

  <section class="guide-block">
    <h2>What you see on screen</h2>
    {what_you_see_html}
  </section>

  <section class="guide-block">
    <h2>Where the data comes from</h2>
    {data_sources_html}
  </section>

  <section class="guide-block">
    <h2>Business workflow context</h2>
    {workflow_context_html}
  </section>
{vocabulary_section}{questions_section}{related_section}
{nav_bottom}
</main>

<footer>
  Screen guide · part of the <a href="index.html">ERP Unite Learning Pack</a> · <a href="screens-library.html">full screens library</a>
</footer>

</body>
</html>
"""


def html_paragraphs(text_or_list):
    """Render text-or-list with markdown formatting applied (bold, italic, code, links)."""
    if isinstance(text_or_list, list):
        items = "".join(f"<li>{md_inline(line)}</li>" for line in text_or_list)
        return f"<ul>{items}</ul>"
    return md_block(text_or_list)


def vocab_section(vocab):
    if not vocab:
        return ""
    cards = "".join(
        f'<div class="vocab-card"><div class="vocab-term">{v["term"]}</div><div class="vocab-defn">{md_inline(v["definition"])}</div></div>'
        for v in vocab
    )
    return f'''
  <section class="guide-block">
    <h2>Vocabulary</h2>
    <div class="vocab-grid">{cards}</div>
  </section>
'''


def questions_section(questions):
    if not questions:
        return ""
    items = "".join(
        f'<li><span class="qa-q">{md_inline(q["q"])}</span><span class="qa-a">{md_inline(q["a"])}</span></li>'
        for q in questions
    )
    return f'''
  <section class="guide-block">
    <h2>Customer Q&amp;A hooks</h2>
    <ul class="qa-list">{items}</ul>
  </section>
'''


def related_section(related):
    if not related:
        return ""
    cards = "".join(
        f'<a class="related-card" href="screen-{r["id"]}.html">{r["title"]}</a>'
        for r in related
    )
    return f'''
  <section class="guide-block">
    <h2>Related screens</h2>
    <div class="related-grid">{cards}</div>
  </section>
'''


def data_note(entry):
    if not entry.get("needs_data"):
        return ""
    return f'''
  <div class="data-note">
    <strong>Note on data:</strong> This screen was captured with no records to display. {md_inline(entry.get("data_followup", "Coming back to this with sample data later."))}
  </div>
'''


def nav_section(prev_entry, next_entry, position, total, location='top'):
    """Prev / Next / position indicator. `location` is 'top' or 'bottom' for slight styling differences."""
    prev_html = (
        f'<a class="guide-nav-btn prev" href="screen-{prev_entry["id"]}.html">'
        f'<span class="guide-nav-label">← Previous</span>'
        f'<span class="guide-nav-title">{prev_entry["title"]}</span></a>'
        if prev_entry else
        '<span class="guide-nav-btn disabled"><span class="guide-nav-label">← Previous</span><span class="guide-nav-title">— start of library —</span></span>'
    )
    next_html = (
        f'<a class="guide-nav-btn next" href="screen-{next_entry["id"]}.html">'
        f'<span class="guide-nav-label">Next →</span>'
        f'<span class="guide-nav-title">{next_entry["title"]}</span></a>'
        if next_entry else
        '<span class="guide-nav-btn disabled"><span class="guide-nav-label">Next →</span><span class="guide-nav-title">— end of library —</span></span>'
    )
    pos_html = (
        f'<a class="guide-nav-pos" href="screens-library.html">'
        f'<strong>{position}</strong> / {total} · all screens</a>'
    )
    return f'<nav class="guide-nav guide-nav-{location}">{prev_html}{pos_html}{next_html}</nav>'


def render_one(entry, out_dir: Path, prev_entry=None, next_entry=None, position=1, total=1):
    out_path = out_dir / f"screen-{entry['id']}.html"
    rendered = HSO_GUIDE_TEMPLATE.format(
        title=entry["title"],
        subtitle=entry["subtitle"],
        app=entry["app"],
        route=entry["route"],
        screenshot=entry["screenshot"],
        captured_at=entry.get("captured_at", "2026-05"),
        data_note_html=data_note(entry),
        what_it_is_html=html_paragraphs(entry["what_it_is"]),
        what_you_see_html=html_paragraphs(entry["what_you_see"]),
        data_sources_html=html_paragraphs(entry["data_sources"]),
        workflow_context_html=html_paragraphs(entry["workflow_context"]),
        vocabulary_section=vocab_section(entry.get("vocabulary")),
        questions_section=questions_section(entry.get("questions")),
        related_section=related_section(entry.get("related", [])),
        nav_top=nav_section(prev_entry, next_entry, position, total, 'top'),
        nav_bottom=nav_section(prev_entry, next_entry, position, total, 'bottom'),
    )
    out_path.write_text(rendered, encoding="utf-8")
    return out_path


LIBRARY_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Screens Library — ERP Unite Learning Pack</title>
<style>
  :root {{ --navy: #00395F; --navy-dark: #00253D; --navy-light: #1A5A8A; --cyan: #079FC3; --cyan-light: #4AB9D4; --teal: #00B294; --yellow: #F2B949; --slate: #44546A; --mute: #737373; --bg: #FAFBFC; --border: #E5E9EE; }}
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: 'Segoe UI', sans-serif; color: var(--navy); background: var(--bg); line-height: 1.6; }}
  .hero {{ background: linear-gradient(135deg, var(--navy-dark) 0%, var(--navy) 50%, var(--navy-light) 100%); color: white; padding: 60px 40px 80px; position: relative; }}
  .hero::after {{ content: ''; position: absolute; bottom: 0; left: 0; right: 0; height: 4px; background: linear-gradient(90deg, var(--cyan) 0%, var(--teal) 50%, var(--cyan) 100%); }}
  .hero-inner {{ max-width: 1300px; margin: 0 auto; }}
  .breadcrumb {{ color: var(--cyan-light); font-size: 13px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 12px; }}
  .breadcrumb a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74, 185, 212, 0.5); }}
  .hero h1 {{ font-size: 56px; font-weight: 300; letter-spacing: -1px; margin-bottom: 14px; }}
  .hero h1 strong {{ font-weight: 600; color: var(--cyan-light); }}
  .hero p {{ font-size: 19px; color: rgba(255, 255, 255, 0.8); max-width: 720px; }}
  main {{ max-width: 1300px; margin: 0 auto; padding: 56px 40px 80px; }}
  .group-label {{ font-size: 13px; font-weight: 700; color: var(--cyan); text-transform: uppercase; letter-spacing: 2px; margin-top: 36px; margin-bottom: 18px; padding-bottom: 8px; border-bottom: 1px solid var(--border); }}
  .group-label:first-child {{ margin-top: 0; }}
  .lib-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 18px; }}
  .lib-card {{ background: white; border: 1px solid var(--border); border-radius: 10px; overflow: hidden; text-decoration: none; color: inherit; transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease; display: block; }}
  .lib-card:hover {{ transform: translateY(-3px); box-shadow: 0 12px 28px rgba(0, 57, 95, 0.14); border-color: var(--cyan); }}
  .lib-thumb {{ aspect-ratio: 16/9; overflow: hidden; background: #F4F7FA; }}
  .lib-thumb img {{ width: 100%; height: 100%; object-fit: cover; object-position: top left; display: block; transition: transform 0.4s ease; }}
  .lib-card:hover .lib-thumb img {{ transform: scale(1.04); }}
  .lib-meta {{ padding: 14px 18px; border-top: 1px solid var(--border); }}
  .lib-title {{ font-size: 15.5px; font-weight: 600; color: var(--navy); margin-bottom: 4px; }}
  .lib-sub {{ font-size: 13px; color: var(--mute); }}
  .lib-flag-needs-data {{ display: inline-block; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; padding: 3px 8px; border-radius: 4px; background: rgba(242, 185, 73, 0.2); color: #8a6914; margin-top: 6px; }}
  footer {{ background: var(--navy-dark); color: rgba(255, 255, 255, 0.7); padding: 24px 40px; text-align: center; font-size: 13px; }}
  footer a {{ color: var(--cyan-light); text-decoration: none; }}
</style>
</head>
<body>

<header class="hero">
  <div class="hero-inner">
    <div class="breadcrumb"><a href="index.html">← ERP Unite Learning Pack</a></div>
    <h1>Screens <strong>Library</strong></h1>
    <p>Every screen of ERP Unite, with a learning guide behind each tile. Click through for what it does, where the data comes from, the workflow it sits in, the vocabulary you need, and the customer questions it answers.</p>
  </div>
</header>

<main>
{groups_html}
</main>

<footer>
  Part of the <a href="index.html">ERP Unite Learning Pack</a> · {n_screens} screens documented
</footer>

</body>
</html>
"""


def render_library(entries, out_dir: Path):
    by_group = {}
    for e in entries:
        g = e.get("group", e["app"])
        by_group.setdefault(g, []).append(e)

    groups_html_parts = []
    for group, items in by_group.items():
        cards = "".join(
            f'''<a class="lib-card" href="screen-{e["id"]}.html">
  <div class="lib-thumb"><img loading="lazy" src="{e["screenshot"]}" alt="{e["title"]}"></div>
  <div class="lib-meta">
    <div class="lib-title">{e["title"]}</div>
    <div class="lib-sub">{e["subtitle"]}</div>
    {('<span class="lib-flag-needs-data">Needs data</span>' if e.get("needs_data") else "")}
  </div>
</a>'''
            for e in items
        )
        groups_html_parts.append(f'<div class="group-label">{group}</div><div class="lib-grid">{cards}</div>')

    out_path = out_dir / "screens-library.html"
    out_path.write_text(
        LIBRARY_TEMPLATE.format(groups_html="".join(groups_html_parts), n_screens=len(entries)),
        encoding="utf-8",
    )
    return out_path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata", help="Path to screens-metadata.json")
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    entries = json.loads(Path(args.metadata).read_text())
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    total = len(entries)
    for i, entry in enumerate(entries):
        prev_entry = entries[i - 1] if i > 0 else None
        next_entry = entries[i + 1] if i < total - 1 else None
        out = render_one(entry, out_dir, prev_entry, next_entry, i + 1, total)
        print(f"  ✓ {entry['id']} → {out.name}")

    lib = render_library(entries, out_dir)
    print(f"\n  ✓ Library index → {lib.name}")
    print(f"\nTotal: {len(entries)} guides + 1 library index")


if __name__ == "__main__":
    main()
