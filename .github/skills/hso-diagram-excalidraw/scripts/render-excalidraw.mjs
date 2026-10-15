#!/usr/bin/env node
// Render an .excalidraw JSON file to SVG using the official @excalidraw/utils
// exportToSvg function, with a minimal jsdom DOM polyfill for Node.
//
// Usage:
//   node render-excalidraw.mjs <input.excalidraw> [output.svg]
//
// If output is omitted, it defaults to the input path with .svg extension.
//
// Exit codes:
//   0  success
//   1  bad arguments / IO error
//   2  excalidraw export error

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, extname, dirname, join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { JSDOM } from 'jsdom';

// ---- argv ----------------------------------------------------------------
const args = process.argv.slice(2);
if (args.length < 1) {
  console.error('Usage: node render-excalidraw.mjs <input.excalidraw> [output.svg]');
  process.exit(1);
}
const inputPath = resolve(args[0]);
if (!existsSync(inputPath)) {
  console.error(`Input not found: ${inputPath}`);
  process.exit(1);
}
const outputPath = args[1]
  ? resolve(args[1])
  : inputPath.replace(/\.excalidraw$/i, '.svg');

// ---- DOM polyfill --------------------------------------------------------
// @excalidraw/utils was built for the browser and expects window/document
// during bundle init. jsdom provides a faithful-enough DOM for SVG export.
const dom = new JSDOM('<!doctype html><html><head></head><body></body></html>', {
  pretendToBeVisual: true,
});
// Node 22 marks `navigator` as read-only on globalThis, so skip it — jsdom
// exposes navigator via window.navigator which is what excalidraw actually reads.
// Assign all other DOM globals defensively with descriptor-aware fallback.
const polyfills = {
  window: dom.window,
  document: dom.window.document,
  HTMLElement: dom.window.HTMLElement,
  Element: dom.window.Element,
  SVGElement: dom.window.SVGElement,
  XMLSerializer: dom.window.XMLSerializer,
  DOMParser: dom.window.DOMParser,
  Image: dom.window.Image,
  getComputedStyle: dom.window.getComputedStyle.bind(dom.window),
};
for (const [k, v] of Object.entries(polyfills)) {
  try { globalThis[k] = v; } catch { /* read-only global — skip */ }
}
if (!globalThis.window.devicePixelRatio) globalThis.window.devicePixelRatio = 1;
// Excalidraw's bundle references `devicePixelRatio` as a bare global.
try { globalThis.devicePixelRatio = 1; } catch { /* ignore */ }
// Same for `location` — some sanitizeUrl paths read `location.origin`.
try { globalThis.location = dom.window.location; } catch { /* ignore */ }

// jsdom doesn't implement the CSS Font Loading API. Excalidraw references
// FontFace + document.fonts to preload its custom fonts. Stub both so the
// render path doesn't throw. We don't need actual font loading — text is
// rendered with fallback system fonts, good enough for SVG export.
class FontFaceStub {
  constructor(family, source, descriptors = {}) {
    this.family = family;
    this.source = source;
    this.status = 'loaded';
    Object.assign(this, descriptors);
  }
  load() { return Promise.resolve(this); }
  loaded = Promise.resolve(this);
}
try { globalThis.FontFace = FontFaceStub; } catch { /* ignore */ }
try { dom.window.FontFace = FontFaceStub; } catch { /* ignore */ }
const fontsStub = {
  _fonts: new Set(),
  add(f) { this._fonts.add(f); return this; },
  delete(f) { return this._fonts.delete(f); },
  has(f) { return this._fonts.has(f); },
  clear() { this._fonts.clear(); },
  ready: Promise.resolve(),
  load: () => Promise.resolve([]),
  check: () => true,
  values: function* () { yield* this._fonts; },
  [Symbol.iterator]: function* () { yield* this._fonts; },
  forEach(cb) { this._fonts.forEach(cb); },
  get size() { return this._fonts.size; },
  addEventListener() {},
  removeEventListener() {},
};
try { Object.defineProperty(dom.window.document, 'fonts', { value: fontsStub, configurable: true }); } catch { /* ignore */ }

// ---- load excalidraw utils ----------------------------------------------
// Dynamic import so DOM polyfill is in place before module init side effects.
const { exportToSvg } = await import('@excalidraw/utils');

