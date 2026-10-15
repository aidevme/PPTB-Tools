/**
 * revealjs-to-pptx-helpers.js
 *
 * Reusable PptxGenJS helper functions for converting HSO Reveal.js editorial
 * decks to PowerPoint. Aligns with the editorial layout in SKILL.md and
 * references/slide-components.md (post-2026-04 rewrite):
 *
 *   - Content slides have kicker → title → subtitle → body → optional pinned
 *     bottom callout, plus a three-slot navy footer (slide-num · section,
 *     deck-tag, HSO wordmark).
 *   - Section dividers are LEFT-ALIGNED (not centered) with kicker + h1 + sub.
 *   - Title slides are split: text + accent vertical bar on the left, hero
 *     photo with logo overlay on the right.
 *   - Stat slides are full-bleed teal with a 200pt+ centered number.
 *   - Closing slides are light-bg with a 3-column "asks" grid.
 *
 * Fonts are bumped ~50% over the previous (compact 9–12pt) scale to match the
 * editorial 1920×1080 HTML reference. Slide layout is LAYOUT_WIDE
 * (13.33×7.5") so the editorial proportions translate cleanly.
 *
 * Usage from a per-deck generation script:
 *
 *   const { C, helpers } = require("./path/to/revealjs-to-pptx-helpers");
 *   const pres = helpers.createPresentation("Deck Title", "Author Name", "Deck Tag");
 *   helpers.addTitleSlide(pres, { title, sub, byline, heroPath, logoPath });
 *   helpers.addSectionDivider(pres, "Section 01", "Capabilities.", "What the platform does.");
 *   const slide = helpers.addContentSlide(pres, {
 *     kicker: "Build · 11", title: "The development toolkit.",
 *     sub: "Describe what you need — get best-practice output.",
 *     footerLeft: "11 · Build", deckTag: "HSO Dataverse Best Practices"
 *   });
 *   helpers.card(slide, 0.6, 1.6, 5.5, 3.5, "Card Title", ["Bullet 1", "Bullet 2"], C.blue);
 *
 * See references/pptx-conversion.md for the full conversion guide.
 */

const pptxgen = require("pptxgenjs");

// ─────────────────────────────────────────────
// HSO Brand Colors (6-char hex, NO # prefix — pptxgenjs corrupts files with #)
// ─────────────────────────────────────────────
const C = {
  navy:        "00395F",   // --hso-dark-blue / --ink
  navyMid:     "1B4A70",   // --ink-2
  blue:        "079FC3",   // --hso-bluegreen / --accent
  blueBright:  "11B6D9",   // --hso-bluegreen-bright / --accent-2
  steel:       "7F9CAF",   // --hso-steel
  green:       "00B294",   // --hso-green
  coral:       "F1554B",   // --hso-salmon
  amber:       "F2B949",   // --hso-mimosa
  amberEdge:   "F9DC95",   // --hso-mimosa-edge (sand variant)
  text:        "505050",   // --text
  muted:       "5A6B78",   // --muted (cool grey, editorial secondary)
  mutedWarm:   "737373",   // --text-muted
  light:       "F7FAFC",   // --card-bg
  codeBg:      "F4F7FA",   // --code-bg
  line:        "E4E8EC",   // --line
  border:      "E6E6E6",   // --border
  white:       "FFFFFF",
  webGrey:     "ECEFF3",
  darkAmber:   "8B6A00",
};

const TITLE_FONT = "Segoe UI";
const BODY_FONT  = "Segoe UI";
const MONO_FONT  = "Consolas";

// ─────────────────────────────────────────────
// Editorial typography scale at LAYOUT_WIDE (13.33 × 7.5") slide.
// HTML 1920×1080 → PowerPoint 13.33×7.5" preserves 16:9 with a ~10× scale
// factor. Fonts here are calibrated to read at the same visual weight as
// the corresponding HTML editorial element when projected.
// ─────────────────────────────────────────────
const FS = {
  hero:     54,   // title-slide h1, divider h1, closing h1, stat .cap
  title:    40,   // content-slide h1.title
  subtitle: 28,   // title-slide .sub, divider .sub, closing .sub
  body:     17,   // p.body, table cells, card body
  small:    16,   // sub-bullets, dense card body
  kicker:   16,   // .kicker (small-caps accent label)
  cardH4:   22,   // .card h4
  cardLi:   16,   // .card ul li
  capName:  20,   // .cap-grid .cap-name
  capDesc:  13,   // .cap-grid .cap-desc
  capNum:   12,   // .cap-grid .num (mono numbered tag)
  statBig:  200,  // section.slide.stat .big
  statNum:  60,   // .stat-box .stat-num inside content slides
  statLbl:  13,   // .stat-box .stat-label
  tableTh:  13,   // table header (uppercase)
  tableTd:  17,   // table body
  footer:   13,   // .footer
  footerTag: 11,  // .footer .tag (deck name)
};

