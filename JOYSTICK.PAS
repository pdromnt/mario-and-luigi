unit Joystick;

  {  SDL2 replacement for DOS joystick unit  }
  {  Original (C) Copyright 1995-2001, Mike Wiering  }

interface

  var
    jsDetected,
    jsEnabled,
    jsCalibrated,
    jsWaitButton,
    jsButtonPressed,
    jsButton1,
    jsButton2,
    jsLeft,
    jsRight,
    jsUp,
    jsDown: Boolean;

    { Configurable button indices (-1 = unbound) }
    BindJSJump:   Integer;
    BindJSRun:    Integer;
    BindJSFire:   Integer;
    BindJSPause:  Integer;
    BindJSSound:  Integer;
    BindJSStatus: Integer;

    { Per-action output booleans (set by ReadJoystick) }
    jsJump,
    jsRun,
    jsFire,
    jsPause,
    jsSound,
    jsStatus: Boolean;

    { Last button index pressed this frame, for remapping UI (-1 = none) }
    LastJSButton: Integer;

  type
    JoyRec =
      record
        X,
        Y,
        XCenter,
        YCenter,
        XMin,
        YMin,
        XMax,
        YMax,
        XLeft,
        YUp,
        XRight,
        YDown: Word;
      end;

  var
    jr: JoyRec;

  procedure ReadJoystick;
  procedure ResetJoystick;
  procedure Calibrate;
  function GetJSButtonName(Idx: Integer): string;

