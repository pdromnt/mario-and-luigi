unit AssetPaths;

{ Resolves asset file paths relative to the executable location. }

{$mode objfpc}{$H+}

interface

function GetAssetsDir: string;
function GetSaveDataDir: string;
function SpritePath(const Name: string): string;
function PalettePath(const Name: string): string;
function BackgroundPath(const Name: string): string;
function FontPath(const Name: string): string;
function LevelPath(const Name: string): string;
function CatalogPath: string;
function ManifestPath: string;

implementation

uses
  SysUtils;

var
  CachedAssetsDir: string;
  CachedSaveDataDir: string;

function GetExeDir: string;
{ Returns the directory containing the executable, with trailing separator.
  Handles edge cases: relative paths, bare exe name, empty ParamStr(0). }
var
  ExePath, Dir: string;
begin
  ExePath := ParamStr(0);
  if ExePath <> '' then
  begin
    Dir := ExtractFileDir(ExpandFileName(ExePath));
    if Dir <> '' then
    begin
      Result := IncludeTrailingPathDelimiter(Dir);
      Exit;
    end;
  end;
  { Fallback: current working directory }
  Result := IncludeTrailingPathDelimiter(GetCurrentDir);
end;

function GetAssetsDir: string;
var
  ExeDir, Try1, Try2, Try3: string;
begin
  if CachedAssetsDir = '' then
  begin
    ExeDir := GetExeDir;

    { Try 1: assets/ next to the executable }
    Try1 := ExeDir + 'assets' + DirectorySeparator;
    if DirectoryExists(Try1) then
    begin
      CachedAssetsDir := Try1;
    end
    else
    begin
      { Try 2: parent directory (for running from OUT/) }
      Try2 := IncludeTrailingPathDelimiter(
        ExtractFileDir(ExcludeTrailingPathDelimiter(ExeDir))) + 'assets' + DirectorySeparator;
      if DirectoryExists(Try2) then
        CachedAssetsDir := Try2
      else
      begin
        { Try 3: current working directory }
        Try3 := IncludeTrailingPathDelimiter(GetCurrentDir) + 'assets' + DirectorySeparator;
        if DirectoryExists(Try3) then
          CachedAssetsDir := Try3
        else
          CachedAssetsDir := Try1;  { Default to exe-relative, will fail with clear error }
      end;
    end;
  end;
  Result := CachedAssetsDir;
end;

function GetSaveDataDir: string;
var
  Dir: string;
begin
  if CachedSaveDataDir = '' then
  begin
    {$IFDEF UNIX}
    Dir := GetEnvironmentVariable('HOME');
    if Dir <> '' then
      Dir := IncludeTrailingPathDelimiter(Dir) + '.game-data' + DirectorySeparator
    else
      Dir := GetExeDir;
    {$ELSE}
    Dir := GetExeDir;
    {$ENDIF}
    Dir := Dir + 'savedata' + DirectorySeparator;
    ForceDirectories(Dir);
    CachedSaveDataDir := Dir;
  end;
  Result := CachedSaveDataDir;
end;

function SpritePath(const Name: string): string;
begin
  Result := GetAssetsDir + 'sprites' + DirectorySeparator + Name;
end;

function PalettePath(const Name: string): string;
begin
  Result := GetAssetsDir + 'palettes' + DirectorySeparator + Name;
end;

function BackgroundPath(const Name: string): string;
begin
  Result := GetAssetsDir + 'backgrounds' + DirectorySeparator + Name;
end;

function FontPath(const Name: string): string;
begin
  Result := GetAssetsDir + 'fonts' + DirectorySeparator + Name;
end;

function LevelPath(const Name: string): string;
begin
  Result := GetAssetsDir + 'levels' + DirectorySeparator + Name;
end;

function CatalogPath: string;
begin
  Result := GetAssetsDir + 'sprites' + DirectorySeparator + 'catalog.json';
end;

function ManifestPath: string;
begin
  Result := GetAssetsDir + 'levels' + DirectorySeparator + 'manifest.json';
end;

end.