// ─────────────────────────────────────────────
// Shadow factory (NEVER reuse objects — pptxgenjs mutates them)
// ─────────────────────────────────────────────
function makeShadow() {
  return { type: "outer", blur: 6, offset: 2, angle: 135, color: "000000", opacity: 0.12 };
}

// ─────────────────────────────────────────────
// Presentation factory — uses LAYOUT_WIDE (13.33 × 7.5") to match editorial proportions.
// Stores deck-wide settings (deckTag, accent) on the pres object so helpers can read them.
// ─────────────────────────────────────────────
function createPresentation(title, author, deckTag) {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE";
  pres.author = author || "HSO";
  pres.title = title || "HSO Presentation";
  pres._hsoDeckTag = deckTag || "";
  return pres;
}

// ─────────────────────────────────────────────
// Footer bar — three slots: NN · Section (left), deck tag (center-right),
// HSO wordmark (far right). Reaches edge-to-edge on a 13.33"-wide slide.
// ─────────────────────────────────────────────
function addFooterBar(slide, opts) {
  const { footerLeft = "", deckTag = "", showWordmark = true } = opts || {};
  const slideW = 13.33;
  const slideH = 7.5;
  const footerH = 0.42;
  const y = slideH - footerH;

  slide.addShape("rect", { x: 0, y, w: slideW, h: footerH, fill: { color: C.navy } });

  if (footerLeft) {
    slide.addText(footerLeft, {
      x: 0.4, y, w: 4, h: footerH,
      fontSize: FS.footer, fontFace: BODY_FONT, color: "B8C4CC",
      valign: "middle", margin: 0
    });
  }
  if (deckTag) {
    slide.addText(deckTag.toUpperCase(), {
      x: slideW - 4.2, y, w: 2.6, h: footerH,
      fontSize: FS.footerTag, fontFace: BODY_FONT, color: "B8C4CC",
      charSpacing: 2, align: "right", valign: "middle", margin: 0
    });
  }
  if (showWordmark) {
    // White pill with HSO in navy
    const pillW = 1.0, pillH = 0.32, pillX = slideW - 1.3, pillY = y + (footerH - pillH) / 2;
    slide.addShape("rect", { x: pillX, y: pillY, w: pillW, h: pillH, fill: { color: C.white } });
    slide.addText("HSO", {
      x: pillX, y: pillY, w: pillW, h: pillH,
      fontSize: 12, fontFace: TITLE_FONT, color: C.navy,
      bold: true, charSpacing: 2, align: "center", valign: "middle", margin: 0
    });
  }
}

// ─────────────────────────────────────────────
// Content slide — kicker + title + subtitle + body + footer.
// `addContentSlide` returns the slide object so the caller can place body
// content (cards, tables, diagrams, etc.) at y >= ~1.6.
// ─────────────────────────────────────────────
function addContentSlide(pres, opts) {
  const { kicker, title, sub, footerLeft, deckTag } = opts || {};
  const slide = pres.addSlide();
  slide.background = { color: C.white };

  let cursorY = 0.5;

  if (kicker) {
    slide.addText(kicker.toUpperCase(), {
      x: 0.6, y: cursorY, w: 12, h: 0.35,
      fontSize: FS.kicker, fontFace: BODY_FONT, color: C.blue,
      charSpacing: 2, bold: true, valign: "middle", margin: 0
    });
    cursorY += 0.45;
  }

  if (title) {
    slide.addText(title, {
      x: 0.6, y: cursorY, w: 12, h: 0.85,
      fontSize: FS.title, fontFace: TITLE_FONT, color: C.navy,
      bold: false, valign: "top", margin: 0,
      charSpacing: -0.2,
    });
    cursorY += 0.95;
  }

  if (sub) {
    slide.addText(sub, {
      x: 0.6, y: cursorY, w: 12, h: 0.5,
      fontSize: FS.subtitle - 8, fontFace: BODY_FONT, color: C.muted,
      valign: "top", margin: 0
    });
  }

  addFooterBar(slide, { footerLeft: footerLeft || "", deckTag: deckTag || pres._hsoDeckTag });
  return slide;
}

