unit Figures;

{  SDL2 port of Figures unit                      }
{  Original (C) Copyright 1994-2001, Mike Wiering  }
{  All VGA planar assembler replaced with pure     }
{  Pascal operating on linear byte framebuffer     }

{$R-}  { no range-checking }

interface

  uses
    Buffers,
    TileDefs,
    Palettes,
    VGA256,
    BackGr,
    SpriteLoader,
    AssetPaths;

  const
    N1 = 3;
    N2 = 13;

  var
    FigList: Array [1 .. N1, 1 .. N2] of ImageBuffer;

    Bricks: Array [0 .. 3] of ImageBuffer;

  var
    Sky: Byte;

  procedure ReColor (P1, P2: Pointer; C: Byte);
  procedure ReColor2 (P1, P2: Pointer; C1, C2: Byte);
  procedure Replace (P1, P2: Pointer; N1, N2: Byte);
  procedure Mirror (P1, P2: Pointer);
  procedure Rotate (P1, P2: Pointer);
  procedure InitSky (NewSky: Byte);
  procedure InitPipes (NewColor: Byte);
  procedure InitWalls (W1, W2, W3: Byte);
  procedure DrawSky (X, Y, W, H: Integer);
  procedure SetSkyPalette;
  procedure Redraw (X, Y: Integer);
  procedure BuildWorld;

  { Returns a pointer to the sprite data for a given tile character.
    Used by the editor to build the tile palette atlas.
    Returns nil if no sprite exists for the character (e.g. enemies). }
  function GetSpritePtr(TileChar: Char): Pointer;

  { Ensure the Bricks[0..2] array is populated with themed sprites.
    When WallType1 < 100 (BuildWall mode), Bricks are never filled by BuildWorld.
    This forces them to be populated so the editor tile palette can display them. }
  procedure EnsureBricks;

  { Returns a pointer to the wall type sprite data (corner/top/body).
    WallType: 0=Green, 1=Sand, 3=Brown, 4=Grass, 5=Desert (2=Custom uses ReColor2)
    Variant: 0=corner, 1=top, 4=body
    Returns nil if invalid. Used by editor for level-independent tile palette. }
  function GetWallSpritePtr(WallType, Variant: LongInt): Pointer;

  { Returns a pointer to the brick pattern sprite data.
    BrickType: 0, 1, 2 (three visual patterns)
    Returns nil if invalid. Used by editor for level-independent tile palette. }
  function GetBrickSpritePtr(BrickType: LongInt): Pointer;

  { Save/restore pristine copies of sprites modified in-place by
    InitPipes (Pipe000-003) and BuildWorld (Block001, Wood000, XBlock000).
    Call SaveSpriteBackups once before the first level load, then call
    RestoreSpriteBackups before each subsequent level load. }
  procedure SaveSpriteBackups;
  procedure RestoreSpriteBackups;

  { --- Per-Tile Color System --- }
  { Pre-colored sprite arrays for per-tile color independence.
    These allow mixing different pipe colors, brick colors, XBlock colors,
    wood colors, and wall styles in a single level without relying on
    Options.PipeColor / Options.BrickColor / etc. }

  { Per-tile color constants (PIPE_COLORS, BRICK_COLORS, XBLOCK_COLORS,
    WOOD_COLORS, CPIPE_BASE, CBRICK_BASE, CXBLOCK_BASE, CWOOD_BASE,
    CBREAK_BASE, CWALL_*, WALL_VARIANTS, WALL_STYLE_BASES, CDECO_*)
    are defined in TileDefs and re-exported via the uses clause above. }

  var
    { Pre-colored pipe sprites: [color_idx 0..5, shape 0..3] }
    ColorPipes: array[0..5, 0..3] of ImageBuffer;

    { Pre-colored brick sprites (pattern 0 base): [color_idx 0..3] }
    ColorBricks: array[0..3, 0..2] of ImageBuffer;

    { Pre-colored XBlock sprites: [color_idx 0..3] }
    ColorXBlocks: array[0..3] of ImageBuffer;

    { Pre-colored Wood sprites: [color_idx 0..2] }
    ColorWood: array[0..2] of ImageBuffer;

    { Pre-colored Breakable block (J) sprites: [color_idx 0..3] }
    ColorBreak: array[0..3] of ImageBuffer;

    { Per-style wall variant sprites: [style 0..4, variant 0..8]
      Variant 0=TL, 1=Top, 2=TR, 3=Left, 4=Body, 5=Right, 6=BL, 7=Bottom, 8=BR }
    WallVariants: array[0..4, 0..8] of ImageBuffer;

    { Pre-colored deco sprites: Window and Lava with palette indices
      remapped to safe slots ($B8-$BE) so they render correctly
      regardless of the level's sky/waterfall palette settings. }
    DecoWindow000, DecoWindow001: array[0..W*H-1] of Byte;
    DecoLava000, DecoLava001: array[0..W*H-1] of Byte;

    { Flag: colored sprites have been initialized }
    ColorSpritesReady: Boolean;

  { Initialize all pre-colored sprite arrays from pristine sprite data.
    Must be called AFTER SaveSpriteBackups and AFTER palette is loaded. }
  { Load all tile sprites from asset files. Must be called at startup. }
  procedure LoadFiguresSprites;

  procedure InitColoredSprites;

  { Set the safe palette slots ($B8-$BE) to correct colors for
    design-independent Window and Lava deco tiles.
    Call after palette initialization (NewPalette/SetSkyPalette). }
  procedure InitDecoSpritePalette;

implementation

  { -- Sprite data: loaded from .sprite asset files at runtime -- }

  type
    TSpriteArray = array[0..279] of Byte;  { Standard 20x14 tile sprite }

  var
    { Walls }
    Green000, Green001, Green002, Green003, Green004: TSpriteArray;
    Ground000, Ground001, Ground002, Ground003, Ground004: TSpriteArray;
    Sand000, Sand001, Sand002, Sand003, Sand004: TSpriteArray;
    Brown000, Brown001, Brown002, Brown003, Brown004: TSpriteArray;
    Grass000, Grass001, Grass002, Grass003, Grass004: TSpriteArray;
    Des000, Des001, Des002, Des003, Des004: TSpriteArray;
    Grass1000, Grass2000, Grass3000: TSpriteArray;
    Grass1001, Grass2001, Grass3001: TSpriteArray;
    Grass1002, Grass2002, Grass3002: TSpriteArray;

    { Pipes }
    Pipe000, Pipe001, Pipe002, Pipe003: TSpriteArray;

    { Blocks }
    Block000, Block001: TSpriteArray;
    Quest000, Quest001: TSpriteArray;

    { Palms }
    WPalm000: TSpriteArray;
    Palm0000, Palm1000, Palm2000, Palm3000: TSpriteArray;
    Palm0001, Palm1001, Palm2001, Palm3001: TSpriteArray;
    Palm0002, Palm1002, Palm2002, Palm3002: TSpriteArray;

    { Decorations }
    Fence000, Fence001: TSpriteArray;
    Pin000: TSpriteArray;
    Fall000, Fall001: TSpriteArray;
    Lava000, Lava001: TSpriteArray;
    Lava2001, Lava2002, Lava2003, Lava2004, Lava2005: TSpriteArray;
    Tree000, Tree001, Tree002, Tree003: TSpriteArray;
    Window000, Window001: TSpriteArray;
    SmTree000, SmTree001: TSpriteArray;

    { Bricks }
    Brick0000, Brick0001, Brick0002: TSpriteArray;
    Brick1000, Brick1001, Brick1002: TSpriteArray;
    Brick2000, Brick2001, Brick2002: TSpriteArray;

    { Items }
    Exit000, Exit001: TSpriteArray;
    Wood000: TSpriteArray;
    Coin000: TSpriteArray;
    Note000: TSpriteArray;
    XBlock000: TSpriteArray;

  { Helper: load a .sprite file into a 280-byte array }
  procedure LoadSpr(const SubPath: string; var Dest: TSpriteArray);
  var
    Spr: TSpriteData;
  begin
    LoadSprite(SpritePath(SubPath), Spr);
    if Length(Spr.Pixels) >= SizeOf(TSpriteArray) then
      Move(Spr.Pixels[0], Dest, SizeOf(TSpriteArray));
  end;

  procedure LoadFiguresSprites;
  begin
    { Walls }
    LoadSpr('walls/green000.sprite', Green000);
    LoadSpr('walls/green001.sprite', Green001);
    LoadSpr('walls/green002.sprite', Green002);
    LoadSpr('walls/green003.sprite', Green003);
    LoadSpr('walls/green004.sprite', Green004);
    LoadSpr('walls/ground000.sprite', Ground000);
    LoadSpr('walls/ground001.sprite', Ground001);
    LoadSpr('walls/ground002.sprite', Ground002);
    LoadSpr('walls/ground003.sprite', Ground003);
    LoadSpr('walls/ground004.sprite', Ground004);
    LoadSpr('walls/sand000.sprite', Sand000);
    LoadSpr('walls/sand001.sprite', Sand001);
    LoadSpr('walls/sand002.sprite', Sand002);
    LoadSpr('walls/sand003.sprite', Sand003);
    LoadSpr('walls/sand004.sprite', Sand004);
    LoadSpr('walls/brown000.sprite', Brown000);
    LoadSpr('walls/brown001.sprite', Brown001);
    LoadSpr('walls/brown002.sprite', Brown002);
    LoadSpr('walls/brown003.sprite', Brown003);
    LoadSpr('walls/brown004.sprite', Brown004);
    LoadSpr('walls/grass000.sprite', Grass000);
    LoadSpr('walls/grass001.sprite', Grass001);
    LoadSpr('walls/grass002.sprite', Grass002);
    LoadSpr('walls/grass003.sprite', Grass003);
    LoadSpr('walls/grass004.sprite', Grass004);
    LoadSpr('walls/des000.sprite', Des000);
    LoadSpr('walls/des001.sprite', Des001);
    LoadSpr('walls/des002.sprite', Des002);
    LoadSpr('walls/des003.sprite', Des003);
    LoadSpr('walls/des004.sprite', Des004);
    LoadSpr('walls/grass1000.sprite', Grass1000);
    LoadSpr('walls/grass2000.sprite', Grass2000);
    LoadSpr('walls/grass3000.sprite', Grass3000);
    LoadSpr('walls/grass1001.sprite', Grass1001);
    LoadSpr('walls/grass2001.sprite', Grass2001);
    LoadSpr('walls/grass3001.sprite', Grass3001);
    LoadSpr('walls/grass1002.sprite', Grass1002);
    LoadSpr('walls/grass2002.sprite', Grass2002);
    LoadSpr('walls/grass3002.sprite', Grass3002);

    { Pipes }
    LoadSpr('tiles/pipe000.sprite', Pipe000);
    LoadSpr('tiles/pipe001.sprite', Pipe001);
    LoadSpr('tiles/pipe002.sprite', Pipe002);
    LoadSpr('tiles/pipe003.sprite', Pipe003);

    { Blocks }
    LoadSpr('tiles/block000.sprite', Block000);
    LoadSpr('tiles/block001.sprite', Block001);
    LoadSpr('tiles/quest000.sprite', Quest000);
    LoadSpr('tiles/quest001.sprite', Quest001);

    { Palms }
    LoadSpr('decorations/wpalm000.sprite', WPalm000);
    LoadSpr('decorations/palm0000.sprite', Palm0000);
    LoadSpr('decorations/palm1000.sprite', Palm1000);
    LoadSpr('decorations/palm2000.sprite', Palm2000);
    LoadSpr('decorations/palm3000.sprite', Palm3000);
    LoadSpr('decorations/palm0001.sprite', Palm0001);
    LoadSpr('decorations/palm1001.sprite', Palm1001);
    LoadSpr('decorations/palm2001.sprite', Palm2001);
    LoadSpr('decorations/palm3001.sprite', Palm3001);
    LoadSpr('decorations/palm0002.sprite', Palm0002);
    LoadSpr('decorations/palm1002.sprite', Palm1002);
    LoadSpr('decorations/palm2002.sprite', Palm2002);
    LoadSpr('decorations/palm3002.sprite', Palm3002);

    { Decorations }
    LoadSpr('decorations/fence000.sprite', Fence000);
    LoadSpr('decorations/fence001.sprite', Fence001);
    LoadSpr('tiles/pin000.sprite', Pin000);
    LoadSpr('decorations/fall000.sprite', Fall000);
    LoadSpr('decorations/fall001.sprite', Fall001);
    LoadSpr('decorations/lava000.sprite', Lava000);
    LoadSpr('decorations/lava001.sprite', Lava001);
    LoadSpr('decorations/lava2001.sprite', Lava2001);
    LoadSpr('decorations/lava2002.sprite', Lava2002);
    LoadSpr('decorations/lava2003.sprite', Lava2003);
    LoadSpr('decorations/lava2004.sprite', Lava2004);
    LoadSpr('decorations/lava2005.sprite', Lava2005);
    LoadSpr('decorations/tree000.sprite', Tree000);
    LoadSpr('decorations/tree001.sprite', Tree001);
    LoadSpr('decorations/tree002.sprite', Tree002);
    LoadSpr('decorations/tree003.sprite', Tree003);
    LoadSpr('decorations/window000.sprite', Window000);
    LoadSpr('decorations/window001.sprite', Window001);
    LoadSpr('decorations/smtree000.sprite', SmTree000);
    LoadSpr('decorations/smtree001.sprite', SmTree001);

    { Bricks }
    LoadSpr('tiles/brick0000.sprite', Brick0000);
    LoadSpr('tiles/brick0001.sprite', Brick0001);
    LoadSpr('tiles/brick0002.sprite', Brick0002);
    LoadSpr('tiles/brick1000.sprite', Brick1000);
    LoadSpr('tiles/brick1001.sprite', Brick1001);
    LoadSpr('tiles/brick1002.sprite', Brick1002);
    LoadSpr('tiles/brick2000.sprite', Brick2000);
    LoadSpr('tiles/brick2001.sprite', Brick2001);
    LoadSpr('tiles/brick2002.sprite', Brick2002);

    { Items }
    LoadSpr('tiles/exit000.sprite', Exit000);
    LoadSpr('tiles/exit001.sprite', Exit001);
    LoadSpr('tiles/wood000.sprite', Wood000);
    LoadSpr('tiles/coin000.sprite', Coin000);
    LoadSpr('tiles/note000.sprite', Note000);
    LoadSpr('tiles/xblock000.sprite', XBlock000);
  end;


  { -- Helper: copy sprite constant data into an ImageBuffer -- }

  procedure CopySpriteToBuffer (var Dest: ImageBuffer; const Src; SrcSize: Integer);
  { Copies a linear byte array into an ImageBuffer [1..H, 1..W] of Char.
    Both are W*H = 280 contiguous bytes in row-major order. }
  begin
    Move(Src, Dest, SrcSize);
  end;


  procedure ConvertGrass (P0, P1, P2: ImageBufferPtr);
  var
    i, j: Integer;
    C0, C1, C2: Byte;

  procedure Convert;
  begin
    C0 := C1;
    if C1 = C2 then Exit;
    if C1 = 2 then
    begin
      C0 := 153;
      if C2 = 0 then Exit;
      C0 := 155;
    end
    else
    if C1 = 3 then
    begin
      C0 := 154;
      if C2 = 0 then Exit;
      C0 := 156;
    end
    else  { C1 = 0 }
      if C2 = 2 then
        C0 := 157
      else
        C0 := 155;
  end;

  begin
    for i := 1 to H do
      for j := 1 to W do
      begin
        C1 := Ord (P1^ [i, j]);
        C2 := Ord (P2^ [i, j]);
        Convert;
        P0^ [i, j] := Chr (C0);
      end;
  end;


  { ReColor: For each pixel in source, if value > $10,
    mask to lower 3 bits and add color offset C. Copy to dest. }
  procedure ReColor (P1, P2: Pointer; C: Byte);
  var
    Src, Dst: PByte;
    i: Integer;
    B: Byte;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    for i := 0 to W * H - 1 do
    begin
      B := Src[i];
      if B > $10 then
        B := (B and $07) + C;
      Dst[i] := B;
    end;
  end;


  { ReColor2: For each pixel in source, if value > $10,
    mask to lower 4 bits; if >= 8, mask to lower 3 bits and add C2,
    otherwise add C1. Copy to dest. }
  procedure ReColor2 (P1, P2: Pointer; C1, C2: Byte);
  var
    Src, Dst: PByte;
    i: Integer;
    B: Byte;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    for i := 0 to W * H - 1 do
    begin
      B := Src[i];
      if B > $10 then
      begin
        B := B and $0F;
        if B >= 8 then
          B := (B and $07) + C2
        else
          B := B + C1;
      end;
      Dst[i] := B;
    end;
  end;


  { Replace: Copy source to dest, replacing any byte equal to N1 with N2 }
  procedure Replace (P1, P2: Pointer; N1, N2: Byte);
  var
    Src, Dst: PByte;
    i: Integer;
    B: Byte;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    for i := 0 to W * H - 1 do
    begin
      B := Src[i];
      if B = N1 then
        B := N2;
      Dst[i] := B;
    end;
  end;


  { Mirror: Flip tile data horizontally (linear byte format).
    Each row of W pixels is reversed left-to-right. }
  procedure Mirror (P1, P2: Pointer);
  var
    Src, Dst: PByte;
    j, i: Integer;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    for j := 0 to H - 1 do
      for i := 0 to W - 1 do
        Dst[j * W + i] := Src[j * W + (W - 1 - i)];
  end;


  { Rotate: Reverse the entire linear buffer (180-degree rotation).
    Reads source from end to start, writes to dest from start to end. }
  procedure Rotate (P1, P2: Pointer);
  var
    Src, Dst: PByte;
    i, Total: Integer;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    Total := W * H;
    for i := 0 to Total - 1 do
      Dst[i] := Src[Total - 1 - i];
  end;


  procedure InitSky (NewSky: Byte);
  begin
    Sky := NewSky;
  end;

  procedure InitPipes (NewColor: Byte);
  begin
    ReColor (@Pipe000, @Pipe000, NewColor);
    ReColor (@Pipe001, @Pipe001, NewColor);
    ReColor (@Pipe002, @Pipe002, NewColor);
    ReColor (@Pipe003, @Pipe003, NewColor);
  end;

  procedure InitWalls (W1, W2, W3: Byte);

  procedure InitWall (N, WallType: Byte);
  var
    i, j: Integer;
  begin
    case WallType of
      0: begin
           CopySpriteToBuffer (FigList [N,  1], Green000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Green001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Green002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Green003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Green004, SizeOf(ImageBuffer));
         end;
      1: begin
           CopySpriteToBuffer (FigList [N,  1], Sand000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Sand001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Sand002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Sand003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Sand004, SizeOf(ImageBuffer));
         end;
      2: begin
           i := Options. GroundColor1;
           j := Options. GroundColor2;
           Recolor2 (@Green000, @FigList [N,  1], i, j);
           Recolor2 (@Green001, @FigList [N,  2], i, j);
           Recolor2 (@Green002, @FigList [N,  4], i, j);
           Recolor2 (@Green003, @FigList [N,  5], i, j);
           Recolor2 (@Green004, @FigList [N, 10], i, j);
         end;
      3: begin
           CopySpriteToBuffer (FigList [N,  1], Brown000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Brown001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Brown002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Brown003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Brown004, SizeOf(ImageBuffer));
         end;
      4: begin
           CopySpriteToBuffer (FigList [N,  1], Grass000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Grass001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Grass002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Grass003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Grass004, SizeOf(ImageBuffer));
         end;
      5: begin
           CopySpriteToBuffer (FigList [N,  1], Des000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Des001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Des002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Des003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Des004, SizeOf(ImageBuffer));
         end;

    end;

    Mirror (@FigList [N,  1], @FigList [N,  3]);
    Rotate (@FigList [N,  4], @FigList [N,  6]);
    Rotate (@FigList [N,  1], @FigList [N,  9]);
    Rotate (@FigList [N,  2], @FigList [N,  8]);
    Rotate (@FigList [N,  3], @FigList [N,  7]);
    Mirror (@FigList [N, 10], @FigList [N, 11]);
    Rotate (@FigList [N, 11], @FigList [N, 12]);
    Mirror (@FigList [N, 12], @FigList [N, 13]);

  end;

  begin  { InitWalls }
    InitWall (1, W1);
    InitWall (2, W2);
    InitWall (3, W3);
  end;

  procedure SetSkyPalette;
  var
    i, j: Integer;
  begin
    case Sky of
      0:
        begin
           ChangePalette ($E0, 35, 45, 63);
           ChangePalette ($F0, 20, 38, 48);
           ChangePalette ($FF, 54, 57, 60);
         end;
      1:
         begin
           ChangePalette ($E0, 52, 55, 55);
           ChangePalette ($F0, 42, 48, 45);
           ChangePalette ($FF, 61, 61, 61);
         end;
      2:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 48 - 2 * j, 58 - j, 58);
          end;
          ChangePalette ($F0, 35, 48, 46);
        end;
      3:
         begin
           ChangePalette ($E0,  0,  5,  3);
           ChangePalette ($F0,  8, 12, 10);
           ChangePalette ($FF,  8, 13, 13);
         end;
      4:
         begin
           ChangePalette ($E0, 35, 45, 53);
           ChangePalette ($F0, 23, 39, 43);
           ChangePalette ($FF, 58, 60, 60);
         end;
      5:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 58 - j div 2, 56 - j, 38 - j);
          end;
          ChangePalette ($F0, 52, 49, 32);
        end;
      6: { Brown bricks }
        if Options.BackGrType = 4 then
        begin
          for i := $E0 to $EF do
            ChangePalette (i, 22, 15, 11);
          ChangePalette ($FD, 22, 15, 11);
          ChangePalette ($FE, 19, 12,  8);
          ChangePalette ($FF, 25, 18, 14);
        end
        else
        begin
          for i := $E0 to $FF do
            ChangePalette (i, 19,  9,  8);
          ChangePalette ($D1, 19,  9,  8);
          ChangePalette ($D6, 21, 11, 10);
          ChangePalette ($D4, 17,  7,  6);
        end;
      7: { Gray bricks }
        if Options.BackGrType = 4 then
        begin
          for i := $E0 to $EF do
            ChangePalette (i, 18, 18, 22);
          ChangePalette ($FD, 18, 18, 22);
          ChangePalette ($FF, 23, 23, 27);
          ChangePalette ($FE, 13, 13, 17);
        end
        else
        begin
          for i := $E0 to $FF do
            ChangePalette (i, 15, 15, 18);
          ChangePalette ($D1, 15, 15, 18);
          ChangePalette ($D4, 18, 18, 21);
          ChangePalette ($D6, 12, 12, 15);
        end;
      8: { Dark brown bricks }
        if Options.BackGrType = 4 then
        begin
          for i := $E0 to $EF do
            ChangePalette (i, 17, 10, 10);
          ChangePalette ($FD, 17, 10, 10);
          ChangePalette ($FE, 11,  5,  5);
          ChangePalette ($FF, 20, 14, 14);
        end
        else
        begin
          for i := $E0 to $FF do
            ChangePalette (i, 15,  5,  5);
          ChangePalette ($D1, 15,  5,  5);
          ChangePalette ($D4, 20, 10, 10);
          ChangePalette ($D6, 10,  0,  0);
        end;
      9:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 63 - j div 3, 50 - j, 25 - j);
          end;
          ChangePalette ($F0, 48, 35, 18);
        end;
      10:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 27 - j, 43 - j, 63 - j);
          end;
          ChangePalette ($F0, 58, 58, 63);
        end;
      11:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 60 - j, 63 - j, 63 - j);
          end;
          ChangePalette ($F0, 42, 48, 45);
        end;
      12:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 55 - j, 63 - j, 63);
          end;
          ChangePalette ($F0, 30, 50, 58);
          ChangePalette ($F0, 36, 45, 41);
        end;
    end;
  end;

  procedure DrawSky (X, Y, W, H: Integer);
  const
    Y1 = 0;
    Y2 = Y1 + 96;
    YStep = (Y2 - Y1) div 16;  { = 6 }
  var
    i, j: Integer;
  begin
    if Options.BackGrType = 0 then
      Fill (X, Y, W, H, $E0)
    else
    case Sky of
      0, 1, 3, 4:
        begin
          i := Options.Horizon;
          j := i - Y;
          if (i < Y) then
            Fill (X, Y, W, H, $F0)
          else
            if (i > Y + H - 1) then
              Fill (X, Y, W, H, $E0)
            else
            begin
              Fill (X, Y, W, j, $E0);
              Fill (X, i, W, H - j, $F0);
            end;
        end;
      2, 5, 9, 10, 11, 12:
        SmoothFill (X, Y, W, H);
      6, 7, 8:
        begin
          { These background renderers expect tile-sized calls (Buffers.W x Buffers.H).
            When DrawSky is called with larger areas (e.g. full screen init),
            tile the calls to avoid reading past sprite data bounds. }
          j := Y;
          while j < Y + H do
          begin
            i := X;
            while i < X + W do
            begin
              case Options.BackGrType of
                4: DrawBricks (i, j, Buffers.W, Buffers.H);
                5: LargeBricks (i, j, Buffers.W, Buffers.H);
                6: Pillar (i, j, Buffers.W, Buffers.H);
                7: Windows (i, j, Buffers.W, Buffers.H);
              end;
              Inc(i, Buffers.W);
            end;
            Inc(j, Buffers.H);
          end;
        end;
    end;
  end;

  procedure Redraw (X, Y: Integer);
  var
    Ch: Char;
    Fig: Pointer;
    L, R, LS, RS: Boolean;
    XPos, YPos: Integer;
  begin
    XPos := X * W;
    YPos := Y * H;
    Ch := WorldMap^ [X, Y];
    if (X >= 0) and (Y >= 0) and (Y < NV) then
    begin
      if (not (Ch in [#0])) then
        if (Ch = '%') and (Options.Design = 4) then
          DrawSky (XPos, YPos, W, H div 2)
        else
          DrawSky (XPos, YPos, W, H);
      if Ch = ' ' then Exit;
      if WorldMap^ [X, Y - 1] = #18 then
      begin
        Fig := @FigList [1, 5];
        PutImage (XPos, YPos, W, H, Fig^);
      end;
      Fig := Nil;
      case Ch of

        #1 .. #26:
          begin
            if Ch > #13 then
              Ch := Chr (Ord (Ch) - 13)
            else
              if WorldMap^ [X - 1, Y] in [#14..#26] then
              begin
                if Ch in [#1, #4, #7] then
                begin
                  Fig := @FigList [1, Ord (WorldMap^ [X - 1, Y]) - 13];
                  PutImage (XPos, YPos, W, H, Fig^);
                end;
              end
              else
                if WorldMap^ [X + 1, Y] in [#14..#26] then
                  if Ch in [#3, #6, #9] then
                  begin
                    Fig := @FigList [1, Ord (WorldMap^ [X + 1, Y]) - 13];
                    PutImage (XPos, YPos, W, H, Fig^);
                  end;

            Fig := @FigList [1, Ord (Ch)];
            if not (Ch in [#1, #3, #4, #6, #7, #9]) then
            begin
              PutImage (XPos, YPos, W, H, Fig^);
              Fig := Nil;
            end;
          end;

        '?': Fig := @Quest000;
        '@': Fig := @Quest001;

        'A': begin
               L := WorldMap^ [X - 1, Y] = 'A';
               R := WorldMap^ [X + 1, Y] = 'A';
               if Odd (X + Y) then
               begin
                 RS := True;
                 LS := False;
               end
               else
               begin
                 LS := True;
                 RS := False;
               end;
               if (LS and R) then
                 Fig := @Bricks [1]
               else
                 if (RS and L) then
                   Fig := @Bricks [2]
                 else
                   Fig := @Bricks [0]
             end;


        'I': Fig := @Block000;
        'J': Fig := @Block001;
        'K': Fig := @Note000;

        'X': Fig := @XBlock000;

        'W': Fig := @Wood000;
        '=': begin
               Fig := @Pin000;
               if WorldMap^ [X, Y + 1] in CanHoldYou then
                 DrawImage (XPos, YPos, W, H, Fig^)
               else
                 UpSideDown (XPos, YPos, W, H, Fig^);
               Fig := NIL;
             end;

        '0': Fig := @Pipe000;
        '1': Fig := @Pipe001;
        '2': Fig := @Pipe002;
        '3': Fig := @Pipe003;

        '*': Fig := @Coin000;

        #254: if WorldMap^ [X, Y - 1] = #254 then
               Fig := @Exit001
             else
               Fig := @Exit000;

        #247: begin
               if (WorldMap^ [X, Y - 1] = #240) and (Options.Design = 2) then
               begin
                 Fig := @SmTree001;
                 DrawImage (XPos, YPos, W, H, Fig^);
               end;
               if WorldMap^ [X, Y - 1] = #246 then
                 if Options.Design in [1] then
                 begin
                   Fig := @WPalm000;
                   DrawImage (XPos, YPos, W, H, Fig^);
                 end;
               if (X = 0) or (WorldMap^ [X - 1, Y] = Ch) then
               begin
                 if WorldMap^ [X + 1, Y] = Ch then
                   Fig := @Grass2000
                 else
                   Fig := @Grass3000;
               end
               else
                 if WorldMap^ [X + 1, Y] = Ch then
                   Fig := @Grass1000
                 else
                   Fig := @Grass3000;
             end;

        #240: case Options.Design of
               1: if WorldMap^ [X, Y - 1] <> Ch then
                    Fig := @Fence001
                  else
                    Fig := @Fence000;
               2: if WorldMap^ [X, Y - 1] <> Ch then
                    Fig := @SmTree000
                  else
                    Fig := @SmTree001;
             end;

        #246: case Options.Design of
               1: Fig := @WPalm000;
             end;
        #250: case Options.Design of
               1: begin
                    if WorldMap^ [X - 1, Y] = #249 then
                    begin
                      Fig := @Palm3000;
                      DrawImage (XPos, YPos, W, H, Fig^);
                    end
                    else
                    if WorldMap^ [X + 1, Y] = #249 then
                    begin
                      Fig := @Palm1000;
                      DrawImage (XPos, YPos, W, H, Fig^);
                    end;
                    Fig := @Palm0000;
                 end;
             end;
        #244: case Options.Design of
               1: begin
                    if WorldMap^ [X, Y + 1] = #246 then
                    begin
                      Fig := @WPalm000;
                      DrawImage (XPos, YPos, W, H, Fig^);
                    end;
                    Fig := @Palm1000;
                  end;
             end;
        #249: case Options.Design of
               1: Fig := @Palm2000;
             end;
        #245: case Options.Design of
               1: begin
                    if WorldMap^ [X, Y + 1] = #246 then
                    begin
                      Fig := @WPalm000;
                      DrawImage (XPos, YPos, W, H, Fig^);
                    end;
                    Fig := @Palm3000;
                  end;
             end;


        { Design-independent deco variants (#148..#154) }
        #148: Fig := @Tree003;   { Tree trunk — same as '#' Design 2 }
        #149: Fig := @Tree002;   { Tree leaves — same as '%' Design 2 }
        #150: Fig := @DecoWindow001; { Window — pre-colored ($B8/$B9) }
        #151: Fig := @DecoWindow000; { Window — pre-colored ($B8/$B9) }
        #152: Fig := @DecoLava000;   { Lava — pre-colored ($BA-$BE) }
        #153: Fig := @DecoLava001;   { Lava — pre-colored ($BA-$BE) }
        #154: if WorldMap^ [X, Y - 1] <> Ch then
                Fig := @SmTree000
              else
                Fig := @SmTree001;

        '#': case Options.Design of
               1: Fig := @Fall000;
               2: case WorldMap^ [X, Y - 1] of
                    '#': PutImage (XPos, YPos, W, H, Tree001);
                    '%': begin
                           Fig := @Tree000;
                           PutImage (XPos, YPos, W, H, Fig^);
                           Fig := @Tree003;
                         end;
                    else Fig := @Tree003;
                  end;
               3: Fig := @Window001;
               4: Fig := @Lava000;
               5: Fill (XPos, YPos, W, H, 5);
             end;
        '%': case Options.Design of
               1: Fig := @Fall001;
               2: case WorldMap^ [X, Y - 1] of
                    '%': PutImage (XPos, YPos, W, H, Tree000);
                    '#': begin
                           Fig := @Tree001;
                           PutImage (XPos, YPos, W, H, Fig^);
                           Fig := @Tree002;
                         end;
                    else
                         Fig := @Tree002;
                  end;
               3: Fig := @Window000;
               4: Fig := @Lava001;
               5: begin
                    case (X + LavaCounter div 8) mod 5 of
                      0: Fig := @Lava2001;
                      1: Fig := @Lava2002;
                      2: Fig := @Lava2003;
                      3: Fig := @Lava2004;
                      4: Fig := @Lava2005;
                    end;
                  end;
             end;

        { --- Per-tile colored variants --- }

        { Colored pipes #178..#201: 6 colors x 4 shapes }
        #178..#201:
          begin
            Fig := @ColorPipes[(Ord(Ch) - CPIPE_BASE) div 4,
                               (Ord(Ch) - CPIPE_BASE) mod 4];
          end;

        { Colored bricks #202..#205: 4 colors, same pattern logic as 'A' }
        #202..#205:
          begin
            L := WorldMap^ [X - 1, Y] in [Ch, 'A', #202..#205];
            R := WorldMap^ [X + 1, Y] in [Ch, 'A', #202..#205];
            if Odd (X + Y) then
            begin
              RS := True;
              LS := False;
            end
            else
            begin
              LS := True;
              RS := False;
            end;
            if (LS and R) then
              Fig := @ColorBricks[Ord(Ch) - CBRICK_BASE, 1]
            else
              if (RS and L) then
                Fig := @ColorBricks[Ord(Ch) - CBRICK_BASE, 2]
              else
                Fig := @ColorBricks[Ord(Ch) - CBRICK_BASE, 0];
          end;

        { Colored XBlocks #206..#209: 4 colors }
        #206..#209:
          Fig := @ColorXBlocks[Ord(Ch) - CXBLOCK_BASE];

        { Colored Wood #210..#212: 3 colors }
        #210..#212:
          Fig := @ColorWood[Ord(Ch) - CWOOD_BASE];

        { Colored Breakable blocks #213..#216: 4 colors }
        #213..#216:
          Fig := @ColorBreak[Ord(Ch) - CBREAK_BASE];

        { Per-style ground wall variants: 5 styles x 9 edge variants }
        { Green wall variants #91..#99 }
        #91..#99:
          Fig := @WallVariants[0, Ord(Ch) - CWALL_GREEN];
        { Sand wall variants #100..#108 }
        #100..#108:
          Fig := @WallVariants[1, Ord(Ch) - CWALL_SAND];
        { Brown wall variants #109..#117 }
        #109..#117:
          Fig := @WallVariants[2, Ord(Ch) - CWALL_BROWN];
        { Grass wall variants #118..#126 }
        #118..#126:
          Fig := @WallVariants[3, Ord(Ch) - CWALL_GRASS];
        { Desert wall variants #139..#147 }
        #139..#147:
          Fig := @WallVariants[4, Ord(Ch) - CWALL_DESERT];

      end;
      if Fig <> Nil then
        DrawImage (XPos, YPos, W, H, Fig^);
    end;
  end;

  procedure BuildWorld;
  var
    AB,
    CD,
    EF,
    LastAB: Char;

  procedure BuildWall (X, Y: Integer);
  const
    IgnoreAbove = [#247];
  var
    A, B, L, R: Byte;
    N: Byte;
    C: Char;
    Ch, ChLeft: Set of Char;
  begin
    C := WorldMap^ [X, Y];
    case C of
      'A', 'B': begin
                  AB := C;
                  Ch := [C] + [#1 .. #13];
                  if LastAB <> C then
                    ChLeft := Ch - [#3, #6, #9]
                  else
                    ChLeft := Ch;
                  N := 0;
                end;
      'C', 'D': begin
                  CD := C;
                  Ch := [C] + [#1..#26] + ['A', 'B'] + IgnoreAbove;
                  ChLeft := Ch;
                  N := 13;
                end;
      else Exit;
    end;
    A := 1 - Byte ((WorldMap^ [X, Y - 1] in (Ch - IgnoreAbove)) or (Y = 0));
    B := 2 * Byte (Not ((Y = NV - 1) or (WorldMap^ [X, Y + 1] in Ch)));
    L := 4 * Byte (Not ((X = 0) or (WorldMap^ [X - 1, Y] in ChLeft)));
    R := 8 * Byte (Not ((X = Options.XSize - 1) or (WorldMap^ [X + 1, Y] in Ch)));
    case A + B + L + R of
      0: begin
           if (X > 0) and (Y > 0) then
             if (not (WorldMap^ [X - 1, Y - 1] in Ch)) then
               begin WorldMap^ [X, Y] := Chr (10 + N); Exit end;
           if (X < Options.XSize - 1) and (Y > 0) then
             if not (WorldMap^ [X + 1, Y - 1] in Ch) then
               begin WorldMap^ [X, Y] := Chr (11 + N); Exit end;
           if (X > 0) and (Y < NV - 1) then
             if not (WorldMap^ [X - 1, Y + 1] in Ch) then
               begin WorldMap^ [X, Y] := Chr (12 + N); Exit end;
           if (X < Options.XSize - 1) and (Y < NV - 1) then
             if not (WorldMap^ [X + 1, Y + 1] in Ch) then
               begin WorldMap^ [X, Y] := Chr (13 + N); Exit end;
           WorldMap^ [X, Y] := Chr (5 + N);
         end;
      1: WorldMap^ [X, Y] := Chr (2 + N);
      2: WorldMap^ [X, Y] := Chr (8 + N);
      4: WorldMap^ [X, Y] := Chr (4 + N);
      8: WorldMap^ [X, Y] := Chr (6 + N);

      5: WorldMap^ [X, Y] := Chr (1 + N);
      6: WorldMap^ [X, Y] := Chr (7 + N);
      9: WorldMap^ [X, Y] := Chr (3 + N);
     10: WorldMap^ [X, Y] := Chr (9 + N);

      else WorldMap^ [X, Y] := Chr (5 + N);
    end;

  end;

  var
    i, j, k, l: Integer;

  begin  { BuildWorld }
    for i := 0 to Options.XSize - 1 do
      for j := 0 to NV - 1 do
        case WorldMap^ [i, j] of
          #253: begin
                 WorldMap^ [i, j - 5] := '?';
                 WorldMap^ [i, j - 6] := #225;
                 WorldMap^ [i, j] := ' ';
               end;
          #252: begin
                 WorldMap^ [i, j - 2] := '*';
                 WorldMap^ [i, j] := ' ';
               end;
          #173: begin
                 k := j + 1;
                 for l := j downto -1 do
                   WorldMap^ [i, l] := WorldMap^ [i, k];
               end;
          #174: begin
                 WorldMap^ [i, j] := WorldMap^ [i, j - 1];
                 WorldMap^ [i, NV] := #254;
               end;
          #175: begin
                 WorldMap^ [i, j] := WorldMap^ [i, j - 1];
                 WorldMap^ [i, NV] := #255;
               end;
        end;

    LastAB := ' ';
    EF := #0;

    with Options do
      BuildWall := (WallType1 < 100);

    if Options.BuildWall then
    begin
      for i := 0 to Options.XSize - 1 do
      begin
        for j := 0 to NV - 1 do
          BuildWall (i, j);

        LastAB := AB;
        LastAB := CD;   { Note: matches original bug - should be LastCD }
        LastAB := EF;   { Note: matches original bug - should be LastEF  }
      end;
    end
    else
      with Options do
      begin
        case WallType1 of
          100:
            begin
              Recolor (@Brick0000, @Bricks [0], GroundColor1);
              Recolor (@Brick0001, @Bricks [1], GroundColor1);
              Recolor (@Brick0002, @Bricks [2], GroundColor1);
            end;
          101:
            begin
              Recolor (@Brick1000, @Bricks [0], GroundColor1);
              Recolor (@Brick1001, @Bricks [1], GroundColor1);
              Recolor (@Brick1002, @Bricks [2], GroundColor1);
            end;
          102:
            begin
              Recolor (@Brick2000, @Bricks [0], GroundColor1);
              Recolor (@Brick2001, @Bricks [1], GroundColor1);
              Recolor (@Brick2002, @Bricks [2], GroundColor1);
            end;

        end;
      end;

    { Convert grass overlays }
    ConvertGrass (@Grass1000, @Grass1001, @Grass1002);
    ConvertGrass (@Grass2000, @Grass2001, @Grass2002);
    ConvertGrass (@Grass3000, @Grass3002, @Grass3001);

    ConvertGrass (@Palm0000, @Palm0001, @Palm0002);
    ConvertGrass (@Palm1000, @Palm1001, @Palm1002);
    ConvertGrass (@Palm2000, @Palm2001, @Palm2002);
    ConvertGrass (@Palm3000, @Palm3001, @Palm3002);

    Recolor (@Block001, @Block001, Options.BrickColor);
    Recolor (@Wood000, @Wood000, Options.WoodColor);
    Recolor (@XBlock000, @XBlock000, Options.XBlockColor);

  end;

  function GetSpritePtr(TileChar: Char): Pointer;
  begin
    case TileChar of
      '?': GetSpritePtr := @Quest000;
      '@': GetSpritePtr := @Quest001;
      'I': GetSpritePtr := @Block000;
      'J': GetSpritePtr := @Block001;
      'K': GetSpritePtr := @Note000;
      'X': GetSpritePtr := @XBlock000;
      'W': GetSpritePtr := @Wood000;
      '*': GetSpritePtr := @Coin000;
      '=': GetSpritePtr := @Pin000;
      '0': GetSpritePtr := @Pipe000;
      '1': GetSpritePtr := @Pipe001;
      '2': GetSpritePtr := @Pipe002;
      '3': GetSpritePtr := @Pipe003;
      #254: GetSpritePtr := @Exit000;
      #255: GetSpritePtr := @Exit001;
      #14: GetSpritePtr := @Grass1000;
      #15: GetSpritePtr := @Grass2000;
      #16: GetSpritePtr := @Grass3000;
      { Decoration tiles — return first design variant }
      'F': GetSpritePtr := @Fence000;
      'f': GetSpritePtr := @Fence001;
      'S': GetSpritePtr := @SmTree000;
      's': GetSpritePtr := @SmTree001;
      'P': GetSpritePtr := @WPalm000;
      'a': GetSpritePtr := @Fall000;
      'b': GetSpritePtr := @Fall001;
      'T': GetSpritePtr := @Tree000;
      't': GetSpritePtr := @Tree001;
      'L': GetSpritePtr := @Lava000;
      'l': GetSpritePtr := @Lava001;
      'w': GetSpritePtr := @Window000;
      'v': GetSpritePtr := @Window001;
      { Palm tree sprites (Design 1) }
      'p': GetSpritePtr := @Palm0000;  { palm trunk/leaf center }
      'q': GetSpritePtr := @Palm1000;  { palm leaf left }
      'r': GetSpritePtr := @Palm2000;  { palm leaf top }
      'u': GetSpritePtr := @Palm3000;  { palm leaf right }
      { Deco tiles by game code (for editor tile palette) }
      '#': GetSpritePtr := @Fall000;   { waterfall/tree/window/lava per Design }
      '%': GetSpritePtr := @Fall001;
      #240: GetSpritePtr := @Fence000; { fence/small tree per Design }
      #246: GetSpritePtr := @WPalm000; { white palm trunk }
      #247: GetSpritePtr := @Grass2000;{ grass decoration (middle variant) }
      #250: GetSpritePtr := @Palm0000; { palm center }
      #244: GetSpritePtr := @Palm1000; { palm left }
      #249: GetSpritePtr := @Palm2000; { palm top }
      #245: GetSpritePtr := @Palm3000; { palm right }
      { Design-independent deco variants }
      #148: GetSpritePtr := @Tree003;   { tree trunk }
      #149: GetSpritePtr := @Tree002;   { tree leaves }
      #150: GetSpritePtr := @DecoWindow001; { window — pre-colored }
      #151: GetSpritePtr := @DecoWindow000; { window — pre-colored }
      #152: GetSpritePtr := @DecoLava000;   { lava — pre-colored }
      #153: GetSpritePtr := @DecoLava001;   { lava — pre-colored }
      #154: GetSpritePtr := @SmTree000; { small tree (top) }
    else
      GetSpritePtr := nil;
    end;
  end;

  procedure EnsureBricks;
  begin
    with Options do
    begin
      { Map WallType1 to brick sprite set and recolor into Bricks[0..2] }
      case WallType1 of
        100:
          begin
            Recolor (@Brick0000, @Bricks [0], GroundColor1);
            Recolor (@Brick0001, @Bricks [1], GroundColor1);
            Recolor (@Brick0002, @Bricks [2], GroundColor1);
          end;
        101:
          begin
            Recolor (@Brick1000, @Bricks [0], GroundColor1);
            Recolor (@Brick1001, @Bricks [1], GroundColor1);
            Recolor (@Brick1002, @Bricks [2], GroundColor1);
          end;
        102:
          begin
            Recolor (@Brick2000, @Bricks [0], GroundColor1);
            Recolor (@Brick2001, @Bricks [1], GroundColor1);
            Recolor (@Brick2002, @Bricks [2], GroundColor1);
          end;
      else
        begin
          { Default: use first brick set with current ground color }
          Recolor (@Brick0000, @Bricks [0], GroundColor1);
          Recolor (@Brick0001, @Bricks [1], GroundColor1);
          Recolor (@Brick0002, @Bricks [2], GroundColor1);
        end;
      end;
    end;
  end;

  function GetWallSpritePtr(WallType, Variant: LongInt): Pointer;
  begin
    GetWallSpritePtr := nil;
    case WallType of
      0: { Green }
        case Variant of
          0: GetWallSpritePtr := @Green000;  { corner }
          1: GetWallSpritePtr := @Green001;  { top }
          4: GetWallSpritePtr := @Green003;  { body }
        end;
      1: { Sand }
        case Variant of
          0: GetWallSpritePtr := @Sand000;
          1: GetWallSpritePtr := @Sand001;
          4: GetWallSpritePtr := @Sand003;
        end;
      3: { Brown }
        case Variant of
          0: GetWallSpritePtr := @Brown000;
          1: GetWallSpritePtr := @Brown001;
          4: GetWallSpritePtr := @Brown003;
        end;
      4: { Grass }
        case Variant of
          0: GetWallSpritePtr := @Grass000;
          1: GetWallSpritePtr := @Grass001;
          4: GetWallSpritePtr := @Grass003;
        end;
      5: { Desert }
        case Variant of
          0: GetWallSpritePtr := @Des000;
          1: GetWallSpritePtr := @Des001;
          4: GetWallSpritePtr := @Des003;
        end;
    end;
  end;

  function GetBrickSpritePtr(BrickType: LongInt): Pointer;
  begin
    GetBrickSpritePtr := nil;
    case BrickType of
      0: GetBrickSpritePtr := @Brick0000;
      1: GetBrickSpritePtr := @Brick1000;
      2: GetBrickSpritePtr := @Brick2000;
    end;
  end;

  { --- Sprite backup/restore for editor level switching --- }

  var
    Bak_Pipe000, Bak_Pipe001, Bak_Pipe002, Bak_Pipe003: ImageBuffer;
    Bak_Block001: ImageBuffer;
    Bak_Wood000:  ImageBuffer;
    Bak_XBlock000: ImageBuffer;
    BakSaved: Boolean;

  procedure SaveSpriteBackups;
  begin
    Move(Pipe000,   Bak_Pipe000,   SizeOf(ImageBuffer));
    Move(Pipe001,   Bak_Pipe001,   SizeOf(ImageBuffer));
    Move(Pipe002,   Bak_Pipe002,   SizeOf(ImageBuffer));
    Move(Pipe003,   Bak_Pipe003,   SizeOf(ImageBuffer));
    Move(Block001,  Bak_Block001,  SizeOf(ImageBuffer));
    Move(Wood000,   Bak_Wood000,   SizeOf(ImageBuffer));
    Move(XBlock000, Bak_XBlock000, SizeOf(ImageBuffer));
    BakSaved := True;
  end;

  procedure RestoreSpriteBackups;
  begin
    if not BakSaved then Exit;
    Move(Bak_Pipe000,   Pipe000,   SizeOf(ImageBuffer));
    Move(Bak_Pipe001,   Pipe001,   SizeOf(ImageBuffer));
    Move(Bak_Pipe002,   Pipe002,   SizeOf(ImageBuffer));
    Move(Bak_Pipe003,   Pipe003,   SizeOf(ImageBuffer));
    Move(Bak_Block001,  Block001,  SizeOf(ImageBuffer));
    Move(Bak_Wood000,   Wood000,   SizeOf(ImageBuffer));
    Move(Bak_XBlock000, XBlock000, SizeOf(ImageBuffer));
  end;

  { --- Per-Tile Color System: Initialize pre-colored sprites --- }

  procedure InitColoredSprites;
  var
    ci: Integer;
  begin
    if not BakSaved then Exit;  { Need pristine backups }

    { Colored pipes: for each of 6 colors, ReColor pristine pipe sprites }
    for ci := 0 to 5 do
    begin
      ReColor(@Bak_Pipe000, @ColorPipes[ci, 0], PIPE_COLORS[ci]);
      ReColor(@Bak_Pipe001, @ColorPipes[ci, 1], PIPE_COLORS[ci]);
      ReColor(@Bak_Pipe002, @ColorPipes[ci, 2], PIPE_COLORS[ci]);
      ReColor(@Bak_Pipe003, @ColorPipes[ci, 3], PIPE_COLORS[ci]);
    end;

    { Colored bricks: for each of 4 colors, ReColor all 3 brick patterns }
    for ci := 0 to 3 do
    begin
      ReColor(@Brick0000, @ColorBricks[ci, 0], BRICK_COLORS[ci]);
      ReColor(@Brick0001, @ColorBricks[ci, 1], BRICK_COLORS[ci]);
      ReColor(@Brick0002, @ColorBricks[ci, 2], BRICK_COLORS[ci]);
    end;

    { Colored XBlocks: for each of 4 colors }
    for ci := 0 to 3 do
      ReColor(@Bak_XBlock000, @ColorXBlocks[ci], XBLOCK_COLORS[ci]);

    { Colored Wood: for each of 3 colors }
    for ci := 0 to 2 do
      ReColor(@Bak_Wood000, @ColorWood[ci], WOOD_COLORS[ci]);

    { Colored Breakable blocks (J): for each of 4 colors }
    for ci := 0 to 3 do
      ReColor(@Bak_Block001, @ColorBreak[ci], BRICK_COLORS[ci]);

    { Wall variant sprites: 5 styles x 9 variants each (TL,Top,TR,Left,Body,Right,BL,Bot,BR)
      Generated using same Mirror/Rotate chain as InitWall in FigList.
      Style 0=Green, 1=Sand, 2=Brown(wall3), 3=Grass(wall4), 4=Desert(wall5) }

    { Style 0: Green }
    CopySpriteToBuffer(WallVariants[0, 0], Green000, SizeOf(ImageBuffer));  { TL corner }
    CopySpriteToBuffer(WallVariants[0, 1], Green001, SizeOf(ImageBuffer));  { Top edge }
    Mirror(@WallVariants[0, 0], @WallVariants[0, 2]);                      { TR = Mirror(TL) }
    CopySpriteToBuffer(WallVariants[0, 3], Green002, SizeOf(ImageBuffer));  { Left edge }
    CopySpriteToBuffer(WallVariants[0, 4], Green003, SizeOf(ImageBuffer));  { Body }
    Rotate(@WallVariants[0, 3], @WallVariants[0, 5]);                      { Right = Rotate(Left) }
    Rotate(@WallVariants[0, 2], @WallVariants[0, 6]);                      { BL = Rotate(TR) }
    Rotate(@WallVariants[0, 1], @WallVariants[0, 7]);                      { Bottom = Rotate(Top) }
    Rotate(@WallVariants[0, 0], @WallVariants[0, 8]);                      { BR = Rotate(TL) }

    { Style 1: Sand }
    CopySpriteToBuffer(WallVariants[1, 0], Sand000, SizeOf(ImageBuffer));
    CopySpriteToBuffer(WallVariants[1, 1], Sand001, SizeOf(ImageBuffer));
    Mirror(@WallVariants[1, 0], @WallVariants[1, 2]);
    CopySpriteToBuffer(WallVariants[1, 3], Sand002, SizeOf(ImageBuffer));
    CopySpriteToBuffer(WallVariants[1, 4], Sand003, SizeOf(ImageBuffer));
    Rotate(@WallVariants[1, 3], @WallVariants[1, 5]);
    Rotate(@WallVariants[1, 2], @WallVariants[1, 6]);
    Rotate(@WallVariants[1, 1], @WallVariants[1, 7]);
    Rotate(@WallVariants[1, 0], @WallVariants[1, 8]);

    { Style 2: Brown (InitWalls type 3) }
    CopySpriteToBuffer(WallVariants[2, 0], Brown000, SizeOf(ImageBuffer));
    CopySpriteToBuffer(WallVariants[2, 1], Brown001, SizeOf(ImageBuffer));
    Mirror(@WallVariants[2, 0], @WallVariants[2, 2]);
    CopySpriteToBuffer(WallVariants[2, 3], Brown002, SizeOf(ImageBuffer));
    CopySpriteToBuffer(WallVariants[2, 4], Brown003, SizeOf(ImageBuffer));
    Rotate(@WallVariants[2, 3], @WallVariants[2, 5]);
    Rotate(@WallVariants[2, 2], @WallVariants[2, 6]);
    Rotate(@WallVariants[2, 1], @WallVariants[2, 7]);
    Rotate(@WallVariants[2, 0], @WallVariants[2, 8]);

    { Style 3: Grass (InitWalls type 4) }
    CopySpriteToBuffer(WallVariants[3, 0], Grass000, SizeOf(ImageBuffer));
    CopySpriteToBuffer(WallVariants[3, 1], Grass001, SizeOf(ImageBuffer));
    Mirror(@WallVariants[3, 0], @WallVariants[3, 2]);
    CopySpriteToBuffer(WallVariants[3, 3], Grass002, SizeOf(ImageBuffer));
    CopySpriteToBuffer(WallVariants[3, 4], Grass003, SizeOf(ImageBuffer));
    Rotate(@WallVariants[3, 3], @WallVariants[3, 5]);
    Rotate(@WallVariants[3, 2], @WallVariants[3, 6]);
    Rotate(@WallVariants[3, 1], @WallVariants[3, 7]);
    Rotate(@WallVariants[3, 0], @WallVariants[3, 8]);

    { Style 4: Desert (InitWalls type 5) }
    CopySpriteToBuffer(WallVariants[4, 0], Des000, SizeOf(ImageBuffer));
    CopySpriteToBuffer(WallVariants[4, 1], Des001, SizeOf(ImageBuffer));
    Mirror(@WallVariants[4, 0], @WallVariants[4, 2]);
    CopySpriteToBuffer(WallVariants[4, 3], Des002, SizeOf(ImageBuffer));
    CopySpriteToBuffer(WallVariants[4, 4], Des003, SizeOf(ImageBuffer));
    Rotate(@WallVariants[4, 3], @WallVariants[4, 5]);
    Rotate(@WallVariants[4, 2], @WallVariants[4, 6]);
    Rotate(@WallVariants[4, 1], @WallVariants[4, 7]);
    Rotate(@WallVariants[4, 0], @WallVariants[4, 8]);

    { Deco sprites: remap conflicting palette indices to safe slots.
      Window sprites: $F0 -> $B8, $FF -> $B9
      Lava sprites:   $07 -> $BA, $08 -> $BB, $09 -> $BC, $0A -> $BD, $0B -> $BE }
    for ci := 0 to W * H - 1 do
    begin
      { Window000 }
      case Window000[ci] of
        $F0: DecoWindow000[ci] := $B8;
        $FF: DecoWindow000[ci] := $B9;
      else
        DecoWindow000[ci] := Window000[ci];
      end;
      { Window001 }
      case Window001[ci] of
        $F0: DecoWindow001[ci] := $B8;
        $FF: DecoWindow001[ci] := $B9;
      else
        DecoWindow001[ci] := Window001[ci];
      end;
      { Lava000 }
      case Lava000[ci] of
        $07: DecoLava000[ci] := $BA;
        $08: DecoLava000[ci] := $BB;
        $09: DecoLava000[ci] := $BC;
        $0A: DecoLava000[ci] := $BD;
        $0B: DecoLava000[ci] := $BE;
      else
        DecoLava000[ci] := Lava000[ci];
      end;
      { Lava001 }
      case Lava001[ci] of
        $07: DecoLava001[ci] := $BA;
        $08: DecoLava001[ci] := $BB;
        $09: DecoLava001[ci] := $BC;
        $0A: DecoLava001[ci] := $BD;
        $0B: DecoLava001[ci] := $BE;
      else
        DecoLava001[ci] := Lava001[ci];
      end;
    end;

    ColorSpritesReady := True;
  end;

  procedure InitDecoSpritePalette;
  { Set palette entries $B8-$BE to fixed colors for deco sprites.
    Window: castle brown tones (from SkyType 8 / BackGrType 4).
    Lava: orange-red lava colors (from SkyType 6, waterfall frame 0). }
  begin
    { Window colors (matching SetWindowPalette / castle theme) }
    OutPalette($B8, 17, 10, 10);  { was $F0 — dark brown }
    OutPalette($B9, 20, 14, 14);  { was $FF — light brown }

    { Lava colors (matching SkyType 6 waterfall, frame 0 static snapshot)
      Formula: SkyType 6..8 → (42+4*k, 5+k*k, 2*k)
      At frame 0: i=0→k=1, i=1→k=2, i=2→k=3, i=3→k=4, i=4→k=5 }
    OutPalette($BA, 46,  6,  2);  { was $07 (idx 7), k=1 }
    OutPalette($BB, 50,  9,  4);  { was $08 (idx 8), k=2 }
    OutPalette($BC, 54, 14,  6);  { was $09 (idx 9), k=3 }
    OutPalette($BD, 58, 21,  8);  { was $0A (idx 10), k=4 }
    OutPalette($BE, 62, 30, 10);  { was $0B (idx 11), k=5 }
  end;

end.
