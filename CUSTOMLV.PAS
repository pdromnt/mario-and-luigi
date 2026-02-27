unit CustomLv;
{ Custom Level Loader -- Game Side
  Loads JSON level files created by the editor and prepares them
  for PlayWorld.  Supports both v1 (flat) and v2 (sublevels array) formats. }

{$MODE OBJFPC}{$H-}  { ObjFPC for SysUtils, H- for ShortString default }

interface

uses
  Buffers;

const
  MAX_CUSTOM_LEVELS = 20;

type
  TCustomLevelInfo = record
    FileName: string[80];
    LevelName: string[40];
  end;

var
  CustomLevels: array[1..MAX_CUSTOM_LEVELS] of TCustomLevelInfo;
  NumCustomLevels: Integer;

  { Map and options for PlayWorld -- sub-level A and B }
  CustomMapA: MapBuffer;
  CustomOptA: WorldOptions;
  CustomMusicA: ShortString;
  CustomMapB: MapBuffer;
  CustomOptB: WorldOptions;
  CustomMusicB: ShortString;

procedure ScanCustomLevels;
function LoadCustomLevel(Index: Integer): Boolean;
function LoadCustomLevelByPath(const Path: ShortString): Boolean;

implementation

uses
  SysUtils;

{ ----- Simple JSON Helpers ----- }

type
  PCharBuf = ^TCharBuf;
  TCharBuf = array[0..1048575] of Char;  { 1 MB max }