// ─────────────────────────────────────────────
// Section divider — full-bleed colored background, LEFT-ALIGNED kicker + h1 + sub.
// Variants: 'ink' (default navy), 'teal', 'coral', 'sand'.
// ─────────────────────────────────────────────
function addSectionDivider(pres, sectionLabel, title, sub, variant) {
  const slide = pres.addSlide();
  const bgColors  = { ink: C.navy, teal: C.blue, coral: C.coral, sand: C.amberEdge };
  const fgColors  = { ink: C.white, teal: C.white, coral: C.white, sand: C.navy };
  const accColors = { ink: C.blueBright, teal: C.navy, coral: C.navy, sand: C.navy };

  const v = variant || "ink";
  slide.background = { color: bgColors[v] || C.navy };

  if (sectionLabel) {
    slide.addText(sectionLabel.toUpperCase(), {
      x: 0.8, y: 2.4, w: 12, h: 0.5,
      fontSize: FS.kicker, fontFace: BODY_FONT, color: accColors[v],
      charSpacing: 2.5, bold: true, valign: "middle", margin: 0
    });
  }
  slide.addText(title, {
    x: 0.8, y: 2.95, w: 12, h: 1.4,
    fontSize: FS.hero, fontFace: TITLE_FONT, color: fgColors[v],
    bold: false, valign: "top", margin: 0,
    charSpacing: -0.4,
  });
  if (sub) {
    slide.addText(sub, {
      x: 0.8, y: 4.35, w: 11.5, h: 1.4,
      fontSize: FS.subtitle, fontFace: BODY_FONT,
      color: v === "sand" ? C.navy : C.white,
      transparency: v === "sand" ? 30 : 15,
      valign: "top", margin: 0
    });
  }
  return slide;
}

// ─────────────────────────────────────────────
// Title slide — split layout: brand+title left, hero photo right.
// `opts` accepts: title, sub, byline, heroPath (jpg/png), logoPath (HSO logo).
// HSO logo is rendered on the dark right-side photo (where it's visible).
// ─────────────────────────────────────────────
function addTitleSlide(pres, opts) {
  const { title, sub, byline, heroPath, logoPath } = opts || {};
  const slide = pres.addSlide();
  slide.background = { color: C.white };

  const slideW = 13.33;
  const halfW = slideW / 2;

  // Right side — hero photo with dark gradient overlay
  if (heroPath) {
    slide.addImage({ path: heroPath, x: halfW, y: 0, w: halfW, h: 7.5, sizing: { type: "cover", w: halfW, h: 7.5 } });
  } else {
    slide.addShape("rect", { x: halfW, y: 0, w: halfW, h: 7.5, fill: { color: C.navy } });
  }
  // Gradient overlay (approximated as a translucent navy band on the right edge)
  slide.addShape("rect", { x: halfW, y: 5.0, w: halfW, h: 2.5, fill: { color: C.navy, transparency: 60 }, line: { type: "none" } });
  // Logo overlay on dark side
  if (logoPath) {
    slide.addImage({ path: logoPath, x: halfW + 0.4, y: 0.4, w: 0.9, h: 0.45 });
  }

  // Left side — accent vertical bar
  slide.addShape("rect", { x: 0, y: 1.4, w: 0.06, h: 4.7, fill: { color: C.blue } });

  // Left side — title block
  slide.addText(title || "", {
    x: 0.6, y: 2.2, w: halfW - 0.8, h: 1.7,
    fontSize: FS.hero, fontFace: TITLE_FONT, color: C.navy,
    bold: false, valign: "top", margin: 0,
    charSpacing: -0.4,
  });
  if (sub) {
    slide.addText(sub, {
      x: 0.6, y: 4.0, w: halfW - 0.8, h: 1.5,
      fontSize: FS.subtitle, fontFace: BODY_FONT, color: C.blue,
      valign: "top", margin: 0
    });
  }
  if (byline) {
    slide.addText(byline, {
      x: 0.6, y: 6.6, w: halfW - 0.8, h: 0.4,
      fontSize: 13, fontFace: BODY_FONT, color: C.muted,
      valign: "middle", margin: 0
    });
  }
  return slide;
}

