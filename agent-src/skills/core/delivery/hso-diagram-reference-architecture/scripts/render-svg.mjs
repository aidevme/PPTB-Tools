#!/usr/bin/env node
// Render a hand-coded SVG to PNG at 2400 px width using sharp.
//
// Usage:
//   node render-svg.mjs <input.svg> [output.png]
//
// If output is omitted, defaults to the input path with .png extension.
//
// Exit codes:
//   0  success
//   1  bad arguments / IO error
//   2  render error

import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import sharp from 'sharp';

// ---- argv ----------------------------------------------------------------
const args = process.argv.slice(2);
if (args.length < 1) {
  console.error('Usage: node render-svg.mjs <input.svg> [output.png]');
  process.exit(1);
}
const inputPath = resolve(args[0]);
if (!existsSync(inputPath)) {
  console.error(`Input not found: ${inputPath}`);
  process.exit(1);
}
const outputPath = args[1]
  ? resolve(args[1])
  : inputPath.replace(/\.svg$/i, '.png');

// ---- read SVG ------------------------------------------------------------
let svg;
try {
  svg = readFileSync(inputPath);
} catch (err) {
  console.error(`Failed to read input: ${err.message}`);
  process.exit(1);
}

// ---- render --------------------------------------------------------------
try {
  await sharp(svg, { density: 200 })
    .resize({ width: 2400 })
    .png()
    .toFile(outputPath);
} catch (err) {
  console.error(`sharp render failed: ${err?.stack ?? err}`);
  process.exit(2);
}

console.log(`OK  ${outputPath}`);
