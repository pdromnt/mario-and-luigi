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
  SysUtils, LevelFormat;

{ Copy a TLevelData (from LevelFormat) into the CustomMap/CustomOpt vars }
procedure CopyLevelToCustom(const Level: TLevelData;
  var Map: MapBuffer; var Opt: WorldOptions; var MusicStr: ShortString);
begin
  Map := Level.Map;
  Opt := Level.Options;
  MusicStr := Level.MusicTrack;
  { Ensure end-of-level terminator is set }
  if Level.Width < MaxWorldSize then
    Map[Level.Width + 1, 1] := #0;
end;

{ ----- Public Interface ----- }

procedure ScanCustomLevels;
var
  SR: TSearchRec;
  Dir: ShortString;
  Level: TLevelData;
  LName: ShortString;
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
        if LevelFormat.LoadLevelJSON(Dir + SR.Name, Level) and (Level.Name <> '') then
          LName := Level.Name
        else
          LName := '(unnamed)';
        CustomLevels[NumCustomLevels].LevelName := LName;
        if NumCustomLevels >= MAX_CUSTOM_LEVELS then Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function LoadCustomLevel(Index: Integer): Boolean;
begin
  LoadCustomLevel := False;
  if (Index < 1) or (Index > NumCustomLevels) then Exit;
  LoadCustomLevel := LoadCustomLevelByPath(CustomLevels[Index].FileName);
end;

function LoadCustomLevelByPath(const Path: ShortString): Boolean;
var
  Level: TLevelData;
begin
  LoadCustomLevelByPath := False;
  if not LevelFormat.LoadLevelJSON(Path, Level) then Exit;

  CopyLevelToCustom(Level, CustomMapA, CustomOptA, CustomMusicA);
  { Single-level files: copy A to B }
  CustomMapB := CustomMapA;
  CustomOptB := CustomOptA;
  CustomMusicB := CustomMusicA;
  LoadCustomLevelByPath := True;
end;

begin
  NumCustomLevels := 0;
end.