implementation

  uses
    sdl2;

  const
    DEAD_ZONE = 8000;  { SDL axis dead zone threshold }

  var
    SDLJoystick: PSDL_Joystick;

  function ReadBtn(Idx: Integer): Boolean;
  begin
    if (Idx >= 0) and (SDLJoystick <> nil) then
      ReadBtn := SDL_JoystickGetButton(SDLJoystick, Idx) <> 0
    else
      ReadBtn := FALSE;
  end;

  function GetJSButtonName(Idx: Integer): string;
  var
    S: string[4];
  begin
    if Idx < 0 then
      GetJSButtonName := 'NONE'
    else
    begin
      Str(Idx, S);
      GetJSButtonName := 'BTN ' + S;
    end;
  end;

  procedure ReadJoystick;
  var
    AxisX, AxisY: SmallInt;
    HatState: Byte;
    NumBtns, BtnIdx: Integer;
  begin
    jr.X := 0;
    jr.Y := 0;
    LastJSButton := -1;

    if not jsEnabled then
    begin
      jsLeft := FALSE;
      jsRight := FALSE;
      jsUp := FALSE;
      jsDown := FALSE;
      jsButton1 := FALSE;
      jsButton2 := FALSE;
      jsJump := FALSE;
      jsRun := FALSE;
      jsFire := FALSE;
      jsPause := FALSE;
      jsSound := FALSE;
      jsStatus := FALSE;
      Exit;
    end;

    if SDLJoystick = nil then
    begin
      jsEnabled := FALSE;
      jsLeft := FALSE;
      jsRight := FALSE;
      jsUp := FALSE;
      jsDown := FALSE;
      jsButton1 := FALSE;
      jsButton2 := FALSE;
      jsJump := FALSE;
      jsRun := FALSE;
      jsFire := FALSE;
      jsPause := FALSE;
      jsSound := FALSE;
      jsStatus := FALSE;
      Exit;
    end;

    { Read axis values (-32768..32767) }
    AxisX := SDL_JoystickGetAxis(SDLJoystick, 0);
    AxisY := SDL_JoystickGetAxis(SDLJoystick, 1);

    { Map to jr record for compatibility }
    jr.X := Word((LongInt(AxisX) + 32768) div 256);  { 0..255 range }
    jr.Y := Word((LongInt(AxisY) + 32768) div 256);

    { Read hat (d-pad) }
    if SDL_JoystickNumHats(SDLJoystick) > 0 then
      HatState := SDL_JoystickGetHat(SDLJoystick, 0)
    else
      HatState := 0;

    { Read legacy buttons (kept for CalibrateJoystick compat) }
    jsButton1 := SDL_JoystickGetButton(SDLJoystick, 0) <> 0;
    jsButton2 := SDL_JoystickGetButton(SDLJoystick, 1) <> 0;

    { Read configurable action buttons }
    jsJump   := ReadBtn(BindJSJump);
    jsRun    := ReadBtn(BindJSRun);
    jsFire   := ReadBtn(BindJSFire);
    jsPause  := ReadBtn(BindJSPause);
    jsSound  := ReadBtn(BindJSSound);
    jsStatus := ReadBtn(BindJSStatus);

    { Scan all buttons for last-pressed capture (remapping UI) }
    NumBtns := SDL_JoystickNumButtons(SDLJoystick);
    if NumBtns > 32 then NumBtns := 32;
    for BtnIdx := 0 to NumBtns - 1 do
      if SDL_JoystickGetButton(SDLJoystick, BtnIdx) <> 0 then
        LastJSButton := BtnIdx;

    if not jsWaitButton then
    begin
      { Combine axis and hat for directional input }
      jsLeft  := (AxisX < -DEAD_ZONE) or (HatState and SDL_HAT_LEFT <> 0);
      jsRight := (AxisX > DEAD_ZONE)  or (HatState and SDL_HAT_RIGHT <> 0);
      jsUp    := (AxisY < -DEAD_ZONE) or (HatState and SDL_HAT_UP <> 0);
      jsDown  := (AxisY > DEAD_ZONE)  or (HatState and SDL_HAT_DOWN <> 0);
    end
    else
    begin
      jsLeft := FALSE;
      jsRight := FALSE;
      jsUp := FALSE;
      jsDown := FALSE;
      jsButtonPressed := jsButtonPressed or jsButton1 or jsButton2;
      jsButton1 := FALSE;
      jsButton2 := FALSE;
      jsJump := FALSE;
      jsRun := FALSE;
      jsFire := FALSE;
      jsPause := FALSE;
      jsSound := FALSE;
      jsStatus := FALSE;
    end;
  end;

  procedure ResetJoystick;
  begin
    jsEnabled := SDL_NumJoysticks > 0;
    if jsEnabled then
    begin
      if SDLJoystick = nil then
        SDLJoystick := SDL_JoystickOpen(0);
      jsEnabled := SDLJoystick <> nil;
    end;

    if jsEnabled then
      with jr do
      begin
        XCenter := 128;
        YCenter := 128;
        XMin := 0;
        YMin := 0;
        XMax := 255;
        YMax := 255;
        XLeft := 64;
        YUp := 64;
        XRight := 192;
        YDown := 192;
        jsCalibrated := FALSE;
      end;
    ReadJoystick;
  end;

  procedure Calibrate;
  begin
    ReadJoystick;
    { SDL handles dead zones and calibration automatically }
    { We just keep the interface for compatibility }
    if jsEnabled then
      jsCalibrated := TRUE;
  end;

begin
  SDLJoystick := nil;
  jsCalibrated := FALSE;
  jsWaitButton := FALSE;
  jsDetected := FALSE;
  jsEnabled := FALSE;
  LastJSButton := -1;

  { Default button bindings }
  BindJSJump   := 0;
  BindJSRun    := 1;
  BindJSFire   := 1;
  BindJSPause  := 6;
  BindJSSound  := -1;
  BindJSStatus := -1;

  jsJump   := FALSE;
  jsRun    := FALSE;
  jsFire   := FALSE;
  jsPause  := FALSE;
  jsSound  := FALSE;
  jsStatus := FALSE;

  { Try to open joystick if available }
  if SDL_NumJoysticks > 0 then
  begin
    SDLJoystick := SDL_JoystickOpen(0);
    if SDLJoystick <> nil then
    begin
      jsDetected := TRUE;
      jsEnabled := TRUE;
    end;
  end;

  ReadJoystick;
end.
