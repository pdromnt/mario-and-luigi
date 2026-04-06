unit AssetPaths;

{ Resolves asset file paths relative to the executable location. }

{$mode objfpc}{$H+}

interface

function GetAssetsDir: string;
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

function GetAssetsDir: string;
var
  ExeDir: string;
begin
  if CachedAssetsDir = '' then
  begin
    ExeDir := ExtractFileDir(ParamStr(0));
    CachedAssetsDir := IncludeTrailingPathDelimiter(ExeDir) + 'assets' + DirectorySeparator;
    if not DirectoryExists(CachedAssetsDir) then
    begin
      { Try parent directory (for running from OUT/) }
      CachedAssetsDir := IncludeTrailingPathDelimiter(
        ExtractFileDir(ExcludeTrailingPathDelimiter(ExeDir))) + 'assets' + DirectorySeparator;
    end;
  end;
  Result := CachedAssetsDir;
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