{ Skip whitespace }
function SkipWS(Buf: PCharBuf; Pos, Len: LongInt): LongInt;
begin
  while (Pos < Len) and (Buf^[Pos] in [' ', #9, #10, #13]) do
    Inc(Pos);
  SkipWS := Pos;
end;

{ Find a JSON key in the buffer within [StartPos..EndPos).
  Returns position after the colon, or -1 if not found. }
function FindKeyInRange(Buf: PCharBuf; const Key: ShortString;
  StartPos, EndPos: LongInt): LongInt;
var
  P, KLen, i: LongInt;
  Match: Boolean;
begin
  FindKeyInRange := -1;
  KLen := Length(Key);
  P := StartPos;
  while P < EndPos - KLen - 2 do
  begin
    if Buf^[P] = '"' then
    begin
      Match := True;
      for i := 1 to KLen do
        if (P + i >= EndPos) or (Buf^[P + i] <> Key[i]) then
        begin
          Match := False;
          Break;
        end;
      if Match and (P + KLen + 1 < EndPos) and (Buf^[P + KLen + 1] = '"') then
      begin
        P := P + KLen + 2;
        P := SkipWS(Buf, P, EndPos);
        if (P < EndPos) and (Buf^[P] = ':') then
        begin
          FindKeyInRange := P + 1;
          Exit;
        end;
      end;
    end;
    Inc(P);
  end;
end;

{ Find a JSON key searching from StartPos to end of buffer }
function FindKey(Buf: PCharBuf; Len: LongInt; const Key: ShortString; StartPos: LongInt): LongInt;
begin
  FindKey := FindKeyInRange(Buf, Key, StartPos, Len);
end;

{ Read an integer value from buffer at Pos (bounded by Len) }
function ReadInt(Buf: PCharBuf; Pos, Len: LongInt; var Value: Integer): LongInt;
var
  S: string[20];
  Code: Integer;
  Neg: Boolean;
begin
  Pos := SkipWS(Buf, Pos, Len);
  S := '';
  Neg := False;
  if (Pos < Len) and (Buf^[Pos] = '-') then
  begin
    Neg := True;
    Inc(Pos);
  end;
  while (Pos < Len) and (Buf^[Pos] in ['0'..'9']) and (Length(S) < 10) do
  begin
    S := S + Buf^[Pos];
    Inc(Pos);
  end;
  Val(S, Value, Code);
  if Code <> 0 then Value := 0;
  if Neg then Value := -Value;
  ReadInt := Pos;
end;

{ Read a JSON string value (between quotes) into a ShortString. }
function ReadStr(Buf: PCharBuf; Pos, Len: LongInt; var Value: ShortString): LongInt;
begin
  Value := '';
  Pos := SkipWS(Buf, Pos, Len);
  if (Pos >= Len) or (Buf^[Pos] <> '"') then
  begin
    ReadStr := Pos;
    Exit;
  end;
  Inc(Pos);
  while (Pos < Len) and (Buf^[Pos] <> '"') and (Length(Value) < 255) do
  begin
    if (Buf^[Pos] = '\') and (Pos + 1 < Len) then
    begin
      Inc(Pos);
      Value := Value + Buf^[Pos];
    end
    else
      Value := Value + Buf^[Pos];
    Inc(Pos);
  end;
  if (Pos < Len) and (Buf^[Pos] = '"') then
    Inc(Pos);
  ReadStr := Pos;
end;

{ Get a JSON key's integer value (unbounded search from start) }
function GetInt(Buf: PCharBuf; Len: LongInt; const Key: ShortString; Default: Integer): Integer;
var
  P: LongInt;
  V: Integer;
begin
  P := FindKey(Buf, Len, Key, 0);
  if P < 0 then
  begin
    GetInt := Default;
    Exit;
  end;
  ReadInt(Buf, P, Len, V);
  GetInt := V;
end;

{ Get a JSON key's integer value within a bounded range }
function GetIntInRange(Buf: PCharBuf; const Key: ShortString;
  StartPos, EndPos: LongInt; Default: Integer): Integer;
var
  P: LongInt;
  V: Integer;
begin
  P := FindKeyInRange(Buf, Key, StartPos, EndPos);
  if P < 0 then
  begin
    GetIntInRange := Default;
    Exit;
  end;
  ReadInt(Buf, P, EndPos, V);
  GetIntInRange := V;
end;

{ Convert 2 hex chars to byte }
function HexToByte(C1, C2: Char): Byte;
  function HexVal(C: Char): Byte;
  begin
    case C of
      '0'..'9': HexVal := Ord(C) - Ord('0');
      'A'..'F': HexVal := Ord(C) - Ord('A') + 10;
      'a'..'f': HexVal := Ord(C) - Ord('a') + 10;
    else
      HexVal := 0;
    end;
  end;
begin
  HexToByte := HexVal(C1) * 16 + HexVal(C2);
end;

{ Decode a tile row directly from buffer into MapBuffer.
  Starts at Pos (should point to opening quote), returns position after closing quote.
  MapRow is 1-based (1..NV). }
function DecodeTileRowFromBuf(Buf: PCharBuf; Pos, Len: LongInt;
  var Map: MapBuffer; MapRow, XSize: Integer): LongInt;
var
  Col: Integer;
begin
  Col := 1;
  Pos := SkipWS(Buf, Pos, Len);
  if (Pos >= Len) or (Buf^[Pos] <> '"') then
  begin
    DecodeTileRowFromBuf := Pos;
    Exit;
  end;
  Inc(Pos); { skip opening quote }
  while (Pos < Len) and (Buf^[Pos] <> '"') and (Col <= XSize) do
  begin
    if (Buf^[Pos] = '\') and (Pos + 1 < Len) then
    begin
      Inc(Pos);
      Map[Col, MapRow] := Buf^[Pos];
      Inc(Pos);
    end
    else if (Buf^[Pos] = '$') and (Pos + 2 < Len) then
    begin
      Map[Col, MapRow] := Chr(HexToByte(Buf^[Pos+1], Buf^[Pos+2]));
      Inc(Pos, 3);
    end
    else
    begin
      Map[Col, MapRow] := Buf^[Pos];
      Inc(Pos);
    end;
    Inc(Col);
  end;
  { Fill remaining columns with spaces }
  while Col <= XSize do
  begin
    Map[Col, MapRow] := ' ';
    Inc(Col);
  end;
  { Skip to closing quote }
  while (Pos < Len) and (Buf^[Pos] <> '"') do
    Inc(Pos);
  if (Pos < Len) and (Buf^[Pos] = '"') then
    Inc(Pos);
  DecodeTileRowFromBuf := Pos;
end;

{ Find the end of a JSON object starting at Pos (should point to '{').
  Returns position after the closing '}', or Len if not found. }
function FindObjEnd(Buf: PCharBuf; Pos, Len: LongInt): LongInt;
var
  Depth: Integer;
  InStr: Boolean;
begin
  Depth := 0;
  InStr := False;
  while Pos < Len do
  begin
    if InStr then
    begin
      if (Buf^[Pos] = '\') and (Pos + 1 < Len) then
        Inc(Pos)  { skip escaped char }
      else if Buf^[Pos] = '"' then
        InStr := False;
    end
    else
    begin
      case Buf^[Pos] of
        '"': InStr := True;
        '{', '[': Inc(Depth);
        '}', ']':
          begin
            Dec(Depth);
            if Depth <= 0 then
            begin
              FindObjEnd := Pos + 1;
              Exit;
            end;
          end;
      end;
    end;
    Inc(Pos);
  end;
  FindObjEnd := Len;
end;

{ Get a JSON key's string value within a bounded range }
function GetStrInRange(Buf: PCharBuf; const Key: ShortString;
  StartPos, EndPos: LongInt; const Default: ShortString): ShortString;
var
  P: LongInt;
  V: ShortString;
begin
  P := FindKeyInRange(Buf, Key, StartPos, EndPos);
  if P < 0 then
  begin
    GetStrInRange := Default;
    Exit;
  end;
  ReadStr(Buf, P, EndPos, V);
  GetStrInRange := V;
end;

{ Parse a single sub-level's data from a bounded JSON object region
  [ObjStart..ObjEnd) into the given Map and Opt. }
procedure ParseSubLevel(Buf: PCharBuf; ObjStart, ObjEnd: LongInt;
  var Map: MapBuffer; var Opt: WorldOptions; var MusicStr: ShortString);
var
  XSz, Row: Integer;
  P: LongInt;
begin
  with Opt do
  begin
    Design := GetIntInRange(Buf, 'design', ObjStart, ObjEnd, 1);
    SkyType := GetIntInRange(Buf, 'skyType', ObjStart, ObjEnd, 0);
    WallType1 := GetIntInRange(Buf, 'wallType1', ObjStart, ObjEnd, 0);
    WallType2 := GetIntInRange(Buf, 'wallType2', ObjStart, ObjEnd, 0);
    WallType3 := GetIntInRange(Buf, 'wallType3', ObjStart, ObjEnd, 0);
    PipeColor := GetIntInRange(Buf, 'pipeColor', ObjStart, ObjEnd, 0);
    GroundColor1 := GetIntInRange(Buf, 'groundColor1', ObjStart, ObjEnd, 0);
    GroundColor2 := GetIntInRange(Buf, 'groundColor2', ObjStart, ObjEnd, 0);
    Horizon := GetIntInRange(Buf, 'horizon', ObjStart, ObjEnd, 6);
    BackGrType := GetIntInRange(Buf, 'backGrType', ObjStart, ObjEnd, 1);
    BackGrColor1 := GetIntInRange(Buf, 'backGrColor1', ObjStart, ObjEnd, 0);
    BackGrColor2 := GetIntInRange(Buf, 'backGrColor2', ObjStart, ObjEnd, 0);
    Stars := GetIntInRange(Buf, 'stars', ObjStart, ObjEnd, 0);
    Clouds := GetIntInRange(Buf, 'clouds', ObjStart, ObjEnd, 3);
    C2r := GetIntInRange(Buf, 'c2r', ObjStart, ObjEnd, 20);
    C2g := GetIntInRange(Buf, 'c2g', ObjStart, ObjEnd, 30);
    C2b := GetIntInRange(Buf, 'c2b', ObjStart, ObjEnd, 63);
    C3r := GetIntInRange(Buf, 'c3r', ObjStart, ObjEnd, 40);
    C3g := GetIntInRange(Buf, 'c3g', ObjStart, ObjEnd, 50);
    C3b := GetIntInRange(Buf, 'c3b', ObjStart, ObjEnd, 60);
    BrickColor := GetIntInRange(Buf, 'brickColor', ObjStart, ObjEnd, 0);
    WoodColor := GetIntInRange(Buf, 'woodColor', ObjStart, ObjEnd, 0);
    XBlockColor := GetIntInRange(Buf, 'xBlockColor', ObjStart, ObjEnd, 0);
    BuildWall := GetIntInRange(Buf, 'buildWall', ObjStart, ObjEnd, 1) <> 0;
    InitX := GetIntInRange(Buf, 'startX', ObjStart, ObjEnd, 2);
    InitY := GetIntInRange(Buf, 'startY', ObjStart, ObjEnd, 10);
  end;

  MusicStr := GetStrInRange(Buf, 'musicTrack', ObjStart, ObjEnd, '');

  XSz := GetIntInRange(Buf, 'width', ObjStart, ObjEnd, 236);
  if (XSz < 1) or (XSz > MaxWorldSize) then XSz := 236;
  Opt.XSize := XSz;

  FillChar(Map, SizeOf(Map), ' ');

  { Find and parse tiles array within this sub-level object }
  P := FindKeyInRange(Buf, 'tiles', ObjStart, ObjEnd);
  if P >= 0 then
  begin
    P := SkipWS(Buf, P, ObjEnd);
    if (P < ObjEnd) and (Buf^[P] = '[') then
    begin
      Inc(P);
      for Row := 1 to NV do
      begin
        P := SkipWS(Buf, P, ObjEnd);
        if P >= ObjEnd then Break;
        P := DecodeTileRowFromBuf(Buf, P, ObjEnd, Map, Row, XSz);
        P := SkipWS(Buf, P, ObjEnd);
        if (P < ObjEnd) and (Buf^[P] = ',') then Inc(P);
      end;
    end;
  end;

  { Set end-of-level terminator }
  if XSz < MaxWorldSize then
    Map[XSz + 1, 1] := #0;
end;

{ Quick-extract level name from a JSON file (reads just the "name" field) }
function ExtractLevelName(const Path: ShortString): ShortString;
var
  F: File;
  Buf: array[0..1023] of Char;
  BytesRead: LongInt;
  P: LongInt;
  S: ShortString;
begin
  ExtractLevelName := '';
  Assign(F, Path);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then Exit;

  { Read first 1024 bytes -- enough to find the name field }
  BlockRead(F, Buf, SizeOf(Buf), BytesRead);
  Close(F);

  P := FindKey(@Buf, BytesRead, 'name', 0);
  if P < 0 then
  begin
    ExtractLevelName := '(unnamed)';
    Exit;
  end;
  ReadStr(@Buf, P, BytesRead, S);
  if S = '' then S := '(unnamed)';
  ExtractLevelName := S;
end;

{ ----- Internal: Load from buffer ----- }

{ Load a JSON level from an already-read buffer.
  Supports v1 (flat) and v2 (sublevels array) formats. }
function LoadFromBuffer(Buf: PCharBuf; BufLen: LongInt): Boolean;
var
  JSONVer: Integer;
  P, ObjStart, ObjEnd: LongInt;
  FoundSubs: Integer;
begin
  LoadFromBuffer := False;

  JSONVer := GetInt(Buf, BufLen, 'version', 1);

  { Check for v2 format with sublevels array }
  if JSONVer >= 2 then
  begin
    P := FindKey(Buf, BufLen, 'sublevels', 0);
    if P >= 0 then
    begin
      P := SkipWS(Buf, P, BufLen);
      if (P < BufLen) and (Buf^[P] = '[') then
      begin
        Inc(P); { skip '[' }
        FoundSubs := 0;

        { Parse sub-level A (first element) }
        P := SkipWS(Buf, P, BufLen);
        if (P < BufLen) and (Buf^[P] = '{') then
        begin
          ObjStart := P;
          ObjEnd := FindObjEnd(Buf, P, BufLen);
          ParseSubLevel(Buf, ObjStart, ObjEnd, CustomMapA, CustomOptA, CustomMusicA);
          FoundSubs := 1;
          P := ObjEnd;

          { Skip comma between elements }
          P := SkipWS(Buf, P, BufLen);
          if (P < BufLen) and (Buf^[P] = ',') then Inc(P);

          { Parse sub-level B (second element, if present) }
          P := SkipWS(Buf, P, BufLen);
          if (P < BufLen) and (Buf^[P] = '{') then
          begin
            ObjStart := P;
            ObjEnd := FindObjEnd(Buf, P, BufLen);
            ParseSubLevel(Buf, ObjStart, ObjEnd, CustomMapB, CustomOptB, CustomMusicB);
            FoundSubs := 2;
          end;
        end;

        if FoundSubs >= 1 then
        begin
          { If only one sub-level, copy A to B }
          if FoundSubs = 1 then
          begin
            CustomMapB := CustomMapA;
            CustomOptB := CustomOptA;
            CustomMusicB := CustomMusicA;
          end;
          LoadFromBuffer := True;
          Exit;
        end;
      end;
    end;
  end;

  { v1 format or fallback: flat keys, single sub-level }
  ParseSubLevel(Buf, 0, BufLen, CustomMapA, CustomOptA, CustomMusicA);
  CustomMapB := CustomMapA;
  CustomOptB := CustomOptA;
  CustomMusicB := CustomMusicA;
  LoadFromBuffer := True;
end;

{ ----- Public Interface ----- }

procedure ScanCustomLevels;
var
  SR: TSearchRec;
  Dir: ShortString;
begin
  NumCustomLevels := 0;
  Dir := 'levels' + DirectorySeparator;

  if FindFirst(Dir + '*.json', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        Inc(NumCustomLevels);
        CustomLevels[NumCustomLevels].FileName := Dir + SR.Name;
        CustomLevels[NumCustomLevels].LevelName := ExtractLevelName(Dir + SR.Name);
        if NumCustomLevels >= MAX_CUSTOM_LEVELS then Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

{ Read a file into a heap buffer. Returns nil on failure. Sets BufLen. }
function ReadFileToBuffer(const Path: ShortString; var BufLen: LongInt): PCharBuf;
var
  F: File;
  Buf: PCharBuf;
  BytesRead: LongInt;
begin
  ReadFileToBuffer := nil;
  BufLen := 0;

  Assign(F, Path);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then Exit;

  BufLen := System.FileSize(F);
  if (BufLen < 10) or (BufLen > 1024 * 1024) then
  begin
    Close(F);
    BufLen := 0;
    Exit;
  end;

  GetMem(Buf, BufLen);
  BlockRead(F, Buf^, BufLen, BytesRead);
  Close(F);

  if BytesRead <> BufLen then
  begin
    FreeMem(Buf, BufLen);
    BufLen := 0;
    Exit;
  end;

  ReadFileToBuffer := Buf;
end;

function LoadCustomLevel(Index: Integer): Boolean;
var
  Buf: PCharBuf;
  BufLen: LongInt;
begin
  LoadCustomLevel := False;
  if (Index < 1) or (Index > NumCustomLevels) then Exit;

  Buf := ReadFileToBuffer(CustomLevels[Index].FileName, BufLen);
  if Buf = nil then Exit;

  LoadCustomLevel := LoadFromBuffer(Buf, BufLen);
  FreeMem(Buf, BufLen);
end;

function LoadCustomLevelByPath(const Path: ShortString): Boolean;
var
  Buf: PCharBuf;
  BufLen: LongInt;
begin
  LoadCustomLevelByPath := False;

  Buf := ReadFileToBuffer(Path, BufLen);
  if Buf = nil then Exit;

  LoadCustomLevelByPath := LoadFromBuffer(Buf, BufLen);
  FreeMem(Buf, BufLen);
end;

begin
  NumCustomLevels := 0;
end.
