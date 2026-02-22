#!/usr/bin/env python3
"""
Extract assembler data (DB/DW directives) from Pascal include files
and convert them to Pascal typed constants.
"""

import re
import os
import sys


def parse_db_value(token):
    """Parse a single DB value token. Returns a list of byte values."""
    token = token.strip()
    if not token:
        return []

    # Hex with $ prefix: $FF
    if token.startswith('$'):
        return [int(token[1:], 16) & 0xFF]

    # Character ordinal: #65
    if token.startswith('#'):
        return [int(token[1:]) & 0xFF]

    # Quoted character: 'A' or single char
    if token.startswith("'") and token.endswith("'"):
        chars = token[1:-1]
        return [ord(c) & 0xFF for c in chars]

    # Plain decimal number
    try:
        return [int(token) & 0xFF]
    except ValueError:
        return []


def parse_dw_value(token):
    """Parse a single DW value token. Returns two bytes in little-endian."""
    token = token.strip()
    if not token:
        return []

    # Hex with $ prefix
    if token.startswith('$'):
        val = int(token[1:], 16) & 0xFFFF
        return [val & 0xFF, (val >> 8) & 0xFF]

    # Plain decimal
    try:
        val = int(token) & 0xFFFF
        return [val & 0xFF, (val >> 8) & 0xFF]
    except ValueError:
        return []


def is_label_ref(token):
    """Check if a token is a label reference (starts with @)."""
    return token.strip().startswith('@')


def extract_asm_bytes(content):
    """
    Extract all bytes from ASM DB/DW directives in a procedure body.
    Returns (procedure_name, list_of_bytes).
    """
    bytes_data = []
    proc_name = None

    # Find procedure name
    proc_match = re.search(r'procedure\s+(\w+)\s*;', content, re.IGNORECASE)
    if proc_match:
        proc_name = proc_match.group(1)

    # Find the ASM...END block
    asm_match = re.search(r'\bASM\b(.*?)\bEND\b', content, re.IGNORECASE | re.DOTALL)
    if not asm_match:
        return proc_name, bytes_data

    asm_body = asm_match.group(1)

    for line in asm_body.split('\n'):
        line = line.strip()
        if not line:
            continue

        # Match DB or DW directive
        m = re.match(r'(DB|DW)\s+(.*)', line, re.IGNORECASE)
        if not m:
            continue

        directive = m.group(1).upper()
        values_str = m.group(2).strip()

        # Remove trailing comments (after ;)
        # Be careful not to remove ; inside quotes
        comment_pos = -1
        in_quote = False
        for i, ch in enumerate(values_str):
            if ch == "'":
                in_quote = not in_quote
            elif ch == ';' and not in_quote:
                comment_pos = i
                break
        if comment_pos >= 0:
            values_str = values_str[:comment_pos].strip()

        # Split by comma, but handle quoted strings carefully
        tokens = []
        current = ''
        in_quote = False
        for ch in values_str:
            if ch == "'":
                in_quote = not in_quote
                current += ch
            elif ch == ',' and not in_quote:
                tokens.append(current.strip())
                current = ''
            else:
                current += ch
        if current.strip():
            tokens.append(current.strip())

        for token in tokens:
            token = token.strip()
            if not token:
                continue

            # Skip label references (like @Space, @Number1, etc.)
            if is_label_ref(token):
                continue

            if directive == 'DB':
                bytes_data.extend(parse_db_value(token))
            elif directive == 'DW':
                bytes_data.extend(parse_dw_value(token))

    return proc_name, bytes_data


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


def process_single_file(filepath):
    """Process a single file and return (proc_name, bytes_data)."""
    with open(filepath, 'r', encoding='latin-1') as f:
        content = f.read()
    return extract_asm_bytes(content)


def write_output(filepath, content):
    """Write output to file, creating directories as needed."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'  Written: {filepath}')


def main():
    base_dir = r'C:\Users\pedro\Desktop\MARIOSRC'
    out_dir = os.path.join(base_dir, 'sdl2_port', 'data')

    print('=== Extract ASM Data ===')
    print()

    # 1. MPAL256 (file has no extension)
    print('Processing MPAL256...')
    filepath = os.path.join(base_dir, 'MPAL256')
    proc_name, bytes_data = process_single_file(filepath)
    print(f'  Procedure: {proc_name}, Bytes: {len(bytes_data)}')
    content = '{ Palette data extracted from MPAL256 }\n'
    content += '{ 256 colors x 3 RGB components = 768 bytes }\n\n'
    content += format_pascal_const('Pal256Data', 'Byte', bytes_data)
    content += '\n'
    write_output(os.path.join(out_dir, 'mpal256.inc'), content)
    print()

    # 2. PALBRICK.$00
    print('Processing PALBRICK.$00...')
    filepath = os.path.join(base_dir, 'PALBRICK.$00')
    proc_name, bytes_data = process_single_file(filepath)
    const_name = proc_name[0].upper() + proc_name[1:] if proc_name else 'Palbrick000'
    print(f'  Procedure: {proc_name}, Bytes: {len(bytes_data)}, Const: {const_name}')
    content = '{ Brick palette data extracted from PALBRICK.$00 }\n\n'
    content += format_pascal_const(const_name + 'Data', 'Byte', bytes_data)
    content += '\n'
    write_output(os.path.join(out_dir, 'palbrick.inc'), content)
    print()

    # 3. PALPILL.$00, $01, $02 -> all in one file
    print('Processing PALPILL.$00, $01, $02...')
    content = '{ Pill palette data extracted from PALPILL.$00, $01, $02 }\n\n'
    for suffix in ['$00', '$01', '$02']:
        filepath = os.path.join(base_dir, f'PALPILL.{suffix}')
        proc_name, bytes_data = process_single_file(filepath)
        const_name = proc_name[0].upper() + proc_name[1:] if proc_name else f'Palpill{suffix}'
        print(f'  Procedure: {proc_name}, Bytes: {len(bytes_data)}, Const: {const_name}')
        content += format_pascal_const(const_name + 'Data', 'Byte', bytes_data)
        content += '\n\n'
    write_output(os.path.join(out_dir, 'palpill.inc'), content)
    print()

    # 4. Background files -> all in one file
    print('Processing background files...')
    bg_files = [
        ('BOGEN.BK', 'bogen'),
        ('BOGEN7.BK', 'bogen7'),
        ('BOGEN26.BK', 'bogen26'),
        ('MOUNT.BK', 'mount'),
    ]
    content = '{ Background data extracted from BOGEN.BK, BOGEN7.BK, BOGEN26.BK, MOUNT.BK }\n\n'
    for filename, expected_name in bg_files:
        filepath = os.path.join(base_dir, filename)
        proc_name, bytes_data = process_single_file(filepath)
        const_name = proc_name[0].upper() + proc_name[1:] if proc_name else expected_name.capitalize()
        print(f'  File: {filename}, Procedure: {proc_name}, Bytes: {len(bytes_data)}, Const: {const_name}')
        content += format_pascal_const(const_name + 'Data', 'Byte', bytes_data)
        content += '\n\n'
    write_output(os.path.join(out_dir, 'backgrounds.inc'), content)
    print()

    print('=== Done ===')


if __name__ == '__main__':
    main()
