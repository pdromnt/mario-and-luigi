program Game;

  { Game for the PC by Mike Wiering, 1994-95 }
  { SDL2 port }

  {$A+} {$B-} {$G+} {$I-} {$R-} {$S+} {$V-} {$X+}
  {$IFDEF WINDOWS}
  {$APPTYPE GUI}
  {$R resources\game.res}
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
    Audio,
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
    { Clean up old files from legacy locations (before savedata/) }
    TryDelete(ExeDir + 'MARIO.CFG');
    TryDelete(ExeDir + 'MARIO.SAV');
    TryDelete(ExeDir + 'MARIO.HIS');
    TryDelete(ExeDir + 'MARIO.DEM');
    TryDelete(ExeDir + 'GAME.CFG');
    TryDelete(ExeDir + 'GAME.SAV');
    TryDelete(ExeDir + 'GAME.HIS');
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

begin  { Game }
  InitKeyBoard;
  InitWorlds;
  LoadFiguresSprites;
  LoadEnemySprites;
  LoadPlayerSprites;
  LoadTmpObjSprites;
  LoadMenuSprites;
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
        CurPlayer := plPlayer1;
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
        if Progress [plPlayer1] > Progress [plPlayer2] then
          Progress [plPlayer2] := Progress [plPlayer1]
        else
          Progress [plPlayer1] := Progress [plPlayer2];

      Lives [plPlayer1] := 3;
      Lives [plPlayer2] := 3;
      Coins [plPlayer1] := 0;
      Coins [plPlayer2] := 0;
      Score [plPlayer1] := 0;
      Score [plPlayer2] := 0;
      Mode [plPlayer1] := mdSmall;
      Mode [plPlayer2] := mdSmall;
    end;

    repeat
      if Data.NumPlayers = 1 then
        Data.Lives [plPlayer2] := 0;
      for CurPlayer := plPlayer1 to Data.NumPlayers - 1 do
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
      (Data.Lives [plPlayer1] + Data.Lives [plPlayer2] = 0);

    { Hi-score check after Game Over (not on quit) }
    if (not QuitGame) and
       (Data.Lives[plPlayer1] + Data.Lives[plPlayer2] = 0) then
    begin
      if IsHiScore(Data.Score[plPlayer1]) then
        EnterHiScoreInitials(Data.Score[plPlayer1], plPlayer1);
      if (Data.NumPlayers = 2) and IsHiScore(Data.Score[plPlayer2]) then
        EnterHiScoreInitials(Data.Score[plPlayer2], plPlayer2);
    end;

    if GameNumber <> -1 then
      Saves.Games[GameNumber] := Data;

{$IFDEF MENU}
  until QuitGame;
{$ENDIF}
  ShutdownBGMusic;
  WriteConfig;
end.
