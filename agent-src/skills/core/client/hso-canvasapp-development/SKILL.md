---
name: hso-canvasapp-development
layer: atomic
scope: core
description: |
  Author, validate and round-trip Power Apps CANVAS apps as source (.pa.yaml) rather than clicking them together in Studio. Covers the pac canvas download/unpack/edit/pack/import loop, the .msapr resource bundle and what it holds, pre-pack YAML validation (pac canvas validate is stubbed out - use the bundled Test-CanvasYaml.py), the ': '-in-plain-scalar parse trap, modern-vs-classic control differences, and the Studio-only steps that genuinely cannot be scripted. Use for "build a canvas app", "edit the canvas app source", "pack/import an msapp", "why won't my .pa.yaml load", or any canvas ALM task. Does NOT cover model-driven apps (see hso-dataverse-ui-config) or PCF controls (see hso-pcf-control-development).
---

# Canvas App Development

Canvas apps in this repo are authored **as source** and packed, not built by clicking in Studio.
This skill exists because that loop has sharp edges that cost real time on first contact
(AP-984, and the 2026-08-10 connection-sharing spike before it).

## The round trip

```
pac canvas download --name "<App Name>" --file-name app.msapp     # from the environment
pac canvas unpack   --msapp app.msapp --sources <dir> --layout SourceCode
#   ... edit <dir>/Src/*.pa.yaml ...
python .claude/skills/hso-canvasapp-development/scripts/Test-CanvasYaml.py <dir>/Src   # MANDATORY
pac canvas pack     --sources <dir> --msapp app.msapp --layout SourceCode --overwrite
#   ... import via maker portal: Apps -> Import app -> From file (.msapp)
```

`--sources` points at the folder that contains **both** `Src/` and the `.msapr`.

## Hard constraints (all learned the expensive way)

### There is no upload verb
`pac canvas` is `download | list | pack | unpack | validate | create`. **None of them upload.**
The only routes into an environment are the maker portal (**Apps → Import app → From file (.msapp)**)
or wrapping the app in a solution and using `pac solution import`. Plan for a human click, or budget
the time to hand-build the solution wrapper.

### `pac canvas validate` is advertised but dead
It is still listed in `pac canvas --help`. Invoking it (2.10.1) returns:

```
Error: 'pac canvas validate' is no longer supported.
```

Note the flag is `--directory` (alias `-d`), **not** `--sources` — so a wrong-flag error arrives
first and can be mistaken for a usage problem rather than a removed feature. Use
`scripts/Test-CanvasYaml.py`; Studio is the only other validator.

### `pac canvas pack` does NOT validate
It packs broken YAML happily and the failure only surfaces on import. Always run the validator first.

### THE `': '` TRAP - the one that will actually bite you
A property value starting with `=` is a YAML **plain scalar**, so its double quotes are *literal
characters*, not string delimiters. Any `': '` inside the Power Fx is then parsed as a nested
mapping and the file breaks:

```yaml
# BROKEN - the ': ' inside the filter is read as YAML structure
OnSelect: =Set(v, Api.GetConnections({'$filter': "environment eq 'x'"}))

# CORRECT - block scalar
OnSelect: |
  =Set(v, Api.GetConnections({'$filter': "environment eq 'x'"}))
```

**Rule: any formula containing `': '` must be a `|` block scalar.** When in doubt, use one anyway —
they are never wrong.

### Modern vs classic controls - WIDER THAN IT LOOKS, and it will cost you an import
**Every bare control name resolves to the MODERN control**, not the classic one you are probably
writing from memory. The modern set exposes a far smaller property surface. Studio rejects each
offending property with `PA2108 : Unknown property '<X>' for control type '<Y>'` — and it rejects
them **all at once, on import**, which is a full round trip if you find out that way.

Confirmed on the AP-984 import (2026-08-11) — Studio's own words, not inference:

| Bare control | Does NOT expose | Fix |
|---|---|---|
| `Label` | `RadiusTopLeft` `RadiusTopRight` `RadiusBottomLeft` `RadiusBottomRight` | **Drop them.** A `Classic/Label` is *unconfirmed* — do not swap on spec. |
| `Button` | `Fill` `HoverFill` `PressedFill` `Color` `HoverColor` `PressedColor` `Size` + all four `Radius*` | **`Classic/Button`** — confirmed to own all of them. |
| `TextInput` | `Default` `HintText` | **`Classic/TextInput`** — confirmed. |

Note what modern `Label` *does* accept, because it is counter-intuitive: `Fill`, `Color`, `Size`,
`BorderColor`, `BorderThickness`, `PaddingLeft/Top/Right`, `Align`, `VerticalAlign`. So a modern
Label still works fine as a coloured card surface — it just cannot have rounded corners.

**A coloured button must be `Classic/Button`.** There is no way to set a brand fill on the modern one
from YAML; it is theme-driven.

