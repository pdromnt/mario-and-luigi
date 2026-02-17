unit Keyboard;

  {  SDL2 replacement for the Turbo Pascal Keyboard unit  }
  {  Original (C) Copyright 1994-2001, Mike Wiering       }
  {  Preserves identical interface                         }

  {$I-}  { I/O checking off — needed for file probing in NextDemoName/SaveMacroToFile }

interface

  const
    kb1 =  #2;   kbQ = #16;   kbA = #30;   kbZ = #44;
    kb2 =  #3;   kbW = #17;   kbS = #31;   kbX = #45;
    kb3 =  #4;   kbE = #18;   kbD = #32;   kbC = #46;
    kb4 =  #5;   kbR = #19;   kbF = #33;   kbV = #47;
    kb5 =  #6;   kbT = #20;   kbG = #34;   kbB = #48;
    kb6 =  #7;   kbY = #21;   kbH = #35;   kbN = #49;
    kb7 =  #8;   kbU = #22;   kbJ = #36;   kbM = #50;
    kb8 =  #9;   kbI = #23;   kbK = #37;
    kb9 = #10;   kbO = #24;   kbL = #38;
    kb0 = #11;   kbP = #25;

    kbEsc        =  #1;
    kbBS         = #14;
    kbTab        = #15;
    kbEnter      = #28;
    kbSP         = #57;
    kbUpArrow    = #72;
    kbLeftArrow  = #75;
    kbRightArrow = #77;
    kbDownArrow  = #80;
    kbF9         = #67;   { AT scancode $43 }
    kbF12        = #134;  { AT scancode $86 }

  var
    Key: Char;
    bKey: Byte absolute Key;

  procedure InitKeyBoard;
  procedure KeyBoardDone;

  procedure ResetKeyBoard;

  procedure RecordMacro;
  procedure PlayMacro;
  procedure SaveMacro;
  procedure StopMacro;
  function PlayingMacro: Boolean;

  type
    DemoHeader = record
      Level: Word;
      Seed: LongInt;
      PosX: Integer;    { Player X pixel position at record start }
      PosY: Integer;    { Player Y pixel position at record start }
      ViewX: Integer;   { XView scroll position at record start }
    end;

  var
    MacroHdr: DemoHeader;  { Populated by LoadMacroFromFile for PlayWorld }

  procedure SaveMacroToFile(const FileName: string; var Hdr: DemoHeader);
  function LoadMacroFromFile(const FileName: string;
    var Hdr: DemoHeader): Boolean;
  function NextDemoName: string;

  function kbHit: Boolean;

  function kbLeft: Boolean;
  function kbRight: Boolean;
  function kbUp: Boolean;
  function kbDown: Boolean;
  function kbAlt: Boolean;
  function kbCtrl: Boolean;
  function kbLeftShift: Boolean;
  function kbRightShift: Boolean;
  function kbSpace: Boolean;

  function GetAsciiCode (c: Char): Char;

  { SDL-specific: must be called each frame to process events }
  procedure PollKeyboard;

  var
    { Configurable SDL keycodes for gameplay keys (LongInt = TSDL_Keycode) }
    BindJump:  LongInt;   { maps to KeyMap[keyAlt],   default: SDLK_LALT  }
    BindRun:   LongInt;   { maps to KeyMap[keyCtrl],  default: SDLK_LCTRL }
    BindFire:  LongInt;   { maps to KeyMap[keySpace], default: SDLK_SPACE }
    BindPause:  LongInt;   { maps to Key := kbP,       default: SDLK_p     }
    BindSound:  LongInt;   { maps to Key := kbQ,       default: SDLK_q     }
    BindStatus: LongInt;   { maps to Key := kbS,       default: SDLK_s     }

    { Last raw SDL keycode pressed — for key assignment UI }
    LastKeyCode: LongInt;

