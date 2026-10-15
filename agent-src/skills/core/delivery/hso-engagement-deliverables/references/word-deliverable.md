# HSO Client Word Document — Recipe & Internals

Detailed implementation for the Word deliverables — the generic **Client Document** and the **Solution Blueprint
Document (SBD)**. Uses `python-docx`. All examples are generic — never embed client names or content in this
skill; read content from the project / user.

> **SBD:** for the fixed SBD skeleton, style family, and Contributors/Revision-History schema, read
> [sbd-word-structure.md](sbd-word-structure.md) first — this file is the shared Word engine underneath it.
>
> **Format from a sample (SOP §6a):** when the user prefaces a request with a sample document, use it as the
> `base` **donor for format only** — its styles/theme/header/skeleton. After cloning, empty the body (§3) and
> rebuild with project content or `[PLACEHOLDER: …]`. **Never leave the sample's body text, client names, or
> named individuals in the output.** The sample stays per-machine/gitignored (`CLAUDE.local.md`), never committed.

---

## 1. Choose the base (most important decision)

Word branding comes from the document's **named styles + theme + header/footer**, not from runtime formatting.
Pick the base in this order:

0. **The bundled HSO donor** (`assets/HSO_Word_base.docx`) — the **zero-config default** used when the spec
   omits `base`. Sanitized from the Global HSO Word Template: empty body, **Segoe UI theme**, stock
   `Title`/`Subtitle`/`Heading 1-4`/`List Paragraph`/`Table Grid`/`TOC Heading` styles, no placeholder cover.
   Nothing to configure — use this unless the user wants a specific look.
1. **An accepted on-brand `*_Client.docx` donor** — when matching a specific approved deliverable. A
   previously-approved HSO client doc already has the theme + working styles; cloning it guarantees that look.
2. **The HSO `.dotx`** (`CLAUDE.local.md` → Branding) — only if you must build from the raw template. It needs
   pre-processing (§2): its body ships a **placeholder header + sample/cover content**. Gotchas by vintage — the
   **legacy Aug-2021** `.dotx` has `docDefaults` **Open Sans** + an "Optional Document Title" header; the
   **2026 Global** `.dotx` fixes the header but ships a **stock Calibri theme** (so headings render Calibri, not
   Segoe UI) — force the theme fonts to Segoe UI (this is exactly what the bundled donor already does).

> Symptom mapping: *"header is wrong / multiple fonts / Calibri"* ⇒ you built on a raw `.dotx`. Use the bundled
> donor (or a `*_Client.docx` donor) instead.

```python
import shutil
shutil.copyfile(DONOR_DOCX, BASE)        # donor path is an accepted *_Client.docx
doc = Document(BASE)
```

## 2. If you must use the `.dotx`: repackage + strip

python-docx cannot open a `.dotx` (content type is `…wordprocessingml.template.main+xml`). Repackage to a
`document` content type, then delete the template's sample body:

```python
import zipfile
with zipfile.ZipFile(DOTX) as zin, zipfile.ZipFile(BASE, "w", zipfile.ZIP_DEFLATED) as zout:
    for it in zin.infolist():
        data = zin.read(it.filename)
        if it.filename == "[Content_Types].xml":
            data = data.replace(b"wordprocessingml.template.main+xml",
                                b"wordprocessingml.document.main+xml")
        zout.writestr(it, data)
doc = Document(BASE)
# then remove the placeholder header part / titlePg, and clear the sample body (see §3)
```

## 3. Empty the body, keep section + header/footer

