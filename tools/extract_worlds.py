#!/usr/bin/env python3
"""
Extract world/level data from WORLDS.PAS assembler blocks and convert
them to Pascal typed constants (byte arrays) for the SDL2 port.

Handles:
  - DB directives: decimal, hex ($xx), char literals (#nn), quoted strings,
    and arithmetic expressions using W=20 and H=14.
  - DW directives: same value types, emitted as 2-byte little-endian.
  - Pascal { } comments (including nested).
"""

import re
import os
import sys

# ---------------------------------------------------------------------------
# Constants used in assembler expressions
# ---------------------------------------------------------------------------
CONSTANTS = {"W": 20, "H": 14}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
INPUT_FILE = os.path.join(ROOT_DIR, "WORLDS.PAS")
OUTPUT_FILE = os.path.join(ROOT_DIR, "sdl2_port", "data", "worlds.inc")


def strip_pascal_comments(line):
    """Remove Pascal { ... } comments, handling nested braces."""
    result = []
    depth = 0
    in_string = False
    i = 0
    while i < len(line):
        ch = line[i]
        if in_string:
            result.append(ch)
            if ch == "'":
                # Check for escaped quote ('')
                if i + 1 < len(line) and line[i + 1] == "'":
                    result.append("'")
                    i += 2
                    continue
                in_string = False
        else:
            if ch == "'" and depth == 0:
                in_string = True
                result.append(ch)
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth = max(0, depth - 1)
            elif depth == 0:
                result.append(ch)
        i += 1
    return "".join(result)


def eval_expression(expr_str):
    """Evaluate a simple arithmetic expression that may contain W and H."""
    s = expr_str.strip()
    if not s:
        raise ValueError("Empty expression")

    # Replace known constants
    for name, value in CONSTANTS.items():
        s = re.sub(r'\b' + name + r'\b', str(value), s)

    # Handle hex ($xx)
    s = re.sub(r'\$([0-9A-Fa-f]+)', lambda m: str(int(m.group(1), 16)), s)

    # Handle Pascal char literal #nn
    s = re.sub(r'#(\d+)', lambda m: str(int(m.group(1))), s)

    # Safety check: only allow digits, operators, spaces, parens
    if not re.match(r'^[\d\s\+\-\*\/\(\)]+$', s):
        raise ValueError(f"Cannot evaluate expression: {expr_str!r} -> {s!r}")

    return int(eval(s))


def parse_value_token(token):
    """Parse a single value token and return its integer value."""
    token = token.strip()
    if not token:
        raise ValueError("Empty token")

    # Hex value $xx
    if token.startswith("$"):
        return int(token[1:], 16)

    # Char literal #nn
    if token.startswith("#"):
        return int(token[1:])

    # Decimal number
    if re.match(r'^\d+$', token):
        return int(token)

    # Expression (contains operators or constant names)
    return eval_expression(token)


def parse_asm_block(lines):
    """Parse the asm lines between 'asm' and 'end;' and return a list of bytes."""
    result_bytes = []

    for raw_line in lines:
        line = strip_pascal_comments(raw_line).strip()
        if not line:
            continue

        # Determine directive type (db or dw)
        upper = line.upper()
        if upper.startswith("DB"):
            directive = "db"
            rest = line[2:]
        elif upper.startswith("DW"):
            directive = "dw"
            rest = line[2:]
        else:
            continue

        # Tokenize the rest, respecting quoted strings
        tokens = tokenize_operands(rest)

        for tok in tokens:
            tok = tok.strip()
            if not tok:
                continue

            # Quoted string
            if tok.startswith("'") and tok.endswith("'"):
                s = tok[1:-1]
                # Handle escaped quotes
                s = s.replace("''", "'")
                for ch in s:
                    b = ord(ch) & 0xFF
                    if directive == "dw":
                        result_bytes.append(b)
                        result_bytes.append(0)
                    else:
                        result_bytes.append(b)
            else:
                val = parse_value_token(tok)
                if directive == "dw":
                    # Little-endian 16-bit
                    result_bytes.append(val & 0xFF)
                    result_bytes.append((val >> 8) & 0xFF)
                else:
                    result_bytes.append(val & 0xFF)

    return result_bytes


def tokenize_operands(rest):
    """Split the operand part of a DB/DW line into tokens, respecting quoted strings."""
    tokens = []
    current = []
    in_string = False
    i = 0
    while i < len(rest):
        ch = rest[i]
        if in_string:
            current.append(ch)
            if ch == "'":
                # Check for escaped quote
                if i + 1 < len(rest) and rest[i + 1] == "'":
                    current.append("'")
                    i += 2
                    continue
                in_string = False
        else:
            if ch == "'":
                in_string = True
                current.append(ch)
            elif ch == ",":
                tokens.append("".join(current))
                current = []
            else:
                current.append(ch)
        i += 1
    if current:
        tokens.append("".join(current))
    return tokens


