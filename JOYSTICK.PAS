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

implementation

  uses
    sdl2;

  const
    DEAD_ZONE = 8000;  { SDL axis dead zone threshold }

  var
    SDLJoystick: PSDL_Joystick;

  procedure ReadJoystick;
  var
    AxisX, AxisY: SmallInt;
  begin
    jr.X := 0;
    jr.Y := 0;

    if not jsEnabled then
    begin
      jsLeft := FALSE;
      jsRight := FALSE;
      jsUp := FALSE;
      jsDown := FALSE;
      jsButton1 := FALSE;
      jsButton2 := FALSE;
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
      Exit;
    end;

    { Read axis values (-32768..32767) }
    AxisX := SDL_JoystickGetAxis(SDLJoystick, 0);
    AxisY := SDL_JoystickGetAxis(SDLJoystick, 1);

    { Map to jr record for compatibility }
    jr.X := Word((LongInt(AxisX) + 32768) div 256);  { 0..255 range }
    jr.Y := Word((LongInt(AxisY) + 32768) div 256);

    { Read buttons }
    jsButton1 := SDL_JoystickGetButton(SDLJoystick, 0) <> 0;
    jsButton2 := SDL_JoystickGetButton(SDLJoystick, 1) <> 0;

    if not jsWaitButton then
    begin
      jsLeft := AxisX < -DEAD_ZONE;
      jsRight := AxisX > DEAD_ZONE;
      jsUp := AxisY < -DEAD_ZONE;
      jsDown := AxisY > DEAD_ZONE;
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