// ─────────────────────────────────────────────
// Stat slide — full-bleed teal background, huge centered number.
// 1–2 per deck max; more and the device loses force.
// ─────────────────────────────────────────────
function addStatSlide(pres, big, caption, note) {
  const slide = pres.addSlide();
  slide.background = { color: C.blue };

  slide.addText(String(big), {
    x: 0.5, y: 1.6, w: 12.33, h: 3.0,
    fontSize: FS.statBig, fontFace: TITLE_FONT, color: C.white,
    bold: false, align: "left", valign: "middle", margin: 0,
    charSpacing: -2,
  });
  if (caption) {
    slide.addText(caption, {
      x: 0.5, y: 5.0, w: 12.33, h: 1.5,
      fontSize: FS.subtitle, fontFace: BODY_FONT, color: C.navy,
      transparency: 10, valign: "top", margin: 0
    });
  }
  if (note) {
    slide.addText(note, {
      x: 0.5, y: 6.5, w: 12.33, h: 0.4,
      fontSize: 14, fontFace: BODY_FONT, color: C.navy, italic: true,
      transparency: 40, valign: "top", margin: 0
    });
  }
  return slide;
}

// ─────────────────────────────────────────────
// Closing slide — light bg, large title + sub + 3-column "asks" grid + contact.
// ─────────────────────────────────────────────
function addClosingSlide(pres, opts) {
  const { title, sub, asks, contact } = opts || {};
  const slide = pres.addSlide();
  slide.background = { color: C.white };

  slide.addText(title || "Questions & discussion.", {
    x: 0.8, y: 1.6, w: 12, h: 1.4,
    fontSize: FS.hero, fontFace: TITLE_FONT, color: C.navy,
    bold: false, valign: "top", margin: 0,
    charSpacing: -0.4,
  });
  if (sub) {
    slide.addText(sub, {
      x: 0.8, y: 3.0, w: 12, h: 0.8,
      fontSize: FS.subtitle, fontFace: BODY_FONT, color: C.blue,
      valign: "top", margin: 0
    });
  }
  if (asks && asks.length) {
    const startY = 4.2;
    const startX = 0.8;
    const gap = 0.5;
    const colW = (12 - gap * (asks.length - 1)) / asks.length;
    asks.forEach((ask, i) => {
      const x = startX + i * (colW + gap);
      slide.addText(`0${i + 1}`, {
        x, y: startY, w: colW, h: 0.3,
        fontSize: 12, fontFace: MONO_FONT, color: C.blue,
        charSpacing: 1.5, bold: true, valign: "top", margin: 0
      });
      slide.addText(ask, {
        x, y: startY + 0.35, w: colW, h: 1.4,
        fontSize: 16, fontFace: TITLE_FONT, color: C.navy,
        bold: false, valign: "top", margin: 0
      });
    });
  }
  if (contact) {
    slide.addText(contact, {
      x: 0.8, y: 6.6, w: 12, h: 0.5,
      fontSize: 14, fontFace: BODY_FONT, color: C.muted,
      valign: "middle", margin: 0
    });
  }
  return slide;
}

// ─────────────────────────────────────────────
// Card — accent-bordered box with title + bullets. Editorial sizing.
// ─────────────────────────────────────────────
function card(slide, x, y, w, h, title, bullets, borderColor) {
  slide.addShape("rect", {
    x, y, w, h,
    fill: { color: C.light },
    line: { color: C.border, width: 0.75 },
    shadow: makeShadow()
  });
  if (borderColor) {
    slide.addShape("rect", { x, y, w: 0.07, h, fill: { color: borderColor } });
  }
  if (title) {
    slide.addText(title, {
      x: x + 0.25, y: y + 0.18, w: w - 0.4, h: 0.5,
      fontSize: FS.cardH4, fontFace: TITLE_FONT,
      color: borderColor || C.navy, bold: true, valign: "middle", margin: 0
    });
  }
  if (bullets && bullets.length) {
    const textArr = bullets.map((b, i) => ({
      text: b,
      options: { bullet: true, breakLine: i < bullets.length - 1, fontSize: FS.cardLi, color: C.navy }
    }));
    slide.addText(textArr, {
      x: x + 0.3, y: y + (title ? 0.7 : 0.2), w: w - 0.5, h: h - (title ? 0.85 : 0.35),
      fontFace: BODY_FONT, valign: "top", paraSpaceAfter: 4, margin: 0
    });
  }
}