`scripts/Test-CanvasYaml.py` enforces this table locally, so you find out in a second rather than
after an import.

### Connector payloads are strictly typed
Power Fx requires **every field the connector declares**, even when empty. Omitting
`principal.tenantId` fails at compile with `Missing column ... with a type of 'Text'`.

### Timers do not tick while invisible
A `Timer` with `Visible: =false` never fires. Bind `Visible` to the state that needs polling rather
than hiding the timer.

### `Header.json` LastSavedDateTimeUTC LIES
Do not trust it for freshness. Use `pac canvas list` (Modified on) and read
`References/DataSources.json`.

### Data sources are pruned if nothing references them
Power Apps removes data sources no formula mentions. Reference each connector somewhere real, or it
vanishes on the next save.

## THE `.msapr` CARRIES THE APP'S IDENTITY - READ THIS BEFORE REUSING ONE

**The `.msapr` is not a bag of connector metadata. It is the app.** `msapp/Properties.json` holds the
app's `Name`, and **maker-portal import matches an existing app by NAME** - so importing a `.msapp`
packed against someone else's `.msapr` **silently overwrites that app** instead of creating a new one.

Proven the hard way on AP-984 (2026-08-11): a new app was packed against the spike's `.msapr`, whose
`Properties.json` said `Name = "Onboarding"`. Import pushed it as a new version of the **existing**
`Onboarding` app - which happened to be a member of the `ContosoWave01` release solution. Note the
ids did **not** match (`9eaf80cf…` in the file vs `24e6c209…` in the environment), so the match was
on **name alone**. Nothing warned; the import reported success.

**Rule: never reuse another app's `.msapr` to create a new app.** To start a genuinely new app:

1. Create a blank canvas app in Studio, add its data sources there, and **Save it with the final name**.
2. `pac canvas download --name "<that name>"` then `unpack` - now you have a `.msapr` carrying the
   NEW app's identity and its data sources.
3. Drop your `Src/*.pa.yaml` over the unpacked `Src/`, delete the stale `_EditorState.pa.yaml`, `pack`.
4. Import. It updates the app you intended.

**Always verify the target before handing over an `.msapp`:**

```bash
python -c "import zipfile,json;print(json.loads(zipfile.ZipFile('x.msapp').read('Properties.json'))['Name'])"
```

If that name is not the app you mean to update, do not import it.

## The `.msapr`, and what you cannot hand-author

`--layout SourceCode` produces `Src/*.pa.yaml` plus a **`.msapr`** — a plain **zip** holding
everything that is not screen source:

```
msapr-header.json
msapp/Header.json  Properties.json  Controls/*.json
msapp/References/DataSources.json  Themes.json  Templates.json  Resources.json
```

It is inspectable and editable as a zip, which is useful for *reading* what is bound.

**But adding a new DATAVERSE table data source by hand is not practical.** Connector entries carry a
full WADL/metadata blob, and Dataverse entries carry a complete table-definition blob, both machine
generated and thousands of lines. **Adding a Dataverse table is a Studio step** (Data → Add data →
pick the table), after which you download/unpack again to capture a correct `.msapr`.

Sequence that works when an app needs a table it does not yet have:

1. Pack and import the app with the formulas already written against the table.
2. Open in Studio; **Data → Add data →** add the table. The unresolved references resolve.
3. Save and publish.
4. `pac canvas download` → `unpack` → commit the now-correct `.msapr` alongside the source.

The `.msapr` is **gitignored** in this repo, so tracked source alone cannot be packed — keep it
locally, or re-download before packing.

## Naming Dataverse things in Power Fx

Power Fx addresses Dataverse by **display name**, not logical name:

| Dataverse | Power Fx |
|---|---|
| `hso_mailboxonboarding` (plural "Mailbox Onboardings") | `'Mailbox Onboardings'` |
| `hso_mailboxaddress_text` ("Mailbox Address") | `'Mailbox Address'` |
| `statuscode` | `'Status Reason'` |
| `statecode` | `Status` |

Confirm the exact strings in Studio's formula bar after adding the data source — a display-name typo
is a silent runtime blank, not a compile error.

## Studio behaviour to expect

- Studio holds an **edit lock**; a stale session makes the app read-only. Co-authoring is enabled on
  this tenant, which mostly hides it, but a hung tab will still block you.
- A freshly imported app opens with formula errors for anything unresolved. That is normal — resolve
  the data sources, then re-check.

## Driving the maker portal in a browser

If automating the portal (import, adding data sources), **click by element reference, never by
screenshot coordinates.** The Power Apps SPA re-lays-out between the screenshot and the click; on
2026-08-11 a coordinate click intended for *Share* landed on *Delete* for a connection bound to five
live objects. Cancelled with nothing lost, but the lesson is cheap to take second-hand.
