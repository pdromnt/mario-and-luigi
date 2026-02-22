#!/usr/bin/env python3
"""
extract_demokeys.py - Extract demo key data from DEMOKEYS.OBJ (OMF 16-bit object file)

Reads the OMF object file, extracts LEDATA records from the CODE segment,
and produces a Pascal include file with the raw bytes as a const array.

OMF record format:
  Each record: type_byte + length_word(LE) + data_bytes + checksum_byte
  LEDATA (0xA0) payload: segment_index(1 byte) + offset(2 bytes LE) + data + checksum

The data consists of 9 KeySeq arrays (each KeySeq = array[0..99] of Word = 200 bytes),
totaling 9 * 200 = 1800 bytes.
"""

import struct
import sys
import os

# OMF record type constants
THEADR  = 0x80  # Translator header
LNAMES  = 0x96  # List of names
SEGDEF  = 0x98  # Segment definition
EXTDEF  = 0x9C  # External definition
PUBDEF  = 0x90  # Public definition
LEDATA  = 0xA0  # Logical enumerated data
MODEND  = 0x8A  # Module end

OMF_TYPE_NAMES = {
    THEADR: "THEADR",
    LNAMES: "LNAMES",
    SEGDEF: "SEGDEF",
    EXTDEF: "EXTDEF",
    PUBDEF: "PUBDEF",
    LEDATA: "LEDATA",
    MODEND: "MODEND",
}

INPUT_FILE  = os.path.join(os.path.dirname(os.path.dirname(__file__)), "DEMOKEYS.OBJ")
OUTPUT_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "sdl2_port", "data", "demokeys.inc")

EXPECTED_SIZE = 9 * 200  # 9 KeySeq arrays, each 200 bytes


def parse_omf_records(data: bytes) -> list:
    """Parse all OMF records from raw file data."""
    records = []
    pos = 0
    while pos < len(data):
        if pos + 3 > len(data):
            print(f"WARNING: Truncated record header at offset 0x{pos:04X}", file=sys.stderr)
            break

        rec_type = data[pos]
        rec_len = struct.unpack_from('<H', data, pos + 1)[0]

        if pos + 3 + rec_len > len(data):
            print(f"WARNING: Truncated record body at offset 0x{pos:04X}, "
                  f"type=0x{rec_type:02X}, declared length={rec_len}", file=sys.stderr)
            break

        # Record payload includes everything after the 3-byte header,
        # up to and including the checksum byte
        payload = data[pos + 3 : pos + 3 + rec_len]

        records.append({
            'offset': pos,
            'type': rec_type,
            'length': rec_len,
            'payload': payload,
        })

        type_name = OMF_TYPE_NAMES.get(rec_type, f"UNKNOWN(0x{rec_type:02X})")
        print(f"  Record at 0x{pos:04X}: {type_name} (0x{rec_type:02X}), length={rec_len}")

        pos += 3 + rec_len

    return records


def extract_ledata(records: list) -> bytes:
    """Extract and concatenate data from all LEDATA records, ordered by offset."""
    ledata_segments = []

    for rec in records:
        if rec['type'] != LEDATA:
            continue

        payload = rec['payload']
        # LEDATA payload: segment_index (1 byte) + data_offset (2 bytes LE) + data + checksum (1 byte)
        seg_index = payload[0]
        data_offset = struct.unpack_from('<H', payload, 1)[0]
        # Data is everything between the 3-byte header and the 1-byte checksum
        segment_data = payload[3:-1]

        print(f"  LEDATA: segment={seg_index}, offset=0x{data_offset:04X}, "
              f"data_size={len(segment_data)} bytes")

        ledata_segments.append((data_offset, segment_data))

    # Sort by offset to ensure correct ordering
    ledata_segments.sort(key=lambda x: x[0])

    # Concatenate all data portions
    result = bytearray()
    for offset, seg_data in ledata_segments:
        # Verify continuity
        if offset != len(result):
            print(f"  WARNING: Gap or overlap detected. Expected offset 0x{len(result):04X}, "
                  f"got 0x{offset:04X}", file=sys.stderr)
            # Pad if there is a gap
            if offset > len(result):
                result.extend(b'\x00' * (offset - len(result)))
        result.extend(seg_data)

    return bytes(result)


def generate_pascal_include(data: bytes, values_per_line: int = 16) -> str:
    """Generate Pascal include file content with byte array constant."""
    lines = []
    lines.append("{ Auto-generated from DEMOKEYS.OBJ by extract_demokeys.py }")
    lines.append("{ 9 KeySeq arrays, each array[0..99] of Word = 200 bytes, total 1800 bytes }")
    lines.append("")
    lines.append("const")
    lines.append(f"  DemoKeysData: array[0..{len(data) - 1}] of Byte = (")

    # Format data bytes, 16 per line
    for i in range(0, len(data), values_per_line):
        chunk = data[i:i + values_per_line]
        hex_values = ", ".join(f"${b:02X}" for b in chunk)

        # Add comma after each line except the last
        if i + values_per_line < len(data):
            hex_values += ","
        else:
            # Last line - no trailing comma
            pass

        lines.append(f"    {hex_values}")

    lines.append("  );")
    lines.append("")

    return "\n".join(lines)


def main():
    print(f"Reading OMF object file: {INPUT_FILE}")

    if not os.path.isfile(INPUT_FILE):
        print(f"ERROR: Input file not found: {INPUT_FILE}", file=sys.stderr)
        sys.exit(1)

    with open(INPUT_FILE, 'rb') as f:
        raw_data = f.read()

    print(f"File size: {len(raw_data)} bytes")
    print()

    # Parse all OMF records
    print("Parsing OMF records:")
    records = parse_omf_records(raw_data)
    print(f"  Total records: {len(records)}")
    print()

    # Extract LEDATA content
    print("Extracting LEDATA segments:")
    extracted = extract_ledata(records)
    print(f"  Total extracted data: {len(extracted)} bytes")
    print()

    # Validate size
    if len(extracted) != EXPECTED_SIZE:
        print(f"WARNING: Expected {EXPECTED_SIZE} bytes but extracted {len(extracted)} bytes",
              file=sys.stderr)
    else:
        print(f"Size matches expected {EXPECTED_SIZE} bytes (9 KeySeq * 200 bytes each)")

    # Show a summary of each KeySeq array
    print()
    print("KeySeq array summary (first 4 words of each):")
    for seq in range(9):
        base = seq * 200
        words = struct.unpack_from('<4H', extracted, base)
        print(f"  KeySeq[{seq}]: {words[0]:5d} {words[1]:5d} {words[2]:5d} {words[3]:5d} ...")

    # Generate output
    pascal_code = generate_pascal_include(extracted)

    # Ensure output directory exists
    output_dir = os.path.dirname(OUTPUT_FILE)
    os.makedirs(output_dir, exist_ok=True)

    with open(OUTPUT_FILE, 'w') as f:
        f.write(pascal_code)

    print()
    print(f"Output written to: {OUTPUT_FILE}")
    print(f"Array size: {len(extracted)} bytes ({len(extracted)} elements)")


if __name__ == '__main__':
    main()
