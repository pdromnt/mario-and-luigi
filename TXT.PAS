unit Txt;

  {$R-}

interface

  uses
    VGA256,
    Buffers,
    AssetPaths;

  const
    Normal      = $00;
    Bold        = $01;
    Shadow      = $02;

  procedure LoadFontData;
  procedure SetFont (i: Integer; Style: Word);
  function Letter (i: Integer): Pointer;
  function TextWidth (S: String): Integer;
  procedure WriteText (X, Y: Integer; S: String; Attr: Byte);
  function CenterX (S: String): Integer;
  procedure CenterText (Y: Integer; S: String; Attr: Byte);

implementation

  var
    SwissFontData: array[0..4555] of Byte;
    Font8x8Data: array[0..1293] of Byte;

  procedure LoadFontData;
  var
    F: File;
    procedure LoadRaw(const Path: string; var Dest; Size: Integer);
    begin
      Assign(F, Path);
      {$I-} Reset(F, 1); {$I+}
      if IOResult = 0 then
      begin
        BlockRead(F, Dest, Size);
        Close(F);
      end;
    end;
  begin
    LoadRaw(AssetPaths.FontPath('swiss.font'), SwissFontData, SizeOf(SwissFontData));
    LoadRaw(AssetPaths.FontPath('font8x8.font'), Font8x8Data, SizeOf(Font8x8Data));
  end;

  const
    bShadow: Boolean = FALSE;
    bBold: Boolean = FALSE;

  var
    FontData: PByte;     { Points to current font data array }
    Base: Byte;          { Character code base (0 for Font8x8, 32 for Swiss) }
    NumGlyphs: Integer;  { Number of glyphs in current font }

  procedure SetFont (i: Integer; Style: Word);
  begin
    case i of
      0: begin
           FontData := @Font8x8Data;
           Base := 0;    { Font8x8 covers chars 0-127 }
           NumGlyphs := 128;
         end;
      1: begin
           FontData := @SwissFontData;
           Base := 32;   { SwissFont covers chars 32-128+ }
           NumGlyphs := 98;
         end;
    end;
    bBold := Style and Bold = Bold;
    bShadow := Style and Shadow = Shadow;
  end;

  function GetGlyphPtr(CharCode: Integer): PByte;
  { Look up glyph data pointer from the offset table in font data }
  var
    Idx: Integer;
    Offset: Word;
  begin
    Idx := CharCode - Base;
    if (Idx < 0) or (Idx >= NumGlyphs) then
      Idx := 0;  { Default to first glyph (space) }

    { Read 16-bit LE offset from table }
    Offset := FontData[Idx * 2] + FontData[Idx * 2 + 1] * 256;

    { Offset is relative to start of font data array }
    GetGlyphPtr := @FontData[Offset];
  end;

  function Letter (i: Integer): Pointer;
  begin
    Letter := GetGlyphPtr(i);
  end;

  function TextWidth (S: String): Integer;
  var
    Width: Integer;
    i: Byte;
    GlyphP: PByte;
  begin
    Width := 0;
    for i := 1 to Length (S) do
    begin
      GlyphP := GetGlyphPtr(Ord(S[i]));
      Inc(Width, GlyphP[0]);  { First byte is glyph width }
      Inc(Width, Byte(bBold) + Byte(bShadow));
    end;
    TextWidth := Width;
  end;

  procedure WriteText (X, Y: Integer; S: String; Attr: Byte);
  var
    i: Byte;
    C: Char;
  begin
    i := 1;
    repeat
      C := S [i];
      if bShadow then
        DrawBitmap (X + 1, Y + 1, Letter (Ord (C))^, 16);
      if bBold then
      begin
        if bShadow then
          DrawBitmap (X, Y + 1, Letter (Ord (C))^, 16);
        DrawBitmap (X - 1, Y, Letter (Ord (C))^, Attr);
      end;
      DrawBitmap (X, Y, Letter (Ord (C))^, Attr);
      inc (X, TextWidth (C));
      Inc (i);
    until i > Length (S);
  end;

  function CenterX (S: String): Integer;
  begin
    CenterX := XView + (SCREEN_WIDTH - TextWidth (S)) shr 1;
  end;

  procedure CenterText (Y: Integer; S: String; Attr: Byte);
  begin
    WriteText (CenterX (S), Y, S, Attr);
  end;

begin
  SetFont (0, Normal);
end.
