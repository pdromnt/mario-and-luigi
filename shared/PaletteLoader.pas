unit PaletteLoader;

{ Loads .pal binary palette files.
  Shared between game and editor. }

{$mode objfpc}{$H+}

interface

type
  { 256-color palette: 768 bytes (256 entries x 3 RGB components) }
  TPaletteData = array[0..767] of Byte;
  PPaletteData = ^TPaletteData;

  { Small palette: 280 bytes (used for brick/pill recolor palettes) }
  TSmallPalette = array[0..279] of Byte;

procedure LoadPalette(const FilePath: string; out Pal: TPaletteData);
procedure LoadSmallPalette(const FilePath: string; out Pal: TSmallPalette);

implementation

uses
  SysUtils, Classes;

procedure LoadPalette(const FilePath: string; out Pal: TPaletteData);
var
  F: TFileStream;
begin
  FillChar(Pal, SizeOf(Pal), 0);
  F := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    F.ReadBuffer(Pal, SizeOf(Pal));
  finally
    F.Free;
  end;
end;

procedure LoadSmallPalette(const FilePath: string; out Pal: TSmallPalette);
var
  F: TFileStream;
begin
  FillChar(Pal, SizeOf(Pal), 0);
  F := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    F.ReadBuffer(Pal, SizeOf(Pal));
  finally
    F.Free;
  end;
end;

end.
