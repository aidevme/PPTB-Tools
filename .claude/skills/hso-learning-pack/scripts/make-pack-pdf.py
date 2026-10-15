#!/usr/bin/env python3
"""make-pack-pdf.py — render every HTML page in the learning pack to PDF and merge into one file.

Output: <pack-root>/<pack-folder-name>.pdf (e.g. iNextITSM-Learning-Pack.pdf)

Page-class handling:
  - Marp deck HTMLs (01..08-*.html): landscape, 16:9 (1280×720pt mapped to 11"×6.18")
  - All other HTMLs: portrait, US Letter

Image embedding: Playwright renders local screenshots inline via file:// URLs.

Run from the learning-pack directory:
  python3 scripts/make-pack-pdf.py
"""
import asyncio
import sys
from pathlib import Path
from playwright.async_api import async_playwright
from pypdf import PdfReader, PdfWriter

PACK_ROOT = Path(__file__).resolve().parent.parent
# Output filename derives from the pack folder name so each project produces its own PDF
OUTPUT = PACK_ROOT / f"{PACK_ROOT.name}.pdf"

# Reading order — what goes into the merged PDF, in sequence
DECK_FILES = [
    "08-industry-primer.html",        # Start here
    "01-executive-overview.html",
    "02-sales-enablement.html",
    "03-functional-consultant.html",
    "04-technical-architect.html",
    "05-enterprise-architect.html",
    "07-project-manager.html",
]

REFERENCE_FILES = [
    "architecture.html",
    "productization.html",
    "split-feature-spec.html",
]

# Hub overview pages (in walk order)
HUB_FILES = [
    "hub-cash-hub.html",
    "hub-comp-hub.html",
    "hub-producer-portal.html",
    "hub-integration-hub.html",
    "hub-cross-cutting.html",
]

INDEX_FILES = [
    "index.html",
    "feature-library.html",
    "screens-library.html",
]


def deck_pdf_opts():
    """Landscape, 16:9 — sized for Marp slides at 1280×720."""
    return dict(
        width="13.33in",
        height="7.5in",
        print_background=True,
        margin=dict(top="0in", bottom="0in", left="0in", right="0in"),
    )


def portrait_pdf_opts():
    """US Letter portrait."""
    return dict(
        format="Letter",
        print_background=True,
        margin=dict(top="0.4in", bottom="0.4in", left="0.4in", right="0.4in"),
    )


def collect_feature_files() -> list[Path]:
    return sorted(PACK_ROOT.glob("feature-*.html"))


def collect_screen_files() -> list[Path]:
    return sorted(PACK_ROOT.glob("screen-*.html"))


async def render_page_to_pdf(page, html_path: Path, out_pdf: Path, opts: dict):
    """Load an HTML file and emit a PDF."""
    file_url = f"file://{html_path}"
    await page.goto(file_url, wait_until="networkidle", timeout=60000)
    # Give Marp slide decks a moment to lay out
    await page.wait_for_timeout(800)
    await page.pdf(path=str(out_pdf), **opts)


async def main():
    work_dir = PACK_ROOT / "_pdf-stage"
    work_dir.mkdir(exist_ok=True)

    files_in_order: list[tuple[str, Path, dict]] = []  # (label, html_path, pdf_opts)

    # 1. Index (landing) — portrait
    files_in_order.append(("landing", PACK_ROOT / "index.html", portrait_pdf_opts()))

    # 2. The decks — Industry Primer first ("Start here"), then audience packs
    for name in DECK_FILES:
        p = PACK_ROOT / name
        if p.exists():
            files_in_order.append((name, p, deck_pdf_opts()))

    # 3. Hub overviews — portrait
    for name in HUB_FILES:
        p = PACK_ROOT / name
        if p.exists():
            files_in_order.append((name, p, portrait_pdf_opts()))

    # 4. Feature library + per-feature guides — portrait
    files_in_order.append(("feature-library", PACK_ROOT / "feature-library.html", portrait_pdf_opts()))
    for p in collect_feature_files():
        if p.name != "feature-library.html":
            files_in_order.append((p.name, p, portrait_pdf_opts()))

    # 5. Screens library + per-screen guides — portrait
    files_in_order.append(("screens-library", PACK_ROOT / "screens-library.html", portrait_pdf_opts()))
    for p in collect_screen_files():
        files_in_order.append((p.name, p, portrait_pdf_opts()))

    # 6. Reference docs — portrait
    for name in REFERENCE_FILES:
        p = PACK_ROOT / name
        if p.exists():
            files_in_order.append((name, p, portrait_pdf_opts()))

    print(f"Will render {len(files_in_order)} HTML pages to PDF, then merge into one.")
    print(f"Output: {OUTPUT}")
    print("")

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        context = await browser.new_context(viewport=dict(width=1920, height=1080))
        page = await context.new_page()

        per_file_pdfs: list[Path] = []
        for i, (label, html_path, opts) in enumerate(files_in_order, start=1):
            stage_pdf = work_dir / f"{i:04d}-{html_path.stem}.pdf"
            try:
                await render_page_to_pdf(page, html_path, stage_pdf, opts)
                size_kb = stage_pdf.stat().st_size / 1024
                per_file_pdfs.append(stage_pdf)
                print(f"  [{i:3d}/{len(files_in_order)}] {label:50s}  {size_kb:7.0f} KB")
            except Exception as e:
                print(f"  [{i:3d}/{len(files_in_order)}] FAIL {label}: {e}")

        await browser.close()

    # Merge with pypdf, preserving outline bookmarks per source HTML
    print("")
    print(f"Merging {len(per_file_pdfs)} PDFs ...")
    writer = PdfWriter()
    for pdf_path in per_file_pdfs:
        reader = PdfReader(str(pdf_path))
        # Friendly label from filename
        label = pdf_path.stem.split("-", 1)[-1].replace("-", " ").title()
        start_page = len(writer.pages)
        for p in reader.pages:
            writer.add_page(p)
        writer.add_outline_item(label, start_page)

    with OUTPUT.open("wb") as f:
        writer.write(f)

    total_kb = OUTPUT.stat().st_size / 1024
    print("")
    print(f"✓ Done. Merged PDF: {OUTPUT}")
    print(f"  Size: {total_kb:,.0f} KB ({total_kb/1024:.1f} MB)")
    print(f"  Pages: {len(writer.pages)}")
    print(f"  Outline bookmarks: {len(per_file_pdfs)}")
    print("")
    print(f"Stage dir: {work_dir} (remove with: rm -rf {work_dir})")


if __name__ == "__main__":
    asyncio.run(main())
