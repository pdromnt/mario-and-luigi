unit BackgroundLoader;

{ Loads .bg binary background height-profile files.
  Shared between game and editor. }

{$mode objfpc}{$H+}

interface

type
  TBackgroundData = array of Byte;

procedure LoadBackground(const FilePath: string; out Data: TBackgroundData);

implementation

uses
  SysUtils, Classes;

procedure LoadBackground(const FilePath: string; out Data: TBackgroundData);
var
  F: TFileStream;
  Size: Int64;
begin
  F := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    Size := F.Size;
    SetLength(Data, Size);
    if Size > 0 then
      F.ReadBuffer(Data[0], Size);
  finally
    F.Free;
  end;
end;

end.
