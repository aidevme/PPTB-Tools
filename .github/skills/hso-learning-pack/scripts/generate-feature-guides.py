#!/usr/bin/env python3
"""generate-feature-guide.py — render feature-by-feature learning guides.

Mirrors generate-screen-guide.py but each entry is a *feature* (a business
capability) rather than a screen. Each feature page:
  - HSO-themed hero
  - Optional screenshot of the most representative screen
  - "What it does" / "Problem it solves" / "What the user does" / "Business value"
  - List of key screens (links to per-screen guides)
  - Collapsed technical anchors section for developers
  - Prev / Next navigation across all features
  - Cross-links to related features

Inputs:
  feature-metadata.json — list of feature entries (see schema below)

Outputs (next to the JSON):
  feature-{id}.html  — one per feature
  feature-library.html — index grouped by hub

Schema per entry:
  {
    "id": "cashhub-statement-intake",
    "group": "Cash Hub",
    "title": "Statement Intake",
    "subtitle": "One screen for receiving every commission statement.",
    "hero_screenshot": "screens-onedigital/cashhub-statements-list.png",
    "what_it_does": "markdown text",
    "the_problem": "markdown text",
    "what_user_does": ["markdown bullet", ...],
    "key_screens": [{"id": "cashhub-statements-list", "title": "..."}],
    "business_value": "markdown text",
    "technical_anchors": "markdown text",
    "related_features": [{"id": "...", "title": "..."}]
  }
"""
import argparse
import json
import re
from pathlib import Path
from markdown_it import MarkdownIt

_MD = MarkdownIt('commonmark', {'html': False, 'breaks': False, 'linkify': True}).enable(['table', 'strikethrough'])


def md_inline(text: str) -> str:
    if not text: return ''
    rendered = _MD.render(text).strip()
    if rendered.startswith('<p>') and rendered.endswith('</p>') and rendered.count('<p>') == 1:
        rendered = rendered[3:-4]
    return rendered


def md_block(text: str) -> str:
    if not text: return ''
    return _MD.render(text).strip()


