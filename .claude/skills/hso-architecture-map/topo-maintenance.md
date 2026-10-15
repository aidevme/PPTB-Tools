# TOPO maintenance rule (canonical checklist)

Run this every time a component is created, modified, or removed. It is the short, always-on
checklist; the per-scenario steps live in the SOP document
(`shared/dv/agent/wiki/reference/topo-standard-operating-procedures.md`).

1. **Locate the block.** Find (or create) the component's block in
   `agent/wiki/system/solution-map.topo` using the correct tag (see SKILL.md §1).
2. **Record intent, not implementation.** One line of *why it exists* and its interface — never a
   field-by-field schema dump.
3. **Wire dependencies BOTH ways.** For every `depends_on` you add, add the mirror `depended_on_by`
   on the target block. Removing a dependency removes both sides. This is the non-negotiable
   bidirectional invariant.
4. **Update neighbours.** New client logic updates its parent `[DE]` list and sets client/server
   PARITY; a new `[API]` updates its backing `[SL]`; a new `[BP]` updates its trigger entity.
5. **Regenerate, don't hand-draw.** Never hand-edit the Mermaid/graph section — run `/topo-validate`
   to regenerate it and check consistency.
6. **Log it.** Append a one-line entry to `agent/log.md` for any material map change.

If any step cannot be completed (e.g. the SOP is ambiguous), STOP and surface it rather than leaving
the map half-updated — a stale map is worse than an obviously-empty one.
