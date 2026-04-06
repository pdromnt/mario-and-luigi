unit LevelFormat;

{ Canonical level file format: load/save JSON levels and manifest.
  Shared between game and editor. Replaces CustomLv.PAS and EdRender save/load.
  Supports v3 (single level), v2 (sublevels array), v1 (flat keys) formats. }

{$mode objfpc}{$H+}

interface

uses
  TileDefs;

type
  WorldOptions = record
    InitX, InitY: Word;
    SkyType, WallType1, WallType2, WallType3,
    PipeColor, GroundColor1, GroundColor2,
    Horizon, BackGrType, BackGrColor1, BackGrColor2,
    Stars, Clouds, Design: Byte;
    C2r, C2g, C2b, C3r, C3g, C3b,
    BrickColor, WoodColor, XBlockColor: Byte;
    BuildWall: Boolean;
    XSize: Word;
  end;

  { Map buffer: column-major tile grid [1..MaxWorldSize, 1..NV] }
  MapBuffer = array[1..MaxWorldSize, 1..NV] of Char;

  { World buffer: map with collision padding }
  WorldBuffer = array[-EX..MaxWorldSize - 1 + EX, -EY1..NV - 1 + EY2] of Char;
  WorldBufferPtr = ^WorldBuffer;

  { Turbo override: key-value pair for turbo-mode theme changes }
  TTurboOverride = record
    Key: string;
    Value: Integer;
  end;

  { A single level's data (one sub-level) }
  TLevelData = record
    Name: string;
    Creator: string;
    Description: string;
    MusicTrack: string;
    Options: WorldOptions;
    TurboOverrides: array of TTurboOverride;
    Width: Integer;
    Map: MapBuffer;
    HiddenRow: array[1..MaxWorldSize] of Char;
  end;

  TWorldManifestEntry = record
    Name: string;
    LevelAFile: string;
    LevelBFile: string;
    TurboOverrides: array of TTurboOverride;
  end;

  TManifest = record
    IntroFile: string;
    Worlds: array of TWorldManifestEntry;
  end;

{ Load a level from a JSON file }
function LoadLevelJSON(const FilePath: string; out Level: TLevelData): Boolean;

{ Save a level to a JSON file (v3 format) }
function SaveLevelJSON(const FilePath: string; const Level: TLevelData): Boolean;

{ Load the world manifest }
function LoadManifest(const FilePath: string; out Manifest: TManifest): Boolean;

{ Convert a MapBuffer into a WorldBuffer (same logic as game's ReadWorld) }
procedure MapToWorldBuffer(const Map: MapBuffer; W: WorldBufferPtr; var Opt: WorldOptions);

{ Apply turbo overrides to a WorldOptions }
procedure ApplyTurboOverrides(var Opt: WorldOptions; const Overrides: array of TTurboOverride);

implementation

uses
  SysUtils, Classes;

{ =====================================================================
  JSON PARSING HELPERS (adapted from CustomLv.PAS)
  ===================================================================== }

type
  PCharBuf = ^TCharBuf;
  TCharBuf = array[0..1048575] of Char;

function SkipWS(Buf: PCharBuf; Pos, Len: LongInt): LongInt;
begin
  while (Pos < Len) and (Buf^[Pos] in [' ', #9, #10, #13]) do
    Inc(Pos);
  Result := Pos;
end;

function FindKeyInRange(Buf: PCharBuf; const Key: string;
  StartPos, EndPos: LongInt): LongInt;
var
  P, KLen, i: LongInt;
  Match: Boolean;
begin
  Result := -1;
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
          Result := P + 1;
          Exit;
        end;
      end;
    end;
    Inc(P);
  end;
end;

function ReadIntFromBuf(Buf: PCharBuf; Pos, Len: LongInt; out Value: Integer): LongInt;
var
  S: string;
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
  Result := Pos;
end;

function ReadStrFromBuf(Buf: PCharBuf; Pos, Len: LongInt; out Value: string): LongInt;
begin
  Value := '';
  Pos := SkipWS(Buf, Pos, Len);
  if (Pos >= Len) or (Buf^[Pos] <> '"') then
  begin
    Result := Pos;
    Exit;
  end;
  Inc(Pos);
  while (Pos < Len) and (Buf^[Pos] <> '"') do
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
  Result := Pos;
end;

function GetIntInRange(Buf: PCharBuf; const Key: string;
  StartPos, EndPos: LongInt; Default: Integer): Integer;
var
  P: LongInt;
  V: Integer;
begin
  P := FindKeyInRange(Buf, Key, StartPos, EndPos);
  if P < 0 then
  begin
    Result := Default;
    Exit;
  end;
  ReadIntFromBuf(Buf, P, EndPos, V);
  Result := V;
end;

function GetStrInRange(Buf: PCharBuf; const Key: string;
  StartPos, EndPos: LongInt; const Default: string): string;
var
  P: LongInt;
  V: string;
begin
  P := FindKeyInRange(Buf, Key, StartPos, EndPos);
  if P < 0 then
  begin
    Result := Default;
    Exit;
  end;
  ReadStrFromBuf(Buf, P, EndPos, V);
  Result := V;
end;

function GetBoolInRange(Buf: PCharBuf; const Key: string;
  StartPos, EndPos: LongInt; Default: Boolean): Boolean;
var
  P: LongInt;
begin
  P := FindKeyInRange(Buf, Key, StartPos, EndPos);
  if P < 0 then
  begin
    Result := Default;
    Exit;
  end;
  P := SkipWS(Buf, P, EndPos);
  if (P < EndPos) and (Buf^[P] = 't') then
    Result := True
  else if (P < EndPos) and (Buf^[P] = 'f') then
    Result := False
  else
    Result := GetIntInRange(Buf, Key, StartPos, EndPos, Ord(Default)) <> 0;
end;

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
        Inc(Pos)
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
              Result := Pos + 1;
              Exit;
            end;
          end;
      end;
    end;
    Inc(Pos);
  end;
  Result := Len;
end;

function HexToByte(C1, C2: Char): Byte;
  function HexVal(C: Char): Byte;
  begin
    case C of
      '0'..'9': Result := Ord(C) - Ord('0');
      'A'..'F': Result := Ord(C) - Ord('A') + 10;
      'a'..'f': Result := Ord(C) - Ord('a') + 10;
    else
      Result := 0;
    end;
  end;
begin
  Result := HexVal(C1) * 16 + HexVal(C2);
end;

{ =====================================================================
  TILE ROW ENCODING/DECODING
  ===================================================================== }

function DecodeTileRowFromBuf(Buf: PCharBuf; Pos, Len: LongInt;
  var Map: MapBuffer; MapRow, XSize: Integer): LongInt;
var
  Col: Integer;
begin
  Col := 1;
  Pos := SkipWS(Buf, Pos, Len);
  if (Pos >= Len) or (Buf^[Pos] <> '"') then
  begin
    Result := Pos;
    Exit;
  end;
  Inc(Pos);
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
  while Col <= XSize do
  begin
    Map[Col, MapRow] := ' ';
    Inc(Col);
  end;
  while (Pos < Len) and (Buf^[Pos] <> '"') do
    Inc(Pos);
  if (Pos < Len) and (Buf^[Pos] = '"') then
    Inc(Pos);
  Result := Pos;
end;

function EncodeTileRow(const Map: MapBuffer; MapRow, XSize: Integer): string;
var
  Col: Integer;
  B: Byte;
  Ch: Char;
begin
  Result := '';
  for Col := 1 to XSize do
  begin
    Ch := Map[Col, MapRow];
    B := Ord(Ch);
    if (B >= 32) and (B <= 126) and (Ch <> '$') then
    begin
      if Ch = '\' then
        Result := Result + '\\'
      else if Ch = '"' then
        Result := Result + '\"'
      else
        Result := Result + Ch;
    end
    else
      Result := Result + '$' + IntToHex(B, 2);
  end;
end;

{ =====================================================================
  PARSE OPTIONS FROM JSON REGION
  ===================================================================== }

procedure ParseOptions(Buf: PCharBuf; S, E: LongInt; out Opt: WorldOptions);
begin
  FillChar(Opt, SizeOf(Opt), 0);
  with Opt do
  begin
    InitX := GetIntInRange(Buf, 'startX', S, E, 2);
    InitY := GetIntInRange(Buf, 'startY', S, E, 10);
    SkyType := GetIntInRange(Buf, 'skyType', S, E, 0);
    WallType1 := GetIntInRange(Buf, 'wallType1', S, E, 0);
    WallType2 := GetIntInRange(Buf, 'wallType2', S, E, 0);
    WallType3 := GetIntInRange(Buf, 'wallType3', S, E, 0);
    PipeColor := GetIntInRange(Buf, 'pipeColor', S, E, 0);
    GroundColor1 := GetIntInRange(Buf, 'groundColor1', S, E, 0);
    GroundColor2 := GetIntInRange(Buf, 'groundColor2', S, E, 0);
    Horizon := GetIntInRange(Buf, 'horizon', S, E, 6);
    BackGrType := GetIntInRange(Buf, 'backgrType', S, E, 1);
    BackGrColor1 := GetIntInRange(Buf, 'backgrColor1', S, E, 0);
    BackGrColor2 := GetIntInRange(Buf, 'backgrColor2', S, E, 0);
    Stars := GetIntInRange(Buf, 'stars', S, E, 0);
    Clouds := GetIntInRange(Buf, 'clouds', S, E, 3);
    Design := GetIntInRange(Buf, 'design', S, E, 1);
    C2r := GetIntInRange(Buf, 'c2r', S, E, 20);
    C2g := GetIntInRange(Buf, 'c2g', S, E, 30);
    C2b := GetIntInRange(Buf, 'c2b', S, E, 63);
    C3r := GetIntInRange(Buf, 'c3r', S, E, 40);
    C3g := GetIntInRange(Buf, 'c3g', S, E, 50);
    C3b := GetIntInRange(Buf, 'c3b', S, E, 60);
    BrickColor := GetIntInRange(Buf, 'brickColor', S, E, 0);
    WoodColor := GetIntInRange(Buf, 'woodColor', S, E, 0);
    XBlockColor := GetIntInRange(Buf, 'xblockColor', S, E, 0);
    BuildWall := GetBoolInRange(Buf, 'buildWall', S, E, True);
  end;
end;

{ =====================================================================
  PARSE SINGLE SUBLEVEL (v2/v3 compat)
  ===================================================================== }

procedure ParseSublevelRegion(Buf: PCharBuf; ObjStart, ObjEnd: LongInt;
  out Level: TLevelData);
var
  XSz, Row: Integer;
  P, OptStart, OptEnd: LongInt;
  TurboEnd: LongInt;
  TKey: string;
  TVal: Integer;
begin
  Level.Name := GetStrInRange(Buf, 'name', ObjStart, ObjEnd, '');
  if Level.Name = '' then
    Level.Name := GetStrInRange(Buf, 'levelName', ObjStart, ObjEnd, '');
  Level.Creator := GetStrInRange(Buf, 'creator', ObjStart, ObjEnd, '');
  Level.Description := GetStrInRange(Buf, 'description', ObjStart, ObjEnd, '');
  Level.MusicTrack := GetStrInRange(Buf, 'musicTrack', ObjStart, ObjEnd, '');

  { Parse options - v3 has nested "options" object, v2/v1 have flat keys }
  P := FindKeyInRange(Buf, 'options', ObjStart, ObjEnd);
  if P >= 0 then
  begin
    P := SkipWS(Buf, P, ObjEnd);
    if (P < ObjEnd) and (Buf^[P] = '{') then
    begin
      OptStart := P;
      OptEnd := FindObjEnd(Buf, P, ObjEnd);
      ParseOptions(Buf, OptStart, OptEnd, Level.Options);
    end
    else
      ParseOptions(Buf, ObjStart, ObjEnd, Level.Options);
  end
  else
    ParseOptions(Buf, ObjStart, ObjEnd, Level.Options);

  XSz := GetIntInRange(Buf, 'width', ObjStart, ObjEnd, 236);
  if (XSz < 1) or (XSz > MaxWorldSize) then XSz := 236;
  Level.Options.XSize := XSz;
  Level.Width := XSz;

  FillChar(Level.Map, SizeOf(Level.Map), ' ');
  FillChar(Level.HiddenRow, SizeOf(Level.HiddenRow), ' ');

  { Parse tiles array }
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
        P := DecodeTileRowFromBuf(Buf, P, ObjEnd, Level.Map, Row, XSz);
        P := SkipWS(Buf, P, ObjEnd);
        if (P < ObjEnd) and (Buf^[P] = ',') then Inc(P);
      end;
    end;
  end;

  { Parse turboOptions if present }
  SetLength(Level.TurboOverrides, 0);
  P := FindKeyInRange(Buf, 'turboOptions', ObjStart, ObjEnd);
  if P >= 0 then
  begin
    P := SkipWS(Buf, P, ObjEnd);
    if (P < ObjEnd) and (Buf^[P] = '{') then
    begin
      TurboEnd := FindObjEnd(Buf, P, ObjEnd);
      P := P + 1;
      while P < TurboEnd - 1 do
      begin
        P := SkipWS(Buf, P, TurboEnd);
        if (P >= TurboEnd) or (Buf^[P] <> '"') then Break;
        ReadStrFromBuf(Buf, P, TurboEnd, TKey);
        P := P + Length(TKey) + 2;
        P := SkipWS(Buf, P, TurboEnd);
        if (P < TurboEnd) and (Buf^[P] = ':') then Inc(P);
        ReadIntFromBuf(Buf, P, TurboEnd, TVal);
        P := SkipWS(Buf, P, TurboEnd);
        while (P < TurboEnd) and (Buf^[P] in ['0'..'9', '-']) do Inc(P);
        if (P < TurboEnd) and (Buf^[P] = ',') then Inc(P);

        SetLength(Level.TurboOverrides, Length(Level.TurboOverrides) + 1);
        Level.TurboOverrides[High(Level.TurboOverrides)].Key := TKey;
        Level.TurboOverrides[High(Level.TurboOverrides)].Value := TVal;
      end;
    end;
  end;

  { Set end-of-level terminator }
  if XSz < MaxWorldSize then
    Level.Map[XSz + 1, 1] := #0;
end;

{ =====================================================================
  PUBLIC: LOAD LEVEL JSON
  ===================================================================== }

function LoadLevelJSON(const FilePath: string; out Level: TLevelData): Boolean;
var
  F: TFileStream;
  Buf: PCharBuf;
  BufLen: LongInt;
  JSONVer: Integer;
  P, ObjStart, ObjEnd: LongInt;
begin
  Result := False;
  FillChar(Level, SizeOf(Level), 0);
  Level.Name := '';
  Level.Creator := '';
  Level.Description := '';
  Level.MusicTrack := '';

  if not FileExists(FilePath) then Exit;

  F := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    BufLen := F.Size;
    if (BufLen < 10) or (BufLen > 1024 * 1024) then Exit;
    GetMem(Buf, BufLen);
    try
      F.ReadBuffer(Buf^, BufLen);

      JSONVer := GetIntInRange(Buf, 'version', 0, BufLen, 1);

      if JSONVer >= 2 then
      begin
        { v2: check for sublevels array — use first sublevel }
        P := FindKeyInRange(Buf, 'sublevels', 0, BufLen);
        if P >= 0 then
        begin
          P := SkipWS(Buf, P, BufLen);
          if (P < BufLen) and (Buf^[P] = '[') then
          begin
            Inc(P);
            P := SkipWS(Buf, P, BufLen);
            if (P < BufLen) and (Buf^[P] = '{') then
            begin
              ObjStart := P;
              ObjEnd := FindObjEnd(Buf, P, BufLen);
              ParseSublevelRegion(Buf, ObjStart, ObjEnd, Level);
              Result := True;
              Exit;
            end;
          end;
        end;
      end;

      { v3 or v1: parse the whole file as one level }
      ParseSublevelRegion(Buf, 0, BufLen, Level);
      Result := True;
    finally
      FreeMem(Buf, BufLen);
    end;
  finally
    F.Free;
  end;
end;

{ =====================================================================
  PUBLIC: SAVE LEVEL JSON
  ===================================================================== }

function SaveLevelJSON(const FilePath: string; const Level: TLevelData): Boolean;
var
  SL: TStringList;
  Row: Integer;
  RowStr: string;
  BW: string;
begin
  Result := False;
  SL := TStringList.Create;
  try
    if Level.Options.BuildWall then BW := 'true' else BW := 'false';

    SL.Add('{');
    SL.Add('  "version": 3,');
    SL.Add('  "name": "' + Level.Name + '",');
    SL.Add('  "creator": "' + Level.Creator + '",');
    SL.Add('  "description": "' + Level.Description + '",');
    SL.Add('  "musicTrack": "' + Level.MusicTrack + '",');
    SL.Add('  "options": {');
    SL.Add('    "startX": ' + IntToStr(Level.Options.InitX) + ',');
    SL.Add('    "startY": ' + IntToStr(Level.Options.InitY) + ',');
    SL.Add('    "skyType": ' + IntToStr(Level.Options.SkyType) + ',');
    SL.Add('    "wallType1": ' + IntToStr(Level.Options.WallType1) + ',');
    SL.Add('    "wallType2": ' + IntToStr(Level.Options.WallType2) + ',');
    SL.Add('    "wallType3": ' + IntToStr(Level.Options.WallType3) + ',');
    SL.Add('    "pipeColor": ' + IntToStr(Level.Options.PipeColor) + ',');
    SL.Add('    "groundColor1": ' + IntToStr(Level.Options.GroundColor1) + ',');
    SL.Add('    "groundColor2": ' + IntToStr(Level.Options.GroundColor2) + ',');
    SL.Add('    "horizon": ' + IntToStr(Level.Options.Horizon) + ',');
    SL.Add('    "backgrType": ' + IntToStr(Level.Options.BackGrType) + ',');
    SL.Add('    "backgrColor1": ' + IntToStr(Level.Options.BackGrColor1) + ',');
    SL.Add('    "backgrColor2": ' + IntToStr(Level.Options.BackGrColor2) + ',');
    SL.Add('    "stars": ' + IntToStr(Level.Options.Stars) + ',');
    SL.Add('    "clouds": ' + IntToStr(Level.Options.Clouds) + ',');
    SL.Add('    "design": ' + IntToStr(Level.Options.Design) + ',');
    SL.Add('    "c2r": ' + IntToStr(Level.Options.C2r) + ',');
    SL.Add('    "c2g": ' + IntToStr(Level.Options.C2g) + ',');
    SL.Add('    "c2b": ' + IntToStr(Level.Options.C2b) + ',');
    SL.Add('    "c3r": ' + IntToStr(Level.Options.C3r) + ',');
    SL.Add('    "c3g": ' + IntToStr(Level.Options.C3g) + ',');
    SL.Add('    "c3b": ' + IntToStr(Level.Options.C3b) + ',');
    SL.Add('    "brickColor": ' + IntToStr(Level.Options.BrickColor) + ',');
    SL.Add('    "woodColor": ' + IntToStr(Level.Options.WoodColor) + ',');
    SL.Add('    "xblockColor": ' + IntToStr(Level.Options.XBlockColor) + ',');
    SL.Add('    "buildWall": ' + BW);
    SL.Add('  },');
    SL.Add('  "width": ' + IntToStr(Level.Width) + ',');
    SL.Add('  "tiles": [');

    for Row := 1 to NV do
    begin
      RowStr := '    "' + EncodeTileRow(Level.Map, Row, Level.Width) + '"';
      if Row < NV then
        RowStr := RowStr + ',';
      SL.Add(RowStr);
    end;

    if Length(Level.TurboOverrides) > 0 then
    begin
      SL.Add('  ],');
      SL.Add('  "turboOptions": {');
      for Row := 0 to High(Level.TurboOverrides) do
      begin
        RowStr := '    "' + Level.TurboOverrides[Row].Key + '": '
          + IntToStr(Level.TurboOverrides[Row].Value);
        if Row < High(Level.TurboOverrides) then
          RowStr := RowStr + ',';
        SL.Add(RowStr);
      end;
      SL.Add('  }');
    end
    else
      SL.Add('  ]');
    SL.Add('}');

    ForceDirectories(ExtractFileDir(FilePath));
    SL.SaveToFile(FilePath);
    Result := True;
  finally
    SL.Free;
  end;
end;

{ =====================================================================
  PUBLIC: LOAD MANIFEST
  ===================================================================== }

function LoadManifest(const FilePath: string; out Manifest: TManifest): Boolean;
var
  F: TFileStream;
  Buf: PCharBuf;
  BufLen: LongInt;
  P, ObjStart, ObjEnd, TurboStart, TurboEnd: LongInt;
  WorldCount, i: Integer;
  Key: string;
  Value: Integer;
begin
  Result := False;
  SetLength(Manifest.Worlds, 0);
  Manifest.IntroFile := '';

  if not FileExists(FilePath) then Exit;

  F := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    BufLen := F.Size;
    if (BufLen < 10) or (BufLen > 1024 * 1024) then Exit;
    GetMem(Buf, BufLen);
    try
      F.ReadBuffer(Buf^, BufLen);

      Manifest.IntroFile := GetStrInRange(Buf, 'intro', 0, BufLen, '');

      { Find worlds array }
      P := FindKeyInRange(Buf, 'worlds', 0, BufLen);
      if P < 0 then Exit;
      P := SkipWS(Buf, P, BufLen);
      if (P >= BufLen) or (Buf^[P] <> '[') then Exit;
      Inc(P);

      { Count and parse world entries }
      WorldCount := 0;
      SetLength(Manifest.Worlds, 16);

      while P < BufLen do
      begin
        P := SkipWS(Buf, P, BufLen);
        if (P >= BufLen) or (Buf^[P] = ']') then Break;
        if Buf^[P] = ',' then begin Inc(P); Continue; end;
        if Buf^[P] <> '{' then Break;

        ObjStart := P;
        ObjEnd := FindObjEnd(Buf, P, BufLen);

        if WorldCount >= Length(Manifest.Worlds) then
          SetLength(Manifest.Worlds, Length(Manifest.Worlds) * 2);

        with Manifest.Worlds[WorldCount] do
        begin
          Name := GetStrInRange(Buf, 'name', ObjStart, ObjEnd, '');
          LevelAFile := GetStrInRange(Buf, 'levelA', ObjStart, ObjEnd, '');
          LevelBFile := GetStrInRange(Buf, 'levelB', ObjStart, ObjEnd, '');

          { Parse turboOptions object }
          SetLength(TurboOverrides, 0);
          TurboStart := FindKeyInRange(Buf, 'turboOptions', ObjStart, ObjEnd);
          if TurboStart >= 0 then
          begin
            TurboStart := SkipWS(Buf, TurboStart, ObjEnd);
            if (TurboStart < ObjEnd) and (Buf^[TurboStart] = '{') then
            begin
              TurboEnd := FindObjEnd(Buf, TurboStart, ObjEnd);
              { Parse key-value pairs inside turboOptions }
              i := TurboStart + 1;
              while i < TurboEnd - 1 do
              begin
                i := SkipWS(Buf, i, TurboEnd);
                if (i >= TurboEnd) or (Buf^[i] <> '"') then Break;
                ReadStrFromBuf(Buf, i, TurboEnd, Key);
                i := i + Length(Key) + 2; { skip past key + quotes }
                i := SkipWS(Buf, i, TurboEnd);
                if (i < TurboEnd) and (Buf^[i] = ':') then Inc(i);
                ReadIntFromBuf(Buf, i, TurboEnd, Value);
                { skip past the number }
                i := SkipWS(Buf, i, TurboEnd);
                while (i < TurboEnd) and (Buf^[i] in ['0'..'9', '-']) do Inc(i);
                if (i < TurboEnd) and (Buf^[i] = ',') then Inc(i);

                SetLength(TurboOverrides, Length(TurboOverrides) + 1);
                TurboOverrides[High(TurboOverrides)].Key := Key;
                TurboOverrides[High(TurboOverrides)].Value := Value;
              end;
            end;
          end;
        end;

        Inc(WorldCount);
        P := ObjEnd;
      end;

      SetLength(Manifest.Worlds, WorldCount);
      Result := True;
    finally
      FreeMem(Buf, BufLen);
    end;
  finally
    F.Free;
  end;
end;

{ =====================================================================
  PUBLIC: MAP TO WORLD BUFFER (replaces Buffers.ReadWorld)
  ===================================================================== }

procedure MapToWorldBuffer(const Map: MapBuffer; W: WorldBufferPtr; var Opt: WorldOptions);
var
  i, j, X: Integer;
begin
  FillChar(W^, SizeOf(W^), ' ');

  { Fill left border padding with wall tiles }
  for i := -EX to -1 do
    for j := -EY1 to NV - 1 + EY2 do
      W^[i, j] := '@';

  { Copy map columns (flipping Y: map row 1 = top = world row NV-1) }
  X := 0;
  while (Map[X + 1, 1] <> #0) and (X < MaxWorldSize) do
  begin
    for i := 1 to NV do
      W^[X, NV - i] := Map[X + 1, i];
    W^[X, -EY1] := #0;
    for i := 1 to EY2 do
      W^[X, NV - 1 + i] := W^[X, NV - 1];
    Inc(X);
  end;

  Opt.XSize := X;

  { Fill right border padding with walls }
  for i := X to X + EX - 1 do
    for j := -EY1 to NV - 1 + EY2 do
      W^[i, j] := '@';
end;

{ =====================================================================
  PUBLIC: APPLY TURBO OVERRIDES
  ===================================================================== }

procedure ApplyTurboOverrides(var Opt: WorldOptions; const Overrides: array of TTurboOverride);
var
  i: Integer;
begin
  for i := 0 to High(Overrides) do
  begin
    if Overrides[i].Key = 'startX' then Opt.InitX := Overrides[i].Value
    else if Overrides[i].Key = 'startY' then Opt.InitY := Overrides[i].Value
    else if Overrides[i].Key = 'skyType' then Opt.SkyType := Overrides[i].Value
    else if Overrides[i].Key = 'wallType1' then Opt.WallType1 := Overrides[i].Value
    else if Overrides[i].Key = 'wallType2' then Opt.WallType2 := Overrides[i].Value
    else if Overrides[i].Key = 'wallType3' then Opt.WallType3 := Overrides[i].Value
    else if Overrides[i].Key = 'pipeColor' then Opt.PipeColor := Overrides[i].Value
    else if Overrides[i].Key = 'groundColor1' then Opt.GroundColor1 := Overrides[i].Value
    else if Overrides[i].Key = 'groundColor2' then Opt.GroundColor2 := Overrides[i].Value
    else if Overrides[i].Key = 'horizon' then Opt.Horizon := Overrides[i].Value
    else if Overrides[i].Key = 'backgrType' then Opt.BackGrType := Overrides[i].Value
    else if Overrides[i].Key = 'backgrColor1' then Opt.BackGrColor1 := Overrides[i].Value
    else if Overrides[i].Key = 'backgrColor2' then Opt.BackGrColor2 := Overrides[i].Value
    else if Overrides[i].Key = 'stars' then Opt.Stars := Overrides[i].Value
    else if Overrides[i].Key = 'clouds' then Opt.Clouds := Overrides[i].Value
    else if Overrides[i].Key = 'design' then Opt.Design := Overrides[i].Value
    else if Overrides[i].Key = 'c2r' then Opt.C2r := Overrides[i].Value
    else if Overrides[i].Key = 'c2g' then Opt.C2g := Overrides[i].Value
    else if Overrides[i].Key = 'c2b' then Opt.C2b := Overrides[i].Value
    else if Overrides[i].Key = 'c3r' then Opt.C3r := Overrides[i].Value
    else if Overrides[i].Key = 'c3g' then Opt.C3g := Overrides[i].Value
    else if Overrides[i].Key = 'c3b' then Opt.C3b := Overrides[i].Value
    else if Overrides[i].Key = 'brickColor' then Opt.BrickColor := Overrides[i].Value
    else if Overrides[i].Key = 'woodColor' then Opt.WoodColor := Overrides[i].Value
    else if Overrides[i].Key = 'xblockColor' then Opt.XBlockColor := Overrides[i].Value;
  end;
end;

end.
