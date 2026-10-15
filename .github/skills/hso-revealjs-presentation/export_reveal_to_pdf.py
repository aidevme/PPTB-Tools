"""
export_reveal_to_pdf.py
-----------------------
Export a Reveal.js HTML presentation to a high-fidelity PDF (one slide per page) using Playwright.

USAGE:
    python export_reveal_to_pdf.py --input path/to/presentation.html --output path/to/output.pdf [--width 1280 --height 720]

REQUIREMENTS:
- Python 3.7+
- pip install playwright
- python -m playwright install

NOTES:
- The script automatically appends ?print-pdf for Reveal.js print mode.
- Default page size is 1280x720px (16:9). Override with --width/--height if needed.
- Input can be a local file or a URL.
"""
import argparse
import os
from playwright.sync_api import sync_playwright

def main():
    parser = argparse.ArgumentParser(description="Export Reveal.js HTML to PDF (one slide per page)")
    parser.add_argument('--input', '-i', required=True, help='Path to Reveal.js HTML file or URL')
    parser.add_argument('--output', '-o', required=True, help='Path to output PDF')
    parser.add_argument('--width', type=int, default=1280, help='PDF page width in px (default: 1280)')
    parser.add_argument('--height', type=int, default=720, help='PDF page height in px (default: 720)')
    args = parser.parse_args()

    # Support local file or URL
    if args.input.startswith(('http://', 'https://', 'file://')):
        file_url = args.input
    else:
        file_url = 'file:///' + os.path.abspath(args.input).replace('\\', '/')
    if '?print-pdf' not in file_url:
        file_url += '?print-pdf'

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        print(f"Loading: {file_url}")
        page.goto(file_url)
        page.wait_for_selector('.slides')
        page.wait_for_timeout(2000)  # Wait for scripts/styles to load
        page.pdf(
            path=args.output,
            width=f'{args.width}px',
            height=f'{args.height}px',
            print_background=True,
            margin={"top": "0", "bottom": "0", "left": "0", "right": "0"}
        )
        browser.close()
    print(f"PDF created successfully: {args.output}")

if __name__ == '__main__':
    main()