// ─────────────────────────────────────────────
// Card (small) — for dense grids (4×N, agenda, KPIs)
// ─────────────────────────────────────────────
function cardSmall(slide, x, y, w, h, title, desc, borderColor, borderSide) {
  slide.addShape("rect", {
    x, y, w, h,
    fill: { color: C.light },
    line: { color: C.border, width: 0.75 },
    shadow: makeShadow()
  });
  if (borderColor && borderSide === "top") {
    slide.addShape("rect", { x, y, w, h: 0.05, fill: { color: borderColor } });
  } else if (borderColor) {
    slide.addShape("rect", { x, y, w: 0.06, h, fill: { color: borderColor } });
  }
  slide.addText(title, {
    x: x + 0.2, y: y + 0.15, w: w - 0.4, h: 0.45,
    fontSize: 16, fontFace: TITLE_FONT,
    color: borderColor || C.navy, bold: true, align: "left", valign: "middle", margin: 0
  });
  slide.addText(desc, {
    x: x + 0.2, y: y + 0.6, w: w - 0.4, h: h - 0.75,
    fontSize: 13, fontFace: BODY_FONT,
    color: C.muted, align: "left", valign: "top", margin: 0
  });
}

// ─────────────────────────────────────────────
// Capability map (cap-grid) — 4×N numbered cells with monospace tag, name, desc.
// `cells` is an array of { num, name, desc, skill }. Auto-laid out in 4-col grid.
// ─────────────────────────────────────────────
function addCapGrid(slide, x, y, w, h, cells) {
  const cols = 4;
  const rows = Math.ceil(cells.length / cols);
  const gap = 0.18;
  const cellW = (w - gap * (cols - 1)) / cols;
  const cellH = (h - gap * (rows - 1)) / rows;

  cells.forEach((cell, i) => {
    const col = i % cols;
    const row = Math.floor(i / cols);
    const cx = x + col * (cellW + gap);
    const cy = y + row * (cellH + gap);

    slide.addShape("rect", { x: cx, y: cy, w: cellW, h: cellH, fill: { color: C.white }, line: { color: C.line, width: 0.75 } });
    slide.addText(cell.num.toUpperCase(), {
      x: cx + 0.2, y: cy + 0.18, w: cellW - 0.4, h: 0.3,
      fontSize: FS.capNum, fontFace: MONO_FONT, color: C.blue,
      charSpacing: 1.2, valign: "top", margin: 0
    });
    slide.addText(cell.name, {
      x: cx + 0.2, y: cy + 0.5, w: cellW - 0.4, h: 0.7,
      fontSize: FS.capName, fontFace: TITLE_FONT, color: C.navy,
      bold: true, valign: "top", margin: 0
    });
    slide.addText(cell.desc, {
      x: cx + 0.2, y: cy + 1.15, w: cellW - 0.4, h: cellH - 1.55,
      fontSize: FS.capDesc, fontFace: BODY_FONT, color: C.muted,
      valign: "top", margin: 0
    });
    if (cell.skill) {
      slide.addText(cell.skill, {
        x: cx + 0.2, y: cy + cellH - 0.4, w: cellW - 0.4, h: 0.3,
        fontSize: 10, fontFace: MONO_FONT, color: C.navyMid,
        valign: "bottom", margin: 0
      });
    }
  });
}

// ─────────────────────────────────────────────
// Roadmap — horizontal phases with dots on a line. Each phase: { dot, q, title, desc }.
// dot: 'done' (filled ink), 'current' (filled accent), 'future' (outlined).
// ─────────────────────────────────────────────
function addRoadmap(slide, x, y, w, phases) {
  const n = phases.length;
  const colW = w / n;
  const lineY = y + 0.18;
  const dotSize = 0.22;

  // Connecting line
  slide.addShape("rect", { x, y: lineY, w, h: 0.025, fill: { color: C.line }, line: { type: "none" } });

  phases.forEach((p, i) => {
    const cx = x + i * colW;
    const dotX = cx + 0.05;
    const dotColor = p.dot === "done" ? C.navy : p.dot === "future" ? C.white : C.blue;
    const dotLine = p.dot === "future" ? { color: C.line, width: 1.5 } : { type: "none" };

    slide.addShape("ellipse", {
      x: dotX, y: lineY - dotSize / 2 + 0.0125, w: dotSize, h: dotSize,
      fill: { color: dotColor }, line: dotLine
    });
    if (p.q) {
      slide.addText(p.q.toUpperCase(), {
        x: cx, y: y + 0.55, w: colW - 0.2, h: 0.3,
        fontSize: 11, fontFace: MONO_FONT, color: C.blue,
        charSpacing: 1.2, valign: "top", margin: 0
      });
    }
    slide.addText(p.title, {
      x: cx, y: y + 0.85, w: colW - 0.2, h: 0.5,
      fontSize: 22, fontFace: TITLE_FONT, color: C.navy,
      bold: true, valign: "top", margin: 0
    });
    if (p.desc) {
      slide.addText(p.desc, {
        x: cx, y: y + 1.4, w: colW - 0.2, h: 0.8,
        fontSize: 13, fontFace: BODY_FONT, color: C.muted,
        valign: "top", margin: 0
      });
    }
  });
}

