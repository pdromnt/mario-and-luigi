unit Config;

{ Configuration, save-game data, key bindings, and command-line parsing.
  Extracted from MARIO.PAS. }

{$A+} {$B-} {$G+} {$I-} {$R-} {$S+} {$V-} {$X+}

interface

  uses
    Buffers, Play, Keyboard, Joystick, AssetPaths, BGMusic, sdl2;

  const
    MAX_SAVE = 3;

  type
    {$A2}  { Word alignment (TP compatible) -- needed for file compatibility }
    SettingsData = record
      Sound: Boolean;
      SLine: Boolean;
      UseJS: Boolean;
      JSDat: JoyRec;
      { Configurable key bindings -- SDL keycodes stored as LongInt }
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
      { Gamepad button bindings (v3) -- button indices, -1 = unbound }
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
    Settings: SettingsData;
    Saves: SaveData;
    TestPlayMode: Boolean;
    TestPlayPath: string[255];
    GameNumber: Integer;
    CurPlayer: Integer;
    Passed,
    EndGame: Boolean;

  function GetUserDataDir: string;
  function GetConfigName: string;
  function GetSaveName: string;
  function GetKeyNameStr(kc: LongInt): string;

  procedure ApplyDefaultKeyBindings;
  procedure ApplyKeyBindings;
  procedure ApplyDefaultJSBindings;
  procedure ApplyJSBindings;
  procedure ReadConfig;
  procedure WriteConfig;
  procedure CalibrateJoystick;
  procedure ReadCmdLine;
  procedure NewData;

implementation

  function GetUserDataDir: string;
  begin
    GetUserDataDir := AssetPaths.GetSaveDataDir;
  end;

  function GetConfigName: string;
  begin
    GetConfigName := GetUserDataDir + 'MARIO.CFG';
  end;

  function GetSaveName: string;
  begin
    GetSaveName := GetUserDataDir + 'MARIO.SAV';
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
    Settings.KeyJump  := LongInt(SDLK_x);
    Settings.KeyRun   := LongInt(SDLK_z);
    Settings.KeyFire  := LongInt(SDLK_c);
    Settings.KeyPause  := LongInt(SDLK_RETURN);
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

    { Consume any stale IOResult }
    IOResult;

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
      IOResult;
    end;

    { Consume any stale IOResult before next file }
    IOResult;

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
        IOResult;
      end;
    end;

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

    { Validate key bindings -- old config files won't have them (fields = 0) }
    if Settings.KeyJump = 0 then
      ApplyDefaultKeyBindings;
    { KeyStatus added later -- old configs may have valid Jump..Sound but no Status }
    if Settings.KeyStatus = 0 then
      Settings.KeyStatus := LongInt(SDLK_s);
    { Sound settings added later -- old configs have BGMVol=0 }
    if Settings.BGMVol = 0 then
    begin
      Settings.BGMOn := TRUE;
      Settings.BGMVol := 5;
      Settings.SFXVol := 10;
    end;
    { Gamepad bindings added later -- old configs have all zeros.
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
    { Consume any stale IOResult before file operations }
    IOResult;

    { Write settings (MARIO.CFG) }
    Assign (FC, GetConfigName);
    ReWrite (FC);
    if IOResult = 0 then
    begin
      Write (FC, Settings);
      Close (FC);
      IOResult;
    end;

    { Consume any stale IOResult before next file }
    IOResult;

    { Write save games (MARIO.SAV) }
    Assign (FS, GetSaveName);
    ReWrite (FS);
    if IOResult = 0 then
    begin
      Write (FS, Saves);
      Close (FS);
      IOResult;
    end;
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
      i: Integer;
      S: String;
  begin
    TestPlayMode := FALSE;
    TestPlayPath := '';
    i := 1;
    while i <= ParamCount do
    begin
      S := ParamStr (i);
      if (Length(S) >= 2) and (S[1] in ['/', '-']) then
      begin
        case UpCase (S[2]) of
          'S': Play.Stat := TRUE;
          'Q': BeeperOff;
          'J': CalibrateJoystick;
          'T': begin
            TestPlayMode := TRUE;
            { Next parameter is the file path }
            Delete(S, 1, 2);
            if S <> '' then
              TestPlayPath := S
            else if i < ParamCount then
            begin
              Inc(i);
              TestPlayPath := ParamStr(i);
            end;
          end;
        end;
      end;
      Inc(i);
    end;
  end;

end.