def extract_procedures(source):
    """
    Extract all 'procedure XXX; assembler;' blocks from the source.
    Returns a dict mapping procedure name to list of asm body lines.
    """
    procedures = {}

    # Split into lines
    src_lines = source.split("\n")

    i = 0
    while i < len(src_lines):
        line = src_lines[i].strip()

        # Match: procedure XXX; assembler;
        m = re.match(r'procedure\s+(\w+)\s*;\s*assembler\s*;', line, re.IGNORECASE)
        if m:
            proc_name = m.group(1)
            # Find 'asm' keyword
            i += 1
            while i < len(src_lines):
                if src_lines[i].strip().lower() == "asm":
                    break
                i += 1
            i += 1  # skip 'asm' line

            # Collect lines until 'end;'
            body_lines = []
            while i < len(src_lines):
                stripped = src_lines[i].strip()
                if stripped.lower() == "end;" or stripped.lower().startswith("end;"):
                    break
                body_lines.append(stripped)
                i += 1

            procedures[proc_name] = body_lines

        i += 1

    return procedures


def format_bytes_as_pascal(name, data_bytes):
    """Format a byte array as a Pascal typed constant."""
    if not data_bytes:
        return f"  {name}_Data: array[0..0] of Byte = (0);\n"

    n = len(data_bytes)
    lines = []
    lines.append(f"  {name}_Data: array[0..{n - 1}] of Byte = (")

    # Format 16 bytes per line
    BYTES_PER_LINE = 16
    for start in range(0, n, BYTES_PER_LINE):
        chunk = data_bytes[start:start + BYTES_PER_LINE]
        hex_vals = ", ".join(f"${b:02X}" for b in chunk)
        if start + BYTES_PER_LINE >= n:
            lines.append(f"    {hex_vals}")
        else:
            lines.append(f"    {hex_vals},")

    lines.append("  );")
    return "\n".join(lines) + "\n"


def main():
    # Read source file - MUST use latin-1 (not cp1252!) because the source
    # contains raw binary bytes $80-$9F in assembler string literals (enemy
    # spawn codes etc).  CP1252 remaps those bytes to different Unicode
    # codepoints, corrupting the data.  Latin-1 maps every byte 1:1 to its
    # Unicode codepoint, so ord(ch) & 0xFF always roundtrips correctly.
    with open(INPUT_FILE, "r", encoding="latin-1") as f:
        source = f.read()

    procedures = extract_procedures(source)

    print(f"Found {len(procedures)} procedures:")
    for name in procedures:
        print(f"  {name}")

    # Define the order of procedures to extract
    proc_order = [
        "Intro_0", "Options_0",
        "Level_1a", "Options_1a", "Opt_1a", "Level_1b", "Options_1b",
        "Level_2a", "Options_2a", "Opt_2a", "Level_2b", "Options_2b",
        "Level_3a", "Options_3a", "Opt_3a", "Level_3b", "Options_3b",
        "Level_4a", "Options_4a", "Opt_4a", "Level_4b", "Options_4b",
        "Level_5a", "Options_5a", "Opt_5a", "Level_5b", "Options_5b",
        "Level_6a", "Options_6a", "Opt_6a", "Level_6b", "Options_6b",
    ]

    # Parse each procedure
    parsed = {}
    for name in proc_order:
        if name in procedures:
            try:
                data = parse_asm_block(procedures[name])
                parsed[name] = data
                print(f"  {name}: {len(data)} bytes")
            except Exception as e:
                print(f"  ERROR parsing {name}: {e}")
                parsed[name] = []
        else:
            print(f"  WARNING: {name} not found in source")

    # Generate output
    output_lines = []
    output_lines.append("{ Auto-generated from WORLDS.PAS by extract_worlds.py }")
    output_lines.append("{ Do not edit manually. }")
    output_lines.append("")
    output_lines.append("const")

    for name in proc_order:
        if name in parsed:
            output_lines.append(format_bytes_as_pascal(name, parsed[name]))

    output_text = "\n".join(output_lines)

    # Write output
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(output_text)

    print(f"\nOutput written to: {OUTPUT_FILE}")
    print(f"Total procedures: {len(parsed)}")
    total_bytes = sum(len(v) for v in parsed.values())
    print(f"Total bytes: {total_bytes}")


if __name__ == "__main__":
    main()