// ---- load scene ----------------------------------------------------------
let scene;
try {
  scene = JSON.parse(readFileSync(inputPath, 'utf8'));
} catch (err) {
  console.error(`Failed to parse JSON: ${err.message}`);
  process.exit(1);
}

if (!scene || !Array.isArray(scene.elements)) {
  console.error('Invalid .excalidraw file: missing "elements" array.');
  process.exit(1);
}

// ---- export --------------------------------------------------------------
let svgEl;
try {
  svgEl = await exportToSvg({
    elements: scene.elements,
    appState: {
      ...(scene.appState ?? {}),
      exportBackground: true,
      exportWithDarkMode: false,
      exportEmbedScene: false,
      viewBackgroundColor:
        scene.appState?.viewBackgroundColor ?? '#FFFFFF',
    },
    files: scene.files ?? {},
  });
} catch (err) {
  console.error(`exportToSvg failed: ${err?.stack ?? err}`);
  process.exit(2);
}

// ---- serialize and write -------------------------------------------------
const serializer = new globalThis.XMLSerializer();
let svgString = serializer.serializeToString(svgEl);

// Excalidraw sets xmlns as a plain attribute on <svg>, and the serializer then
// injects it AGAIN as a namespace declaration — producing duplicate xmlns
// attributes which are invalid XML. Browsers silently render nothing.
// Collapse any duplicates on the root <svg> tag.
svgString = svgString.replace(
  /^(<svg\b[^>]*)$/m,
  (match) => {
    // dedupe xmlns="..." occurrences within the opening tag
    let seen = false;
    return match.replace(/\s+xmlns="http:\/\/www\.w3\.org\/2000\/svg"/g, (m) => {
      if (seen) return '';
      seen = true;
      return m;
    });
  }
);
// The above only matches if the opening tag is on its own line; do a direct
// single-pass cleanup as well in case everything is on one line.
{
  const openMatch = svgString.match(/<svg\b[^>]*>/);
  if (openMatch) {
    let seen = false;
    const cleaned = openMatch[0].replace(
      /\s+xmlns="http:\/\/www\.w3\.org\/2000\/svg"/g,
      (m) => { if (seen) return ''; seen = true; return m; }
    );
    if (cleaned !== openMatch[0]) {
      svgString = svgString.replace(openMatch[0], cleaned);
    }
  }
}

// Font embedding is OPT-IN via the --embed-fonts flag. Each Excalidraw TTF is
// ~10MB; embedding all three as base64 produces ~35MB SVGs. By default the
// SVG relies on system font fallback for text while keeping the hand-drawn
// SHAPES (the real signature of excalidraw, produced by roughjs) intact.
if (process.argv.includes('--embed-fonts')) try {
  const fontsDir = join(
    dirname(fileURLToPath(import.meta.url)),
    'node_modules/@excalidraw/utils/dist/prod/assets',
  );
  const fontFiles = [
    { family: 'Virgil',       file: 'Virgil.ttf' },
    { family: 'Cascadia',     file: 'Cascadia Code.ttf' },
    { family: 'Excalifont',   file: 'Excalifont.ttf' },
  ];
  const faceRules = [];
  for (const { family, file } of fontFiles) {
    const fp = join(fontsDir, file);
    if (!existsSync(fp)) continue;
    const b64 = readFileSync(fp).toString('base64');
    faceRules.push(
      `@font-face{font-family:"${family}";font-style:normal;font-weight:400;` +
      `src:url(data:font/ttf;base64,${b64}) format("truetype");}`
    );
  }
  if (faceRules.length > 0) {
    const injection = faceRules.join('');
    // Excalidraw emits: <defs><style class="style-fonts">\n      </style></defs>
    svgString = svgString.replace(
      /(<style class="style-fonts">)([\s\S]*?)(<\/style>)/,
      (_, open, _inner, close) => `${open}${injection}${close}`,
    );
  }
} catch (err) {
  console.warn(`(warning) could not embed fonts: ${err.message}`);
}

writeFileSync(outputPath, svgString, 'utf8');

const bytes = Buffer.byteLength(svgString, 'utf8');
console.log(`OK  ${outputPath}  (${bytes} bytes)`);