```python
from docx.oxml.ns import qn
body = doc.element.body
for child in list(body):
    if child.tag != qn("w:sectPr"):     # keep the trailing section props
        body.remove(child)
```
(Header/footer parts live outside the body and are preserved. With the donor base there's nothing else to do.)

## 4. Resolve styles (use styles, never manual font/size)

```python
styles = set(s.name for s in doc.styles)
def S(name, fb="Normal"): return name if name in styles else fb
TITLE = S("Title"); SUB = S("Subtitle", "AKA Subtitle of Report")
H1 = S("HSO 1st Level Heading", "Heading 1")    # both auto-number decimal in the HSO template
H2 = S("HSO 2nd Level Heading", "Heading 2")
H3 = S("HSO 3rd Level Heading", "Heading 3")
NORMAL = S("Normal"); BULLET = S("List Bullet"); TBL = "Table Grid" if "Table Grid" in styles else "Normal Table"
```

## 5. Numbering — style-driven, never typed

Check whether the chosen heading style auto-numbers (the donor's stock `Heading 1` usually does **not**;
the HSO template's `HSO 1st/2nd/3rd Level Heading` and `Heading 1` **do**, sharing one decimal multilevel list).
If it does, just apply the style with **no number in the text**. If it does **not**, inject one list and bind it:

```python
from docx.oxml import parse_xml
W = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
numbering = doc.part.numbering_part.element
ABS = max([int(e.get(qn("w:abstractNumId"))) for e in numbering.findall(qn("w:abstractNum"))] + [99]) + 1
NUM = max([int(e.get(qn("w:numId"))) for e in numbering.findall(qn("w:num"))] + [99]) + 1
lvls = "".join(
    f'<w:lvl w:ilvl="{i}"><w:start w:val="1"/><w:numFmt w:val="decimal"/>'
    f'<w:lvlText w:val="{t}"/><w:lvlJc w:val="left"/>'
    f'<w:pPr><w:ind w:left="{360*(i+1)}" w:hanging="360"/></w:pPr></w:lvl>'
    for i, t in enumerate(["%1.", "%1.%2", "%1.%2.%3"]))
numbering.findall(qn("w:abstractNum"))[-1].addnext(
    parse_xml(f'<w:abstractNum {W} w:abstractNumId="{ABS}"><w:multiLevelType w:val="multilevel"/>{lvls}</w:abstractNum>'))
numbering.append(parse_xml(f'<w:num {W} w:numId="{NUM}"><w:abstractNumId w:val="{ABS}"/></w:num>'))

def heading(text, level):            # level 1..3, auto-numbered, NO typed number
    p = doc.add_paragraph(text, style={1:H1,2:H2,3:H3}[level])
    pPr = p._p.get_or_add_pPr()
    numPr = parse_xml(f'<w:numPr {W}><w:ilvl w:val="{level-1}"/><w:numId w:val="{NUM}"/></w:numPr>')
    ps = pPr.find(qn("w:pStyle")); (ps.addnext(numPr) if ps is not None else pPr.insert(0, numPr))
    return p
```

## 6. Table of Contents (auto-updating field)

```python
if "TOC Heading" in styles: doc.add_paragraph("Table of Contents", style="TOC Heading")
p = doc.add_paragraph()
for frag in [
    '<w:r %s><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>' % W,
    '<w:r %s><w:instrText xml:space="preserve"> TOC \\o "1-3" \\h \\z \\u </w:instrText></w:r>' % W,
    '<w:r %s><w:fldChar w:fldCharType="separate"/></w:r>' % W,
    '<w:r %s><w:t>Right-click and choose "Update Field" (F9) to build the table of contents.</w:t></w:r>' % W,
    '<w:r %s><w:fldChar w:fldCharType="end"/></w:r>' % W,
]: p._p.append(parse_xml(frag))
# ...and so Word rebuilds it on open:
from docx.oxml import OxmlElement
s = doc.settings.element
if s.find(qn("w:updateFields")) is None:
    uf = OxmlElement("w:updateFields"); uf.set(qn("w:val"), "true"); s.append(uf)
```

## 7. Attribution — Contributors + Revision History (HSO standard)

**No single stamped author.** The old "Change Record with `Author = HSO - <name>` on every row" is retired —
it wrongly attributed the whole document to the running maintainer. Use the two HSO SBD tables instead, and
**never default a name from `CLAUDE.local.md`** into them (SOP §5).

```python
# Contributors — who worked on it (near the front matter)
heading("Contributors", 1)
table(["Name", "Role", "Company"], [
    ["[PLACEHOLDER: name]", "[PLACEHOLDER: role]", "HSO"],   # only real names the user supplies for THIS doc
])

# Revision History — what changed (front matter or last section)
heading("Revision History", 1)
table(["Version", "Section", "Content Change", "Date"], [
    ["1.0", "All", "Initial Release", "<date>"],
    ["", "", "", ""],                                        # blank row for future entries
])
```

- Company defaults to `HSO`; leave `[PLACEHOLDER: name]`/`[PLACEHOLDER: role]` for the team unless the user
  names contributors for this document. Do **not** write the maintainer's name anywhere.
- Leave the docx **core author metadata blank** (or set to `HSO`) — see §8.
- `table()` adds a `Table Grid` table with a bold header row; `kv_table()` (bold-left 2-col) suits an optional
  "Prepared for / by / Date / Status" control block near the top.

## 7a. Placeholders are highlighted (visible gaps)

Every `[PLACEHOLDER: …]` segment is emitted as its own **yellow-highlighted run** so a reader sees, at a
glance, exactly what still needs to be filled in before the deliverable is issued. The builder's `add_text()`
helper splits author-supplied text on the `[PLACEHOLDER:[^\]]*]` pattern and highlights only the matching
segments — surrounding prose in the same paragraph renders normally. It runs everywhere content may carry a gap:
`para`, `bullets`, and table body cells (and thus the SBD skeleton/front-matter leaves and Contributors rows).

- The colon is required: `[PLACEHOLDER: user counts]` highlights; a bare `[PLACEHOLDER]` written in prose to
  *describe* the convention does not. Author real gaps as `[PLACEHOLDER: <what's needed>]`.
- Fill a gap by overwriting the text in Word (or by re-running with the value supplied) — the highlight is a run
  property, so replacing the placeholder text clears it. Before issuing, confirm no yellow remains.

## 7b. Integrity scan (non-blocking) — fabrication-smell + internal-pointer leakage

After saving, the builder scans authored content (`lead` + `blocks`) with `scan_integrity()` and prints an
`INTEGRITY REVIEW` list. It flags the two things that must not reach a client (SOP §6–§7): **fabrication-smell**
— "across N HSO engagements", "HSO experience shows", the signature the 2026-05 override audit removed — and
**internal-pointer / internal-IP leakage** — "HSO Override", `agent/wiki`, ADR numbers, `/SKILL.md`, "per HSO
SOP §x". It is a **heuristic warning, not a gate**: it does not edit the document. Clear or confirm each item
against the [pre-issue QA checklist](sbd-qa-checklist.md) before issuing — take the *recommendation*, never the
internal rationale. (The scan reads the spec, so it catches gaps in authored `blocks`; it cannot see content you
type directly into Word afterward — the checklist's structural items cover the saved `.docx`.)

## 8. Save (and clear author metadata)

Before saving, blank the core author metadata so the running maintainer's name is not embedded (SOP §5):

```python
cp = doc.core_properties
cp.author = "HSO"            # or ""  — never the CLAUDE.local.md maintainer
cp.last_modified_by = "HSO"
```

Save to `work/deliverables/`. **A file open in Word is locked** → `PermissionError`; ask the user to close it.

## Gotchas (all observed in practice)

| Symptom | Cause | Fix |
|---|---|---|
| Wrong/placeholder header; mixed fonts | Built on raw `.dotx` body (logo-placeholder header, Open Sans/Arial) | Clone an accepted donor `*_Client.docx` |
| `… is not a Word file, content type is …template.main+xml` | Opened a `.dotx` with python-docx | Repackage content type to `document` (§2) |
| Headings show double numbers (e.g. "1. 1. Purpose") | Typed "1." in text **and** the style auto-numbers | Remove typed numbers; rely on the style |
| Headings show no number | Style has no `numPr` and no typed number | Inject a multilevel list and bind (§5) |
| `ImportError: circular import 'docx'` when running a script | A local file (e.g. `inspect.py`) shadows a stdlib module on `sys.path[0]` | Don't name scripts after stdlib modules; or run via `python -` |
| `cloud file provider exited unexpectedly` | OneDrive cloud-only placeholder not downloaded | Hydrate (open / "Always keep on this device") before reading |
| Garbled `©`/`–` in console | Console code page, not the docx | The `.docx` stores correct UTF-8; set `PYTHONIOENCODING=utf-8` for console only |
