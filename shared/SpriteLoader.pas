unit SpriteLoader;

{ Loads .sprite binary files and provides sprite manipulation routines.
  Shared between game and editor. No rendering logic — just data. }

{$mode objfpc}{$H+}
{$R-}

interface

uses
  TileDefs;

type
  TSpriteData = record
    Width:  Word;
    Height: Word;
    Pixels: array of Byte;
  end;

  PSpriteData = ^TSpriteData;

procedure LoadSprite(const FilePath: string; out Sprite: TSpriteData);
procedure CopySprite(const Src: TSpriteData; out Dst: TSpriteData);

{ Sprite manipulation (same algorithms as game's Figures.PAS) }
procedure ReColorSprite(const Src: TSpriteData; out Dst: TSpriteData; C: Byte);
procedure ReColor2Sprite(const Src: TSpriteData; out Dst: TSpriteData; C1, C2: Byte);
procedure MirrorSprite(const Src: TSpriteData; out Dst: TSpriteData);
procedure RotateSprite(const Src: TSpriteData; out Dst: TSpriteData);

{ Copy sprite pixel data into a flat buffer (for game's ImageBuffer compatibility) }
procedure SpriteToBuffer(const Sprite: TSpriteData; Buf: PByte; BufSize: Integer);

implementation

uses
  SysUtils, Classes;

procedure LoadSprite(const FilePath: string; out Sprite: TSpriteData);
var
  F: TFileStream;
  DataSize: Integer;
begin
  F := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    Sprite.Width := F.ReadWord;
    Sprite.Height := F.ReadWord;
    DataSize := Sprite.Width * Sprite.Height;
    SetLength(Sprite.Pixels, DataSize);
    if DataSize > 0 then
      F.ReadBuffer(Sprite.Pixels[0], DataSize);
  finally
    F.Free;
  end;
end;

procedure CopySprite(const Src: TSpriteData; out Dst: TSpriteData);
begin
  Dst.Width := Src.Width;
  Dst.Height := Src.Height;
  SetLength(Dst.Pixels, Length(Src.Pixels));
  if Length(Src.Pixels) > 0 then
    Move(Src.Pixels[0], Dst.Pixels[0], Length(Src.Pixels));
end;

procedure ReColorSprite(const Src: TSpriteData; out Dst: TSpriteData; C: Byte);
var
  i: Integer;
  B: Byte;
begin
  Dst.Width := Src.Width;
  Dst.Height := Src.Height;
  SetLength(Dst.Pixels, Length(Src.Pixels));
  for i := 0 to Length(Src.Pixels) - 1 do
  begin
    B := Src.Pixels[i];
    if B > $10 then
      Dst.Pixels[i] := (B and $07) + C
    else
      Dst.Pixels[i] := B;
  end;
end;

procedure ReColor2Sprite(const Src: TSpriteData; out Dst: TSpriteData; C1, C2: Byte);
var
  i: Integer;
  B: Byte;
begin
  Dst.Width := Src.Width;
  Dst.Height := Src.Height;
  SetLength(Dst.Pixels, Length(Src.Pixels));
  for i := 0 to Length(Src.Pixels) - 1 do
  begin
    B := Src.Pixels[i];
    if B > $10 then
    begin
      B := B and $0F;
      if B >= 8 then
        Dst.Pixels[i] := (B and $07) + C2
      else
        Dst.Pixels[i] := B + C1;
    end
    else
      Dst.Pixels[i] := Src.Pixels[i];
  end;
end;

procedure MirrorSprite(const Src: TSpriteData; out Dst: TSpriteData);
var
  Row, Col: Integer;
  W: Word;
begin
  W := Src.Width;
  Dst.Width := W;
  Dst.Height := Src.Height;
  SetLength(Dst.Pixels, Length(Src.Pixels));
  for Row := 0 to Src.Height - 1 do
    for Col := 0 to W - 1 do
      Dst.Pixels[Row * W + Col] := Src.Pixels[Row * W + (W - 1 - Col)];
end;

procedure RotateSprite(const Src: TSpriteData; out Dst: TSpriteData);
var
  i, Total: Integer;
begin
  Dst.Width := Src.Width;
  Dst.Height := Src.Height;
  Total := Length(Src.Pixels);
  SetLength(Dst.Pixels, Total);
  for i := 0 to Total - 1 do
    Dst.Pixels[i] := Src.Pixels[Total - 1 - i];
end;

procedure SpriteToBuffer(const Sprite: TSpriteData; Buf: PByte; BufSize: Integer);
var
  CopySize: Integer;
begin
  CopySize := Sprite.Width * Sprite.Height;
  if CopySize > BufSize then
    CopySize := BufSize;
  if CopySize > 0 then
    Move(Sprite.Pixels[0], Buf^, CopySize);
end;

end.
