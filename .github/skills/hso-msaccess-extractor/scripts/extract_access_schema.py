"""
MS Access Schema and Data Extraction Script
Uses DAO via COM automation to extract:
- Table definitions (fields, types, descriptions, defaults)
- Indexes and primary keys
- Relationships between tables
- Query definitions (SQL)
- All table data (to CSV)

Requirements:
- Python 3.x (64-bit for 64-bit Access)
- pywin32: pip install pywin32
- Microsoft Access installed (for DAO driver)

Usage:
    python extract_access_schema.py <database_path> <output_folder>

Example:
    python extract_access_schema.py "C:\Path\To\database.accdb" "C:\Output"
"""

import win32com.client
import json
import csv
import sys
import os
import re
from pathlib import Path
from datetime import datetime


def sanitize_filename(name):
    """Replace characters that are invalid in filenames."""
    # Replace characters invalid in Windows filenames
    invalid_chars = r'[<>:"/\\|?*]'
    return re.sub(invalid_chars, '_', name)

# DAO Field Type Constants
FIELD_TYPES = {
    1: 'Boolean',
    2: 'Byte',
    3: 'Integer',
    4: 'Long',
    5: 'Currency',
    6: 'Single',
    7: 'Double',
    8: 'Date/Time',
    9: 'Binary',
    10: 'Text',
    11: 'Long Binary (OLE Object)',
    12: 'Memo',
    15: 'GUID',
    16: 'Big Integer',
    101: 'Attachment',
    102: 'Complex Byte',
    103: 'Complex Integer',
    104: 'Complex Long',
    105: 'Complex Single',
    106: 'Complex Double',
    107: 'Complex GUID',
    108: 'Complex Decimal',
    109: 'Complex Text'
}

# DAO Query Type Constants
QUERY_TYPES = {
    0: 'Select',
    16: 'Crosstab',
    32: 'Delete',
    48: 'Update',
    64: 'Append',
    80: 'Make Table',
    96: 'Data Definition',
    112: 'Pass-Through',
    128: 'Union',
    240: 'Action',
}

# DAO Relation Attributes
RELATION_ATTRIBUTES = {
    1: 'Enforce Referential Integrity',
    2: 'Cascade Updates',
    4: 'Cascade Deletes',
    256: 'Left Join',
    512: 'Right Join',
}


def get_field_type_name(type_code):
    """Convert DAO field type code to readable name."""
    return FIELD_TYPES.get(type_code, f'Unknown ({type_code})')


def get_query_type_name(type_code):
    """Convert DAO query type code to readable name."""
    return QUERY_TYPES.get(type_code, f'Unknown ({type_code})')


def decode_relation_attributes(attr_value):
    """Decode relation attributes bitmask to list of strings."""
    attrs = []
    for bit, name in RELATION_ATTRIBUTES.items():
        if attr_value & bit:
            attrs.append(name)
    return attrs


def get_field_property(field, prop_name):
    """Safely get a field property that may not exist."""
    try:
        for prop in field.Properties:
            if prop.Name == prop_name:
                return prop.Value
    except Exception:
        pass
    return None


