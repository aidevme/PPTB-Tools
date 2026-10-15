# MS Access Extraction Research

## Extraction Approaches

### Option 1: Python + pywin32/DAO (Recommended for Schema/Data)

Uses COM automation to access DAO (Data Access Objects) for complete database introspection.

**Capabilities:**
- Table definitions with field types, sizes, descriptions
- Indexes and primary keys
- Relationships between tables
- Query definitions (SQL)
- All table data export to CSV

**Limitations:**
- Requires MS Access installed (for DAO driver)
- Cannot extract forms/reports (use SaveAsText)
- Python/Access bitness must match

### Option 2: SaveAsText/LoadFromText (VBA - For Forms/Reports/Code)

Undocumented but stable Access functions that export objects to text files.

**Supported Objects:**
| Object Type | Constant | File Extension |
|-------------|----------|----------------|
| Query | acQuery (1) | .sql |
| Form | acForm (2) | .txt |
| Report | acReport (3) | .txt |
| Macro | acMacro (4) | .txt |
| Module | acModule (5) | .bas |

**Note:** Tables cannot be exported with SaveAsText - use DAO/Python instead.

### Option 3: pyodbc (Lightweight Alternative)

ODBC-based access, lighter weight but fewer metadata capabilities.

```python
import pyodbc
conn_str = r'DRIVER={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=path\to\db.accdb;'
conn = pyodbc.connect(conn_str)
```

**Metadata Methods:**
- `cursor.tables()` - List tables/views
- `cursor.columns(table='X')` - Column definitions
- `cursor.primaryKeys(table='X')` - Primary keys
- `cursor.foreignKeys(table='X')` - Foreign keys

### Option 4: MDB Tools (Linux/Mac - No Access Required)

Open-source utilities for reading Access files without MS Access.

```bash
mdb-tables database.accdb          # List tables
mdb-schema database.accdb          # Export schema as SQL
mdb-export database.accdb Table    # Export table to CSV
```

## DAO Field Type Reference

| Code | Type | Description |
|------|------|-------------|
| 1 | Boolean | Yes/No |
| 2 | Byte | 0-255 |
| 3 | Integer | -32768 to 32767 |
| 4 | Long | -2B to 2B |
| 5 | Currency | Fixed-point |
| 6 | Single | Single-precision float |
| 7 | Double | Double-precision float |
| 8 | Date/Time | Dates and times |
| 9 | Binary | Binary data |
| 10 | Text | Up to 255 characters |
| 11 | Long Binary | OLE Object |
| 12 | Memo | Long text |
| 15 | GUID | Globally unique identifier |
| 16 | Big Integer | Large integers |
| 101 | Attachment | File attachments |

## DAO Query Types

| Code | Type |
|------|------|
| 0 | Select |
| 16 | Crosstab |
| 32 | Delete |
| 48 | Update |
| 64 | Append |
| 80 | Make Table |
| 96 | Data Definition |
| 112 | Pass-Through |
| 128 | Union |

## Relationship Attributes

| Bit | Meaning |
|-----|---------|
| 1 | Enforce Referential Integrity |
| 2 | Cascade Updates |
| 4 | Cascade Deletes |
| 256 | Left Join |
| 512 | Right Join |

## Split Database Detection

**Indicators of linked tables:**
1. Table exists in schema but has 0 record count
2. Table name prefixed with database name
3. `TableDef.Connect` property contains path to external database

**To find linked table sources:**
```python
for table_def in db.TableDefs:
    if table_def.Connect:
        print(f"{table_def.Name} -> {table_def.Connect}")
```

## External References

- [ISLADogs - SaveAsText/LoadFromText](https://isladogs.co.uk/save-load-text/index.html)
- [Python Programming on Win32 - DAO](https://www.oreilly.com/library/view/python-programming-on/1565926218/ch13s03s04.html)
- [mdbtools - GitHub](https://github.com/mdbtools/mdbtools)
- [pyodbc Wiki](https://github.com/mkleehammer/pyodbc/wiki)
