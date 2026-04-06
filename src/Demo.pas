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
    NUM_LEV = 6;  { Must match MARIO.PAS }

  procedure PlayDemo;
  var
    Hdr: DemoHeader;
    DemoPath: string;
    DemoLoaded: Boolean;
  begin
    { Try MARIO.DEM (user override), then default.rpl (shipped asset) }
    FillChar(Hdr, SizeOf(Hdr), 0);
    DemoLoaded := LoadMacroFromFile(GetUserDataDir + 'MARIO.DEM', Hdr);
    if not DemoLoaded then
    begin
      DemoPath := GetAssetsDir + 'demos' + DirectorySeparator + 'default.rpl';
      DemoLoaded := LoadMacroFromFile(DemoPath, Hdr);
    end;
    if DemoLoaded then
    begin
      NewData;
      Turbo := FALSE;
      Data.Progress[plMario] := Hdr.Level;
      if Hdr.Level < NUM_LEV then
        PlayWorldByIndex(' ', ' ', Hdr.Level, plMario);
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
    Data.Progress[plMario] := Hdr.Level;
    case Hdr.Level of
      0: PlayWorldByIndex(' ', ' ', 0, plMario);
      1: PlayWorldByIndex(' ', ' ', 1, plMario);
      2: PlayWorldByIndex(' ', ' ', 2, plMario);
      3: PlayWorldByIndex(' ', ' ', 3, plMario);
      4: PlayWorldByIndex(' ', ' ', 4, plMario);
      5: PlayWorldByIndex(' ', ' ', 5, plMario);
    end;
    StopMacro;
  end;

end.
