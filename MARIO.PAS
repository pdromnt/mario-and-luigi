program Mario;

  { Mario game for the PC by Mike Wiering, 1994-95 }
  { SDL2 port }

  {$A+} {$B-} {$G+} {$I-} {$R-} {$S+} {$V-} {$X+}
  {$APPTYPE GUI}
  {$R mario.res}

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
    sdl2;

  const
    NUM_LEV = 6;
    LAST_LEV = 2 * NUM_LEV - 1;
    MAX_SAVE = 3;
    WAIT_BEFORE_DEMO = 714;

  type
    {$A2}  { Word alignment (TP compatible) — needed for file compatibility }
    SettingsData = record
      Sound: Boolean;
      SLine: Boolean;
      UseJS: Boolean;
      JSDat: JoyRec;
      { Configurable key bindings — SDL keycodes stored as LongInt }
      KeyJump:  LongInt;   { default: SDLK_LALT  }
      KeyRun:   LongInt;   { default: SDLK_LCTRL }
      KeyFire:  LongInt;   { default: SDLK_SPACE }
      KeyPause:  LongInt;   { default: SDLK_p     }
      KeySound:  LongInt;   { default: SDLK_q     }
      KeyStatus: LongInt;   { default: SDLK_s     }
      { Sound settings (v2) }
      BGMOn: Boolean;        { Background music enabled }
      BGMVol: Integer;       { 0-10 }
      SFXVol: Integer;       { 0-10 }
      { Gamepad button bindings (v3) — button indices, -1 = unbound }
      JSBtnJump:   Integer;  { default: 0 }
      JSBtnRun:    Integer;  { default: 1 }
      JSBtnFire:   Integer;  { default: 1 }
      JSBtnPause:  Integer;  { default: 6 (Start) }
      JSBtnSound:  Integer;  { default: -1 (unbound) }
      JSBtnStatus: Integer;  { default: -1 (unbound) }
    end;

    SaveData = record
      Games: array[0..MAX_SAVE - 1] of GameData;
    end;
    {$A+}  { Restore default alignment }

    SettingsFile = file of SettingsData;
    SaveFile = file of SaveData;

  var
    GameNumber: Integer;

  var
    CurPlayer: Integer;
    Passed,
    EndGame: Boolean;
    Settings: SettingsData;
    Saves: SaveData;

  {$I sprites\BLOCK000.inc}

  {$I sprites\INTRO000.inc}
  {$I sprites\INTRO001.inc}
  {$I sprites\INTRO002.inc}

  {$I sprites\START000.inc}
  {$I sprites\START001.inc}

  procedure NewData;
  begin
    with Data do
    begin
      Lives [plMario] := 3;
      Lives [plLuigi] := 3;
      Coins [plMario] := 0;
      Coins [plLuigi] := 0;
      Score [plMario] := 0;
      Score [plLuigi] := 0;
      Progress [plMario] := 0;
      Progress [plLuigi] := 0;
      Mode [plMario] := mdSmall;
      Mode [plLuigi] := mdSmall;
    end;
  end;

  procedure ApplyDefaultKeyBindings;
  begin
    Settings.KeyJump  := LongInt(SDLK_LALT);
    Settings.KeyRun   := LongInt(SDLK_LCTRL);
    Settings.KeyFire  := LongInt(SDLK_SPACE);
    Settings.KeyPause  := LongInt(SDLK_p);
    Settings.KeySound  := LongInt(SDLK_q);
    Settings.KeyStatus := LongInt(SDLK_s);
  end;

  procedure ApplyKeyBindings;
  { Copy key bindings from Settings record to Keyboard unit variables }
  begin
    Keyboard.BindJump  := Settings.KeyJump;
    Keyboard.BindRun   := Settings.KeyRun;
    Keyboard.BindFire  := Settings.KeyFire;
    Keyboard.BindPause  := Settings.KeyPause;
    Keyboard.BindSound  := Settings.KeySound;
    Keyboard.BindStatus := Settings.KeyStatus;
  end;

  procedure ApplyDefaultJSBindings;
  begin
    Settings.JSBtnJump   := 0;
    Settings.JSBtnRun    := 1;
    Settings.JSBtnFire   := 1;
    Settings.JSBtnPause  := 6;
    Settings.JSBtnSound  := -1;
    Settings.JSBtnStatus := -1;
  end;

  procedure ApplyJSBindings;
  { Copy gamepad bindings from Settings record to Joystick unit variables }
  begin
    Joystick.BindJSJump   := Settings.JSBtnJump;
    Joystick.BindJSRun    := Settings.JSBtnRun;
    Joystick.BindJSFire   := Settings.JSBtnFire;
    Joystick.BindJSPause  := Settings.JSBtnPause;
    Joystick.BindJSSound  := Settings.JSBtnSound;
    Joystick.BindJSStatus := Settings.JSBtnStatus;
  end;

  procedure DebugLog(const Msg: string);
  var
    F: Text;
    Dummy: Integer;
  begin
    Assign(F, 'debug.log');
    Append(F);
    if IOResult <> 0 then
    begin
      ReWrite(F);
      if IOResult <> 0 then Exit;  { Can't open log at all }
    end;
    WriteLn(F, Msg);
    Close(F);
    Dummy := IOResult;  { Always consume IOResult so it never leaks }
  end;

  function GetKeyNameStr(kc: LongInt): string;
  { Convert SDL keycode to uppercase display name, max 12 chars }
  var
    P: PAnsiChar;
    S: string;
    i: Integer;
  begin
    if kc = 0 then
    begin
      GetKeyNameStr := '???';
      Exit;
    end;
    P := SDL_GetKeyName(kc);
    if P = nil then
    begin
      GetKeyNameStr := '???';
      Exit;
    end;
    S := '';
    i := 0;
    while (P[i] <> #0) and (i < 12) do
    begin
      if (P[i] >= 'a') and (P[i] <= 'z') then
        S := S + Chr(Ord(P[i]) - 32)
      else
        S := S + P[i];
      Inc(i);
    end;
    if S = '' then S := '???';
    GetKeyNameStr := S;
  end;

  function GetConfigName: string;
    var
      S: string;
      Len: byte absolute S;
  begin
    S := ParamStr (0);
    if Len >= 3 then
    begin
      S[Len - 2] := 'C';
      S[Len - 1] := 'F';
      S[Len - 0] := 'G';
    end
    else
      S := 'MARIO.CFG';
    GetConfigName := S;
  end;

  function GetSaveName: string;
    var
      S: string;
      Len: byte absolute S;
  begin
    S := ParamStr (0);
    if Len >= 3 then
    begin
      S[Len - 2] := 'S';
      S[Len - 1] := 'A';
      S[Len - 0] := 'V';
    end
    else
      S := 'MARIO.SAV';
    GetSaveName := S;
  end;

  procedure ReadConfig;
    var
      i: Integer;
      UF: File;
      FS: SaveFile;
      SettingsOK, SavesOK: Boolean;
      FileBytes, ReadBytes: LongInt;
  begin
    SettingsOK := FALSE;
    SavesOK := FALSE;

    { Zero the settings record BEFORE reading to prevent stale data }
    FillChar(Settings, SizeOf(Settings), 0);

  {$IFDEF MENU}
    { Consume any stale IOResult }
    i := IOResult;

    { Read settings (MARIO.CFG) using untyped file for backward compat }
    Assign (UF, GetConfigName);
    Reset (UF, 1);
    if IOResult = 0 then
    begin
      FileBytes := FileSize(UF);
      if FileBytes > SizeOf(Settings) then
        FileBytes := SizeOf(Settings);
      if FileBytes > 0 then
      begin
        BlockRead(UF, Settings, FileBytes, ReadBytes);
        SettingsOK := (IOResult = 0) and (ReadBytes = FileBytes);
      end;
      Close (UF);
      i := IOResult;
    end;

    { Consume any stale IOResult before next file }
    i := IOResult;

    { Read save games (MARIO.SAV) }
    Assign (FS, GetSaveName);
    Reset (FS);
    if IOResult = 0 then
    begin
      Read (FS, Saves);
      if IOResult = 0 then
      begin
        Close (FS);
        SavesOK := IOResult = 0;
      end
      else
      begin
        Close (FS);
        i := IOResult;
      end;
    end;
  {$ENDIF}

    if not SettingsOK then
    begin
      with Settings do
      begin
        SLine := TRUE;
        Sound := TRUE;
        UseJS := FALSE;
      end;
      ApplyDefaultKeyBindings;
    end;

    { Validate key bindings — old config files won't have them (fields = 0) }
    if Settings.KeyJump = 0 then
      ApplyDefaultKeyBindings;
    { KeyStatus added later — old configs may have valid Jump..Sound but no Status }
    if Settings.KeyStatus = 0 then
      Settings.KeyStatus := LongInt(SDLK_s);
    { Sound settings added later — old configs have BGMVol=0 }
    if Settings.BGMVol = 0 then
    begin
      Settings.BGMOn := TRUE;
      Settings.BGMVol := 5;
      Settings.SFXVol := 10;
    end;
    { Gamepad bindings added later — old configs have all zeros.
      Real configs always have JSBtnPause=6 and JSBtnSound=-1, so
      all-zeros means old format needing defaults. }
    if (Settings.JSBtnJump = 0) and (Settings.JSBtnRun = 0)
      and (Settings.JSBtnFire = 0) and (Settings.JSBtnPause = 0)
      and (Settings.JSBtnSound = 0) and (Settings.JSBtnStatus = 0) then
      ApplyDefaultJSBindings;

    if not SavesOK then
    begin
      NewData;
      for i := 0 to MAX_SAVE - 1 do
        Saves.Games[i] := Data;
      GameNumber := -1;
    end;

    with Settings do
    begin
      Play.Stat := SLine;
      Buffers.BeeperSound := Sound;
      Buffers.BGMEnabled := BGMOn;
      Buffers.BGMVolume := BGMVol;
      Buffers.SFXVolume := SFXVol;
      Buffers.ApplySFXVolume;
    end;

    ApplyKeyBindings;
    ApplyJSBindings;
  end;

  procedure WriteConfig;
    var
      FC: SettingsFile;
      FS: SaveFile;
      Dummy: Integer;
  begin
    with Settings do
    begin
      SLine := Play.Stat;
      Sound := Buffers.BeeperSound;
      BGMOn := Buffers.BGMEnabled;
      BGMVol := Buffers.BGMVolume;
      SFXVol := Buffers.SFXVolume;
    end;
    { Copy current key bindings from Keyboard unit to Settings for saving }
    Settings.KeyJump  := LongInt(Keyboard.BindJump);
    Settings.KeyRun   := LongInt(Keyboard.BindRun);
    Settings.KeyFire  := LongInt(Keyboard.BindFire);
    Settings.KeyPause  := LongInt(Keyboard.BindPause);
    Settings.KeySound  := LongInt(Keyboard.BindSound);
    Settings.KeyStatus := LongInt(Keyboard.BindStatus);
    { Copy current gamepad bindings from Joystick unit to Settings }
    Settings.JSBtnJump   := Joystick.BindJSJump;
    Settings.JSBtnRun    := Joystick.BindJSRun;
    Settings.JSBtnFire   := Joystick.BindJSFire;
    Settings.JSBtnPause  := Joystick.BindJSPause;
    Settings.JSBtnSound  := Joystick.BindJSSound;
    Settings.JSBtnStatus := Joystick.BindJSStatus;
  {$IFDEF MENU}
    { Consume any stale IOResult before file operations }
    Dummy := IOResult;

    { Write settings (MARIO.CFG) }
    Assign (FC, GetConfigName);
    ReWrite (FC);
    if IOResult = 0 then
    begin
      Write (FC, Settings);
      Close (FC);
      Dummy := IOResult;
    end;

    { Consume any stale IOResult before next file }
    Dummy := IOResult;

    { Write save games (MARIO.SAV) }
    Assign (FS, GetSaveName);
    ReWrite (FS);
    if IOResult = 0 then
    begin
      Write (FS, Saves);
      Close (FS);
      Dummy := IOResult;
    end;
  {$ENDIF}
  end;

  procedure CalibrateJoystick;
  begin
    SDL_Delay (100);
    System.WriteLn ('Rotate joystick and press button');
    System.WriteLn ('or press any key to use keyboard...');
    SDL_Delay (100);
    Key := #0;
    repeat
      Calibrate;
    until jsButton1 or jsButton2 or (Key <> #0);
    System.WriteLn;
    if (Key <> #0) then
    begin
      jsEnabled := FALSE;
      ReadJoystick;
    end;
    Settings.UseJS := jsEnabled;
    Settings.JSDat := jr;
    Key := #0;
  end;

  procedure ReadCmdLine;
    var
      i, j: Integer;
      S: String;
  begin
    for i := 1 to ParamCount do
    begin
      S := ParamStr (i);
      while S <> '' do
      begin
        if (Length (S) >= 2) and (S[1] in ['/', '-'])
        then
        begin
          case UpCase (S[2]) of
            'S': Play.Stat := TRUE;
            'Q': BeeperOff;
            'J': CalibrateJoystick;

          end;
          Delete (S, 1, 2);
        end
        else
          Delete (S, 1, 1);
      end;
    end;
  end;

  procedure Demo;
  begin
    NewData;
    Turbo := FALSE;
    Data.Progress [plMario] := 5;
    PlayMacro;
    PlayWorld (' ', ' ', Level_6a_Data, Options_6a_Data, Options_6a_Data,
      Level_6b_Data, Options_6b_Data, Options_6b_Data, plMario);
    StopMacro;
  end;

  procedure Intro;
    var
      P, i, j, k, l, wd, ht, xp: Integer;
      NextNumPlayers,
      Selected: Integer;
      IntroDone,
      TestVGAMode,
      Update: Boolean;
      Counter: Integer;
      MacroKey: Char;
      Status,
      OldStatus,
      LastStatus: (ST_NONE,
                   ST_MENU,
                   ST_START,
                   ST_LOAD,
                   ST_ERASE,
                   ST_OPTIONS,
                   ST_NUMPLAYERS,
                   ST_KEYS,
                   ST_SOUND,
                   ST_GAMEPAD);
      Menu: array[1..7] of string[40];
      KeyVal: array[1..6] of string[14];   { Key name for ST_KEYS items }
      JSVal:  array[1..6] of string[14];   { Button name for ST_GAMEPAD items }
      VolStr: string[2];                   { For displaying volume values }
      BG: array[0..MAX_PAGE, 1..7] of Word;
      NumOptions: Integer;
      WaitingForKey: Integer;
      WaitingForJSButton: Integer;
      Page: Byte;

    procedure Up;
    begin
      if Selected = 1 then
        Selected := NumOptions
      else
        Dec (Selected);
    end;

    procedure Down;
    begin
      if Selected = NumOptions then
        Selected := 1
      else
        Inc (Selected);
    end;

  begin
    Page := CurrentPage;
    Status := ST_NONE;
    TestVGAMode := FALSE;
    GameNumber := -1;
    NextNumPlayers := Data.NumPlayers;
    WaitingForKey := 0;
    WaitingForJSButton := 0;
    FillChar(KeyVal, SizeOf(KeyVal), 0);
    FillChar(JSVal, SizeOf(JSVal), 0);

    repeat
      if TestVGAMode then
        InitVGA;
      TestVGAMode := FALSE;
      IntroDone := FALSE;
      NewData;

      PlayWorld (#0, #0, Intro_0_Data, Options_0_Data, Options_0_Data,
        Intro_0_Data, Options_0_Data, Options_0_Data, plMario);
      InitBackGr (3, 0);

      OutPalette ($A0, 35, 45, 50);
      OutPalette ($A1, 45, 55, 60);

      OutPalette ($EF, 30, 40, 30);
      OutPalette ($18, 10, 15, 25);

      OutPalette ($8D, 28, 38, 50);
      OutPalette ($8F, 40, 50, 63);

      for i := 1 to 50 do
        BlinkPalette;

      for P := 0 to MAX_PAGE do
      begin
        for i := 1 downto 0 do
          for j := 1 downto 0 do
            for k := 1 downto 0 do
            begin
              DrawImage (38 + i + j, 29 + i + k, 108, 28, Intro000);
              DrawImage (159 + i + j, 29 + i + k, 24, 28, Intro001);
              DrawImage (198 + i + j, 29 + i + k, 84, 28, Intro002);
            end;

        DrawBackGrMap (10 * H + 6, 11 * H - 1, 54, $A0);
        DrawBackGrMap (10 * H + 6, 11 * H - 1, 55, $A1);
        DrawBackGrMap (10 * H + 6, 11 * H - 1, 53, $A1);
        for i := 0 to NH - 1 do
          for j := 0 to NV - 1 do
            if (i in [0, NH - 1]) or (j in [0, NV - 1]) then
              DrawImage (i * W, j * H, W, H, Block000);
        DrawPlayer;
        ShowPage;
      end;
      UnlockPal;
      Key := #0;
      FadeUp (64);
      ResetStack;

      FillChar (BG, SizeOf (BG), 0);
      FillChar (Menu, SizeOf (Menu), 0);
      SetFont (0, Bold + Shadow);
      PlayMenuMusic;

      if Status <> ST_OPTIONS then
      begin
        OldStatus := ST_NONE;
        LastStatus := ST_NONE;
        Status := ST_MENU;
        Selected := 1;
      end;
      UpDate := TRUE;

      Counter := 1;
      repeat

        if UpDate or (Status <> OldStatus) then
        begin
          if (Status <> OldStatus) then
            Selected := 1;
          case Status of
            ST_MENU:
              begin
                 Menu[1] := 'START';
                 Menu[2] := 'OPTIONS';
                 Menu[3] := 'END';
                 Menu[4] := '';
                 Menu[5] := '';
                 Menu[6] := '';
                 Menu[7] := '';
                 NumOptions := 3;
                 LastStatus := ST_MENU;
               end;
            ST_OPTIONS:
              begin
                 Menu[1] := 'SOUND >';
                 if Play.Stat then
                   Menu[2] := 'STATUSLINE ON '
                 else
                   Menu[2] := 'STATUSLINE OFF';
                 Menu[3] := 'KEYBOARD';
                 Menu[4] := 'GAMEPAD';
                 Menu[5] := 'BACK';
                 Menu[6] := '';
                 Menu[7] := '';
                 NumOptions := 5;
                 LastStatus := ST_MENU;
              end;
            ST_KEYS:
              begin
                 Menu[1] := 'JUMP';
                 Menu[2] := 'RUN';
                 Menu[3] := 'FIRE';
                 Menu[4] := 'PAUSE';
                 Menu[5] := 'SOUND';
                 Menu[6] := 'STATUS';
                 Menu[7] := 'BACK';
                 { Only rebuild key names when NOT waiting for input }
                 if WaitingForKey = 0 then
                 begin
                   KeyVal[1] := GetKeyNameStr(Settings.KeyJump);
                   KeyVal[2] := GetKeyNameStr(Settings.KeyRun);
                   KeyVal[3] := GetKeyNameStr(Settings.KeyFire);
                   KeyVal[4] := GetKeyNameStr(Settings.KeyPause);
                   KeyVal[5] := GetKeyNameStr(Settings.KeySound);
                   KeyVal[6] := GetKeyNameStr(Settings.KeyStatus);
                 end;
                 NumOptions := 7;
                 LastStatus := ST_OPTIONS;
              end;
            ST_SOUND:
              begin
                 if Buffers.BGMEnabled then
                   Menu[1] := 'BGM ON '
                 else
                   Menu[1] := 'BGM OFF';
                 if BeeperSound then
                   Menu[2] := 'SFX ON '
                 else
                   Menu[2] := 'SFX OFF';
                 Str(Buffers.BGMVolume, VolStr);
                 Menu[3] := 'BGM VOLUME '#7' ' + VolStr;
                 Str(Buffers.SFXVolume, VolStr);
                 Menu[4] := 'SFX VOLUME '#7' ' + VolStr;
                 Menu[5] := 'BACK';
                 Menu[6] := '';
                 Menu[7] := '';
                 NumOptions := 5;
                 LastStatus := ST_OPTIONS;
              end;
            ST_GAMEPAD:
              begin
                 Menu[1] := 'JUMP';
                 Menu[2] := 'RUN';
                 Menu[3] := 'FIRE';
                 Menu[4] := 'PAUSE';
                 Menu[5] := 'SOUND';
                 Menu[6] := 'STATUS';
                 Menu[7] := 'BACK';
                 if WaitingForJSButton = 0 then
                 begin
                   JSVal[1] := GetJSButtonName(Settings.JSBtnJump);
                   JSVal[2] := GetJSButtonName(Settings.JSBtnRun);
                   JSVal[3] := GetJSButtonName(Settings.JSBtnFire);
                   JSVal[4] := GetJSButtonName(Settings.JSBtnPause);
                   JSVal[5] := GetJSButtonName(Settings.JSBtnSound);
                   JSVal[6] := GetJSButtonName(Settings.JSBtnStatus);
                 end;
                 NumOptions := 7;
                 LastStatus := ST_OPTIONS;
              end;
            ST_START:
              begin
                 Menu[1] := 'NO SAVE';
                 Menu[2] := 'GAME SELECT';
                 Menu[3] := 'ERASE';
                 Menu[4] := 'BACK';
                 Menu[5] := '';
                 Menu[6] := '';
                 Menu[7] := '';
                 NumOptions := 4;
                 LastStatus := ST_MENU;
               end;
            ST_NUMPLAYERS:
              begin
                 Menu[1] := 'ONE PLAYER';
                 Menu[2] := 'TWO PLAYERS';
                 Menu[3] := 'BACK';
                 Menu[4] := '';
                 Menu[5] := '';
                 Menu[6] := '';
                 Menu[7] := '';
                 if (Status <> OldStatus) then
                   Selected := Data.NumPlayers;
                 NumOptions := 3;
                 LastStatus := ST_START;
               end;
            ST_LOAD,
            ST_ERASE:
              begin
                 Menu[1] := 'GAME #1 '#7' ';
                 Menu[2] := 'GAME #2 '#7' ';
                 Menu[3] := 'GAME #3 '#7' ';
                 Menu[5] := '';
                 Menu[6] := '';
                 Menu[7] := '';
                 for i := 1 to 3 do
                   with Saves.Games[i - 1] do
                     if (Progress[plMario] = 0) and (Progress[plLuigi] = 0) then
                       Menu[i] := Menu[i] + 'EMPTY'
                     else
                     begin
                       j := Progress[plMario];
                       k := Byte (Progress [CurPlayer] >= NUM_LEV);
                       if k > 0 then
                         Dec (j, NUM_LEV);
                       if Progress[plLuigi] > j then
                       begin
                         j := Progress[plLuigi];
                         Progress[plMario] := j;
                       end;
                       Menu[i] := Menu[i] +
                         'LEVEL ' + Chr (j + Ord ('0') + 1) + ' ';
                       if k = 0 then
                         Menu[i] := Menu[i] + #7' '
                       else
                         Menu[i] := Menu[i] + '* ';
                       Menu[i] := Menu[i] +
                         Chr (NumPlayers + Ord ('0')) + 'P';
                     end;
                 Menu[4] := 'BACK';
                 NumOptions := 4;
                 LastStatus := ST_START;
               end;


          end;
          wd := 0;
          xp := 0;
          if (Status = ST_KEYS) or (Status = ST_GAMEPAD) then
          begin
            { Fixed layout for controls: label + dot + keyname/btnname }
            { Widest full line ~152px + 20px arrow area = 172px }
            wd := 152;
          end
          else
          begin
            for i := 1 to 7 do
            begin
              j := TextWidth (Menu[i]);
              if j > wd then
                wd := j;
            end;
          end;
          ht := 8;
          { Center the visual block (arrow + gap + text) on screen:
            arrow at xp-12, text at xp+8, total = 20 + wd pixels }
          xp := (SCREEN_WIDTH - 20 - wd) div 2 + 12;
          OldStatus := Status;
          Update := FALSE;
        end;

        MacroKey := #0;

        { Key assignment mode: capture next keypress for binding }
        if (Status = ST_KEYS) and (WaitingForKey > 0) then
        begin
          if Keyboard.LastKeyCode <> SDLK_UNKNOWN then
          begin
            { Reject non-remappable keys (needed for menu navigation) }
            if (Keyboard.LastKeyCode <> SDLK_ESCAPE)
              and (Keyboard.LastKeyCode <> SDLK_RETURN)
              and (Keyboard.LastKeyCode <> SDLK_UP)
              and (Keyboard.LastKeyCode <> SDLK_DOWN)
              and (Keyboard.LastKeyCode <> SDLK_LEFT)
              and (Keyboard.LastKeyCode <> SDLK_RIGHT) then
            begin
              case WaitingForKey of
                1: Settings.KeyJump   := LongInt(Keyboard.LastKeyCode);
                2: Settings.KeyRun    := LongInt(Keyboard.LastKeyCode);
                3: Settings.KeyFire   := LongInt(Keyboard.LastKeyCode);
                4: Settings.KeyPause  := LongInt(Keyboard.LastKeyCode);
                5: Settings.KeySound  := LongInt(Keyboard.LastKeyCode);
                6: Settings.KeyStatus := LongInt(Keyboard.LastKeyCode);
              end;
              ApplyKeyBindings;
              WaitingForKey := 0;
            end
            else if Keyboard.LastKeyCode = SDLK_ESCAPE then
              WaitingForKey := 0;  { Cancel assignment }
          end;
          Key := #0;
          Keyboard.LastKeyCode := SDLK_UNKNOWN;
          Update := TRUE;
        end
        else if (Status = ST_GAMEPAD) and (WaitingForJSButton > 0) then
        begin
          { Gamepad button assignment mode: capture next button press }
          ReadJoystick;
          if Joystick.LastJSButton >= 0 then
          begin
            case WaitingForJSButton of
              1: Settings.JSBtnJump   := Joystick.LastJSButton;
              2: Settings.JSBtnRun    := Joystick.LastJSButton;
              3: Settings.JSBtnFire   := Joystick.LastJSButton;
              4: Settings.JSBtnPause  := Joystick.LastJSButton;
              5: Settings.JSBtnSound  := Joystick.LastJSButton;
              6: Settings.JSBtnStatus := Joystick.LastJSButton;
            end;
            ApplyJSBindings;
            WaitingForJSButton := 0;
          end;
          if Key = kbEsc then
            WaitingForJSButton := 0;
          Key := #0;
          Keyboard.LastKeyCode := SDLK_UNKNOWN;
          Update := TRUE;
        end
        else
        begin
          { Normal menu key processing }
          case Key of
            kbEsc:
              if Status = ST_MENU then
              begin
                IntroDone := TRUE;
                QuitGame := TRUE;
              end
              else
                Status := LastStatus;
            kbUpArrow:
              Up;
            kbDownArrow:
              Down;
            kbLeftArrow:
              if Status = ST_SOUND then
              begin
                case Selected of
                  3: if Buffers.BGMVolume > 0 then
                     begin
                       Dec(Buffers.BGMVolume);
                       ApplyBGMVolume;
                     end;
                  4: if Buffers.SFXVolume > 0 then
                     begin
                       Dec(Buffers.SFXVolume);
                       ApplySFXVolume;
                     end;
                end;
              end;
            kbRightArrow:
              if Status = ST_SOUND then
              begin
                case Selected of
                  3: if Buffers.BGMVolume < 10 then
                     begin
                       Inc(Buffers.BGMVolume);
                       ApplyBGMVolume;
                     end;
                  4: if Buffers.SFXVolume < 10 then
                     begin
                       Inc(Buffers.SFXVolume);
                       ApplySFXVolume;
                     end;
                end;
              end;
            kbSP,
            kbEnter:
              case Status of

                ST_MENU:
                  case Selected of
                    1: Status := ST_START;
                    2: Status := ST_OPTIONS;
                    3: begin
                         IntroDone := TRUE;
                         QuitGame := TRUE;
                       end;
                  end;

                ST_START:
                  case Selected of
                    1: Status := ST_NUMPLAYERS;
                    2: Status := ST_LOAD;
                    3: Status := ST_ERASE;
                    4: Status := LastStatus;
                  end;

                ST_OPTIONS:
                  case Selected of
                    1: Status := ST_SOUND;
                    2: Play.Stat := not Play.Stat;
                    3: begin
                         Status := ST_KEYS;
                         WaitingForKey := 0;
                       end;
                    4: begin
                         Status := ST_GAMEPAD;
                         WaitingForJSButton := 0;
                       end;
                    5: Status := LastStatus;
                  end;

                ST_KEYS:
                  if Selected = 7 then
                    Status := LastStatus
                  else
                  begin
                    { Start waiting for key assignment }
                    WaitingForKey := Selected;
                    KeyVal[WaitingForKey] := '...';
                    Keyboard.LastKeyCode := SDLK_UNKNOWN;
                  end;

                ST_GAMEPAD:
                  if Selected = 7 then
                    Status := LastStatus
                  else
                  begin
                    { Start waiting for gamepad button assignment }
                    WaitingForJSButton := Selected;
                    JSVal[WaitingForJSButton] := '...';
                    Joystick.LastJSButton := -1;
                  end;

                ST_SOUND:
                  case Selected of
                    1: begin  { BGM ON/OFF }
                         Buffers.BGMEnabled := not Buffers.BGMEnabled;
                         if Buffers.BGMEnabled then
                         begin
                           ResetCurrentTrack;
                           PlayMenuMusic;
                         end
                         else
                           StopBGMusic;
                       end;
                    2: begin  { SFX ON/OFF }
                         if BeeperSound then
                           BeeperOff
                         else
                           BeeperOn;
                       end;
                    3: begin end;  { BGM VOLUME: use Left/Right }
                    4: begin end;  { SFX VOLUME: use Left/Right }
                    5: Status := LastStatus;
                  end;

                ST_NUMPLAYERS:
                  case Selected of
                    1: begin
                         NextNumPlayers := 1;
                         IntroDone := TRUE;
                       end;
                    2: begin
                         NextNumPlayers := 2;
                         IntroDone := TRUE;
                       end;
                    3: Status := LastStatus;
                  end;

                ST_LOAD:
                  if Selected = 4 then
                    Status := LastStatus
                  else
                  begin
                    GameNumber := Selected - 1;
                    Saves.Games[GameNumber].NumPlayers := 1;
                    with Saves.Games[GameNumber] do
                      if (Progress[plMario] = 0) and (Progress[plLuigi] = 0) then
                        Status := ST_NUMPLAYERS
                      else
                      begin
                        IntroDone := TRUE;
                        NextNumPlayers := Saves.Games[GameNumber].NumPlayers;
                      end;
                  end;

                ST_ERASE:
                  if Selected = 4 then
                    Status := LastStatus
                  else
                  begin
                    NewData;
                    Saves.Games[Selected - 1] := Data;
                    Saves.Games[Selected - 1].NumPlayers := 1;
                    GameNumber := -1;
                  end;

              end;
          end;
        end;
        if Key <> #0 then
        begin
          Counter := 0;
          Key := MacroKey;
          Update := TRUE;
        end;

        { Restore backgrounds for ALL 7 rows (not just active items).
          This ensures stale text from a previous state with more items
          is properly cleaned up on both double-buffer pages. }
        for k := 1 to 7 do
          if BG[Page, k] <> 0 then
            PopBackGr (BG[Page, k]);

        for k := 1 to 7 do
        begin
          i := xp;
          j := 56 + 14 * k;
          { Always save background for all 7 rows so PopBackGr can
            clean them up even when the new state has fewer items }
          BG[Page, k] := PushBackGr (0, j, SCREEN_WIDTH, ht + 2);
          if Menu[k] <> '' then
          begin
            if k = Selected then
              WriteText (i - 12, j, #16, 5);
            l := 15;
            if (Length (Menu[k]) > 19) and (Menu[k][19] = '*') then
              l := 14 + (Counter and 1);
            SetPalette (14, 63, 61, 31);
            WriteText (i + 8, j, Menu[k], l);
            { ST_KEYS items 1-6: draw dot + key name at fixed column }
            { Guard: only draw values after setup has run (OldStatus = Status) }
            if (Status = ST_KEYS) and (OldStatus = ST_KEYS) and (k <= 6) then
            begin
              if (WaitingForKey = k) then
              begin
                { Blink "..." while waiting for key input }
                if (SDL_GetTicks div 300) mod 2 = 0 then
                  WriteText (i + 64, j, #7' ...         ', l)
                else
                  WriteText (i + 64, j, #7'              ', l);
              end
              else
                WriteText (i + 64, j, #7' ' + KeyVal[k], l);
            end;
            if (Status = ST_GAMEPAD) and (OldStatus = ST_GAMEPAD) and (k <= 6) then
            begin
              if (WaitingForJSButton = k) then
              begin
                { Blink "..." while waiting for gamepad button }
                if (SDL_GetTicks div 300) mod 2 = 0 then
                  WriteText (i + 64, j, #7' ...         ', l)
                else
                  WriteText (i + 64, j, #7'              ', l);
              end
              else
                WriteText (i + 64, j, #7' ' + JSVal[k], l);
            end;
          end;
        end;
        ShowPage;
        BlinkPalette;
        ResetStack;

        { Only count toward demo timeout on the main menu }
        if Status = ST_MENU then
          Inc (Counter);
      until IntroDone or (Counter = WAIT_BEFORE_DEMO);
      FadeDown (64);

      if not IntroDone then
        Demo;
    until IntroDone and (not TestVGAMode);

    if GameNumber <> -1 then
      Data := Saves.Games[GameNumber];
    Data.NumPlayers := NextNumPlayers;
  end;  { Intro }


  procedure ShowPlayerName (Player: Byte);
    var
      iW, iH, i: Integer;
  begin
    ClearPalette;
    LockPal;
    ClearVGAMem;
    SetView (0, 0);
    iH := 13;
    for i := 0 to MAX_PAGE do
    begin
      case Player of
        plMario:
          begin
            iW := 116;
            DrawImage (160 - iW div 2, 85 - iH div 2, iW, iH, Start000);
          end;
        plLuigi:
          begin
            iW := 108;
            DrawImage (160 - iW div 2, 85 - iH div 2, iW, iH, Start001);
          end;
      end;
      ShowPage;
    end;
    NewPalette (P256^);
    UnLockPal;
    Palettes.ReadPalette (Palette);
    for i := 1 to 100 do
      ShowPage;
    ClearPalette;
    ClearVGAMem;
  end;

  var
    OldExitProc: Pointer;

  procedure CleanupOnExit; far;
  begin
    ExitProc := OldExitProc;  { Restore previous exit proc }
    WriteConfig;
    ShutdownBGMusic;
  end;

begin  { Mario }
  InitKeyBoard;
  InitWorlds;
  Data.NumPlayers := 1;
  ReadConfig;
  ReadCmdLine;

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
              0: Passed := PlayWorld ('x', '1', Level_1a_Data, Options_1a_Data, Opt_1a_Data,
                   Level_1b_Data, Options_1b_Data, Options_1b_Data, CurPlayer);
              1: Passed := PlayWorld ('x', '2', Level_2a_Data, Options_2a_Data, Opt_2a_Data,
                   Level_2b_Data, Options_2b_Data, Options_2b_Data, CurPlayer);
              2: Passed := PlayWorld ('x', '3', Level_3a_Data, Options_3a_Data, Opt_3a_Data,
                   Level_3b_Data, Options_3b_Data, Options_3b_Data, CurPlayer);
              3: Passed := PlayWorld ('x', '4', Level_5a_Data, Options_5a_Data, Opt_5a_Data,
                   Level_5b_Data, Options_5b_Data, Options_5b_Data, CurPlayer);
              4: Passed := PlayWorld ('x', '5', Level_6a_Data, Options_6a_Data, Opt_6a_Data,
                   Level_6b_Data, Options_6b_Data, Options_6b_Data, CurPlayer);
              5: Passed := PlayWorld ('x', '6', Level_4a_Data, Options_4a_Data, Opt_4a_Data,
                   Level_4b_Data, Options_4b_Data, Options_4b_Data, CurPlayer);
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

    if GameNumber <> -1 then
      Saves.Games[GameNumber] := Data;

{$IFDEF MENU}
  until QuitGame;
{$ENDIF}
  ShutdownBGMusic;
  WriteConfig;
end.