def extract_schema(db_path, output_dir):
    """Extract complete schema from Access database."""
    print(f"\n{'='*60}")
    print(f"Extracting schema from: {db_path}")
    print(f"{'='*60}\n")

    # Initialize DAO Engine
    try:
        dao_engine = win32com.client.Dispatch('DAO.DBEngine.120')
    except Exception as e:
        print(f"Error: Could not initialize DAO Engine. Is Access installed?")
        print(f"Details: {e}")
        return None

    # Open database
    try:
        db = dao_engine.OpenDatabase(db_path)
    except Exception as e:
        print(f"Error: Could not open database.")
        print(f"Details: {e}")
        return None

    schema = {
        'database': os.path.basename(db_path),
        'extracted_at': datetime.now().isoformat(),
        'tables': [],
        'relationships': [],
        'queries': []
    }

    # Extract Table Definitions
    print("Extracting tables...")
    for table_def in db.TableDefs:
        # Skip system tables and temp tables
        if table_def.Name.startswith('MSys') or table_def.Name.startswith('~'):
            continue

        print(f"  - {table_def.Name}")

        table_info = {
            'name': table_def.Name,
            'record_count': table_def.RecordCount,
            'fields': [],
            'indexes': []
        }

        # Extract Fields
        for field in table_def.Fields:
            field_info = {
                'name': field.Name,
                'type_code': field.Type,
                'type_name': get_field_type_name(field.Type),
                'size': field.Size,
                'required': field.Required,
                'allow_zero_length': getattr(field, 'AllowZeroLength', None),
                'ordinal_position': field.OrdinalPosition,
            }

            # Get optional properties
            default_val = field.DefaultValue
            if default_val:
                field_info['default_value'] = str(default_val)

            validation_rule = field.ValidationRule
            if validation_rule:
                field_info['validation_rule'] = str(validation_rule)

            validation_text = field.ValidationText
            if validation_text:
                field_info['validation_text'] = str(validation_text)

            # Get Description property (custom property)
            description = get_field_property(field, 'Description')
            if description:
                field_info['description'] = str(description)

            # Get Caption property
            caption = get_field_property(field, 'Caption')
            if caption:
                field_info['caption'] = str(caption)

            # Get Format property
            format_prop = get_field_property(field, 'Format')
            if format_prop:
                field_info['format'] = str(format_prop)

            table_info['fields'].append(field_info)

        # Extract Indexes (with error handling for linked tables)
        try:
            for index in table_def.Indexes:
                try:
                    index_info = {
                        'name': index.Name,
                        'primary': index.Primary,
                        'unique': index.Unique,
                        'foreign': index.Foreign,
                        'ignore_nulls': index.IgnoreNulls,
                        'required': index.Required,
                        'fields': [f.Name for f in index.Fields]
                    }
                    table_info['indexes'].append(index_info)
                except Exception as idx_err:
                    table_info['indexes'].append({'error': str(idx_err)})
        except Exception as e:
            table_info['index_error'] = f"Could not read indexes: {e}"

        schema['tables'].append(table_info)

    # Extract Relationships
    print("\nExtracting relationships...")
    for relation in db.Relations:
        # Skip system relationships
        if relation.Name.startswith('MSys'):
            continue

        print(f"  - {relation.Name}: {relation.Table} -> {relation.ForeignTable}")

        rel_info = {
            'name': relation.Name,
            'table': relation.Table,
            'foreign_table': relation.ForeignTable,
            'attributes': relation.Attributes,
            'attribute_names': decode_relation_attributes(relation.Attributes),
            'field_mappings': []
        }

        for field in relation.Fields:
            rel_info['field_mappings'].append({
                'field': field.Name,
                'foreign_field': field.ForeignName
            })

        schema['relationships'].append(rel_info)

    # Extract Query Definitions
    print("\nExtracting queries...")
    queries_dir = output_dir / 'Queries'
    queries_dir.mkdir(parents=True, exist_ok=True)

    for query_def in db.QueryDefs:
        # Skip temp queries
        if query_def.Name.startswith('~'):
            continue

        print(f"  - {query_def.Name} ({get_query_type_name(query_def.Type)})")

        query_info = {
            'name': query_def.Name,
            'type_code': query_def.Type,
            'type_name': get_query_type_name(query_def.Type),
            'sql': query_def.SQL
        }
        schema['queries'].append(query_info)

        # Also save SQL to individual file
        sql_file = queries_dir / f"{query_def.Name}.sql"
        with open(sql_file, 'w', encoding='utf-8') as f:
            f.write(f"-- Query: {query_def.Name}\n")
            f.write(f"-- Type: {get_query_type_name(query_def.Type)}\n\n")
            f.write(query_def.SQL)

    db.Close()

    # Save schema to JSON
    schema_file = output_dir / 'schema.json'
    with open(schema_file, 'w', encoding='utf-8') as f:
        json.dump(schema, f, indent=2, default=str)

    print(f"\nSchema saved to: {schema_file}")
    print(f"Queries saved to: {queries_dir}")

    # Print summary
    print(f"\n{'='*60}")
    print("EXTRACTION SUMMARY")
    print(f"{'='*60}")
    print(f"Tables:        {len(schema['tables'])}")
    print(f"Relationships: {len(schema['relationships'])}")
    print(f"Queries:       {len(schema['queries'])}")

    return schema