implementation

  uses
    sdl2;

  const
    MaxKeys = 9;

  const
    keyLeft   = 1;
    keyRight  = 2;
    keyUp     = 3;
    keyDown   = 4;
    keyAlt    = 5;
    keyCtrl   = 6;
    keyShiftL = 7;
    keyShiftR = 8;
    keySpace  = 9;

  const
    MAX_SEQ_LEN = 100;

  type
    KeySeq = array[0..MAX_SEQ_LEN - 1] of Word;

  var
    Sequence: array[1..MaxKeys] of KeySeq;
    SeqPos: array[1..MaxKeys] of Word;

  const
    Recording: Boolean = FALSE;
    Playing: Boolean = FALSE;

  const
    KeyMap: Array[1..MaxKeys] of Boolean =
      (False, False, False, False, False, False, False, False, False);

    HandlerActive: Boolean = FALSE;
    KeyHit: Boolean = FALSE;

  { Demo keys data - extracted from DEMOKEYS.OBJ }
  {$I data\demokeys.inc}

  function MapSDLKeyToScancode(sym: TSDL_Keycode): Byte;
    { Map SDL key code to PC AT scancode }
  begin
    case sym of
      SDLK_ESCAPE:    MapSDLKeyToScancode := 1;
      SDLK_1:         MapSDLKeyToScancode := 2;
      SDLK_2:         MapSDLKeyToScancode := 3;
      SDLK_3:         MapSDLKeyToScancode := 4;
      SDLK_4:         MapSDLKeyToScancode := 5;
      SDLK_5:         MapSDLKeyToScancode := 6;
      SDLK_6:         MapSDLKeyToScancode := 7;
      SDLK_7:         MapSDLKeyToScancode := 8;
      SDLK_8:         MapSDLKeyToScancode := 9;
      SDLK_9:         MapSDLKeyToScancode := 10;
      SDLK_0:         MapSDLKeyToScancode := 11;
      SDLK_BACKSPACE: MapSDLKeyToScancode := 14;
      SDLK_TAB:       MapSDLKeyToScancode := 15;
      SDLK_q:         MapSDLKeyToScancode := 16;
      SDLK_w:         MapSDLKeyToScancode := 17;
      SDLK_e:         MapSDLKeyToScancode := 18;
      SDLK_r:         MapSDLKeyToScancode := 19;
      SDLK_t:         MapSDLKeyToScancode := 20;
      SDLK_y:         MapSDLKeyToScancode := 21;
      SDLK_u:         MapSDLKeyToScancode := 22;
      SDLK_i:         MapSDLKeyToScancode := 23;
      SDLK_o:         MapSDLKeyToScancode := 24;
      SDLK_p:         MapSDLKeyToScancode := 25;
      SDLK_RETURN:    MapSDLKeyToScancode := 28;
      SDLK_a:         MapSDLKeyToScancode := 30;
      SDLK_s:         MapSDLKeyToScancode := 31;
      SDLK_d:         MapSDLKeyToScancode := 32;
      SDLK_f:         MapSDLKeyToScancode := 33;
      SDLK_g:         MapSDLKeyToScancode := 34;
      SDLK_h:         MapSDLKeyToScancode := 35;
      SDLK_j:         MapSDLKeyToScancode := 36;
      SDLK_k:         MapSDLKeyToScancode := 37;
      SDLK_l:         MapSDLKeyToScancode := 38;
      SDLK_z:         MapSDLKeyToScancode := 44;
      SDLK_x:         MapSDLKeyToScancode := 45;
      SDLK_c:         MapSDLKeyToScancode := 46;
      SDLK_v:         MapSDLKeyToScancode := 47;
      SDLK_b:         MapSDLKeyToScancode := 48;
      SDLK_n:         MapSDLKeyToScancode := 49;
      SDLK_m:         MapSDLKeyToScancode := 50;
      SDLK_SPACE:     MapSDLKeyToScancode := 57;
      SDLK_UP:        MapSDLKeyToScancode := 72;
      SDLK_LEFT:      MapSDLKeyToScancode := 75;
      SDLK_RIGHT:     MapSDLKeyToScancode := 77;
      SDLK_DOWN:      MapSDLKeyToScancode := 80;
      SDLK_F9:        MapSDLKeyToScancode := 67;
      SDLK_F12:       MapSDLKeyToScancode := 134;
    else
      MapSDLKeyToScancode := 0;
    end;
  end;

  procedure PollKeyboard;
    { Process SDL events and update key states }
  var
    Event: TSDL_Event;
    sc: Byte;
    sym: TSDL_Keycode;
  begin
    while SDL_PollEvent(@Event) <> 0 do
    begin
      case Event.type_ of
        SDL_KEYDOWN:
          if Event.key.repeat_ = 0 then  { Ignore key repeats }
          begin
            KeyHit := True;
            sym := Event.key.keysym.sym;
            LastKeyCode := sym;

            { Scancode mapping for menu navigation & single-press actions }
            sc := MapSDLKeyToScancode(sym);
            if sc <> 0 then
              Key := Chr(sc);

            { Configurable Pause/Sound/Status: inject scancodes so PLAY.PAS needs no changes }
            if sym = BindPause  then Key := kbP;
            if sym = BindSound  then Key := kbQ;
            if sym = BindStatus then Key := kbS;

            { Non-remappable directional keys }
            if sym = SDLK_LEFT then   KeyMap[keyLeft] := True;
            if sym = SDLK_RIGHT then  KeyMap[keyRight] := True;
            if sym = SDLK_UP then     KeyMap[keyUp] := True;
            if sym = SDLK_DOWN then   KeyMap[keyDown] := True;

            { Non-remappable shift keys }
            if sym = SDLK_LSHIFT then KeyMap[keyShiftL] := True;
            if sym = SDLK_RSHIFT then KeyMap[keyShiftR] := True;

            { Configurable gameplay keys }
            if sym = BindJump then KeyMap[keyAlt] := True;
            if sym = BindRun then  KeyMap[keyCtrl] := True;
            if sym = BindFire then KeyMap[keySpace] := True;
          end;

        SDL_KEYUP:
          begin
            sym := Event.key.keysym.sym;

            { Non-remappable keys }
            if sym = SDLK_LEFT then   KeyMap[keyLeft] := False;
            if sym = SDLK_RIGHT then  KeyMap[keyRight] := False;
            if sym = SDLK_UP then     KeyMap[keyUp] := False;
            if sym = SDLK_DOWN then   KeyMap[keyDown] := False;
            if sym = SDLK_LSHIFT then KeyMap[keyShiftL] := False;
            if sym = SDLK_RSHIFT then KeyMap[keyShiftR] := False;

            { Configurable gameplay keys }
            if sym = BindJump then KeyMap[keyAlt] := False;
            if sym = BindRun then  KeyMap[keyCtrl] := False;
            if sym = BindFire then KeyMap[keySpace] := False;
          end;

        SDL_QUITEV:
          Halt(0);
      end;
    end;
  end;

  procedure InitKeyBoard;
  begin
    HandlerActive := TRUE;
    KeyHit := FALSE;
    Key := #0;
    FillChar(MacroHdr, SizeOf(MacroHdr), 0);
    { Default key bindings }
    BindJump  := LongInt(SDLK_LALT);
    BindRun   := LongInt(SDLK_LCTRL);
    BindFire  := LongInt(SDLK_SPACE);
    BindPause  := LongInt(SDLK_p);
    BindSound  := LongInt(SDLK_q);
    BindStatus := LongInt(SDLK_s);
    LastKeyCode := LongInt(SDLK_UNKNOWN);
  end;

  procedure KeyBoardDone;
  begin
    HandlerActive := FALSE;
  end;

  procedure ResetKeyBoard;
  var
    i: Byte;
  begin
    Recording := FALSE;
    Playing := FALSE;
    for i := 1 to MaxKeys do
      KeyMap[i] := False;
    Key := #0;
  end;

  procedure RecordMacro;
  begin
    Recording := TRUE;
    Playing := FALSE;
    FillChar(SeqPos, SizeOf(SeqPos), 0);
    FillChar(Sequence, SizeOf(Sequence), 0);
    { Note: RandSeed is NOT reset here. For built-in demo recording
      (cheat code 76DD), RandSeed is set to 0 by PlayMacro before
      playback. For F9 recordings we save/restore RandSeed via the
      .RPL file header so mid-level recordings replay correctly. }
  end;

  procedure PlayMacro;
  begin
    Playing := TRUE;
    Recording := FALSE;
    FillChar(SeqPos, SizeOf(SeqPos), 0);
    Move(DemoKeysData, Sequence, SizeOf(Sequence));
    RandSeed := 0;
  end;

  procedure StopMacro;
  begin
    Playing := FALSE;
    Recording := FALSE;
  end;

  procedure SaveMacro;
  var
    F: File of KeySeq;
    i: Integer;
  begin
    Assign(F, '$');
    ReWrite(F);
    for i := 1 to MaxKeys do
      Write(F, Sequence[i]);
    Close(F);
    Recording := FALSE;
    FillChar(SeqPos, SizeOf(SeqPos), 0);
  end;

  procedure SaveMacroToFile(const FileName: string; var Hdr: DemoHeader);
  var
    F: File;
    i: Integer;
  begin
    Assign(F, FileName);
    ReWrite(F, 1);
    if IOResult = 0 then
    begin
      BlockWrite(F, Hdr, SizeOf(DemoHeader));
      BlockWrite(F, Sequence, SizeOf(Sequence));
      Close(F);
    end;
    i := IOResult;
    Recording := FALSE;
    FillChar(SeqPos, SizeOf(SeqPos), 0);
  end;

  function LoadMacroFromFile(const FileName: string;
    var Hdr: DemoHeader): Boolean;
  var
    F: File;
    ReadBytes: LongInt;
    i: Integer;
  begin
    LoadMacroFromFile := FALSE;
    Assign(F, FileName);
    Reset(F, 1);
    if IOResult <> 0 then Exit;
    BlockRead(F, Hdr, SizeOf(DemoHeader), ReadBytes);
    if (IOResult <> 0) or (ReadBytes <> SizeOf(DemoHeader)) then
    begin
      Close(F);
      i := IOResult;
      Exit;
    end;
    BlockRead(F, Sequence, SizeOf(Sequence), ReadBytes);
    Close(F);
    i := IOResult;
    if ReadBytes = SizeOf(Sequence) then
    begin
      Playing := TRUE;
      Recording := FALSE;
      FillChar(SeqPos, SizeOf(SeqPos), 0);
      RandSeed := Hdr.Seed;
      MacroHdr := Hdr;     { Store for PlayWorld to read on init }
      LoadMacroFromFile := TRUE;
    end;
  end;

  function NextDemoName: string;
  var
    F: File;
    i, Dummy: Integer;
    Name: string;
  begin
    NextDemoName := '';
    for i := 1 to 9 do
    begin
      Name := 'DEMO' + Chr(i + Ord('0')) + '.RPL';
      Assign(F, Name);
      Reset(F, 1);
      if IOResult <> 0 then
      begin
        NextDemoName := Name;
        Exit;
      end;
      Close(F);
      Dummy := IOResult;
    end;
  end;

  function PlayingMacro: Boolean;
  begin
    PlayingMacro := Playing;
  end;

  function Check (KeyNr: Byte; Press: Boolean): Boolean;
  begin
    Check := Press;
    if Playing or Recording then
    begin
      if Recording then
      begin
        if Press xor (SeqPos[KeyNr] mod 2 = 1) then
        begin
          Inc(SeqPos[KeyNr]);
          if SeqPos[KeyNr] >= MAX_SEQ_LEN then
            SeqPos[KeyNr] := MAX_SEQ_LEN - 1;
        end;
        Inc(Sequence[KeyNr, SeqPos[KeyNr]]);
      end;
      if Playing then
      begin
        if Sequence[KeyNr, SeqPos[KeyNr]] = 0 then
          Playing := FALSE
        else
        begin
          Dec(Sequence[KeyNr, SeqPos[KeyNr]]);
          if Sequence[KeyNr, SeqPos[KeyNr]] = 0 then
            Inc(SeqPos[KeyNr]);
          Check := (SeqPos[KeyNr] mod 2 = 1);
        end;
      end;
    end;
  end;

  function kbHit: Boolean;
  begin
    kbHit := KeyHit;
    KeyHit := FALSE;
  end;

  function kbLeft: Boolean;
  begin
    kbLeft := Check(keyLeft, KeyMap[keyLeft]);
  end;

  function kbRight: Boolean;
  begin
    kbRight := Check(keyRight, KeyMap[keyRight]);
  end;

  function kbUp: Boolean;
  begin
    kbUp := Check(keyUp, KeyMap[keyUp]);
  end;

  function kbDown: Boolean;
  begin
    kbDown := Check(keyDown, KeyMap[keyDown]);
  end;

  function kbAlt: Boolean;
  begin
    kbAlt := Check(keyAlt, KeyMap[keyAlt]);
  end;

  function kbCtrl: Boolean;
  begin
    kbCtrl := Check(keyCtrl, KeyMap[keyCtrl]);
  end;

  function kbLeftShift: Boolean;
  begin
    kbLeftShift := Check(keyShiftL, KeyMap[keyShiftL]);
  end;

  function kbRightShift: Boolean;
  begin
    kbRightShift := Check(keyShiftR, KeyMap[keyShiftR]);
  end;

  function kbSpace: Boolean;
  begin
    kbSpace := Check(keySpace, KeyMap[keySpace]);
  end;

  function GetAsciiCode (c: Char): Char;
    const
      kbTable: array[0..3] of string[10] =
        ('1234567890',
         'QWERTYUIOP',
         'ASDFGHJKL',
         'ZXCVBNM');
    var
      i: Byte absolute c;
  begin
    case i of
       2..11: GetAsciiCode := kbTable[0, i - 2 + 1];
      16..25: GetAsciiCode := kbTable[1, i - 16 + 1];
      30..38: GetAsciiCode := kbTable[2, i - 30 + 1];
      44..50: GetAsciiCode := kbTable[3, i - 44 + 1];
    else
      GetAsciiCode := #0;
    end
  end;

end.
