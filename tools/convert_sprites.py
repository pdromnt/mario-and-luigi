#!/usr/bin/env python3
"""
convert_sprites.py
------------------
Scans the MARIOSRC root directory for binary sprite files (.000, .001, .002, etc.)
and converts each one into a Free Pascal typed-constant include file (.inc) placed
in sdl2_port/sprites/.

Binary format of each .NNN file:
    byte 0  = width
    byte 1  = height
    bytes 2 .. 2+width*height-1 = raw pixel data

Output .inc format example (COIN.000 -> COIN.inc):
    const
      Coin000_W = 20;
      Coin000_H = 14;
      Coin000: array[0..279] of Byte = (
        $00, $00, $00, ...    { 16 values per line }
      );

Naming rules:
    - The constant name is built from the base filename (without the dot) plus the
      numeric extension digits.  The first letter is uppercase, the rest lowercase.
    - Examples:  COIN.000  -> Coin000
                 CHIBIBO.001 -> Chibibo001
                 F.000 -> F000
"""

import os
import sys
import re
import glob


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SRC_DIR = r"C:\Users\pedro\Desktop\MARIOSRC"
OUT_DIR = os.path.join(SRC_DIR, "sdl2_port", "sprites")
VALUES_PER_LINE = 16


def make_const_name(basename: str, ext_digits: str) -> str:
    """
    Build the Pascal constant name from the file's base name and numeric
    extension.  First letter uppercase, rest lowercase, digits appended.
    E.g. COIN + 000 -> Coin000,  F + 000 -> F000,  CHIBIBO + 001 -> Chibibo001
    """
    if len(basename) == 0:
        return ext_digits
    if len(basename) == 1:
        return basename.upper() + ext_digits
    return basename[0].upper() + basename[1:].lower() + ext_digits


def convert_sprite(filepath: str, out_dir: str) -> dict:
    """
    Read a binary sprite file, produce a .inc Pascal include file.
    Returns a dict with metadata for the manifest, or None on error.
    """
    filename = os.path.basename(filepath)
    basename_no_ext, dot_ext = os.path.splitext(filename)
    ext_digits = dot_ext.lstrip(".")          # e.g. "000", "001"

    # Read entire file
    with open(filepath, "rb") as f:
        data = f.read()

    if len(data) < 2:
        print(f"  WARNING: {filename} is too small ({len(data)} bytes), skipping.")
        return None

    width = data[0]
    height = data[1]
    pixel_count = width * height
    expected_size = 2 + pixel_count

    if len(data) < expected_size:
        print(f"  WARNING: {filename} claims {width}x{height} ({pixel_count} px) "
              f"but file is only {len(data)} bytes (need {expected_size}). Skipping.")
        return None

    pixels = data[2:2 + pixel_count]

    # Build constant name
    const_name = make_const_name(basename_no_ext, ext_digits)

    # Build output .inc filename  (e.g. COIN.inc, CHIBIBO.inc)
    # We use the ORIGINAL base name (uppercase) for the filename,
    # plus the numeric ext, so COIN.000 -> COIN000.inc,
    # but wait -- the spec says "base name with .inc extension"
    # e.g. COIN.000 -> COIN.inc.  For multi-digit suffixes like .001
    # they would collide.  Let's include the digits in the filename
    # to avoid collisions: COIN000.inc, CHIBIBO001.inc, etc.
    out_filename = f"{basename_no_ext}{ext_digits}.inc"
    out_path = os.path.join(out_dir, out_filename)

    # Format the pixel data as hex bytes, 16 per line
    lines = []
    for i in range(0, len(pixels), VALUES_PER_LINE):
        chunk = pixels[i:i + VALUES_PER_LINE]
        hex_vals = ", ".join(f"${b:02X}" for b in chunk)
        # Add comma after line unless it's the last chunk AND last line
        if i + VALUES_PER_LINE < len(pixels):
            hex_vals += ","
        lines.append(f"    {hex_vals}")

    array_body = "\n".join(lines)

    inc_content = (
        f"const\n"
        f"  {const_name}_W = {width};\n"
        f"  {const_name}_H = {height};\n"
        f"  {const_name}: array[0..{pixel_count - 1}] of Byte = (\n"
        f"{array_body}\n"
        f"  );\n"
    )

    with open(out_path, "w", newline="\r\n") as f:
        f.write(inc_content)

    return {
        "src_file": filename,
        "out_file": out_filename,
        "const_name": const_name,
        "width": width,
        "height": height,
        "pixel_count": pixel_count,
    }


def main():
    # Ensure output directory exists
    os.makedirs(OUT_DIR, exist_ok=True)

    # Collect all sprite files: anything matching *.NNN where NNN are digits
    pattern = re.compile(r"^\.\d{3}$")
    sprite_files = []
    for entry in os.listdir(SRC_DIR):
        full = os.path.join(SRC_DIR, entry)
        if not os.path.isfile(full):
            continue
        _, ext = os.path.splitext(entry)
        if pattern.match(ext):
            sprite_files.append(full)

    sprite_files.sort(key=lambda p: os.path.basename(p).upper())

    if not sprite_files:
        print("No sprite files found.")
        sys.exit(1)

    print(f"Found {len(sprite_files)} sprite file(s) in {SRC_DIR}")
    print(f"Output directory: {OUT_DIR}\n")

    manifest_entries = []
    converted = 0
    skipped = 0

    for fpath in sprite_files:
        fname = os.path.basename(fpath)
        info = convert_sprite(fpath, OUT_DIR)
        if info is None:
            skipped += 1
            continue
        converted += 1
        manifest_entries.append(info)
        print(f"  [{converted:3d}] {info['src_file']:20s} -> {info['out_file']:20s}  "
              f"({info['const_name']}, {info['width']}x{info['height']})")

    # Write manifest
    manifest_path = os.path.join(OUT_DIR, "sprites_manifest.txt")
    with open(manifest_path, "w", newline="\r\n") as mf:
        mf.write(f"Sprite Conversion Manifest\n")
        mf.write(f"==========================\n")
        mf.write(f"Source directory : {SRC_DIR}\n")
        mf.write(f"Output directory : {OUT_DIR}\n")
        mf.write(f"Total converted : {converted}\n")
        mf.write(f"Total skipped   : {skipped}\n")
        mf.write(f"\n")
        mf.write(f"{'Source File':<20s} {'Inc File':<20s} {'Constant':<20s} {'W':>4s} {'H':>4s} {'Pixels':>8s}\n")
        mf.write(f"{'-'*20} {'-'*20} {'-'*20} {'-'*4} {'-'*4} {'-'*8}\n")
        for e in manifest_entries:
            mf.write(f"{e['src_file']:<20s} {e['out_file']:<20s} {e['const_name']:<20s} "
                      f"{e['width']:>4d} {e['height']:>4d} {e['pixel_count']:>8d}\n")

    print(f"\nDone. Converted {converted} sprites, skipped {skipped}.")
    print(f"Manifest written to: {manifest_path}")


if __name__ == "__main__":
    main()
