# XmlFormatter

Read-only, syntax-highlighted display of an XML string, purpose-built for showing Dataverse form XML in
PCF2BPF's "Xml Details" tab. Dependency-free by design — PPTB bundles this tool to a single IIFE (see the
root `CLAUDE.md`'s build-constraint note), so pulling in a full syntax-highlighting library would add real
weight for what's otherwise a small amount of text.

## Features

- **Syntax coloring** — tags, attribute names/values, and comments are colored separately via a lightweight
  regex tokenizer (`xmlTokenizer.ts`).
- **Pretty-printing** (`prettyPrint` prop) — re-indents the XML via a small structural parser
  (`xmlParser.ts`) instead of showing it exactly as received.
- **Fold/collapse** (`collapsible` prop) — any element whose content spans more than one line gets a
  chevron to collapse it to `<tag …> … </tag>`. `initiallyCollapsedTags` seeds which tag names start
  folded.
- **Search highlighting** (`highlightQuery` prop) — every case-insensitive substring match is wrapped in a
  `<mark>`. Highlights only; it does not filter out non-matching lines.
- **Diff highlighting** (`compareXml` / `diffHighlight` props) — GitHub-style full-row green/red background
  for lines that don't have a counterpart on another `XmlFormatter` instance's side. See
  [Diff highlighting](#diff-highlighting) below.
- **Line-number gutter** (`showLineNumbers` prop).
- **Copy button** (`showCopyButton` prop) — copies the currently displayed (post-pretty-print) text via
  `window.toolboxAPI.utils.copyToClipboard`.
- **Theming** (`theme` prop) — built-in `"light"`/`"dark"` palettes, or a fully custom `XmlTheme` object.
  Colors are applied via CSS custom properties set inline on the root element, not compile-time Fluent
  tokens, since the palette is independent of the app's own Fluent theme.

## Usage

```tsx
import { XmlFormatter } from "../xmlformatter";

<XmlFormatter
    xml={formXml}
    placeholder="Load a Business Process Flow to see its form XML..."
    theme="light"
    prettyPrint
    highlightQuery={searchQuery}
/>;
```

See `components/panels/FormXmlPanel.tsx` for the Before/After diff pairing used by PCF2BPF's "Xml Details"
tab.

## Props

| Prop                   | Type                             | Default    | Description                                                                     |
| ----------------------- | --------------------------------- | ---------- | --------------------------------------------------------------------------------- |
| `xml`                   | `string`                          | —          | Raw XML to display. Empty string renders `placeholder` instead.                   |
| `theme`                 | `XmlThemeName \| XmlTheme`        | `"dark"`   | Built-in palette name, or a fully custom palette.                                 |
| `showLineNumbers`       | `boolean`                         | `true`     | Show the line-number gutter.                                                      |
| `collapsible`           | `boolean`                         | `true`     | Show fold chevrons on multi-line elements.                                        |
| `prettyPrint`           | `boolean`                         | `false`    | Re-indent via the internal structural formatter instead of showing input as-is.   |
| `indent`                | `string`                          | `"  "`     | Indent unit used when `prettyPrint` is on.                                        |
| `showCopyButton`        | `boolean`                         | `true`     | Show the floating copy-to-clipboard button.                                       |
| `initiallyCollapsedTags`| `string[]`                        | —          | Tag names (not paths) that start folded on first render.                          |
| `placeholder`           | `string`                          | —          | Message shown in place of the content when `xml` is empty.                        |
| `highlightQuery`        | `string`                          | —          | Case-insensitive substring to highlight; empty/omitted disables highlighting.     |
| `compareXml`            | `string`                          | —          | The other side's raw XML to diff this instance's lines against. Omit to disable.  |
| `diffHighlight`         | `"added" \| "removed"`            | —          | Whether lines that differ from `compareXml` render green (added) or red (removed).|
| `className`             | `string`                          | —          | Additional class applied to the root element.                                     |
| `style`                 | `CSSProperties`                   | —          | Additional inline styles, merged after the theme's CSS custom properties.         |

## Diff highlighting

`compareXml`/`diffHighlight` add a GitHub-style before/after diff: each `XmlFormatter` instance formats the
other side's XML the same way it formats its own (respecting `prettyPrint`), then runs a line-level LCS diff
(`xmlDiff.ts`, the same idea `git diff` uses) to find lines with no counterpart on the other side. Those
lines get a full-row background — green when `diffHighlight="added"`, red when `diffHighlight="removed"`.
A collapsed fold region also picks up the highlight if any line it hides changed, so a diff isn't hidden by
collapsing its container element.

Each instance only knows its own role — it doesn't infer "before" vs "after". To diff a pair, pass each
instance's own `xml` as the other's `compareXml`, and set `diffHighlight` accordingly:

```tsx
<XmlFormatter xml={beforeXml} compareXml={showDiff ? afterXml : undefined} diffHighlight="removed" />
<XmlFormatter xml={afterXml} compareXml={showDiff ? beforeXml : undefined} diffHighlight="added" />
```

Diffing is line-based, not word-based — a one-character change on an otherwise-identical line still marks
that whole line as changed on both sides (it won't show as a paired "modification").

## Architecture

```
xmlformatter/
├── index.ts          # Barrel export
├── XmlFormatter.tsx  # The component itself
├── xmlTokenizer.ts   # Regex-based tokenizer -> color-codable spans (tags, attrs, comments, text)
├── xmlParser.ts       # Structural parser -> element tree with line spans, used for folding + pretty-print
├── xmlDiff.ts          # Line-level LCS diff, used for before/after highlighting
└── xmlTheme.ts         # Color palettes, applied via CSS custom properties
```

`xmlParser.ts`'s parser only understands elements, attributes, text, and comments — no processing
instructions, CDATA, or DOCTYPE. That's sufficient for Dataverse form XML but not arbitrary XML documents.
If parsing fails, the component falls back to coloring the raw text as a single block with no line numbers,
folding, or diffing, so malformed input still renders something instead of crashing.

Folding and pretty-printing re-parse after re-indenting so fold regions point at lines in the *displayed*
text, not the original `xml`. Element ids stay comparable across the two parses since both assign them in
document order and re-indenting never reorders elements.
