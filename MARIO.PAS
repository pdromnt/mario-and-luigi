program Mario;

  { Mario game for the PC by Mike Wiering, 1994-95 }
  { SDL2 port }

  {$A+} {$B-} {$G+} {$I-} {$R-} {$S+} {$V-} {$X+}
  {$IFDEF WINDOWS}
  {$APPTYPE GUI}
  {$R resources\mario.res}
  {$ENDIF}

  {$DEFINE MENU}

  uses
    CPU286,
    Play,
    Players,
    Enemies,
    Buffers,
    VGA256,
    Worlds,
    BackGr,
    KeyBoard,
    Joystick,
    Figures,
    Palettes,
    Txt,
    Music,
    BGMusic,
    CustomLv,
    TmpObj,
    SpriteLoader,
    AssetPaths,
    Config,
    HiScore,
    Demo,
    Menus,
    {$IFDEF UNIX}
    dos,
    {$ENDIF}
    sdl2;

  const
    NUM_LEV = 6;
    LAST_LEV = 2 * NUM_LEV - 1;

  procedure DebugLog(const Msg: string);
  var
    F: Text;
  begin
    Assign(F, GetUserDataDir + 'debug.log');
    {$I-}
    Append(F);
    if IOResult <> 0 then
    begin
      ReWrite(F);
      if IOResult <> 0 then Exit;
    end;
    WriteLn(F, Msg);
    Close(F);
    if IOResult <> 0 then ;
    {$I+}
  end;

  procedure CleanupOldFiles;
  { Remove legacy files from old locations (before savedata/ was introduced) }
  var
    F: File;
    ExeDir: string;
    S: string;
    Len: Byte absolute S;
    p: Integer;

    procedure TryDelete(const Path: string);
    begin
      Assign(F, Path);
      {$I-}
      Erase(F);
      if IOResult <> 0 then ;
      {$I+}
    end;

  var
    i: Integer;
  begin
    S := ParamStr(0);
    p := Len;
    while (p > 0) and (S[p] <> '\') and (S[p] <> '/') do Dec(p);
    if p > 0 then
      ExeDir := Copy(S, 1, p)
    else
      ExeDir := '';
    TryDelete(ExeDir + 'MARIO.CFG');
    TryDelete(ExeDir + 'MARIO.SAV');
    TryDelete(ExeDir + 'MARIO.HIS');
    TryDelete(ExeDir + 'MARIO.DEM');
    TryDelete(ExeDir + 'debug.log');
    for i := 1 to 9 do
      TryDelete(ExeDir + 'REPLAY' + Chr(i + Ord('0')) + '.RPL');
  end;

  var
    OldExitProc: Pointer;

  procedure CleanupOnExit;
  begin
    ExitProc := OldExitProc;  { Restore previous exit proc }
    WriteConfig;
    WriteHiScores;
    ShutdownBGMusic;
  end;

begin  { Mario }
  InitKeyBoard;
  InitWorlds;
  LoadFiguresSprites;
  LoadEnemySprites;
  LoadPlayerSprites;
  LoadTmpObjSprites;
  LoadMarioSprites;
  LoadBackGrData;
  LoadFontData;
  Data.NumPlayers := 1;
  ReadConfig;
  ReadHiScores;
  ReadCmdLine;

  { Clean up old files from pre-savedata locations }
  CleanupOldFiles;

  jr := Settings.JSDat;
  jsEnabled := jsDetected and Settings.UseJS;

  ResetKeyBoard;

  if not InGraphicsMode then
    InitVGA;

  InitAudio;  { Open SDL audio device for PC speaker emulation }
  InitBGMusic;  { Open SDL2_mixer for background music }

  { Install exit handler so settings are saved even on Halt(0) / window close }
  OldExitProc := ExitProc;
  ExitProc := @CleanupOnExit;

{$IFDEF MENU}
  repeat
{$ENDIF}

    ClearVGAMem;

    InitPlayerFigures;
    InitEnemyFigures;
    SaveSpriteBackups;
    InitColoredSprites;  { Per-tile color variants for mixed pipes/bricks/etc. }
    InitDecoSpritePalette;  { Fixed palette entries for design-independent deco }

    { Test play mode: load level from path, play immediately, then exit }
    if TestPlayMode and (TestPlayPath <> '') then
    begin
      if LoadCustomLevelByPath(TestPlayPath) then
      begin
        NewData;
        Data.NumPlayers := 1;
        CurPlayer := plMario;
        { Play custom music track if specified }
        if CustomMusicA <> '' then
          PlayMusicByName(CustomMusicA)
        else
          PlayLevelMusic(1);  { Default to level 1 music }
        Passed := PlayWorld('x', 'C',
          CustomMapA, CustomOptA, CustomOptA,
          CustomMapB, CustomOptB, CustomOptB,
          CurPlayer);
      end;
      Halt(0);
    end;

    EndGame := FALSE;
  {$IFDEF MENU}
    Intro;
  {$ENDIF}

    Randomize;

    with Data do
    begin
      if NumPlayers = 2 then
        if Progress [plMario] > Progress [plLuigi] then
          Progress [plLuigi] := Progress [plMario]
        else
          Progress [plMario] := Progress [plLuigi];

      Lives [plMario] := 3;
      Lives [plLuigi] := 3;
      Coins [plMario] := 0;
      Coins [plLuigi] := 0;
      Score [plMario] := 0;
      Score [plLuigi] := 0;
      Mode [plMario] := mdSmall;
      Mode [plLuigi] := mdSmall;
    end;

    repeat
      if Data.NumPlayers = 1 then
        Data.Lives [plLuigi] := 0;
      for CurPlayer := plMario to Data.NumPlayers - 1 do
      begin
        if not (EndGame or QuitGame) then
          if Data.Lives [CurPlayer] >= 1 then
          begin
            with Data do
            begin
              Turbo := (Progress [CurPlayer] >= NUM_LEV);
              if Progress [CurPlayer] > LAST_LEV then
                Progress [CurPlayer] := NUM_LEV;
            end;
         {$IFDEF MENU}
            ShowPlayerName (CurPlayer);
         {$ENDIF}
            case Data.Progress [CurPlayer] mod NUM_LEV of
              0: Passed := PlayWorldByIndex('x', '1', 0, CurPlayer);
              1: Passed := PlayWorldByIndex('x', '2', 1, CurPlayer);
              2: Passed := PlayWorldByIndex('x', '3', 2, CurPlayer);
              3: Passed := PlayWorldByIndex('x', '4', 3, CurPlayer);
              4: Passed := PlayWorldByIndex('x', '5', 4, CurPlayer);
              5: Passed := PlayWorldByIndex('x', '6', 5, CurPlayer);
              else
                EndGame := TRUE;
            end;

            if Passed then
              Inc (Data.Progress [CurPlayer]);
            if QuitGame then
            begin
              EndGame := TRUE;
            {$IFDEF MENU}
              QuitGame := FALSE;
            {$ENDIF}
            end;
          end;

      end;
    until EndGame or QuitGame or
      (Data.Lives [plMario] + Data.Lives [plLuigi] = 0);

    { Hi-score check after Game Over (not on quit) }
    if (not QuitGame) and
       (Data.Lives[plMario] + Data.Lives[plLuigi] = 0) then
    begin
      if IsHiScore(Data.Score[plMario]) then
        EnterHiScoreInitials(Data.Score[plMario], plMario);
      if (Data.NumPlayers = 2) and IsHiScore(Data.Score[plLuigi]) then
        EnterHiScoreInitials(Data.Score[plLuigi], plLuigi);
    end;

    if GameNumber <> -1 then
      Saves.Games[GameNumber] := Data;

{$IFDEF MENU}
  until QuitGame;
{$ENDIF}
  ShutdownBGMusic;
  WriteConfig;
end.
