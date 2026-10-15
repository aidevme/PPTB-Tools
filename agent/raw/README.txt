raw/ — IMMUTABLE sources (read-only)

The agent READS from here but NEVER writes or modifies these files after capture. Ingest skills write
once, then treat the file as frozen. This folder holds actual local files AND capture files (markdown
pointers + snapshot content) for external sources.

Note: this file is .txt, not .md, on purpose — the wiki linter requires every .md file under raw/ to
be a `type: capture` file (invariant 9). Folder notes use .txt to stay out of that rule.

Subfolders (by source KIND, not locality):
  transcripts/   meeting transcripts, Teams captures
  discovery/     client PDFs, Excel, Word, requirements docs
  screenshots/   image captures
  exports/       ADO exports, solution XML, DB dumps

See ../schema.md (Captures) for the capture frontmatter and fidelity rules.
