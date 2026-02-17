unit Buffers;

  {  SDL2 port of game state and buffer management  }
  {  Original (C) Copyright 1994-2001, Mike Wiering  }

  {$R-}      { No range checking }

interface

  uses
    VGA256;

  const
    CanHoldYou    = [#0..#13, '0'..'Z'];
    CanStandOn    = [#14..#16, 'a'..'f'];
    Hidden        = ['$'];

  function GetTimer: LongInt;
  function GetwTimer: Word;
  function GetbTimer: Byte;

  const
    W  = 20;
    H  = 14;
    NH = 16;
    NV = 13;

    MaxWorldSize = 236;

    EX  = 1;
    EY1 = 8;
    EY2 = 3;

    dirLeft       = 0;
    dirRight      = 1;

    mdSmall       = 0;
    mdLarge       = 1;
    mdFire        = 2;

    plMario = 0;
    plLuigi = 1;

    QuitGame: Boolean = FALSE;
    BeeperSound: Boolean = TRUE;

  type
    {$A2}  { Word alignment (TP compatible) — needed for save game file compatibility }
    GameData = record
      NumPlayers: Integer;
      Progress: array[plMario..plLuigi] of Integer;
      Lives: array[plMario..plLuigi] of Integer;
      Coins: array[plMario..plLuigi] of Integer;
      Score: array[plMario..plLuigi] of LongInt;
      Mode: array[plMario..plLuigi] of Byte;
    end;
    {$A+}  { Restore default alignment }

  const
    PlayerName: array [plMario..plLuigi] of string [5] = ('MARIO', 'LUIGI');

  var
    Player: Byte;
    Data: GameData;
    WorldNumber: string[3];
    LevelScore: LongInt;


  type
    ImageBufferPtr = ^ImageBuffer;
    ImageBuffer = array [1 .. H, 1 .. W] of Char;

    ScreenBuffer = array [0 .. MAX_PAGE] of ImageBuffer;

    PicBuffer = array [1 .. 2 * H, 1 .. W] of Char;

    PictureBufferPtr = ^PictureBuffer;
    PictureBuffer = array [plMario .. plLuigi, mdSmall .. mdFire,
      0 .. 3, dirLeft .. dirRight] of PicBuffer;

    MapBufferPtr = ^MapBuffer;
    MapBuffer = array [1 .. MaxWorldSize, 1 .. NV] of Char;

    StarBufferPtr = ^StarBuffer;
    StarBuffer = array [0 .. MAX_PAGE, 0 .. 319] of Byte;

    WorldBufferPtr = ^WorldBuffer;
    WorldBuffer = array [-EX .. MaxWorldSize - 1 + EX,
      -EY1 .. NV - 1 + EY2] of Char;

    WorldOptions = Record
      InitX,
      InitY: Word;
      SkyType,
      WallType1, WallType2, WallType3,
      PipeColor,
      GroundColor1,
      GroundColor2,
      Horizon,
      BackGrType,
      BackGrColor1,
      BackGrColor2,
      Stars,
      Clouds,
      Design: Byte;
      C2r, C2g, C2b,
      C3r, C3g, C3b,
      BrickColor,
      WoodColor,
      XBlockColor: Byte;

      BuildWall: Boolean;
      XSize: Word;
    end;

  var
    GameDone,
    Passed: Boolean;
    WorldMap,
    SaveWorldMap: WorldBufferPtr;
    Options,
    SaveOptions: WorldOptions;
    XView,
    YView: Integer;
    LastXView: array [0 .. MAX_PAGE] of Integer;
    StarBackGr: StarBufferPtr;
    Size: Word;
    Pictures: PictureBufferPtr;
    Demo,
    TextCounter: Integer;
    LavaCounter: Byte;

  const
    dmNoDemo        = 0;
    dmDownInToPipe  = 1;
    dmUpOutOfPipe   = 2;
    dmUpInToPipe    = 3;
    dmDownOutOfPipe = 4;
    dmDead          = 5;


  procedure ReadWorld (var Map; W: WorldBufferPtr; var Opt);
  procedure Swap;

  { Shared audio state for SDL audio callback }
  var
    AudioFrequency: Integer;  { 0 = silence, >0 = freq in Hz }
    BeepAge: Integer;         { Sound effect frame counter:
                                0 = no active SFX beep,
                                1 = fresh beep (don't overwrite yet),
                                2+ = beep has been heard, can overwrite }

  procedure BeeperOn;
  procedure BeeperOff;
  procedure Beep (Freq: Word);

  procedure InitLevelScore;
  procedure AddScore (N: LongInt);


implementation

  uses
    sdl2;

  function GetTimer: LongInt;
    { Replacement for Timer absolute $0000:$046C }
    { DOS timer ticks at ~18.2 Hz (every ~55ms) }
  begin
    GetTimer := LongInt(SDL_GetTicks) div 55;
  end;

  function GetwTimer: Word;
  begin
    GetwTimer := Word(SDL_GetTicks div 55);
  end;

  function GetbTimer: Byte;
  begin
    GetbTimer := Byte(SDL_GetTicks div 55);
  end;

  procedure ReadWorld (var Map; W: WorldBufferPtr; var Opt);
  var
    M: MapBufferPtr;
    i, j, X: Integer;
  begin
    Move(Opt, Options, SizeOf(Options));
    M := @Map;
    FillChar(W^, SizeOf(W^), ' ');
    for i := -EX to -1 do
      for j := -EY1 to NV - 1 + EY2 do
        W^ [i, j] := '@';
    X := 0;

    While (M^ [X + 1, 1] <> #0) and (X < MaxWorldSize) do
    begin
      for i := 1 to NV do
        W^ [X, NV - i] := M^ [X + 1, i];
      W^ [X, -EY1] := #0;
      for i := 1 to EY2 do
        W^ [X, NV - 1 + i] := W^ [X, NV - 1];
      Inc(X);
    end;

    Options.XSize := X;
    for i := X to X + EX - 1 do
      for j := -EY1 to NV - 1 + EY2 do
        W^ [i, j] := '@';
  end;


  procedure Swap;
  var
    TempOptions: WorldOptions;
    C: Char;
    i, j: Integer;
  begin
    Move(Options, TempOptions, SizeOf(TempOptions));
    Move(SaveOptions, Options, SizeOf(Options));
    Move(TempOptions, SaveOptions, SizeOf(SaveOptions));
    for i := -EX to MaxWorldSize - 1 + EX do
      for j := -EY1 to NV - 1 + EY2 do
      begin
        C := WorldMap^ [i, j];
        WorldMap^ [i, j] := SaveWorldMap^ [i, j];
        SaveWorldMap^ [i, j] := C;
      end;
  end;

  procedure BeeperOn;
  begin
    BeeperSound := TRUE;
    Beep(0);  { silence }
  end;

  procedure BeeperOff;
  begin
    BeeperSound := FALSE;
    Beep(0);  { silence }
  end;

  procedure Beep (Freq: Word);
  begin
    if BeeperSound then
    begin
      AudioFrequency := Freq;
      if Freq > 0 then
        BeepAge := 1   { Mark as fresh — PlayMusic won't overwrite until next frame }
      else
        BeepAge := 0;
    end
    else
    begin
      AudioFrequency := 0;
      BeepAge := 0;
    end;
  end;

  procedure InitLevelScore;
  begin
    LevelScore := 0;
  end;

  procedure AddScore (N: LongInt);
  begin
    Inc(LevelScore, N);
  end;

begin
  GetMem(WorldMap, SizeOf(WorldBuffer));
  GetMem(SaveWorldMap, SizeOf(WorldBuffer));
  GetMem(StarBackGr, SizeOf(StarBuffer));
  GetMem(Pictures, SizeOf(PictureBuffer));
end.