// ─────────────────────────────────────────────
// Workflow — horizontal process flow with arrow separators
// ─────────────────────────────────────────────
function addWorkflow(slide, y, nodes, highlightLast) {
  const totalWidth = 12;
  const arrowWidth = 0.35;
  const n = nodes.length;
  const arrows = n - 1;
  const nodeW = (totalWidth - arrows * arrowWidth) / n;
  const startX = 0.7;
  let x = startX;

  for (let i = 0; i < n; i++) {
    const isLast = i === n - 1 && highlightLast;
    slide.addShape("rect", {
      x, y, w: nodeW, h: 0.7,
      fill: { color: isLast ? C.green : C.codeBg },
      line: { color: isLast ? C.green : C.blue, width: 1.5 },
      shadow: makeShadow()
    });
    slide.addText(nodes[i], {
      x, y, w: nodeW, h: 0.7,
      fontSize: 14, fontFace: BODY_FONT,
      color: isLast ? C.white : C.navy,
      bold: true, align: "center", valign: "middle", margin: 0
    });
    x += nodeW;
    if (i < n - 1) {
      slide.addText("➡", {
        x, y, w: arrowWidth, h: 0.7,
        fontSize: 18, color: C.blue, align: "center", valign: "middle"
      });
      x += arrowWidth;
    }
  }
}

// ─────────────────────────────────────────────
// Layer stack — stacked horizontal bars (architecture layers)
// ─────────────────────────────────────────────
function addLayerStack(slide, y, layers) {
  const w = 12, startX = 0.7, h = 0.65, gap = 0.15;
  layers.forEach((l, i) => {
    const ly = y + i * (h + gap);
    slide.addShape("rect", {
      x: startX, y: ly, w, h,
      fill: { color: l.bg }, line: { color: l.border, width: 1 }
    });
    slide.addText([
      { text: l.label + "  ", options: { bold: true, fontSize: 16, color: l.color } },
      { text: l.desc, options: { fontSize: 13, color: l.color } }
    ], {
      x: startX + 0.3, y: ly, w: w - 0.6, h,
      valign: "middle", fontFace: BODY_FONT, margin: 0
    });
  });
}

// ─────────────────────────────────────────────
// Bullet list
// ─────────────────────────────────────────────
function addBullets(slide, x, y, w, h, items, fontSize) {
  const textArr = items.map((item, i) => ({
    text: item,
    options: { bullet: true, breakLine: i < items.length - 1, fontSize: fontSize || FS.body, color: C.navy }
  }));
  slide.addText(textArr, {
    x, y, w, h,
    fontFace: BODY_FONT, valign: "top", paraSpaceAfter: 6, margin: 0
  });
}

// ─────────────────────────────────────────────
// Callout — colored left-bar box (info/amber/warn/success)
// ─────────────────────────────────────────────
function addCallout(slide, x, y, w, h, text, type) {
  const colors = {
    info:    { bg: "EEF6FB", border: C.blue },
    amber:   { bg: "FFF8E1", border: C.amber },
    warn:    { bg: "FBEEEC", border: C.coral },
    success: { bg: "E8F5E9", border: C.green },
    default: { bg: "FFF8E1", border: C.amber },
  };
  const c = colors[type] || colors.default;
  slide.addShape("rect", { x, y, w, h, fill: { color: c.bg } });
  slide.addShape("rect", { x, y, w: 0.07, h, fill: { color: c.border } });
  slide.addText(text, {
    x: x + 0.25, y, w: w - 0.4, h,
    fontSize: 14, fontFace: BODY_FONT, color: C.navy,
    valign: "middle", margin: 0
  });
}

