unit Demo;

{ Demo playback: auto-demo and user replay files.
  Extracted from MARIO.PAS. }

{$A+} {$B-} {$G+} {$I-} {$R-} {$S+} {$V-} {$X+}

interface

  procedure PlayDemo;
  procedure PlayDemoFile(const FileName: string; Level: Word);

implementation

  uses
    Keyboard, Worlds, Buffers, Enemies, Config, AssetPaths;

  const
    NUM_LEV = 6;  { Must match game constant }

  procedure PlayDemo;
  var
    Hdr: DemoHeader;
    DemoPath: string;
  begin
    DemoPath := GetAssetsDir + 'demos' + DirectorySeparator + 'default.rpl';
    FillChar(Hdr, SizeOf(Hdr), 0);
    if LoadMacroFromFile(DemoPath, Hdr) then
    begin
      NewData;
      Turbo := FALSE;
      Data.Progress[plPlayer1] := Hdr.Level;
      if Hdr.Level < NUM_LEV then
        PlayWorldByIndex(' ', ' ', Hdr.Level, plPlayer1);
    end;
    StopMacro;
  end;

  procedure PlayDemoFile(const FileName: string; Level: Word);
  var
    Hdr: DemoHeader;
  begin
    FillChar(Hdr, SizeOf(Hdr), 0);
    Hdr.Level := Level;
    if not LoadMacroFromFile(GetUserDataDir + FileName, Hdr) then Exit;
    NewData;
    Turbo := FALSE;
    Data.Progress[plPlayer1] := Hdr.Level;
    if Hdr.Level < NUM_LEV then
      PlayWorldByIndex(' ', ' ', Hdr.Level, plPlayer1);
    StopMacro;
  end;

end.
