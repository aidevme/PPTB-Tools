#!/usr/bin/env python3
"""md-to-hso-html.py — render a markdown file as an HSO-themed HTML page.

Usage:
    python3 md-to-hso-html.py <input.md> <output.html> "Title" "Subtitle"

Matches the visual design of docs/learning-packs/index.html.
"""
import sys
import re
from pathlib import Path
from markdown_it import MarkdownIt

HSO_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} — ERP Unite</title>
<style>
  :root {{
    --navy: #00395F;
    --navy-dark: #00253D;
    --navy-light: #1A5A8A;
    --cyan: #079FC3;
    --cyan-light: #4AB9D4;
    --teal: #00B294;
    --red: #F1554B;
    --yellow: #F2B949;
    --slate: #44546A;
    --mute: #737373;
    --bg: #FAFBFC;
    --card-bg: #FFFFFF;
    --border: #E5E9EE;
    --code-bg: #F4F7FA;
    --code-border: #DCE3EB;
  }}

  * {{ margin: 0; padding: 0; box-sizing: border-box; }}

  html {{ scroll-behavior: smooth; }}

  body {{
    font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
    color: var(--navy);
    background: var(--bg);
    line-height: 1.6;
    -webkit-font-smoothing: antialiased;
  }}

  /* ─── Hero ─── */

  .doc-hero {{
    background: linear-gradient(135deg, var(--navy-dark) 0%, var(--navy) 50%, var(--navy-light) 100%);
    color: white;
    padding: 56px 40px 64px;
    position: relative;
    overflow: hidden;
  }}

  .doc-hero::before {{
    content: '';
    position: absolute;
    top: -40%;
    right: -10%;
    width: 500px;
    height: 500px;
    background: radial-gradient(circle, rgba(7, 159, 195, 0.22) 0%, transparent 65%);
    pointer-events: none;
  }}

  .doc-hero::after {{
    content: '';
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: linear-gradient(90deg, var(--cyan) 0%, var(--teal) 50%, var(--cyan) 100%);
  }}

  .doc-hero-inner {{
    max-width: 960px;
    margin: 0 auto;
    position: relative;
  }}

  .doc-eyebrow {{
    color: var(--cyan-light);
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 2px;
    text-transform: uppercase;
    margin-bottom: 12px;
  }}

  .doc-eyebrow a {{
    color: var(--cyan-light);
    text-decoration: none;
    border-bottom: 1px dotted rgba(74, 185, 212, 0.5);
    padding-bottom: 2px;
    transition: border-color 0.2s ease;
  }}

  .doc-eyebrow a:hover {{ border-color: var(--cyan-light); }}

  .doc-hero h1 {{
    font-size: 48px;
    font-weight: 400;
    letter-spacing: -0.5px;
    line-height: 1.1;
    margin-bottom: 14px;
  }}

  .doc-hero .subtitle {{
    font-size: 18px;
    font-weight: 300;
    color: rgba(255, 255, 255, 0.78);
    max-width: 720px;
  }}

  /* ─── Body ─── */

  main {{
    max-width: 960px;
    margin: 0 auto;
    padding: 48px 40px 80px;
  }}

  main h1, main h2, main h3, main h4, main h5, main h6 {{
    color: var(--navy);
    font-weight: 600;
    line-height: 1.25;
    margin-top: 2em;
    margin-bottom: 0.6em;
  }}

  main h1 {{ font-size: 32px; border-bottom: 2px solid var(--cyan); padding-bottom: 8px; margin-top: 1.6em; }}
  main h2 {{ font-size: 24px; color: var(--navy); margin-top: 2em; }}
  main h2::before {{
    content: '';
    display: inline-block;
    width: 4px;
    height: 20px;
    background: var(--cyan);
    margin-right: 12px;
    vertical-align: middle;
    border-radius: 2px;
  }}
  main h3 {{ font-size: 19px; color: var(--navy-light); }}
  main h4 {{ font-size: 16px; color: var(--slate); text-transform: uppercase; letter-spacing: 1px; }}
  main h5, main h6 {{ font-size: 15px; color: var(--slate); }}

  main p, main li {{ font-size: 16px; color: #1F2D3D; line-height: 1.7; }}
  main p {{ margin-bottom: 1em; }}

  main ul, main ol {{
    margin-left: 1.5em;
    margin-bottom: 1em;
  }}

  main ul li, main ol li {{ margin-bottom: 0.35em; }}

  main strong {{ color: var(--navy); font-weight: 600; }}
  main em {{ color: var(--slate); }}

  main a {{
    color: var(--cyan);
    text-decoration: none;
    border-bottom: 1px solid rgba(7, 159, 195, 0.3);
    transition: border-color 0.15s ease, color 0.15s ease;
  }}

  main a:hover {{
    color: var(--navy);
    border-color: var(--navy);
  }}

  main code {{
    background: var(--code-bg);
    color: var(--navy);
    padding: 2px 7px;
    border-radius: 4px;
    font-family: 'Cascadia Code', 'Consolas', 'SF Mono', monospace;
    font-size: 0.88em;
    border: 1px solid var(--code-border);
  }}

  main pre {{
    background: #F4F7FA;
    border: 1px solid var(--code-border);
    border-left: 4px solid var(--cyan);
    border-radius: 8px;
    padding: 16px 20px;
    overflow-x: auto;
    margin: 1em 0;
    line-height: 1.5;
  }}

  main pre code {{
    background: transparent;
    border: none;
    padding: 0;
    color: var(--navy);
    font-size: 13.5px;
  }}

  main blockquote {{
    border-left: 4px solid var(--yellow);
    background: #FFFBF0;
    padding: 12px 20px;
    margin: 1em 0;
    color: var(--slate);
    border-radius: 0 6px 6px 0;
  }}

  main blockquote p {{ margin-bottom: 0; }}

  main table {{
    width: 100%;
    border-collapse: collapse;
    margin: 1.5em 0;
    background: white;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 1px 3px rgba(0, 57, 95, 0.06);
  }}

  main thead {{
    background: var(--navy);
    color: white;
  }}

  main thead th {{
    padding: 12px 16px;
    text-align: left;
    font-weight: 600;
    font-size: 14px;
    letter-spacing: 0.3px;
  }}

  main tbody td {{
    padding: 10px 16px;
    border-bottom: 1px solid var(--border);
    font-size: 14.5px;
    color: #1F2D3D;
  }}

  main tbody tr:nth-child(even) {{ background: #FAFBFC; }}
  main tbody tr:hover {{ background: #F0F6FB; }}

  main tbody tr:last-child td {{ border-bottom: none; }}

  main hr {{
    border: none;
    height: 1px;
    background: linear-gradient(90deg, transparent 0%, var(--border) 50%, transparent 100%);
    margin: 2.5em 0;
  }}

  /* ─── Footer ─── */

  footer {{
    background: var(--navy-dark);
    color: rgba(255, 255, 255, 0.7);
    padding: 24px 40px;
    text-align: center;
    font-size: 13px;
  }}

  footer a {{
    color: var(--cyan-light);
    text-decoration: none;
    border-bottom: 1px dotted rgba(74, 185, 212, 0.5);
  }}

  footer a:hover {{ color: white; border-color: white; }}

  /* ─── Responsive ─── */

  @media (max-width: 720px) {{
    .doc-hero {{ padding: 40px 24px 48px; }}
    .doc-hero h1 {{ font-size: 36px; }}
    main {{ padding: 32px 24px 56px; }}
    main h1 {{ font-size: 26px; }}
    main h2 {{ font-size: 20px; }}
  }}

  /* Print friendly */
  @media print {{
    .doc-hero {{ background: var(--navy) !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }}
    main {{ padding: 24px 0; max-width: 100%; }}
    main pre {{ break-inside: avoid; }}
    main table {{ break-inside: avoid; }}
  }}
</style>
</head>
<body>

<header class="doc-hero">
  <div class="doc-hero-inner">
    <div class="doc-eyebrow">
      <a href="index.html">← ERP Unite learning pack</a>
    </div>
    <h1>{title}</h1>
    <p class="subtitle">{subtitle}</p>
  </div>
</header>

<main>
{body}
</main>

<footer>
  Source markdown: <code style="background: rgba(255,255,255,0.1); padding: 2px 8px; border-radius: 3px; color: var(--cyan-light);">{source}</code> · part of the <a href="index.html">ERP Unite learning pack</a>
</footer>

</body>
</html>
"""


def slugify(text: str) -> str:
    """Convert heading text to a fragment-safe slug."""
    # Strip HTML tags first (markdown may have rendered inline tags inside the heading)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s-]", "", text)
    text = re.sub(r"\s+", "-", text).strip("-")
    return text


def add_heading_ids(html: str) -> str:
    """Post-process: add id='slug' to every h1/h2/h3/h4 that doesn't already have one."""
    used_ids = set()

    def repl(m):
        tag = m.group(1)
        existing_attrs = m.group(2) or ""
        inner = m.group(3)
        if 'id=' in existing_attrs:
            return m.group(0)
        slug_base = slugify(inner)
        if not slug_base:
            return m.group(0)
        slug = slug_base
        n = 2
        while slug in used_ids:
            slug = f"{slug_base}-{n}"
            n += 1
        used_ids.add(slug)
        return f'<{tag}{existing_attrs} id="{slug}">{inner}</{tag}>'

    return re.sub(
        r"<(h[1-4])([^>]*)>(.*?)</\1>",
        repl,
        html,
        flags=re.DOTALL,
    )


def rewrite_md_links_to_html(html: str) -> str:
    """Convert intra-doc .md links to .html so navigation stays inside the rendered pack."""
    # FEATURES.md, ARCHITECTURE.md, SPEC-productization.md, SPEC.md → corresponding .html
    name_map = {
        'FEATURES.md': 'features.html',
        'ARCHITECTURE.md': 'architecture.html',
        'SPEC-productization.md': 'productization.html',
        'SPEC.md': 'split-feature-spec.html',
    }
    for md, html_name in name_map.items():
        # Match href="...FEATURES.md", href="../FEATURES.md", href="FEATURES.md"
        html = re.sub(
            r'href="([^"]*/)?' + re.escape(md) + r'"',
            f'href="{html_name}"',
            html,
        )
        # Also handle bare references like ../FEATURES.md
        html = re.sub(
            r'href="\.\./' + re.escape(md) + r'"',
            f'href="{html_name}"',
            html,
        )
    return html


def main():
    if len(sys.argv) < 5:
        print(f"Usage: {sys.argv[0]} <input.md> <output.html> <title> <subtitle>", file=sys.stderr)
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    title = sys.argv[3]
    subtitle = sys.argv[4]

    md_text = input_path.read_text(encoding='utf-8')

    # Strip leading YAML frontmatter if present
    if md_text.startswith('---'):
        end = md_text.find('---', 3)
        if end != -1:
            md_text = md_text[end + 3:].lstrip()

    md = MarkdownIt('commonmark', {'html': True, 'linkify': True, 'typographer': False}) \
        .enable('table') \
        .enable('strikethrough')

    body_html = md.render(md_text)
    body_html = add_heading_ids(body_html)
    body_html = rewrite_md_links_to_html(body_html)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        HSO_TEMPLATE.format(
            title=title,
            subtitle=subtitle,
            body=body_html,
            source=input_path.name,
        ),
        encoding='utf-8',
    )

    size_kb = output_path.stat().st_size / 1024
    print(f"  ✓ {input_path.name} → {output_path.name} ({size_kb:.1f} KB)")


if __name__ == '__main__':
    main()