// ─────────────────────────────────────────────
// Quote box — italic editorial quote, often pinned to slide bottom.
// Caller positions it where they want; pin-bottom semantics in HTML don't
// translate directly — explicitly place at y ≈ 5.5–6.0 for bottom-pinned look.
// ─────────────────────────────────────────────
function addQuoteBox(slide, x, y, w, h, text) {
  slide.addShape("rect", { x, y, w, h, fill: { color: C.codeBg } });
  slide.addShape("rect", { x, y, w: 0.08, h, fill: { color: C.blue } });
  slide.addText(text, {
    x: x + 0.3, y, w: w - 0.5, h,
    fontSize: 18, fontFace: BODY_FONT, color: C.navy, italic: true,
    valign: "middle", margin: 0
  });
}

// ─────────────────────────────────────────────
// Table — navy header, alternating rows. Editorial sizing.
// ─────────────────────────────────────────────
function addTable(slide, x, y, w, rows, colW) {
  const tableRows = rows.map((row, ri) =>
    row.map(cell => ({
      text: cell,
      options: ri === 0
        ? {
            fill: { color: C.navy }, color: C.white, bold: true,
            fontSize: FS.tableTh, fontFace: BODY_FONT,
            charSpacing: 1.2, // tracked uppercase look
            border: { pt: 0.5, color: C.line }
          }
        : {
            fill: { color: ri % 2 === 0 ? C.light : C.white }, color: C.navy,
            fontSize: FS.tableTd, fontFace: BODY_FONT,
            border: { pt: 0.5, color: C.line }
          }
    }))
  );
  slide.addTable(tableRows, { x, y, w, colW, rowH: 0.45 });
}

// ─────────────────────────────────────────────
// Stat boxes — large number with small label. Inline (use inside content slides).
// For full-bleed "stat slide", use addStatSlide().
// ─────────────────────────────────────────────
function addStatBoxes(slide, y, stats) {
  const n = stats.length;
  const totalWidth = n * 2.4 + (n - 1) * 0.8;
  const startX = (13.33 - totalWidth) / 2;

  stats.forEach((st, i) => {
    const x = startX + i * 3.2;
    slide.addText(st.num, {
      x, y, w: 2.4, h: 1.0,
      fontSize: FS.statNum, fontFace: TITLE_FONT, color: C.blue,
      bold: false, align: "left", valign: "bottom", margin: 0,
      charSpacing: -1,
    });
    slide.addText(st.label.toUpperCase(), {
      x, y: y + 0.95, w: 2.4, h: 0.35,
      fontSize: FS.statLbl, fontFace: BODY_FONT, color: C.muted,
      charSpacing: 1.5, align: "left", valign: "top", margin: 0
    });
  });
}

// ─────────────────────────────────────────────
// SVG diagram embedding (requires sharp). Rasterizes at 2400px for HD output.
// ─────────────────────────────────────────────
async function embedSvg(slide, svgPath, x, y, w, h) {
  const fs = require("fs");
  const sharp = require("sharp");

  if (!fs.existsSync(svgPath)) {
    slide.addText("[Diagram not found: " + svgPath + "]", {
      x: x + 1, y: y + h / 2 - 0.3, w: w - 2, h: 0.6,
      fontSize: 14, color: C.muted, align: "center"
    });
    return;
  }

  const svgBuf = fs.readFileSync(svgPath);
  const pngBuf = await sharp(svgBuf).resize({ width: 2400 }).png().toBuffer();
  const b64 = "image/png;base64," + pngBuf.toString("base64");
  slide.addImage({ data: b64, x, y, w, h, sizing: { type: "contain", w, h } });
}

// ─────────────────────────────────────────────
// Exports
// ─────────────────────────────────────────────
module.exports = {
  C,
  FS,
  TITLE_FONT,
  BODY_FONT,
  MONO_FONT,
  makeShadow,
  helpers: {
    createPresentation,
    addFooterBar,
    addContentSlide,
    addSectionDivider,
    addTitleSlide,
    addStatSlide,
    addClosingSlide,
    card,
    cardSmall,
    addCapGrid,
    addRoadmap,
    addWorkflow,
    addLayerStack,
    addBullets,
    addCallout,
    addQuoteBox,
    addTable,
    addStatBoxes,
    embedSvg,
  }
};
