#!/usr/bin/env python3
"""merge-pack-pdf.py — concat the per-page PDFs from render-all-pdfs.js into one master.

Reads `_pdf-stage/_manifest.json` (written by render-all-pdfs.js), preserves order,
adds an outline bookmark per source file. Output filename derives from the pack
folder name (e.g. <pack-folder>.pdf).
"""
import json
from pathlib import Path
from pypdf import PdfReader, PdfWriter

PACK_ROOT = Path(__file__).resolve().parent.parent
STAGE = PACK_ROOT / "_pdf-stage"
OUTPUT = PACK_ROOT / f"{PACK_ROOT.name}.pdf"


def friendly_label(label: str) -> str:
    s = label.removesuffix(".html")
    s = s.replace("-", " ")
    return s.title()


def main():
    manifest_path = STAGE / "_manifest.json"
    if not manifest_path.exists():
        raise SystemExit(f"No manifest at {manifest_path} — run render-all-pdfs.js first.")

    manifest = json.loads(manifest_path.read_text())

    writer = PdfWriter()
    print(f"Merging {len(manifest)} PDFs into {OUTPUT.name} ...")

    for entry in manifest:
        pdf_path = Path(entry["pdf"])
        if not pdf_path.exists():
            print(f"  skip (missing): {pdf_path}")
            continue
        reader = PdfReader(str(pdf_path))
        start = len(writer.pages)
        for page in reader.pages:
            writer.add_page(page)
        writer.add_outline_item(friendly_label(entry["label"]), start)

    with OUTPUT.open("wb") as f:
        writer.write(f)

    size_kb = OUTPUT.stat().st_size / 1024
    print(f"\n✓ {OUTPUT}")
    print(f"  Size : {size_kb:,.0f} KB ({size_kb/1024:.1f} MB)")
    print(f"  Pages: {len(writer.pages)}")
    print(f"  Bookmarks: {len(manifest)}")


if __name__ == "__main__":
    main()
