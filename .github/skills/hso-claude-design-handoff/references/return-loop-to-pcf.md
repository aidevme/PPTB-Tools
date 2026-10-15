# Return Loop — Reconciling Claude Design Output into a PCF Spec

Claude Design produces **runnable HTML/CSS/JS**. That output is the **UX source of truth**,
not the build artifact. Engineers do **not** paste its raw HTML into a control — it will not
theme to Dataverse, will not pass Solution Checker, and is not Fluent v9. Instead we
**reconcile** the design into a [PCF control spec](../../../../shared/dv/agent/wiki/reference/pcf-control-spec-template.md),
which `hso-pcf-control-development` then builds against HSO's stack (virtual React control,
Fluent UI v9, `context.webAPI`).

> **Mental model:** Claude Design answered *"what should the experience be?"*. The PCF spec
> answers *"how do we build that experience inside a model-driven app, within platform
> constraints?"*. Reconcile, don't transliterate.

## Steps

1. **Capture the output.** Save the exported HTML/CSS/JS and the final screenshots into
   `agent/work/design/<Feature>/` (or `agent/raw/exports/` if you want an immutable snapshot
   of what Claude Design produced). Note the Claude Design project URL.

2. **Inventory screens and states.** List every screen and every state Claude Design drew.
   Claude Design often shows the happy path richly and the edge states thinly — you will fill
   the gaps in step 6.

3. **Map UI regions to Fluent v9 components.** Walk the design region by region and pick the
   nearest Fluent v9 primitive. The control is rebuilt in Fluent, so this mapping is the
   bridge:

   | Claude Design region | Fluent UI v9 component |
   |----------------------|------------------------|
   | Data table / editable grid | `DataGrid` (or a virtualised list for large sets) |
   | Primary / secondary actions | `Button`, `MenuButton`, `Toolbar` |
   | Text / number / currency inputs | `Input`, `SpinButton`, `Field` |
   | Single / multi choice | `Dropdown`, `Combobox`, `RadioGroup`, `Checkbox` |
   | Record cards / tiles | `Card`, `CardHeader` |
   | Side panel / drawer | `Drawer` (mind the portal token-resolution fix — see theming SOP) |
   | Modal / confirm | `Dialog` |
   | Tabs / sections | `TabList`, `Accordion` |
   | Status / inline messages | `MessageBar`, `Badge`, `Tag` |
   | Loading | `Spinner`, `Skeleton` |
   | Icons | **Custom SVG components — NEVER `@fluentui/react-icons`** (bundle ban) |

4. **Decide control identity and binding.** From the [spec template](../../../../shared/dv/agent/wiki/reference/pcf-control-spec-template.md):
   - **Field control** (bound to one column) vs **dataset control** (a grid/view over many
     records) vs **standalone form-area control**.
   - Control name (PascalCase), namespace, display name, `virtual` type.
   - Input properties (configuration knobs the maker sets on the form).
   - Manifest `uses-feature` flags (WebAPI / Utility) the design implies.

5. **Map interactions to Dataverse data access.** For each action in the design, specify the
   entity, columns (`$select`), filter, expand, and CRUD operation against the **real**
   schema (logical names verified via MCP). The design tells you *what* data appears; the
   data model tells you *where it lives*.

6. **Define every required UI state.** The spec must cover them even if Claude Design didn't:
   **Loading · Empty · Error · Normal · Disabled/read-only · No-permission.** Decide what each
   renders (Spinner, empty-state message + action, MessageBar + retry, etc.).

7. **Feasibility pass — flag the gap (CRITICAL).** Claude Design can use capabilities a PCF
   control should not. For each, record the adaptation in the spec's feasibility notes:

   | Claude Design may use… | In a PCF control… | Adaptation |
   |------------------------|-------------------|------------|
   | Arbitrary fonts / global CSS | CSS must be namespace-scoped; type comes from Fluent tokens | Re-style with Fluent v9 tokens; no global styles |
   | `@fluentui/react-icons`, large icon sets | Banned (bundle weight) | Custom SVG icon components |
   | `localStorage` / `sessionStorage` | Prohibited | Persist via Dataverse or in-memory only |
   | Web-only APIs, external fetch, CDNs | Restricted; Solution Checker flags | Use `context.webAPI`; bundle deps |
   | Video / shaders / 3D / voice | Out of scope for line-of-business PCF | Drop or replace with a static affordance |
   | Fixed-pixel desktop layout | Must be responsive; full-tab uses `position: absolute` sizing | Define responsive behaviour + form-factor handling |
   | Rich animation | Keep subtle; perf budget applies | Minimal, token-driven transitions only |
   | Unlimited bundle size | ~50 KB field / ~200 KB dataset budget | Note any heavy element as a risk |

   Anything you cannot honour cleanly is either an explicit adaptation in the spec or a
   conversation to have before build — not a silent drop.

8. **Accessibility & performance.** Carry WCAG 2.1 AA into the spec (keyboard, ARIA,
   contrast, focus). Set the record-volume / paging / virtual-scroll / bundle targets.

9. **Write the spec and hand off.** Produce
   `agent/work/specs/<Feature>/<Feature>_Spec.md` from the
   [PCF spec template](../../../../shared/dv/agent/wiki/reference/pcf-control-spec-template.md),
   then invoke `hso-pcf-control-development` to build and `hso-dataverse-ui-config` to host it
   on the form.

10. **Record material divergences.** If the agreed UX departs meaningfully from the legacy
    D365 design, capture an ADR via `hso-wiki-write-decision` so the reasoning survives.

## Output of this loop

A PCF spec that an engineer can build without re-opening Claude Design, plus:
- a saved copy of the Claude Design output (the visual reference),
- a feasibility-notes section listing every adaptation from design to platform,
- (if applicable) an ADR for the UX divergence from the legacy system.

See the parent [SKILL.md](../SKILL.md) for the full outbound + return workflow.