HSO_FEATURE_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} — ERP Unite Feature Guide</title>
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

  .feature-hero {{ background: linear-gradient(135deg, var(--navy-dark) 0%, var(--navy) 50%, var(--navy-light) 100%); color: white; padding: 56px 40px 64px; position: relative; overflow: hidden; }}
  .feature-hero::before {{ content: ''; position: absolute; top: -40%; right: -10%; width: 600px; height: 600px; background: radial-gradient(circle, rgba(7, 159, 195, 0.22) 0%, transparent 65%); pointer-events: none; }}
  .feature-hero::after {{ content: ''; position: absolute; bottom: 0; left: 0; right: 0; height: 4px; background: linear-gradient(90deg, var(--cyan) 0%, var(--teal) 50%, var(--cyan) 100%); }}
  .feature-hero-inner {{ max-width: 1100px; margin: 0 auto; position: relative; }}
  .breadcrumb {{ color: var(--cyan-light); font-size: 13px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 12px; }}
  .breadcrumb a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74, 185, 212, 0.5); padding-bottom: 2px; }}
  .breadcrumb a:hover {{ border-color: var(--cyan-light); }}
  .breadcrumb .sep {{ opacity: 0.5; margin: 0 8px; }}
  .feature-hero h1 {{ font-size: 48px; font-weight: 400; letter-spacing: -0.5px; line-height: 1.08; margin-bottom: 14px; }}
  .feature-hero .subtitle {{ font-size: 19px; font-weight: 300; color: rgba(255, 255, 255, 0.85); max-width: 760px; }}
  .feature-hero .pill-row {{ margin-top: 22px; display: flex; gap: 12px; flex-wrap: wrap; }}
  .pill {{ font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px; padding: 5px 12px; border-radius: 999px; background: rgba(7, 159, 195, 0.22); color: white; border: 1px solid rgba(7, 159, 195, 0.55); }}

  main {{ max-width: 1100px; margin: 0 auto; padding: 40px 40px 80px; }}

  .feature-hero-image {{ background: white; border: 1px solid var(--border); border-radius: 14px; padding: 14px; box-shadow: 0 14px 36px rgba(0, 57, 95, 0.10); margin-bottom: 40px; overflow: hidden; }}
  .feature-hero-image img {{ width: 100%; height: auto; border-radius: 8px; display: block; border: 1px solid var(--border); }}
  .feature-hero-image .caption {{ display: flex; align-items: center; justify-content: space-between; padding: 14px 6px 4px; font-size: 13px; color: var(--mute); }}
  .feature-hero-image .caption a {{ color: var(--cyan); text-decoration: none; font-weight: 600; }}

  section.feature-block {{ margin-bottom: 40px; }}
  section.feature-block h2 {{ font-size: 24px; color: var(--navy); font-weight: 600; margin-bottom: 14px; padding-left: 14px; border-left: 4px solid var(--cyan); }}
  section.feature-block p {{ font-size: 16.5px; color: #1F2D3D; line-height: 1.72; margin-bottom: 14px; }}
  section.feature-block ul, section.feature-block ol {{ margin-left: 1.4em; margin-bottom: 10px; }}
  section.feature-block li {{ margin-bottom: 8px; font-size: 16px; color: #1F2D3D; line-height: 1.65; }}
  section.feature-block strong {{ color: var(--navy); font-weight: 600; }}
  section.feature-block em {{ color: var(--slate); }}
  section.feature-block code {{ background: #F4F7FA; color: var(--navy); padding: 1px 6px; border-radius: 4px; font-family: 'Cascadia Code', 'Consolas', monospace; font-size: 0.9em; border: 1px solid #DCE3EB; }}
  section.feature-block a {{ color: var(--cyan); text-decoration: none; border-bottom: 1px solid rgba(7, 159, 195, 0.3); }}
  section.feature-block a:hover {{ color: var(--navy); border-color: var(--navy); }}

  .key-screens {{ background: #F0F6FB; border: 1px solid var(--border); border-radius: 12px; padding: 24px 28px; }}
  .key-screens-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 10px; margin-top: 10px; }}
  .key-screens-grid a {{ background: white; border: 1px solid var(--border); border-left: 3px solid var(--cyan); border-radius: 6px; padding: 12px 14px; text-decoration: none; color: var(--navy); font-weight: 600; font-size: 14.5px; transition: all 0.15s ease; display: block; }}
  .key-screens-grid a:hover {{ border-color: var(--cyan); background: #E6F4F9; transform: translateY(-1px); }}

  .value-callout {{ background: linear-gradient(135deg, #E5F8F3 0%, #D1F2EA 100%); border-left: 4px solid var(--teal); border-radius: 0 12px 12px 0; padding: 20px 26px; margin: 0; }}
  .value-callout p {{ color: var(--navy); font-weight: 500; }}
  .value-callout p:first-of-type::before {{ content: '★ '; color: var(--teal); font-weight: 700; }}

  details.tech-anchors {{ background: #FAFBFC; border: 1px solid var(--border); border-radius: 8px; padding: 14px 22px; margin-top: 30px; }}
  details.tech-anchors summary {{ font-weight: 600; color: var(--navy); cursor: pointer; padding: 4px 0; font-size: 15px; letter-spacing: 0.3px; }}
  details.tech-anchors summary:hover {{ color: var(--cyan); }}
  details.tech-anchors[open] summary {{ margin-bottom: 12px; border-bottom: 1px solid var(--border); padding-bottom: 10px; }}
  details.tech-anchors .tech-body p {{ font-size: 14.5px; color: var(--slate); line-height: 1.65; margin-bottom: 10px; }}
  details.tech-anchors .tech-body code {{ background: #F0F4F8; }}

  .related-features {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 10px; }}
  .related-features a {{ background: white; border: 1px solid var(--border); border-radius: 6px; padding: 10px 14px; text-decoration: none; color: var(--navy); font-size: 14px; font-weight: 600; }}
  .related-features a:hover {{ border-color: var(--cyan); background: #F0F6FB; }}

  /* Prev/Next nav (same as screen guides) */
  .feature-nav {{ display: grid; grid-template-columns: 1fr auto 1fr; gap: 12px; align-items: stretch; margin: 24px 0; }}
  .feature-nav-top {{ margin-top: 0; margin-bottom: 36px; }}
  .feature-nav-bottom {{ margin-top: 56px; margin-bottom: 0; }}
  .feature-nav-btn {{ background: white; border: 1px solid var(--border); border-radius: 10px; padding: 12px 18px; text-decoration: none; color: var(--navy); display: flex; flex-direction: column; gap: 4px; transition: border-color 0.15s ease, background 0.15s ease, transform 0.15s ease; min-width: 0; }}
  .feature-nav-btn:hover:not(.disabled) {{ border-color: var(--cyan); background: #F0F6FB; transform: translateY(-1px); }}
  .feature-nav-btn.next {{ text-align: right; }}
  .feature-nav-btn.disabled {{ opacity: 0.45; cursor: default; }}
  .feature-nav-label {{ font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: var(--cyan); }}
  .feature-nav-btn.disabled .feature-nav-label {{ color: var(--mute); }}
  .feature-nav-title {{ font-size: 14px; font-weight: 600; color: var(--navy); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
  .feature-nav-pos {{ display: flex; flex-direction: column; align-items: center; justify-content: center; background: white; border: 1px solid var(--border); border-radius: 10px; padding: 12px 22px; text-decoration: none; color: var(--slate); font-size: 12px; letter-spacing: 0.5px; white-space: nowrap; }}
  .feature-nav-pos strong {{ color: var(--navy); font-size: 17px; font-weight: 700; line-height: 1; margin-bottom: 4px; }}
  .feature-nav-pos:hover {{ border-color: var(--cyan); color: var(--cyan); }}
  @media (max-width: 720px) {{ .feature-nav {{ grid-template-columns: 1fr; }} .feature-nav-pos {{ order: -1; }} .feature-nav-btn.next {{ text-align: left; }} }}

  footer {{ background: var(--navy-dark); color: rgba(255, 255, 255, 0.7); padding: 24px 40px; text-align: center; font-size: 13px; }}
  footer a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74, 185, 212, 0.5); }}
  footer a:hover {{ color: white; border-color: white; }}

  @media (max-width: 720px) {{ .feature-hero {{ padding: 40px 22px 48px; }} .feature-hero h1 {{ font-size: 34px; }} main {{ padding: 32px 22px 56px; }} }}
</style>
</head>
<body>

<header class="feature-hero">
  <div class="feature-hero-inner">
    <div class="breadcrumb">
      <a href="index.html">← ERP Unite Learning Pack</a>
      <span class="sep">/</span>
      <a href="feature-library.html">Feature library</a>
    </div>
    <h1>{title}</h1>
    <p class="subtitle">{subtitle}</p>
    <div class="pill-row">
      <span class="pill">{group}</span>
    </div>
  </div>
</header>

<main>
{nav_top}
{hero_image_html}
  <section class="feature-block">
    <h2>What it does</h2>
    {what_it_does_html}
  </section>

  <section class="feature-block">
    <h2>The problem it solves</h2>
    {the_problem_html}
  </section>

  <section class="feature-block">
    <h2>What the user actually does</h2>
    {what_user_does_html}
  </section>
{key_screens_section}
  <section class="feature-block">
    <h2>Business value</h2>
    <div class="value-callout">
      {business_value_html}
    </div>
  </section>
{technical_section}{related_section}
{nav_bottom}
</main>

<footer>
  Feature guide · part of the <a href="index.html">ERP Unite Learning Pack</a> · <a href="feature-library.html">full feature library</a>
</footer>

</body>
</html>
"""


def hero_image_block(entry):
    img = entry.get('hero_screenshot')
    if not img:
        return ''
    return f'''  <div class="feature-hero-image">
    <img loading="lazy" src="{img}" alt="{entry["title"]} representative screen">
    <div class="caption">
      <span>Representative screen</span>
      <a href="{img}" target="_blank" rel="noopener">Open full-size →</a>
    </div>
  </div>
'''


def html_paragraphs(text_or_list):
    if isinstance(text_or_list, list):
        items = "".join(f"<li>{md_inline(line)}</li>" for line in text_or_list)
        return f"<ul>{items}</ul>"
    return md_block(text_or_list or "")


def key_screens_section(screens):
    if not screens: return ''
    cards = "".join(
        f'<a href="screen-{s["id"]}.html">{s["title"]} →</a>'
        for s in screens
    )
    return f'''
  <section class="feature-block">
    <h2>Key screens</h2>
    <div class="key-screens">
      <p style="margin-bottom: 12px; color: var(--slate); font-size: 14.5px;">Click any screen to open its dedicated guide — what's on the page, where the data comes from, vocabulary, and customer Q&amp;A.</p>
      <div class="key-screens-grid">{cards}</div>
    </div>
  </section>
'''


def technical_section(tech):
    if not tech: return ''
    return f'''
  <details class="tech-anchors">
    <summary>Technical anchors (entities, handlers, integrations)</summary>
    <div class="tech-body">
      {md_block(tech)}
    </div>
  </details>
'''


def related_section(related):
    if not related: return ''
    cards = "".join(
        f'<a href="feature-{r["id"]}.html">{r["title"]}</a>'
        for r in related
    )
    return f'''
  <section class="feature-block">
    <h2>Related features</h2>
    <div class="related-features">{cards}</div>
  </section>
'''


def nav_block(prev_e, next_e, position, total, where='top'):
    prev_html = (
        f'<a class="feature-nav-btn prev" href="feature-{prev_e["id"]}.html">'
        f'<span class="feature-nav-label">← Previous</span>'
        f'<span class="feature-nav-title">{prev_e["title"]}</span></a>'
        if prev_e else
        '<span class="feature-nav-btn disabled"><span class="feature-nav-label">← Previous</span><span class="feature-nav-title">— start of library —</span></span>'
    )
    next_html = (
        f'<a class="feature-nav-btn next" href="feature-{next_e["id"]}.html">'
        f'<span class="feature-nav-label">Next →</span>'
        f'<span class="feature-nav-title">{next_e["title"]}</span></a>'
        if next_e else
        '<span class="feature-nav-btn disabled"><span class="feature-nav-label">Next →</span><span class="feature-nav-title">— end of library —</span></span>'
    )
    pos_html = (
        f'<a class="feature-nav-pos" href="feature-library.html">'
        f'<strong>{position}</strong> / {total} · all features</a>'
    )
    return f'<nav class="feature-nav feature-nav-{where}">{prev_html}{pos_html}{next_html}</nav>'


def render_one(entry, out_dir: Path, prev_e=None, next_e=None, pos=1, total=1):
    out_path = out_dir / f"feature-{entry['id']}.html"
    rendered = HSO_FEATURE_TEMPLATE.format(
        title=entry["title"],
        subtitle=entry["subtitle"],
        group=entry["group"],
        hero_image_html=hero_image_block(entry),
        what_it_does_html=html_paragraphs(entry.get("what_it_does", "")),
        the_problem_html=html_paragraphs(entry.get("the_problem", "")),
        what_user_does_html=html_paragraphs(entry.get("what_user_does", [])),
        key_screens_section=key_screens_section(entry.get("key_screens", [])),
        business_value_html=html_paragraphs(entry.get("business_value", "")),
        technical_section=technical_section(entry.get("technical_anchors")),
        related_section=related_section(entry.get("related_features", [])),
        nav_top=nav_block(prev_e, next_e, pos, total, 'top'),
        nav_bottom=nav_block(prev_e, next_e, pos, total, 'bottom'),
    )
    out_path.write_text(rendered, encoding="utf-8")
    return out_path


LIBRARY_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Feature Library — ERP Unite Learning Pack</title>
<style>
  :root {{ --navy: #00395F; --navy-dark: #00253D; --navy-light: #1A5A8A; --cyan: #079FC3; --cyan-light: #4AB9D4; --teal: #00B294; --red: #F1554B; --yellow: #F2B949; --slate: #44546A; --mute: #737373; --bg: #FAFBFC; --border: #E5E9EE; }}
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: 'Segoe UI', sans-serif; color: var(--navy); background: var(--bg); line-height: 1.6; }}
  .hero {{ background: linear-gradient(135deg, var(--navy-dark) 0%, var(--navy) 50%, var(--navy-light) 100%); color: white; padding: 64px 40px 84px; position: relative; }}
  .hero::after {{ content: ''; position: absolute; bottom: 0; left: 0; right: 0; height: 4px; background: linear-gradient(90deg, var(--cyan) 0%, var(--teal) 50%, var(--cyan) 100%); }}
  .hero-inner {{ max-width: 1300px; margin: 0 auto; }}
  .breadcrumb {{ color: var(--cyan-light); font-size: 13px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 14px; }}
  .breadcrumb a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74, 185, 212, 0.5); }}
  .hero h1 {{ font-size: 60px; font-weight: 300; letter-spacing: -1px; margin-bottom: 16px; }}
  .hero h1 strong {{ font-weight: 600; color: var(--cyan-light); }}
  .hero p {{ font-size: 20px; color: rgba(255, 255, 255, 0.82); max-width: 760px; }}
  main {{ max-width: 1300px; margin: 0 auto; padding: 60px 40px 80px; }}
  .group-label {{ font-size: 14px; font-weight: 700; color: var(--cyan); text-transform: uppercase; letter-spacing: 2px; margin-top: 48px; margin-bottom: 18px; padding-bottom: 10px; border-bottom: 2px solid var(--border); display: flex; justify-content: space-between; align-items: baseline; }}
  .group-label:first-child {{ margin-top: 0; }}
  .group-label .count {{ color: var(--mute); font-size: 12px; font-weight: 500; }}
  .feat-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(360px, 1fr)); gap: 18px; }}
  .feat-card {{ background: white; border: 1px solid var(--border); border-radius: 12px; padding: 22px 26px; text-decoration: none; color: inherit; transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease; display: flex; flex-direction: column; gap: 8px; min-height: 160px; }}
  .feat-card:hover {{ transform: translateY(-3px); box-shadow: 0 12px 28px rgba(0, 57, 95, 0.14); border-color: var(--cyan); }}
  .feat-card .num {{ font-size: 13px; font-weight: 700; color: var(--cyan); letter-spacing: 1.5px; }}
  .feat-card h3 {{ font-size: 19px; font-weight: 600; color: var(--navy); margin: 4px 0 6px 0; }}
  .feat-card p {{ font-size: 14.5px; color: var(--slate); line-height: 1.55; }}
  .feat-card .open-cue {{ margin-top: auto; padding-top: 12px; color: var(--cyan); font-size: 13px; font-weight: 600; }}
  footer {{ background: var(--navy-dark); color: rgba(255, 255, 255, 0.7); padding: 24px 40px; text-align: center; font-size: 13px; }}
  footer a {{ color: var(--cyan-light); text-decoration: none; }}
  @media (max-width: 720px) {{ .hero h1 {{ font-size: 40px; }} .feat-grid {{ grid-template-columns: 1fr; }} }}
</style>
</head>
<body>

<header class="hero">
  <div class="hero-inner">
    <div class="breadcrumb"><a href="index.html">← ERP Unite Learning Pack</a></div>
    <h1>Feature <strong>Library</strong></h1>
    <p>Every business capability of ERP Unite, organized by hub. Click any feature for what it does, the problem it solves, what the user does day-to-day, the key screens, and the business value — with technical anchors collapsed for the developers who need them.</p>
    <p style="margin-top: 18px; color: var(--cyan-light); font-size: 15px;">→ Read straight through with Next-Next-Next, or jump to any feature directly.</p>
  </div>
</header>

<main>
{groups_html}
</main>

<footer>
  Part of the <a href="index.html">ERP Unite Learning Pack</a> · {n_features} features · also see the <a href="screens-library.html">Screens library</a>
</footer>

</body>
</html>
"""


def render_library(entries, out_dir: Path):
    by_group = {}
    for i, e in enumerate(entries):
        by_group.setdefault(e["group"], []).append((i + 1, e))

    groups_html = []
    for group, items in by_group.items():
        cards = "".join(
            f'''<a class="feat-card" href="feature-{e["id"]}.html">
  <span class="num">{n:02d}</span>
  <h3>{e["title"]}</h3>
  <p>{e["subtitle"]}</p>
  <span class="open-cue">Open feature guide →</span>
</a>'''
            for (n, e) in items
        )
        groups_html.append(
            f'<div class="group-label"><span>{group}</span><span class="count">{len(items)} features</span></div>'
            f'<div class="feat-grid">{cards}</div>'
        )

    out_path = out_dir / "feature-library.html"
    out_path.write_text(
        LIBRARY_TEMPLATE.format(groups_html="".join(groups_html), n_features=len(entries)),
        encoding="utf-8",
    )
    return out_path


# ─── Hub overview pages ───

HUB_NARRATIVES = {
    "Cash Hub": {
        "slug": "cash-hub",
        "tagline": "The finance back office of an insurance brokerage. Where commission statements become posted GL entries.",
        "narrative": "Cash Hub is the workflow path from *'a carrier statement arrived'* to *'the GL is current.'* Statements get ingested, parsed by template, matched to products and customers, reconciled against bank deposits, posted as journals. At month-end, accruals book what hasn't materialized as cash yet; aged accruals roll into collections cases that either resolve or write off.\n\nThis hub owns more screens than any other in Unite — and more business risk. Get cash application wrong and the brokerage's GL doesn't balance. Get accruals wrong and the close slips by days. The features here exist to make every step explicit, every decision audited, every variance investigable.\n\nThe features below span the full flow: **statement ingestion → Mapping Studio (the AI authoring surface) → the 6-tab Statement Detail workflow → cash app matching → reconciliation with cash deposits → AH journals → accruals → collections.** Walk them in order to follow the workflow end-to-end.",
        "stats": [
            {"value": "10", "label": "features"},
            {"value": "200+", "label": "carrier formats handled"},
            {"value": "AI-driven", "label": "template authoring"},
        ],
    },
    "Compensation Hub": {
        "slug": "comp-hub",
        "tagline": "Producer pay, made auditable. The system of record for compensation rules, splits, and payouts.",
        "narrative": "Compensation Hub is the system of record for everything that drives what a producer earns: the compensation plan (PCP) per producer × vertical, the split intake (SIF) per opportunity, the rate tables, the change audit log, the coverage-gap audits that catch unconfigured products *before* they create unpaid producers.\n\nThe hub bridges two worlds. **Inbound** from Accounting Hub: actuals calculated against posted commissions. **Outbound** to AH: approved payable transactions for the payroll path. Between them: the human work of authoring SIFs, approving them, managing producer master data, and handling adjustments.\n\nProducer disputes — historically a major back-office time sink — drop dramatically once every dollar paid has a documented source. The features below cover the full lifecycle from rate-table setup through SIF approval through actuals batch processing.",
        "stats": [
            {"value": "7", "label": "features"},
            {"value": "Versioned", "label": "SIF history forever"},
            {"value": "AH ↔ Unite", "label": "bidirectional"},
        ],
    },
    "Producer Portal": {
        "slug": "producer-portal",
        "tagline": "The external surface. Producers and brokers sign in to see their own splits and reports.",
        "narrative": "Producer Portal lives on its own subdomain (`salescomp-dev.onedigital.com`), separate from the internal hubs. It's where independent producers and broker partners sign in to see their own splits, submit changes, and view their compensation reports.\n\n**Authentication is dual-OIDC**: HSO / OneDigital staff sign in via the internal Entra tenant; external partners via a separate B2B/B2C tenant. Same data underneath, scoped per user via the AnyHierarchy permission gate — different audiences see different slices.\n\nFor the brokerage, this is producer-relationship infrastructure. A producer who can self-serve their pay detail trusts the system. A producer who has to call the back office to ask 'where's my check?' becomes a flight risk. The features below give producers the self-service surface that the internal hubs don't expose.",
        "stats": [
            {"value": "2", "label": "features"},
            {"value": "Dual-OIDC", "label": "internal + external auth"},
            {"value": "AnyHierarchy", "label": "permission gate"},
        ],
    },
    "Integration Hub": {
        "slug": "integration-hub",
        "tagline": "Six Azure Function apps wiring Unite to the rest of the customer's tech estate.",
        "narrative": "Integration Hub is the plumbing — six Azure Function apps that connect Unite to everything else the brokerage runs: Accounting Hub, FinOps / Dynamics 365, Workday, Mulesoft, Databricks, Microsoft Entra. Where Cash Hub and Comp Hub are user-facing, Integration Hub is unattended infrastructure.\n\nThe architectural pattern is consistent across all six apps: **handoff/polling pairs**. A handoff function is blob-triggered and pushes data immediately when a file lands; a polling function is timer-triggered and scans the database for changed records to send out. Every transfer is logged in `ImportsStatistics` for end-to-end auditability.\n\nAdding a new integration is a known recipe (build a new handoff/polling pair against `ImportsStatistics`), not an architecture decision. The features below cover the highest-leverage integrations; the rest are catalogued in the library.",
        "stats": [
            {"value": "6", "label": "function apps"},
            {"value": "90+", "label": "integration touchpoints"},
            {"value": "ImportsStatistics", "label": "audit table"},
        ],
    },
    "Cross-cutting": {
        "slug": "cross-cutting",
        "tagline": "The substrate every feature stands on — authorization, workflow, AI services.",
        "narrative": "Cross-cutting features aren't user-facing surfaces in their own right — they're the shared substrate that every other feature builds on. The authorization framework decides who sees what. The workflow framework gives every business process the same shape. The AI services layer keeps Gemini-driven inference behind a swappable, auditable abstraction.\n\nThese aren't optional. They're invisible when they work and catastrophic when they don't. The features below document what's in each so developers don't reinvent and architects know what's reusable.",
        "stats": [
            {"value": "3", "label": "features"},
            {"value": "Shared", "label": "across all hubs"},
            {"value": "Pluggable", "label": "AI vendor abstraction"},
        ],
    },
}


HUB_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{name} — ERP Unite</title>
<style>
  :root {{ --navy: #00395F; --navy-dark: #00253D; --navy-light: #1A5A8A; --cyan: #079FC3; --cyan-light: #4AB9D4; --teal: #00B294; --red: #F1554B; --yellow: #F2B949; --slate: #44546A; --mute: #737373; --bg: #FAFBFC; --border: #E5E9EE; }}
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html {{ scroll-behavior: smooth; }}
  body {{ font-family: 'Segoe UI', sans-serif; color: var(--navy); background: var(--bg); line-height: 1.6; }}
  .hub-hero {{ background: linear-gradient(135deg, var(--navy-dark) 0%, var(--navy) 50%, var(--navy-light) 100%); color: white; padding: 64px 40px 84px; position: relative; overflow: hidden; }}
  .hub-hero::before {{ content: ''; position: absolute; top: -50%; right: -10%; width: 600px; height: 600px; background: radial-gradient(circle, rgba(7, 159, 195, 0.22) 0%, transparent 65%); pointer-events: none; }}
  .hub-hero::after {{ content: ''; position: absolute; bottom: 0; left: 0; right: 0; height: 4px; background: linear-gradient(90deg, var(--cyan) 0%, var(--teal) 50%, var(--cyan) 100%); }}
  .hub-hero-inner {{ max-width: 1200px; margin: 0 auto; position: relative; }}
  .breadcrumb {{ color: var(--cyan-light); font-size: 13px; font-weight: 600; letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 14px; }}
  .breadcrumb a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74, 185, 212, 0.5); padding-bottom: 2px; }}
  .breadcrumb a:hover {{ border-color: var(--cyan-light); }}
  .breadcrumb .sep {{ opacity: 0.5; margin: 0 8px; }}
  .hub-hero h1 {{ font-size: 64px; font-weight: 300; letter-spacing: -1.5px; line-height: 1.04; margin-bottom: 16px; }}
  .hub-hero h1 strong {{ font-weight: 600; color: var(--cyan-light); }}
  .hub-hero .tagline {{ font-size: 22px; font-weight: 300; color: rgba(255,255,255,0.85); max-width: 800px; margin-bottom: 36px; }}
  .hub-stats {{ display: flex; gap: 48px; flex-wrap: wrap; margin-top: 12px; }}
  .hub-stat {{ border-left: 3px solid var(--cyan); padding-left: 16px; }}
  .hub-stat-value {{ font-size: 28px; font-weight: 600; color: white; line-height: 1; }}
  .hub-stat-label {{ font-size: 13px; color: rgba(255,255,255,0.7); margin-top: 6px; letter-spacing: 0.5px; }}

  main {{ max-width: 1200px; margin: 0 auto; padding: 56px 40px 80px; }}
  .hub-narrative {{ background: white; border: 1px solid var(--border); border-radius: 14px; padding: 36px 44px; margin-bottom: 48px; box-shadow: 0 6px 18px rgba(0,57,95,0.05); }}
  .hub-narrative .section-eyebrow {{ color: var(--cyan); font-size: 13px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; margin-bottom: 12px; }}
  .hub-narrative h2 {{ font-size: 28px; font-weight: 500; color: var(--navy); margin-bottom: 16px; }}
  .hub-narrative p {{ font-size: 16.5px; color: #1F2D3D; line-height: 1.75; margin-bottom: 14px; }}
  .hub-narrative p:last-child {{ margin-bottom: 0; }}
  .hub-narrative strong {{ color: var(--navy); font-weight: 600; }}
  .hub-narrative em {{ color: var(--slate); }}
  .hub-narrative code {{ background: #F4F7FA; color: var(--navy); padding: 1px 6px; border-radius: 4px; font-family: 'Cascadia Code', 'Consolas', monospace; font-size: 0.92em; border: 1px solid #DCE3EB; }}

  .features-eyebrow {{ font-size: 14px; font-weight: 700; color: var(--cyan); text-transform: uppercase; letter-spacing: 2px; margin-bottom: 18px; padding-bottom: 10px; border-bottom: 2px solid var(--border); display: flex; justify-content: space-between; align-items: baseline; }}
  .features-eyebrow .count {{ color: var(--mute); font-size: 12px; font-weight: 500; }}
  .feat-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(360px, 1fr)); gap: 18px; }}
  .feat-card {{ background: white; border: 1px solid var(--border); border-radius: 12px; padding: 22px 26px; text-decoration: none; color: inherit; transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease; display: flex; flex-direction: column; gap: 8px; min-height: 160px; }}
  .feat-card:hover {{ transform: translateY(-3px); box-shadow: 0 12px 28px rgba(0, 57, 95, 0.14); border-color: var(--cyan); }}
  .feat-card .num {{ font-size: 13px; font-weight: 700; color: var(--cyan); letter-spacing: 1.5px; }}
  .feat-card h3 {{ font-size: 19px; font-weight: 600; color: var(--navy); margin: 4px 0 6px 0; }}
  .feat-card p {{ font-size: 14.5px; color: var(--slate); line-height: 1.55; }}
  .feat-card .open-cue {{ margin-top: auto; padding-top: 12px; color: var(--cyan); font-size: 13px; font-weight: 600; }}

  /* Hub-level prev/next */
  .hub-nav {{ display: grid; grid-template-columns: 1fr auto 1fr; gap: 12px; align-items: stretch; margin: 48px 0 0 0; }}
  .hub-nav-btn {{ background: white; border: 1px solid var(--border); border-radius: 10px; padding: 14px 20px; text-decoration: none; color: var(--navy); display: flex; flex-direction: column; gap: 4px; transition: border-color 0.15s ease, background 0.15s ease, transform 0.15s ease; min-width: 0; }}
  .hub-nav-btn:hover:not(.disabled) {{ border-color: var(--cyan); background: #F0F6FB; transform: translateY(-1px); }}
  .hub-nav-btn.next {{ text-align: right; }}
  .hub-nav-btn.disabled {{ opacity: 0.45; cursor: default; }}
  .hub-nav-label {{ font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: var(--cyan); }}
  .hub-nav-btn.disabled .hub-nav-label {{ color: var(--mute); }}
  .hub-nav-title {{ font-size: 15px; font-weight: 600; color: var(--navy); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
  .hub-nav-pos {{ display: flex; flex-direction: column; align-items: center; justify-content: center; background: white; border: 1px solid var(--border); border-radius: 10px; padding: 12px 24px; text-decoration: none; color: var(--slate); font-size: 12px; letter-spacing: 0.5px; white-space: nowrap; }}
  .hub-nav-pos:hover {{ border-color: var(--cyan); color: var(--cyan); }}

  footer {{ background: var(--navy-dark); color: rgba(255,255,255,0.7); padding: 24px 40px; text-align: center; font-size: 13px; }}
  footer a {{ color: var(--cyan-light); text-decoration: none; border-bottom: 1px dotted rgba(74, 185, 212, 0.5); }}
  footer a:hover {{ color: white; border-color: white; }}

  @media (max-width: 720px) {{ .hub-hero h1 {{ font-size: 40px; }} .hub-hero .tagline {{ font-size: 17px; }} .feat-grid {{ grid-template-columns: 1fr; }} .hub-nav {{ grid-template-columns: 1fr; }} }}
</style>
</head>
<body>

<header class="hub-hero">
  <div class="hub-hero-inner">
    <div class="breadcrumb">
      <a href="index.html">← ERP Unite Learning Pack</a>
      <span class="sep">/</span>
      <a href="feature-library.html">Feature library</a>
    </div>
    <h1>{name_html}</h1>
    <p class="tagline">{tagline}</p>
    <div class="hub-stats">
      {stats_html}
    </div>
  </div>
</header>

<main>
  <div class="hub-narrative">
    <div class="section-eyebrow">What this hub is</div>
    {narrative_html}
  </div>

  <div class="features-eyebrow">
    <span>Features in this hub</span>
    <span class="count">{feature_count} feature{plural}</span>
  </div>
  <div class="feat-grid">
{feature_cards}
  </div>

  <nav class="hub-nav">
    {prev_btn}
    <a class="hub-nav-pos" href="feature-library.html">All hubs ·  full library</a>
    {next_btn}
  </nav>
</main>

<footer>
  Part of the <a href="index.html">ERP Unite Learning Pack</a> · also: <a href="feature-library.html">Feature library</a> · <a href="screens-library.html">Screens library</a>
</footer>

</body>
</html>
"""


def split_name_for_h1(name: str) -> str:
    """Split 'Compensation Hub' -> 'Compensation <strong>Hub</strong>'."""
    parts = name.rsplit(' ', 1)
    if len(parts) == 2:
        return f'{parts[0]} <strong>{parts[1]}</strong>'
    return name


def render_hubs(entries, out_dir: Path):
    by_group = {}
    for e in entries:
        by_group.setdefault(e["group"], []).append(e)

    groups_in_order = [g for g in HUB_NARRATIVES.keys() if g in by_group]
    n = len(groups_in_order)
    output_paths = []

    for i, group in enumerate(groups_in_order):
        hub = HUB_NARRATIVES[group]
        hub_features = by_group[group]

        feature_cards = ""
        for n_card, feat in enumerate(hub_features, start=1):
            feature_cards += f'''    <a class="feat-card" href="feature-{feat["id"]}.html">
      <span class="num">{n_card:02d}</span>
      <h3>{feat["title"]}</h3>
      <p>{feat["subtitle"]}</p>
      <span class="open-cue">Open feature guide →</span>
    </a>
'''

        stats_html = ""
        for s in hub["stats"]:
            stats_html += f'<div class="hub-stat"><div class="hub-stat-value">{s["value"]}</div><div class="hub-stat-label">{s["label"]}</div></div>'

        prev_btn = ''
        next_btn = ''
        if i > 0:
            prev_g = groups_in_order[i - 1]
            prev_btn = f'<a class="hub-nav-btn" href="hub-{HUB_NARRATIVES[prev_g]["slug"]}.html"><span class="hub-nav-label">← Previous hub</span><span class="hub-nav-title">{prev_g}</span></a>'
        else:
            prev_btn = '<span class="hub-nav-btn disabled"><span class="hub-nav-label">← Previous hub</span><span class="hub-nav-title">— first hub —</span></span>'
        if i < n - 1:
            next_g = groups_in_order[i + 1]
            next_btn = f'<a class="hub-nav-btn next" href="hub-{HUB_NARRATIVES[next_g]["slug"]}.html"><span class="hub-nav-label">Next hub →</span><span class="hub-nav-title">{next_g}</span></a>'
        else:
            next_btn = '<span class="hub-nav-btn next disabled"><span class="hub-nav-label">Next hub →</span><span class="hub-nav-title">— last hub —</span></span>'

        rendered = HUB_TEMPLATE.format(
            name=group,
            name_html=split_name_for_h1(group),
            tagline=hub["tagline"],
            narrative_html=md_block(hub["narrative"]),
            stats_html=stats_html,
            feature_count=len(hub_features),
            plural='' if len(hub_features) == 1 else 's',
            feature_cards=feature_cards,
            prev_btn=prev_btn,
            next_btn=next_btn,
        )
        out_path = out_dir / f"hub-{hub['slug']}.html"
        out_path.write_text(rendered, encoding='utf-8')
        output_paths.append(out_path)

    return output_paths


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata", help="Path to feature-metadata.json")
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    entries = json.loads(Path(args.metadata).read_text(encoding='utf-8'))
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    total = len(entries)
    for i, entry in enumerate(entries):
        prev_e = entries[i - 1] if i > 0 else None
        next_e = entries[i + 1] if i < total - 1 else None
        out = render_one(entry, out_dir, prev_e, next_e, i + 1, total)
        print(f"  ✓ {entry['id']} → {out.name}")

    lib = render_library(entries, out_dir)
    print(f"\n  ✓ Library index → {lib.name}")

    hub_paths = render_hubs(entries, out_dir)
    for p in hub_paths:
        print(f"  ✓ Hub overview → {p.name}")

    print(f"\nTotal: {total} feature guides + 1 library index + {len(hub_paths)} hub overviews")


if __name__ == "__main__":
    main()
