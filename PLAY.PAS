unit Play;

interface

  uses
    Players,
    TmpObj,
    Blocks,
    Figures,
    Glitter,
    Buffers,
    BackGr,
    Enemies,
    Palettes,
    VGA256,
    Stars,
    Status,
    Txt,
    Music,
    BGMusic,
    KeyBoard,
    Joystick,
    sdl2;

  const
    Stat: Boolean = FALSE;
    ShowRetrace: Boolean = FALSE;

  function PlayWorld (N1, N2: Char; var Map1; var Opt1; var Opt1b;
    var Map2; var Opt2; var Opt2b; Player: Byte): Boolean;

implementation

  const
    CheatsUsed: Integer = 0;
    NUM_LEV = 6;  { Must match MARIO.PAS }

  function PlayWorld (N1, N2: Char; var Map1; var Opt1; var Opt1b;
                      var Map2; var Opt2; var Opt2b; Player: Byte): Boolean;
    var
      i, j, k, x, y: Integer;

    procedure MoveScreen;
      var
        Scroll: Integer;
        N1, N2: Integer;
        i, j, OldX, NewX, Page: Integer;

    begin
      Page := CurrentPage;

      Scroll := XView - LastXView [Page];

      if not EarthQuake then
        SetView (XView, YView)
      else
      begin
        Inc (EarthQuakeCounter);
        if EarthQuakeCounter > 0 then
          EarthQuake := False;
        SetView (XView, YView + Random (2) - Random (2));
      end;

      if Scroll < 0 then
        StartEnemies ((XView div W) - StartEnemiesAt, 1)
      else
        if Scroll > 0 then
          StartEnemies ((XView div W) + NH + StartEnemiesAt, - 1);

      With Options do
      begin
        i := Horizon;
        Horizon := i + GetYOffset - YBASE;
        DrawBackGr (FALSE);
        Horizon := i;
      end;

      if Scroll > 0 then
        for j := LastXView [Page] to XView do
        begin
          { Original cleared enemy column markers at row 0 here via PutPixel.
            In VGA Mode X, row 0 was above the visible area due to CRTC
            start address offset. In SDL2 row 0 is visible, so skip it. }
          i := W - j mod W - 1;
          Redraw (j div W + NH + 1, i);
        end;

      if Scroll < 0 then
        for j := LastXView [Page] downto XView do
        begin
          i := W - j mod W - 1;
          Redraw (j div W - 1, i);
        end;

    end;

    procedure FindPipeExit;
      var
        i, j: Integer;
    begin
      for i := 0 to Options.XSize - 1 - 1 do
        for j := 0 to NH - 1 do
          if (i <> MapX) or (j <> MapY) then
            if (WorldMap^ [i, j] in [#$E0 .. #$EF])
              and (WorldMap^ [i + 1, j] = PipeCode [2]) then
              begin
                MapX := i;
                MapY := j;
                XView := Succ (i - NH div 2) * W;
                if XView > (Options.XSize - NH) * W then
                  XView := (Options.XSize - NH) * W;
                if XView < 0 then
                  XView := 0;
                Exit;
              end;
    end;

    Label
      BuildLevel,
      Restart;

    var
      Waiting: Boolean;
      TextStatus: Boolean;
      TotalBackGrAddr: array[0..MAX_PAGE] of Integer;
      ShowScore,
      CountingScore,
      ShowObjects: Boolean;
      OnlyDraw: Boolean;
      ScoreTick: Byte;
      InSubWorld: Boolean;
      jsPausePrev,
      jsSoundPrev,
      jsStatusPrev: Boolean;
      DemoRecording: Boolean;
      RecHdr: DemoHeader;
      DemoName: string;
      RecBackGrAddr: array[0..MAX_PAGE] of Integer;
      WasPlayingMacro: Boolean;


    procedure WriteTotalScore;
      var
        i: Integer;
        S: String;
    begin
      SetFont (0, Bold + Shadow);
      Str (Data.Score[Player]: 11, S);
      for i := 4 to Length (S) do
        if S[i] = ' ' then
          S[i] := '0';
      CenterText (120, 'TOTAL SCORE:' + S, 31);
    end;

    procedure ShowTotalBack;
    begin
      TotalBackGrAddr[CurrentPage] := PushBackGr (XView + 160, 120, 120, 8);
      WriteTotalScore;
      { Play a tick sound while counting down the score.
        Original called Beep(4*880), Beep(2*880), Beep(0) within one frame
        but with SDL2 async audio only the last value would be heard (silence).
        Alternate between high and low tones each tick for a pleasant effect. }
      if Passed and CountingScore then
      begin
        if Odd(ScoreTick) then
          Beep (880)
        else
          Beep (2 * 880);
        Inc(ScoreTick);
      end;
    end;

    procedure HideTotalBack;
      var
        Page: Integer;
    begin
      Page := CurrentPage;
      if TotalBackGrAddr[Page] <> 0 then
        PopBackGr (TotalBackGrAddr[CurrentPage]);
      TotalBackGrAddr[Page] := 0;
    end;


    procedure Pause;
      type
        StrPtr = ^string;
      var
        i,
        PauseBack: Integer;
        OldKey,
        Ch: Char;
        EndPause: Boolean;
        PauseText,
        Cheat: String;
        P: StrPtr;

      const
        CRED_LEN = 26;

      const Credit: array[0..CRED_LEN] of Byte = (CRED_LEN,
        ord('P')+  1 + $10, ord('R')+  2 + $20, ord('O')+  3 + $30,
        ord('G')+  4 + $40, ord('R')+  5 + $50, ord('A')+  6 + $60,
        ord('M')+  7 + $70, ord('M')+  8 + $80, ord('E')+  9 + $10,
        ord('D')+ 10 + $20, ord(' ')+ 11 + $30, ord('B')+ 12 + $40,
        ord('Y')+ 13 + $50, ord(' ')+ 14 + $60, ord('M')+ 15 + $70,
        ord('I')+ 16 + $80, ord('K')+ 17 + $10, ord('E')+ 18 + $20,
        ord(' ')+ 19 + $30, ord('W')+ 20 + $40, ord('I')+ 21 + $50,
        ord('E')+ 22 + $60, ord('R')+ 23 + $70, ord('I')+ 24 + $80,
        ord('N')+ 25 + $10, ord('G')+ 26 + $20);

    begin  { pause }
      PauseText := 'PAUSE';

      PauseMusic;
      FadeDown (8);

      SwapPages;
      PauseBack := PushBackGr (XView + 120, 85, 80, 10);

      if PauseBack <> 0 then
      begin
        OutPalette ($0F, 63, 63, 63);
        SetFont (0, Bold + Shadow);
        CenterText (85, PauseText, $0F);
      end;

      EndPause := FALSE;
      Cheat := '';
      While Key = kbP do ;
      While Chr (bKey - $80) = kbP do ;
      OldKey := Key;
      if Key = kbTab then
      begin
        repeat
          if Key <> OldKey then
          begin
            Ch := GetAsciiCode (Key);
            if Key < #$80 then
            begin
              Cheat := Cheat + Key;
              EndPause := (Ch = #0);
            end;
            OldKey := Key;

            if (Cheat = kbT+kbE+kbS+kbT) or    { TEST }
               (Cheat = kb0+kb0+kb4+kb4) then  { 0044 - ShowRetrace }
            begin
              ShowRetrace := not ShowRetrace;
              EndPause := TRUE;
            end;
            if Cheat = kb0+kb3+kbE+kb8 then   { 03E8 - AddLife }
            begin
              AddLife;
              EndPause := TRUE;
            end;
            if Cheat = kbB+kb1+kb7+kb2 then   { B172 - 10000 Lives }
            begin
              Data.Lives[Player] := 10000;
              EndPause := TRUE;
            end;
            if Cheat = kb9+kbC+kb3+kb2 then    { 9C32 - Star }
            begin
              cdStar := 1;
              EndPause := TRUE;
            end;
            if Cheat = kbF+kb1+kbF+kb2 then    { F1F2 - Champ }
            begin
              cdChamp := 1;
              EndPause := TRUE;
            end;
            if Cheat = kbF+kbF+kbB+kb5 then    { FFB5 - Flower }
            begin
              cdFlower := 1;
              EndPause := TRUE;
            end;
            if Cheat = kbD+kb2+kb3+kb5 then   { D235 - Turbo mode }
            begin
              Turbo := not Turbo;
              EndPause := TRUE;
            end;
            if Cheat = kb7+kb6+kbD+kbD then   { 76DD - Record demo }
            begin
              RecordMacro;
              EndPause := TRUE;
            end;
            if Cheat = kbC+kb7+kbB+kb4 then   { C7B4 - Play demo }
            begin
              PlayMacro;
              EndPause := TRUE;
            end;
            if Cheat = kb2+kb0+kb8+kbD then   { 208D - Save demo (file: $.) }
            begin
              SaveMacro;
              EndPause := TRUE;
            end;

            if Cheat = kb1+kbU+kbP then   { 1UP }
            begin
            { AddLife; }
              if CheatsUsed and 1 = 0 then
              begin
                NewEnemy (tpLife, 0, XView div W, -1, 2, 0, 2);
                CheatsUsed := CheatsUsed or 1;
              end
              else
              begin
                NewEnemy (tpChamp, 1, (XView + Random (100)) div W,
                  -1, 2 - Random (2), 0, 2);
                if Random (10) = 0 then
                  CheatsUsed := CheatsUsed and not 1;
              end;
              EndPause := TRUE;
            end;
            if Cheat = kb2+kb3+kb0+kb5 then   { 2305 - next level }
            begin
              Passed := TRUE;
              Waiting := TRUE;
              TextCounter := 200;
              PipeCode [1] := #$E7;
              InPipe := TRUE;
              EndPause := TRUE;
            end;
            if Cheat = kbM+kbO+kbN+kbO then  { MONO }
            begin
              PaletteEffect := peBlackWhite;
              RefreshPalette (Palette);
              EndPause := TRUE;
            end;
            if (Cheat = kbE+kbG+kbA+kbM+kbO+kbD+kbE) then  { EGAMODE }
            begin
              PaletteEffect := peEGAMode;
              RefreshPalette (Palette);
              EndPause := TRUE;
            end;
            if (Cheat = kbV+kbG+kbA+kbM+kbO+kbD+kbE) or  { VGAMODE }
               (Cheat = kbC+kbO+kbL+kbO+kbR) then  { COLOR }
            begin
              PaletteEffect := peNoEffect;
              RefreshPalette (Palette);
              EndPause := TRUE;
            end;

            if (Cheat = kbC+kbR+kbE+kbD+kbI+kbT+kbS) then
            begin
              P := @CREDIT;
              Move (P^, PauseText, SizeOf (PauseText));
              for i := 1 to CRED_LEN do
                PauseText[i] := Chr ((Ord (PauseText[i]) - i) - $10 - (((i - 1) mod 8) shl 4));
              if PauseBack <> 0 then
                PopBackGr (PauseBack);
              PauseBack := PushBackGr (XView + 20, 85, 280, 10);
              CenterText (85, PauseText, $0F);
            end;
          end;
        until EndPause;
      end;

      if PauseBack <> 0 then
        PopBackGr (PauseBack);
      SwapPages;

      FadeUp (8);
      Key := #255;
    end;


    procedure DebugMenu;
    { Overlay debug menu — draws on BOTH pages then waits for input.
      Redraws on both pages when selection changes, restores on exit. }
    const
      NUM_DEBUG_ITEMS = 7;
      MENU_X = 20;
      MENU_Y = 42;
      MENU_W = 280;
      MENU_H = 118;
    var
      DebugBack0, DebugBack1: Integer;
      Selected, TargetLevel: Integer;
      Done, Redraw: Boolean;
      Action: Integer;
      MenuItems: array[1..NUM_DEBUG_ITEMS] of string[20];
      n: string[2];

      procedure DrawDebugOverlay;
      var
        di: Integer;
        dl: Byte;
        dy: Integer;
        bx, by: Integer;
      begin
        { Use palette index $08 for border, $09 for dark fill }
        OutPalette ($08, 25, 25, 30);  { Border: dark blue-gray }
        OutPalette ($09, 5, 5, 10);    { Fill: very dark }

        { Draw dark filled box }
        bx := XView + MENU_X;
        by := MENU_Y;
        Fill (bx + 2, by, MENU_W - 4, MENU_H, $09);      { Main fill }
        Fill (bx + 1, by + 1, 1, MENU_H - 2, $09);        { Left edge fill }
        Fill (bx + MENU_W - 2, by + 1, 1, MENU_H - 2, $09); { Right edge fill }

        { Draw border lines }
        Fill (bx + 2, by, MENU_W - 4, 1, $08);             { Top }
        Fill (bx + 2, by + MENU_H - 1, MENU_W - 4, 1, $08); { Bottom }
        Fill (bx, by + 2, 1, MENU_H - 4, $08);             { Left }
        Fill (bx + MENU_W - 1, by + 2, 1, MENU_H - 4, $08); { Right }
        { Rounded corners: 1-pixel steps }
        PutPixel (bx + 1, by + 1, $08);                    { TL }
        PutPixel (bx + MENU_W - 2, by + 1, $08);           { TR }
        PutPixel (bx + 1, by + MENU_H - 2, $08);           { BL }
        PutPixel (bx + MENU_W - 2, by + MENU_H - 2, $08);  { BR }

        SetFont (0, Bold + Shadow);
        OutPalette ($0E, 63, 60, 0);
        OutPalette ($0F, 63, 63, 63);
        OutPalette ($07, 40, 40, 40);
        CenterText (45, 'DEBUG', $0E);
        for di := 1 to NUM_DEBUG_ITEMS do
        begin
          dy := 45 + 12 * di;
          if di = Selected then
          begin
            WriteText (CenterX(MenuItems[di]) - 12, dy, #16, $0E);
            dl := $0F;
          end
          else
            dl := $07;
          CenterText (dy, MenuItems[di], dl);
        end;
      end;

    begin
      PauseBGMusic;
      PauseMusic;

      Selected := 1;
      TargetLevel := Ord(N2) - Ord('0');
      if (TargetLevel < 1) or (TargetLevel > 6) then TargetLevel := 1;
      Done := FALSE;
      Action := 0;
      Key := #0;

      { Build menu items }
      MenuItems[1] := 'TRIGGER GAME OVER';
      MenuItems[2] := 'SKIP TO NEXT LEVEL';
      Str(TargetLevel, n);
      MenuItems[3] := 'SKIP TO LEVEL ' + n;
      MenuItems[4] := 'BACK TO MAIN MENU';
      MenuItems[5] := 'MAX LIVES';
      MenuItems[6] := 'POWER UP';
      MenuItems[7] := 'RESUME';

      { Save background on BOTH pages, draw overlay on BOTH pages }
      { Current page after last ShowPage in game loop has already swapped,
        so we need to draw on current page and then swap+draw on the other. }
      DebugBack0 := PushBackGr (XView + MENU_X, MENU_Y, MENU_W, MENU_H);
      DrawDebugOverlay;
      PresentFrame;

      SwapPages;
      DebugBack1 := PushBackGr (XView + MENU_X, MENU_Y, MENU_W, MENU_H);
      DrawDebugOverlay;
      PresentFrame;
      SwapPages;  { Back to original page }

      repeat
        PollKeyboard;
        WaitRetrace;  { Frame timing }

        Redraw := FALSE;
        case Key of
          kbUpArrow:
            begin
              if Selected = 1 then Selected := NUM_DEBUG_ITEMS
              else Dec(Selected);
              Redraw := TRUE;
            end;
          kbDownArrow:
            begin
              if Selected = NUM_DEBUG_ITEMS then Selected := 1
              else Inc(Selected);
              Redraw := TRUE;
            end;
          kbLeftArrow:
            if Selected = 3 then
            begin
              if TargetLevel > 1 then Dec(TargetLevel)
              else TargetLevel := 6;
              Redraw := TRUE;
            end;
          kbRightArrow:
            if Selected = 3 then
            begin
              if TargetLevel < 6 then Inc(TargetLevel)
              else TargetLevel := 1;
              Redraw := TRUE;
            end;
          kbSP, kbEnter:
            begin
              Action := Selected;
              Done := TRUE;
            end;
          kbEsc, kbF12:
            begin
              Action := 0;
              Done := TRUE;
            end;
        end;
        Key := #0;

        if Redraw and not Done then
        begin
          { Update menu items if changed }
          Str(TargetLevel, n);
          MenuItems[3] := 'SKIP TO LEVEL ' + n;

          { Restore then redraw on both pages }
          if DebugBack0 <> 0 then
            PopBackGr (DebugBack0);
          DebugBack0 := PushBackGr (XView + MENU_X, MENU_Y, MENU_W, MENU_H);
          DrawDebugOverlay;
          PresentFrame;

          SwapPages;
          if DebugBack1 <> 0 then
            PopBackGr (DebugBack1);
          DebugBack1 := PushBackGr (XView + MENU_X, MENU_Y, MENU_W, MENU_H);
          DrawDebugOverlay;
          PresentFrame;
          SwapPages;
        end;
      until Done;

      { Restore backgrounds on both pages }
      if DebugBack0 <> 0 then
        PopBackGr (DebugBack0);
      SwapPages;
      if DebugBack1 <> 0 then
        PopBackGr (DebugBack1);
      SwapPages;

      case Action of
        1: begin  { Trigger Game Over — kill Mario properly }
             Data.Lives[Player] := 1;
             Data.Mode[Player] := mdSmall;
             cdHit := 1;  { MovePlayer will start death demo }
             StopBGMusic;
           end;
        2: begin  { Skip to Next Level }
             PlayWorld := TRUE;
             Passed := TRUE;
             GameDone := TRUE;
             StopBGMusic;
           end;
        3: begin  { Skip to Level N — subtract 2 because main loop will Inc }
             Data.Progress[Player] := TargetLevel - 2;
             PlayWorld := TRUE;
             Passed := TRUE;
             GameDone := TRUE;
             StopBGMusic;
           end;
        4: begin  { Back to Main Menu }
             QuitGame := TRUE;
             StopBGMusic;
           end;
        5: begin  { Max Lives }
             Data.Lives[Player] := 99;
             ResumeBGMusic;
           end;
        6: begin  { Power Up }
             case Data.Mode[Player] of
               mdSmall: cdChamp := 1;
               mdLarge: cdFlower := 1;
               { mdFire: do nothing }
             end;
             ResumeBGMusic;
           end;
      else
        begin  { Resume (Action = 0 or 7) }
          ResumeBGMusic;
        end;
      end;
      Key := #255;
    end;


  begin  { PlayWorld }
    PlayWorld := False;
    Key := #0;

    SetYOffset (YBase);
    SetYStart ($12);
    SetYEnd ($7D);

    ClearPalette;
    LockPal;
    ClearVGAMem;

    TextCounter := 0;

    WorldNumber := N1 + '-' + N2;
    OnlyDraw := (N1 = #0) and (N2 = #0);

    ShowObjects := TRUE;

    InPipe := False;
    PipeCode := '  ';
    Demo := dmNoDemo;

    InitLevelScore;
    FillChar (TotalBackGrAddr, SizeOf (TotalBackGrAddr), #0);
    ShowScore := FALSE;
    ScoreTick := 0;
    InSubWorld := FALSE;
    DemoRecording := FALSE;

    if not Turbo then
    begin
      ReadWorld (Map2, WorldMap, Opt2);
      Swap;
      ReadWorld (Map1, WorldMap, Opt1);
    end
    else
    begin
      ReadWorld (Map2, WorldMap, Opt2b);
      Swap;
      ReadWorld (Map1, WorldMap, Opt1b);
    end;

    with Options do
    begin
      InitPlayer (InitX, InitY, Player);
      MapX := InitX;
      MapY := InitY;
    end;

    XView := 0;
    YView := 0;

    { If playing back a replay with saved position, reposition before draw }
    if PlayingMacro and (MacroHdr.PosX <> 0) then
    begin
      InitPlayer(MacroHdr.PosX, MacroHdr.PosY, Player);
      XView := MacroHdr.ViewX;
      { Restore player powerup mode if saved in header }
      if MacroHdr.Mode in [mdSmall, mdLarge, mdFire] then
        Data.Mode[Player] := MacroHdr.Mode;
    end;

    FillChar (LastXView, SizeOf (LastXView), 0);
    SetView (XView, YView);

  BuildLevel:

    with Options do
    begin
      InitSky (SkyType);
      InitWalls (WallType1, WallType2, WallType3);
      InitPipes (PipeColor);
      InitBackGr (BackGrType, Clouds);
      if Stars <> 0 then
        InitStars;
    end;

    BuildWorld;

    { Start background music for this level }
    if N2 in ['1'..'6'] then
    begin
      if InSubWorld then
        PlaySubLevelMusic
      else
        PlayLevelMusic(Ord(N2) - Ord('0'));
    end;

  Restart:
    ResetStack;

    TextStatus := FALSE;
    InitStatus;

    InitBlocks;
    InitTempObj;
    ClearGlitter;
    ClearEnemies;

    ShowPage;

    GameDone := FALSE;
    Passed := FALSE;

    for i := - StartEnemiesAt to NH + StartEnemiesAt do
    begin
      j := (XView div W) + i;
      StartEnemies (j, 1 - 2 * Byte (j > MapX));
    end;

    SetYOffset (YBase);

    for i := 0 to MAX_PAGE do
    begin
      DrawSky (XView, 0, NH * W, NV * H);

      StartClouds;

      for X := XView div W - 1 to XView div W + NH do
        for Y := 0 to NV - 1 do
          Redraw (X, Y);

      DrawBackGr (TRUE);
      ReadColorMap;

      if Options.Stars <> 0 then
        ShowStars;

      ShowEnemies;
      if not OnlyDraw then
        DrawPlayer;
      ShowPage;
    end;

    { Sync LastXView so the first game-loop frame sees zero delta.
      Without this, replays starting deep in the level get corrupt
      sky/parallax because MoveScreen computes a huge scroll delta. }
    for i := 0 to MAX_PAGE do
      LastXView[i] := XView;

    Demo := dmNoDemo;
    Waiting := FALSE;

    NewPalette (P256^);
    for i := 1 to 100 do  { Waterfalls }
      BlinkPalette;

    SetSkyPalette;
    DrawPalBackGr;
    InitGrass;

    if OnlyDraw then
      Exit;

    UnLockPal;
    FadeUp (64);
    Palettes.ReadPalette (Palette);

    WasPlayingMacro := PlayingMacro;
    TextStatus := Stat and (not WasPlayingMacro);
    if not DemoRecording then
      FillChar(RecHdr, SizeOf(RecHdr), 0);
    FillChar(RecBackGrAddr, SizeOf(RecBackGrAddr), 0);
    jsPausePrev := FALSE;
    jsSoundPrev := FALSE;
    jsStatusPrev := FALSE;

    repeat

      if not PlayingMacro then
      begin

        { Edge-detect gamepad utility buttons and inject scancodes }
        if jsPause and (not jsPausePrev) then Key := #25;   { P }
        if jsSound and (not jsSoundPrev) then Key := #16;   { Q }
        if jsStatus and (not jsStatusPrev) then Key := #31;  { S }
        jsPausePrev := jsPause;
        jsSoundPrev := jsSound;
        jsStatusPrev := jsStatus;

        if Key = #31 then  { S - Status on/off }
        begin
          Stat := not Stat;
          TextStatus := Stat;
          Key := #255;
        end;
        if Key = #16 then  { Q - quiet/sound }
        begin
          if BeeperSound or Buffers.BGMEnabled then
          begin
            BeeperOff;
            Buffers.BGMEnabled := FALSE;
            PauseBGMusic;
          end
          else
          begin
            BeeperOn;
            Beep (80);
            Buffers.BGMEnabled := TRUE;
            ResumeBGMusic;
          end;
          Key := #255;
        end;

        if Key = kbF9 then
        begin
          if not DemoRecording then
          begin
            { Start recording — capture full game state }
            FillChar(RecHdr, SizeOf(RecHdr), 0);
            RecHdr.Level := Data.Progress[Player] mod NUM_LEV;
            RecHdr.Seed := RandSeed;
            GetPlayerPos(RecHdr.PosX, RecHdr.PosY);
            RecHdr.ViewX := XView;
            RecHdr.Mode := Data.Mode[Player];
            RecordMacro;
            DemoRecording := TRUE;
          end
          else
          begin
            { Stop recording and save }
            DemoName := NextDemoName;
            if DemoName <> '' then
              SaveMacroToFile(DemoName, RecHdr);
            DemoRecording := FALSE;
          end;
          Key := #0;
        end;

        if Key in [#197, #198] then  { Pause/Break }
        begin
          PauseMusic;
          repeat
            while Key = #197 do ;
          until kbHit;
        end;
      end
      else
        if Key <> #0 then
        begin
          GameDone := TRUE;
          Passed := TRUE;
        end;


      if TextCounter in [40..40 + MAX_PAGE] then
        ShowObjects := FALSE;

      begin
        HideGlitter;
        if Options.Stars <> 0 then
          HideStars;
        if ShowObjects then
          HideTempObj;
        HideStatus;
        if RecBackGrAddr[CurrentPage] <> 0 then
        begin
          PopBackGr(RecBackGrAddr[CurrentPage]);
          RecBackGrAddr[CurrentPage] := 0;
        end;
        if ShowScore then
          HideTotalBack;
        ErasePlayer;
        if ShowObjects then
        begin
          HideEnemies;
          EraseBlocks;
        end;

      end;

    {  Fade; }
      Inc (LavaCounter);

      if not Waiting then
        if Demo = dmNoDemo then
        begin
          MoveEnemies;
          MovePlayer;
        end
        else
          DoDemo;

      if not Waiting then
        if Passed then
        begin
          if (Demo = dmNoDemo) or (InPipe) then
          begin
            Waiting := TRUE;
            TextCounter := 0;
            StopBGMusic;
            { Auto-save demo recording on level complete }
            if DemoRecording then
            begin
              DemoName := NextDemoName;
              if DemoName <> '' then
                SaveMacroToFile(DemoName, RecHdr);
              DemoRecording := FALSE;
            end;
          end;
          Inc (TextCounter);
          if (not ShowScore) and (TextCounter in [50..50 + MAX_PAGE]) then
          begin
            SetFont (0, Bold + Shadow);
            CenterText (20, PlayerName [Player], $1E);
            SetFont (1, Bold + Shadow);
            CenterText (40, 'STAGE CLEAR!', 31);
            if TextCounter = 50 + MAX_PAGE then
              ShowScore := TRUE;
          end;
        end
        else
          if GameDone then
          begin
            Dec (Data.Lives [Player]);
            Data.Mode [Player] := mdSmall;
            TextCounter := 0;
            Inc (Data.Score[Player], LevelScore);
            Waiting := TRUE;
            GameDone := FALSE;
            StopBGMusic;
          end;

      if Key = #25 then  { P - pause }
        Pause;

      if Key = kbF12 then  { F12 - debug menu }
        DebugMenu;

      if ShowScore and (TextCounter = 120) and (LevelScore > 0) then
      begin
        i := LevelScore - 50;
        if i < 0 then i := 0;
        Inc (Data.Score[Player], LevelScore - i);
        LevelScore := i;
        TextCounter := 119;
        CountingScore := TRUE;
      end
      else
        CountingScore := FALSE;

      if Waiting then
      begin
        Inc (TextCounter);
        if Data.Lives [player] = 0 then
        begin
          if TextCounter in [100..100 + MAX_PAGE] then
          begin
            if TextCounter = 100 then
              PlayGameOverMusic;
            SetFont (0, Bold + Shadow);
            CenterText (20, PlayerName [Player], $1E);
            SetFont (1, Bold + Shadow);
            CenterText (40, 'GAME OVER', 31);
            ShowScore := TRUE;
          end;
          if TextCounter > 350 then
            GameDone := TRUE;
        end
        else
          if Passed then
          begin
            if TextCounter > 250 then
              Waiting := FALSE;
          end
          else
            if TextCounter > 100 then
              GameDone := TRUE;
      end;

      MoveTempObj;
      MoveBlocks;

      if (Key in [kbEsc, #129]) then
      begin
        QuitGame := True;  { Esc }
        StopBGMusic;
      end;

      MoveScreen;
      RunRemove;

      if Options.Horizon < NV then
      begin
        j := Options.Horizon - 1;
        for i := 0 div W to NH do
        begin
          k := XView div W + (i + LavaCounter div 8) mod (NH + 1);
          if WorldMap^ [k, j] = '%'
          then
            Redraw (k, j);
        end;
      end;

      ResetStack;

      begin
        if ShowObjects then
        begin
          DrawBlocks;
          ShowEnemies;
        end;
        DrawPlayer;

        if ShowScore then
          ShowTotalBack;
        if TextStatus then
          ShowStatus;
        if ShowObjects then
          ShowTempObj;
        if Options.Stars <> 0 then
          ShowStars;
        ShowGlitter;

        if DemoRecording then
        begin
          RecBackGrAddr[CurrentPage] := PushBackGr(XView + SCREEN_WIDTH - 30, 16, 30, 12);
          if (SDL_GetTicks div 500) mod 2 = 0 then
          begin
            SetFont(0, Bold + Shadow);
            WriteText(XView + SCREEN_WIDTH - 28, 17, 'REC', 4);
          end;
        end;
      end;

      LastXView [CurrentPage] := XView;

      if ShowRetrace then
        SetPalette (0, 0, 0, 0);

      ShowPage;

      if ShowRetrace then
        SetPalette (0, 63, 63, 63);

      DrawPalBackGr;

      BlinkPalette;

      PlayMusic;

      { Let pipe transitions happen during replay playback so that
        user-recorded replays survive cross-world pipes. The key
        sequence was recorded through the pipe, so playback should
        follow the same path. The old guard aborted ALL replays on
        ANY pipe, which caused replays to end prematurely. }

      { Auto-end demo playback when sequence runs out }
      if WasPlayingMacro and (not PlayingMacro) then
      begin
        ResetKeyBoard;  { Clear stale key states so Mario doesn't jump }
        GameDone := TRUE;
        QuitGame := TRUE;
        StopBGMusic;
      end;

      if InPipe and (not GameDone) and (not Waiting) then
      begin
        StopEnemies;
        ClearGlitter;
        FadeDown (64);
        ClearPalette;
        LockPal;
        ClearVGAMem;

        case PipeCode [1] of
          #$E0: begin
                 FindPipeExit;
                 SDL_Delay (100);
               end;
          #$E1: begin
                 Swap;
                 FindPipeExit;
                 InSubWorld := not InSubWorld;
               end;
          #$E7: begin
                 GameDone := True;
                 PlayWorld := True;
                 StopBGMusic;
               end;

        end;

        InitPlayer (MapX * W + W div 2, (MapY - 1) * H, Player);

        SetView (XView, YView);
        SetYOffset (YBase);

        for i := 0 to MAX_PAGE do
          LastXView [i] := XView;

        if PipeCode [1] in [#$E0] then
          GoTo Restart
        else
          if PipeCode [1] in [#$E1] then
            GoTo BuildLevel;
      end;
    until GameDone or QuitGame;

    SetYOffset (YBase);

    ClearEnemies;
    ClearGlitter;
    FadeDown (64);
    ClearPalette;
    ClearVGAMem;
    StopMusic;
  end;

end.