def export_data(db_path, output_dir, schema=None):
    """Export all table data to CSV files."""
    print(f"\n{'='*60}")
    print(f"Exporting data from: {db_path}")
    print(f"{'='*60}\n")

    # Initialize DAO Engine
    try:
        dao_engine = win32com.client.Dispatch('DAO.DBEngine.120')
        db = dao_engine.OpenDatabase(db_path)
    except Exception as e:
        print(f"Error: Could not open database: {e}")
        return

    data_dir = output_dir / 'Data'
    data_dir.mkdir(parents=True, exist_ok=True)

    export_summary = []

    for table_def in db.TableDefs:
        # Skip system tables and temp tables
        if table_def.Name.startswith('MSys') or table_def.Name.startswith('~'):
            continue

        table_name = table_def.Name

        # Check if table is linked (has a Connect string)
        try:
            connect_str = table_def.Connect
            if connect_str:
                print(f"Skipping: {table_name}... LINKED TABLE -> {connect_str[:80]}...")
                export_summary.append({'table': table_name, 'rows': 0, 'status': f'Linked: {connect_str}'})
                continue
        except Exception:
            pass  # Some tables may not have Connect property

        print(f"Exporting: {table_name}...", end=' ')

        try:
            # Get field names
            field_names = [field.Name for field in table_def.Fields]

            # Open recordset
            rs = db.OpenRecordset(table_name, 4)  # 4 = dbOpenSnapshot (read-only)

            # Write to CSV
            csv_path = data_dir / f"{sanitize_filename(table_name)}.csv"
            row_count = 0

            with open(csv_path, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(field_names)

                while not rs.EOF:
                    row = []
                    for field_name in field_names:
                        try:
                            value = rs.Fields(field_name).Value
                            # Handle special types
                            if value is None:
                                row.append('')
                            elif isinstance(value, (bytes, bytearray)):
                                row.append('[BINARY DATA]')
                            else:
                                row.append(value)
                        except Exception:
                            row.append('[ERROR]')
                    writer.writerow(row)
                    row_count += 1
                    rs.MoveNext()

            rs.Close()
            print(f"{row_count} rows")
            export_summary.append({'table': table_name, 'rows': row_count, 'status': 'OK'})

        except Exception as e:
            print(f"ERROR: {e}")
            export_summary.append({'table': table_name, 'rows': 0, 'status': f'Error: {e}'})

    db.Close()

    # Save export summary
    summary_file = data_dir / '_export_summary.json'
    with open(summary_file, 'w', encoding='utf-8') as f:
        json.dump({
            'database': os.path.basename(db_path),
            'exported_at': datetime.now().isoformat(),
            'tables': export_summary
        }, f, indent=2)

    print(f"\nData exported to: {data_dir}")
    print(f"Export summary: {summary_file}")

    # Print summary
    total_rows = sum(t['rows'] for t in export_summary)
    print(f"\n{'='*60}")
    print("DATA EXPORT SUMMARY")
    print(f"{'='*60}")
    print(f"Tables exported: {len(export_summary)}")
    print(f"Total rows:      {total_rows}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("\nUsage: python extract_access_schema.py <database_path> [output_folder]")
        print("  Provide the path to an .accdb file as the first argument.")
        sys.exit(1)

    db_path = sys.argv[1]
    if not os.path.exists(db_path):
        print(f"Error: Database not found: {db_path}")
        sys.exit(1)

    # Default output directory
    if len(sys.argv) >= 3:
        output_dir = Path(sys.argv[2])
    else:
        db_name = Path(db_path).stem
        output_dir = Path.cwd() / "output" / db_name

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Output directory: {output_dir}")

    # Extract schema
    schema = extract_schema(db_path, output_dir)

    # Export data
    if schema:
        export_data(db_path, output_dir, schema)

    print(f"\n{'='*60}")
    print("EXTRACTION COMPLETE")
    print(f"{'='*60}")
    print(f"Output: {output_dir}")


if __name__ == '__main__':
    main()
