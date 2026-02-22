#!/usr/bin/env python3
"""
Extract SwissFont data from TXT.PAS and convert to Pascal typed constant.

The SwissFont procedure contains:
  1. DW directives with label references (@Space, @Number1, etc.) - these are
     offset pointers to each glyph and become part of the binary data
  2. Labels (@Space:, @Number1:, etc.) marking glyph positions
  3. DB directives with hex values ($00, $FF, etc.) for glyph data
     (each glyph starts with width byte and height byte, then pixel data)

We need to extract ALL the raw binary data from the ASM block: the DW offsets
are part of the font data structure (they form a lookup table), and the DB
values are the actual glyph bitmaps.

Since DW with label refs are assembled into 2-byte offsets at runtime, we
cannot know their absolute values at extraction time. Instead, we compute
them: each DW label ref becomes a 2-byte offset pointing to where that label's
data begins within the extracted byte stream.
"""

import re
import os
import sys


def parse_hex_byte(token):
    """Parse a $XX hex byte."""
    token = token.strip()
    if token.startswith('$'):
        return int(token[1:], 16) & 0xFF
    try:
        return int(token) & 0xFF
    except ValueError:
        return None


def extract_swissfont(content):
    """
    Extract the SwissFont data from TXT.PAS content.
    Returns a list of bytes representing the entire font data structure.

    Strategy:
    - First pass: identify all labels and their positions in the byte stream
      (counting only DB data, not DW label refs yet)
    - The DW label refs at the start form a table of 2-byte offsets
    - We calculate the size of the DW table, then compute label offsets
      relative to the start of the data block
    """

    # Find the SwissFont procedure's ASM...END block
    # Match "procedure SwissFont; assembler;" then find ASM...END
    swiss_match = re.search(
        r'procedure\s+SwissFont\s*;\s*assembler\s*;\s*\basm\b(.*?)\bend\b',
        content, re.IGNORECASE | re.DOTALL
    )
    if not swiss_match:
        print('ERROR: Could not find SwissFont procedure')
        sys.exit(1)

    asm_body = swiss_match.group(1)

    # Parse the ASM body line by line
    # We need to:
    # 1. Count DW label references (to know table size)
    # 2. Collect all labels and their byte positions (relative to after the DW table)
    # 3. Collect all DB data bytes

    lines = asm_body.split('\n')

    # First pass: collect structure
    dw_label_refs = []  # list of label names referenced by DW
    labels = {}  # label_name -> byte position in db_data
    db_data = []  # all DB bytes after the DW table

    phase = 'dw_table'  # Start by reading the DW table

    for line in lines:
        line = line.strip()
        if not line:
            continue

        # Check for label definition (e.g., "@Space:")
        label_match = re.match(r'@(\w+)\s*:', line)
        if label_match:
            label_name = label_match.group(1).lower()  # Normalize to lowercase
            labels[label_name] = len(db_data)
            phase = 'db_data'
            # There might be data after the label on the same line
            rest = line[label_match.end():].strip()
            if rest:
                line = rest
            else:
                continue

        # Check for DW directive
        dw_match = re.match(r'DW\s+(.*)', line, re.IGNORECASE)
        if dw_match:
            values_str = dw_match.group(1).strip()
            tokens = [t.strip() for t in values_str.split(',')]
            for token in tokens:
                if not token:
                    continue
                if token.startswith('@'):
                    dw_label_refs.append(token[1:].lower())  # Remove @ and normalize
                else:
                    # Numeric DW value - store as 2 bytes little-endian
                    if token.startswith('$'):
                        val = int(token[1:], 16) & 0xFFFF
                    else:
                        try:
                            val = int(token) & 0xFFFF
                        except ValueError:
                            continue
                    # This shouldn't happen in the label table, but handle anyway
                    pass
            continue

        # Check for DB directive
        db_match = re.match(r'DB\s+(.*)', line, re.IGNORECASE)
        if db_match:
            values_str = db_match.group(1).strip()
            tokens = [t.strip() for t in values_str.split(',')]
            for token in tokens:
                val = parse_hex_byte(token)
                if val is not None:
                    db_data.append(val)
            continue

    # Now build the complete byte stream:
    # [DW table: N x 2 bytes] [DB data]
    dw_table_size = len(dw_label_refs) * 2  # Each DW is 2 bytes
    all_bytes = []

    # Write DW table: each entry is an offset from the start of the data
    # to the label position (label positions are relative to start of db_data,
    # so we add dw_table_size to get absolute offset from start)
    for label_name in dw_label_refs:
        if label_name in labels:
            offset = dw_table_size + labels[label_name]
        else:
            print(f'  WARNING: Label @{label_name} not found, using 0')
            offset = 0
        # Little-endian 16-bit
        all_bytes.append(offset & 0xFF)
        all_bytes.append((offset >> 8) & 0xFF)

    # Append all DB data
    all_bytes.extend(db_data)

    print(f'  DW label references: {len(dw_label_refs)}')
    print(f'  DW table size: {dw_table_size} bytes')
    print(f'  DB data size: {len(db_data)} bytes')
    print(f'  Total size: {len(all_bytes)} bytes')
    print(f'  Labels found: {len(labels)}')

    return all_bytes


def format_pascal_const(const_name, array_type, bytes_data, items_per_line=16):
    """Format bytes as a Pascal typed constant."""
    n = len(bytes_data)
    lines = []
    lines.append(f'const')
    lines.append(f'  {const_name}: array[0..{n - 1}] of {array_type} = (')

    for i in range(0, n, items_per_line):
        chunk = bytes_data[i:i + items_per_line]
        vals = ', '.join(f'${b:02X}' for b in chunk)
        if i + items_per_line >= n:
            lines.append(f'    {vals}')
        else:
            lines.append(f'    {vals},')

    lines.append(f'  );')
    return '\n'.join(lines)


def main():
    base_dir = r'C:\Users\pedro\Desktop\MARIOSRC'
    out_dir = os.path.join(base_dir, 'sdl2_port', 'data')

    print('=== Extract Font Data ===')
    print()

    # Read TXT.PAS
    txt_pas = os.path.join(base_dir, 'TXT.PAS')
    print(f'Reading {txt_pas}...')
    with open(txt_pas, 'r', encoding='latin-1') as f:
        content = f.read()

    # Extract SwissFont
    print('Extracting SwissFont...')
    bytes_data = extract_swissfont(content)

    # Write output
    out_file = os.path.join(out_dir, 'font.inc')
    output = '{ SwissFont data extracted from TXT.PAS }\n'
    output += '{ Format: DW offset table followed by glyph data }\n'
    output += '{ Each glyph: DB width, DB height, then bitmap bytes }\n\n'
    output += format_pascal_const('SwissFontData', 'Byte', bytes_data)
    output += '\n'

    os.makedirs(os.path.dirname(out_file), exist_ok=True)
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write(output)
    print(f'  Written: {out_file}')
    print()

    print('=== Done ===')


if __name__ == '__main__':
    main()
