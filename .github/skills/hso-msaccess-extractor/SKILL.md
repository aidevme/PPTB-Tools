---
name: hso-msaccess-extractor
layer: atomic
scope: core
description: |
  Extract schema, data, queries, forms, reports, and VBA code from MS Access databases (.accdb/.mdb).
  Use when: (1) Migrating Access databases to Dataverse or other platforms, (2) Documenting legacy Access
  database structure, (3) Extracting table schemas, relationships, and queries, (4) Exporting table data
  to CSV, (5) Extracting VBA code modules, forms, and reports for analysis.
---

# MS Access Database Extractor

Extract complete database structure and content from MS Access databases for modernization projects.

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `database_path` | Yes | Path to the .accdb or .mdb file |
| `output_dir` | No | Output directory (defaults to `agent/work/analysis/MSAccess_Extracted/<db_name>`) |
| `mode` | No | `full` (default), `schema-only`, or `data-only` |

## Quick Start

### Extract Schema, Data, and Queries (Python)

```bash
python scripts/extract_access_schema.py "<database_path>" "<output_dir>"
```

**Output:**
- `schema.json` - Table definitions, fields, types, indexes, relationships
- `Data/*.csv` - One CSV per table
- `Queries/*.sql` - One SQL file per query

### Extract Forms, Reports, VBA Modules (VBA - run in Access)

1. Open the Access database
2. Press Alt+F11 to open VBA Editor
3. Insert > Module, paste content from `scripts/ExportAllObjects.bas`
4. Run: `Call ExportAllObjects("C:\Output\Path")`

**Output:**
- `Forms/*.txt` - Form definitions (SaveAsText format)
- `Reports/*.txt` - Report definitions
- `Modules/*.bas` - VBA code modules
- `Macros/*.txt` - Macro definitions

## Prerequisites

- **Python extraction:** Python 3.x + pywin32 (`pip install pywin32`), MS Access installed
- **VBA extraction:** MS Access (must run inside the database)
- **Bitness:** Python and Access must match (both 32-bit or both 64-bit)

## Split Database Architecture

Access often uses a **split database architecture**:

```
Front-End.accdb (Forms, Queries, UI)
    │ linked tables
    ▼
Back-End.accdb (Actual data)
```

### Detecting Linked Tables

| Indicator | Meaning |
|-----------|---------|
| `TableDef.Connect` not empty | Linked table (Access or ODBC) |
| `record_count = -1` | ODBC linked table |
| `record_count = 0` with schema | May be linked or empty |
| Status contains "Linked:" | Confirmed linked in export summary |

**Connect string patterns:**
- `;DATABASE=C:\path\file.accdb` - Linked Access table
- `ODBC;DRIVER=SQL Server;SERVER=...` - ODBC linked table
- `\\server\share\path\file.accdb` - Network share linked table

### Resolution options
1. Extract from the back-end database directly
2. Re-link tables to local copies before extraction
3. Run extraction from a machine with network access to linked paths
4. For ODBC tables, query the SQL Server directly

## Output Structure

```
<output_dir>/
├── schema.json           # Complete schema with tables, fields, indexes, relationships
├── Data/
│   ├── TableName.csv     # One CSV per table
│   └── _export_summary.json
├── Queries/
│   └── QueryName.sql     # One SQL file per query
├── Forms/                # (VBA extraction only)
│   └── FormName.txt
├── Reports/              # (VBA extraction only)
│   └── ReportName.txt
├── Modules/              # (VBA extraction only)
│   └── ModuleName.bas
└── Macros/               # (VBA extraction only)
    └── MacroName.txt
```

## Schema JSON Format

```json
{
  "database": "DatabaseName.accdb",
  "extracted_at": "2026-01-16T12:00:00",
  "tables": [{
    "name": "TableName",
    "record_count": 1000,
    "fields": [{
      "name": "FieldName",
      "type_code": 10,
      "type_name": "Text",
      "size": 255,
      "required": false,
      "description": "Field description"
    }],
    "indexes": [{
      "name": "PrimaryKey",
      "primary": true,
      "unique": true,
      "fields": ["ID"]
    }]
  }],
  "relationships": [{
    "name": "RelationName",
    "table": "ParentTable",
    "foreign_table": "ChildTable",
    "field_mappings": [{"field": "ID", "foreign_field": "ParentID"}]
  }],
  "queries": [{
    "name": "QueryName",
    "type_name": "Select",
    "sql": "SELECT * FROM Table"
  }]
}
```

## DAO Field Types

| Code | Type |
|------|------|
| 1 | Boolean |
| 3 | Integer |
| 4 | Long |
| 5 | Currency |
| 7 | Double |
| 8 | Date/Time |
| 10 | Text |
| 12 | Memo |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Could not initialize DAO Engine" | Install MS Access or Access Database Engine |
| Bitness mismatch | Use 64-bit Python with 64-bit Access (or 32/32) |
| Linked tables show 0 rows | Tables are linked to external database - extract from source |
| Unicode errors on Windows | Set `PYTHONIOENCODING=utf-8` environment variable |
| Extraction hangs on linked tables | Script auto-skips tables with non-empty `Connect` property |
| Large table (500K+ rows) timeout | Add `--skip-tables TABLENAME` or increase timeout |
| Partial export (CSV exists) | Delete CSV to re-export, or add resume logic |

## Large Table Handling

Tables with 100K+ rows may timeout during export. Options:
1. **Skip and export separately:** Add table to skip list, export with dedicated script
2. **Increase timeout:** Modify script timeout (default 2 min per operation)
3. **Chunked export:** For very large tables, export in batches using SQL with TOP/OFFSET

## Resume Extraction

If extraction stops mid-way:
1. Schema is usually complete (check `schema.json`)
2. Check `Data/_export_summary.json` for what was exported
3. Check `Data/*.csv` files for partial exports
4. Delete partial CSVs and re-run, or modify script to skip existing files

## References

- [Extraction Research](references/extraction_research.md) - Detailed research on extraction approaches

---

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
