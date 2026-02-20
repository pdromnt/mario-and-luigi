unit EdRender;
{
  Editor Rendering Unit
  Bridges the game's VGA256 indexed framebuffer with OpenGL textures
  for display in the ImGui level viewport.

  Flow:
    1. LoadLevel() loads a built-in level into the game's WorldMap/Options
    2. RenderLevel() draws all tiles into the FrameBuffer using game routines
    3. UpdateTexture() converts indexed pixels to RGBA and uploads to OpenGL
    4. GetLevelTexture() returns the GL texture ID for ImGui.Image()
}

{$IFDEF FPC}
  {$mode Delphi}{$H+}{$J-}
{$ENDIF}

interface

uses
  glad_gl;

{ Initialize the editor renderer (create textures, etc.) }
procedure EdRenderInit;

{ Shut down the editor renderer (free textures) }
procedure EdRenderShutdown;

{ Load a built-in level by index (0..5) and sub-level ('A' or 'B') }
procedure EdLoadLevel(WorldIdx: Integer; Sub: Char);

{ Render the full level into the framebuffer and update the GL texture.
  ScrollX is the horizontal scroll offset in pixels. }
procedure EdRenderLevel(ScrollX: Integer);

{ Get the OpenGL texture ID for ImGui.Image() }
function EdGetLevelTexture: GLuint;

{ Get level width in pixels }
function EdGetLevelWidth: Integer;

{ Get viewport dimensions }
function EdGetViewWidth: Integer;
function EdGetViewHeight: Integer;

{ Get tile character at world tile coordinates }
function EdGetTileAt(TileX, TileY: Integer): Char;

{ Get tile width and height in pixels }
function EdGetTileW: Integer;
function EdGetTileH: Integer;

{ Get number of vertical tiles }
function EdGetNV: Integer;

{ Get player start position (tile coordinates) }
function EdGetPlayerStartX: Integer;
function EdGetPlayerStartY: Integer;

{ Get level XSize (number of horizontal tiles) }
function EdGetLevelXSize: Integer;

{ Get level theme options }
function EdGetSkyType: Integer;
function EdGetBackGrType: Integer;
function EdGetClouds: Integer;
function EdGetHorizon: Integer;

{ --- Tile Atlas for Palette Panel --- }

const
  ATLAS_COLS = 16;
  ATLAS_ROWS = 12;
  ATLAS_PX_W = ATLAS_COLS * 20;  { 320 }
  ATLAS_PX_H = ATLAS_ROWS * 14;  { 168 }

  CAT_GROUND   = 0;
  CAT_BRICKS   = 1;
  CAT_PIPES    = 2;
  CAT_BLOCKS   = 3;
  CAT_ITEMS    = 4;
  CAT_ENEMIES  = 5;
  CAT_DECO     = 6;
  CAT_PLATFORM = 7;
  CAT_REWARDS  = 8;

const
  { ColorType constants for level-independent recoloring }
  CT_NONE   = 0;  { Use sprite data as-is (no recoloring) }
  CT_PIPE   = 1;  { Apply ReColor with ColorVal as pipe color }
  CT_BRICK  = 2;  { Apply ReColor with ColorVal as brick color }
  CT_WOOD   = 3;  { Apply ReColor with ColorVal as wood color }
  CT_XBLOCK = 4;  { Apply ReColor with ColorVal as xblock color }

type
  TTileAtlasEntry = record
    CharCode: Byte;
    Name: PAnsiChar;
    Category: Byte;
    AtlasCol: Byte;
    AtlasRow: Byte;
    IsMarker: Boolean;
    MarkerLab: AnsiChar;
    MarkerCol: LongWord;  { ABGR color for marker tiles }
    ColorType: Byte;       { CT_NONE, CT_PIPE, CT_BRICK, CT_WOOD, CT_XBLOCK }
    ColorVal: Byte;        { Color value to apply via ReColor }
  end;

{ Build the tile atlas texture (call after loading a level) }
procedure EdBuildTileAtlas;

{ Get atlas texture ID for ImGui }
function EdGetAtlasTexture: GLuint;

{ Get tile atlas catalog info }
function EdGetTileAtlasCount: Integer;
function EdGetTileAtlasEntry(Index: Integer): TTileAtlasEntry;

{ --- Sky & Background Preview --- }

const
  SKY_PV_W = 320;   { Preview width = full screen width }
  SKY_PV_H = 200;   { Preview height — full VGA screen to capture sky + parallax }

{ Build sky preview texture (call after loading a level) }
procedure EdBuildSkyPreview;

{ Build sky preview for a specific sky type and background type.
  Temporarily overrides the level's settings, renders, then restores. }
procedure EdBuildSkyPreviewForType(ASkyType, ABackGrType, AHorizon, AClouds: Integer);

{ Get sky preview texture ID for ImGui }
function EdGetSkyTexture: GLuint;

{ Get descriptive name for a sky type }
function EdGetSkyTypeName(ASkyType: Integer): PAnsiChar;

{ Get descriptive name for a background type }
function EdGetBackGrTypeName(ABackGrType: Integer): PAnsiChar;

{ --- Enemy Atlas for Viewport Sprites & Enemy Palette --- }

const
  ENEMY_ATLAS_COLS = 7;
  ENEMY_ATLAS_ROWS = 2;
  ENEMY_CELL_W = 24;   { Max sprite width (Piranha Plant is 24 wide) }
  ENEMY_CELL_H = 24;   { Max sprite height (Koopa is 24 tall) }
  ENEMY_ATLAS_PX_W = ENEMY_ATLAS_COLS * ENEMY_CELL_W;  { 168 }
  ENEMY_ATLAS_PX_H = ENEMY_ATLAS_ROWS * ENEMY_CELL_H;  { 48 }
  ENEMY_ATLAS_COUNT = 13;

type
  TEnemyAtlasEntry = record
    CharCode: Byte;        { Primary character code in WorldMap }
    Name: PAnsiChar;       { Human-readable name }
    AtlasCol: Byte;        { Column in atlas grid (0..2) }
    AtlasRow: Byte;        { Row in atlas grid (0..2) }
    SprW: Byte;            { Actual sprite width in pixels }
    SprH: Byte;            { Actual sprite height in pixels }
  end;

{ Build the enemy atlas texture (call after loading a level) }
procedure EdBuildEnemyAtlas;

{ Get enemy atlas texture ID for ImGui }
function EdGetEnemyAtlasTexture: GLuint;

{ Get enemy atlas catalog info }
function EdGetEnemyAtlasCount: Integer;
function EdGetEnemyAtlasEntry(Index: Integer): TEnemyAtlasEntry;

{ Find enemy atlas index for a given tile character, or -1 if not found }
function EdFindEnemyAtlasIndex(Ch: Char): Integer;

{ --- Camera Lock Markers --- }

const
  CAM_LOCK_LEFT  = 1;  { #254 in hidden row — blocks leftward scrolling }
  CAM_LOCK_RIGHT = 2;  { #255 in hidden row — blocks rightward scrolling }

type
  TCamLockEntry = record
    Col: Integer;       { Tile column where lock is placed }
    LockType: Byte;     { CAM_LOCK_LEFT or CAM_LOCK_RIGHT }
  end;

{ Get all camera lock markers in the level.
  Returns the count; fills Entries array (max MaxEntries). }
function EdGetCameraLocks(out Entries: array of TCamLockEntry; MaxEntries: Integer): Integer;

{ --- Player Sprite for Viewport Start Marker --- }

const
  PLAYER_SPR_W = 20;
  PLAYER_SPR_H = 28;

{ Build the player sprite texture (call after loading a level) }
procedure EdBuildPlayerSprite;

{ Get player sprite texture ID for ImGui }
function EdGetPlayerSpriteTexture: GLuint;

implementation

uses
  SysUtils,
  VGA256, Buffers, Figures, BackGr, Worlds, Palettes, Enemies;

{ Small Mario standing sprite — included directly to avoid pulling in Players unit.
  Sprite faces left; we flip it horizontally when building the texture. }
{$I ..\sprites\SWMAR000.inc}

const
  { Viewport dimensions match the game }
  VIEW_W = SCREEN_WIDTH;       { 320 pixels }
  VIEW_H = WINDOWHEIGHT;       { 182 pixels (13 * 14) }

const
  { Tile atlas catalog — level-independent with all color variants.
    Atlas is 16x12 = 192 slots.
    Pipe colors:   $18(Gray) $30(Green) $50(Teal) $70(Lime) $80(Purple) $B0(Red)
    Brick colors:  $18(Gray) $30(Brown) $48(Blue) $B0(Red)
    Wood colors:   $18(Gray) $30(Brown) $48(Blue)
    XBlock colors: $30(Brown) $68(Orange) $A0(LtGreen) $B0(Red) }
  TILE_ATLAS_COUNT = 112;
  TileAtlas: array[0..TILE_ATLAS_COUNT - 1] of TTileAtlasEntry = (
    { === ROW 0: Ground wall types (body/top/corner) === }
    { Current level's ground (cols 0-2) }
    (CharCode: Ord('C'); Name: 'Ground (body)';   Category: CAT_GROUND; AtlasCol:  0; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Ground (top)';    Category: CAT_GROUND; AtlasCol:  1; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Ground (corner)'; Category: CAT_GROUND; AtlasCol:  2; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Green wall type 0 (cols 3-5) }
    (CharCode: Ord('C'); Name: 'Green (body)';    Category: CAT_GROUND; AtlasCol:  3; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Green (top)';     Category: CAT_GROUND; AtlasCol:  4; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Green (corner)';  Category: CAT_GROUND; AtlasCol:  5; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Sand wall type 1 (cols 6-8) }
    (CharCode: Ord('C'); Name: 'Sand (body)';     Category: CAT_GROUND; AtlasCol:  6; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Sand (top)';      Category: CAT_GROUND; AtlasCol:  7; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Sand (corner)';   Category: CAT_GROUND; AtlasCol:  8; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Brown wall type 3 (cols 9-11) }
    (CharCode: Ord('C'); Name: 'Brown (body)';    Category: CAT_GROUND; AtlasCol:  9; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Brown (top)';     Category: CAT_GROUND; AtlasCol: 10; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Brown (corner)';  Category: CAT_GROUND; AtlasCol: 11; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Grass wall type 4 (cols 12-14) }
    (CharCode: Ord('C'); Name: 'Grass (body)';    Category: CAT_GROUND; AtlasCol: 12; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Grass (top)';     Category: CAT_GROUND; AtlasCol: 13; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Grass (corner)';  Category: CAT_GROUND; AtlasCol: 14; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { === ROW 1: Ground cont + Platforms === }
    { Desert wall type 5 (cols 0-2) }
    (CharCode: Ord('C'); Name: 'Desert (body)';   Category: CAT_GROUND; AtlasCol:  0; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Desert (top)';    Category: CAT_GROUND; AtlasCol:  1; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('C'); Name: 'Desert (corner)'; Category: CAT_GROUND; AtlasCol:  2; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Platforms (cols 3-6) }
    (CharCode: 14;       Name: 'Platform (left)';  Category: CAT_PLATFORM; AtlasCol: 3; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 15;       Name: 'Platform (mid)';   Category: CAT_PLATFORM; AtlasCol: 4; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 16;       Name: 'Platform (right)'; Category: CAT_PLATFORM; AtlasCol: 5; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('='); Name: 'Pin';              Category: CAT_PLATFORM; AtlasCol: 6; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Static blocks (cols 7-12) }
    (CharCode: Ord('?'); Name: 'Question Block'; Category: CAT_BLOCKS; AtlasCol:  7; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('@'); Name: 'Used Block';     Category: CAT_BLOCKS; AtlasCol:  8; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('$'); Name: 'Hidden Block';   Category: CAT_BLOCKS; AtlasCol:  9; AtlasRow: 1; IsMarker: True;  MarkerLab: '?'; MarkerCol: $80FFFFFF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('I'); Name: 'Solid Block';    Category: CAT_BLOCKS; AtlasCol: 10; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('K'); Name: 'Note Block';     Category: CAT_BLOCKS; AtlasCol: 11; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Items (cols 12-14) }
    (CharCode: Ord('*'); Name: 'Coin';           Category: CAT_ITEMS; AtlasCol: 12; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 254;      Name: 'Flag (top)';     Category: CAT_ITEMS; AtlasCol: 13; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 255;      Name: 'Flag (pole)';    Category: CAT_ITEMS; AtlasCol: 14; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),

    { === ROW 2-3: Pipes — all 6 colors x 4 tiles = 24 entries === }
    { Pipe color $18 (Gray) }
    (CharCode: Ord('0'); Name: 'Pipe TL $18';  Category: CAT_PIPES; AtlasCol:  0; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $18),
    (CharCode: Ord('1'); Name: 'Pipe TR $18';  Category: CAT_PIPES; AtlasCol:  1; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $18),
    (CharCode: Ord('2'); Name: 'Pipe BL $18';  Category: CAT_PIPES; AtlasCol:  2; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $18),
    (CharCode: Ord('3'); Name: 'Pipe BR $18';  Category: CAT_PIPES; AtlasCol:  3; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $18),
    { Pipe color $30 (Green) }
    (CharCode: Ord('0'); Name: 'Pipe TL $30';  Category: CAT_PIPES; AtlasCol:  4; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $30),
    (CharCode: Ord('1'); Name: 'Pipe TR $30';  Category: CAT_PIPES; AtlasCol:  5; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $30),
    (CharCode: Ord('2'); Name: 'Pipe BL $30';  Category: CAT_PIPES; AtlasCol:  6; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $30),
    (CharCode: Ord('3'); Name: 'Pipe BR $30';  Category: CAT_PIPES; AtlasCol:  7; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $30),
    { Pipe color $50 (Teal) }
    (CharCode: Ord('0'); Name: 'Pipe TL $50';  Category: CAT_PIPES; AtlasCol:  8; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $50),
    (CharCode: Ord('1'); Name: 'Pipe TR $50';  Category: CAT_PIPES; AtlasCol:  9; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $50),
    (CharCode: Ord('2'); Name: 'Pipe BL $50';  Category: CAT_PIPES; AtlasCol: 10; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $50),
    (CharCode: Ord('3'); Name: 'Pipe BR $50';  Category: CAT_PIPES; AtlasCol: 11; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $50),
    { Pipe color $70 (Lime) }
    (CharCode: Ord('0'); Name: 'Pipe TL $70';  Category: CAT_PIPES; AtlasCol: 12; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $70),
    (CharCode: Ord('1'); Name: 'Pipe TR $70';  Category: CAT_PIPES; AtlasCol: 13; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $70),
    (CharCode: Ord('2'); Name: 'Pipe BL $70';  Category: CAT_PIPES; AtlasCol: 14; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $70),
    (CharCode: Ord('3'); Name: 'Pipe BR $70';  Category: CAT_PIPES; AtlasCol: 15; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $70),
    { Pipe color $80 (Purple) }
    (CharCode: Ord('0'); Name: 'Pipe TL $80';  Category: CAT_PIPES; AtlasCol:  0; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $80),
    (CharCode: Ord('1'); Name: 'Pipe TR $80';  Category: CAT_PIPES; AtlasCol:  1; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $80),
    (CharCode: Ord('2'); Name: 'Pipe BL $80';  Category: CAT_PIPES; AtlasCol:  2; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $80),
    (CharCode: Ord('3'); Name: 'Pipe BR $80';  Category: CAT_PIPES; AtlasCol:  3; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $80),
    { Pipe color $B0 (Red) }
    (CharCode: Ord('0'); Name: 'Pipe TL $B0';  Category: CAT_PIPES; AtlasCol:  4; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $B0),
    (CharCode: Ord('1'); Name: 'Pipe TR $B0';  Category: CAT_PIPES; AtlasCol:  5; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $B0),
    (CharCode: Ord('2'); Name: 'Pipe BL $B0';  Category: CAT_PIPES; AtlasCol:  6; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $B0),
    (CharCode: Ord('3'); Name: 'Pipe BR $B0';  Category: CAT_PIPES; AtlasCol:  7; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $B0),

    { === ROW 3 cols 8+, ROW 4: Bricks — 3 patterns x 4 colors = 12 entries === }
    { Brick Pattern 0 x 4 colors }
    (CharCode: Ord('A'); Name: 'Brick0 $18';  Category: CAT_BRICKS; AtlasCol:  8; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $18),
    (CharCode: Ord('A'); Name: 'Brick0 $30';  Category: CAT_BRICKS; AtlasCol:  9; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $30),
    (CharCode: Ord('A'); Name: 'Brick0 $48';  Category: CAT_BRICKS; AtlasCol: 10; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $48),
    (CharCode: Ord('A'); Name: 'Brick0 $B0';  Category: CAT_BRICKS; AtlasCol: 11; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $B0),
    { Brick Pattern 1 x 4 colors }
    (CharCode: Ord('A'); Name: 'Brick1 $18';  Category: CAT_BRICKS; AtlasCol: 12; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $18),
    (CharCode: Ord('A'); Name: 'Brick1 $30';  Category: CAT_BRICKS; AtlasCol: 13; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $30),
    (CharCode: Ord('A'); Name: 'Brick1 $48';  Category: CAT_BRICKS; AtlasCol: 14; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $48),
    (CharCode: Ord('A'); Name: 'Brick1 $B0';  Category: CAT_BRICKS; AtlasCol: 15; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $B0),
    { Brick Pattern 2 x 4 colors }
    (CharCode: Ord('A'); Name: 'Brick2 $18';  Category: CAT_BRICKS; AtlasCol:  0; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $18),
    (CharCode: Ord('A'); Name: 'Brick2 $30';  Category: CAT_BRICKS; AtlasCol:  1; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $30),
    (CharCode: Ord('A'); Name: 'Brick2 $48';  Category: CAT_BRICKS; AtlasCol:  2; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $48),
    (CharCode: Ord('A'); Name: 'Brick2 $B0';  Category: CAT_BRICKS; AtlasCol:  3; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $B0),

    { === ROW 4 cols 4+: Color-variant blocks === }
    { Breakable Block 'J' x 4 brick colors }
    (CharCode: Ord('J'); Name: 'Break $18';   Category: CAT_BLOCKS; AtlasCol:  4; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $18),
    (CharCode: Ord('J'); Name: 'Break $30';   Category: CAT_BLOCKS; AtlasCol:  5; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $30),
    (CharCode: Ord('J'); Name: 'Break $48';   Category: CAT_BLOCKS; AtlasCol:  6; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $48),
    (CharCode: Ord('J'); Name: 'Break $B0';   Category: CAT_BLOCKS; AtlasCol:  7; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $B0),
    { Wood 'W' x 3 wood colors }
    (CharCode: Ord('W'); Name: 'Wood $18';    Category: CAT_BLOCKS; AtlasCol:  8; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_WOOD;  ColorVal: $18),
    (CharCode: Ord('W'); Name: 'Wood $30';    Category: CAT_BLOCKS; AtlasCol:  9; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_WOOD;  ColorVal: $30),
    (CharCode: Ord('W'); Name: 'Wood $48';    Category: CAT_BLOCKS; AtlasCol: 10; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_WOOD;  ColorVal: $48),
    { XBlock 'X' x 4 xblock colors }
    (CharCode: Ord('X'); Name: 'XBlock $30';  Category: CAT_BLOCKS; AtlasCol: 11; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_XBLOCK; ColorVal: $30),
    (CharCode: Ord('X'); Name: 'XBlock $68';  Category: CAT_BLOCKS; AtlasCol: 12; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_XBLOCK; ColorVal: $68),
    (CharCode: Ord('X'); Name: 'XBlock $A0';  Category: CAT_BLOCKS; AtlasCol: 13; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_XBLOCK; ColorVal: $A0),
    (CharCode: Ord('X'); Name: 'XBlock $B0';  Category: CAT_BLOCKS; AtlasCol: 14; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_XBLOCK; ColorVal: $B0),

    { === ROW 5: Rewards + Enemy markers === }
    (CharCode: $E0; Name: 'Mushroom/Fire';     Category: CAT_REWARDS; AtlasCol:  0; AtlasRow: 5; IsMarker: True; MarkerLab: 'M'; MarkerCol: $CC0000FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E1; Name: '1-Up Mushroom';     Category: CAT_REWARDS; AtlasCol:  1; AtlasRow: 5; IsMarker: True; MarkerLab: '1'; MarkerCol: $CC00CC00; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E2; Name: 'Star';              Category: CAT_REWARDS; AtlasCol:  2; AtlasRow: 5; IsMarker: True; MarkerLab: 'S'; MarkerCol: $CC00FFFF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E3; Name: 'Multi-Coin (x2)';  Category: CAT_REWARDS; AtlasCol:  3; AtlasRow: 5; IsMarker: True; MarkerLab: '$'; MarkerCol: $CC00CCFF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $ED; Name: 'Poison Mushroom';   Category: CAT_REWARDS; AtlasCol:  4; AtlasRow: 5; IsMarker: True; MarkerLab: 'X'; MarkerCol: $CC0000AA; ColorType: CT_NONE; ColorVal: 0),
    { Pipe action markers }
    (CharCode: $E0; Name: 'Pipe: Warp';        Category: CAT_REWARDS; AtlasCol:  5; AtlasRow: 5; IsMarker: True; MarkerLab: 'W'; MarkerCol: $CC00CC00; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E1; Name: 'Pipe: World Swap';  Category: CAT_REWARDS; AtlasCol:  6; AtlasRow: 5; IsMarker: True; MarkerLab: 'S'; MarkerCol: $CCFFCC00; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E7; Name: 'Pipe: Exit';        Category: CAT_REWARDS; AtlasCol:  7; AtlasRow: 5; IsMarker: True; MarkerLab: 'E'; MarkerCol: $CC0055FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $EF; Name: 'Note Block Jump';   Category: CAT_REWARDS; AtlasCol:  8; AtlasRow: 5; IsMarker: True; MarkerLab: 'N'; MarkerCol: $CC8888FF; ColorType: CT_NONE; ColorVal: 0),
    { Enemy markers (tile atlas only, actual sprites in enemy atlas) }
    (CharCode: $80; Name: 'Goomba';           Category: CAT_ENEMIES; AtlasCol:  9; AtlasRow: 5; IsMarker: True; MarkerLab: 'G'; MarkerCol: $CC0000FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $83; Name: 'Grey Goomba';      Category: CAT_ENEMIES; AtlasCol: 10; AtlasRow: 5; IsMarker: True; MarkerLab: 'G'; MarkerCol: $CC0000FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $81; Name: 'Fish';             Category: CAT_ENEMIES; AtlasCol: 11; AtlasRow: 5; IsMarker: True; MarkerLab: 'F'; MarkerCol: $CCFFCC00; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $82; Name: 'Fireball';         Category: CAT_ENEMIES; AtlasCol: 12; AtlasRow: 5; IsMarker: True; MarkerLab: '!'; MarkerCol: $CC0088FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $84; Name: 'Piranha Plant';    Category: CAT_ENEMIES; AtlasCol: 13; AtlasRow: 5; IsMarker: True; MarkerLab: 'P'; MarkerCol: $CCFF00FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $87; Name: 'Spiny';            Category: CAT_ENEMIES; AtlasCol: 14; AtlasRow: 5; IsMarker: True; MarkerLab: 'S'; MarkerCol: $CC0066FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $88; Name: 'Green Koopa';      Category: CAT_ENEMIES; AtlasCol: 15; AtlasRow: 5; IsMarker: True; MarkerLab: 'K'; MarkerCol: $CC00CC00; ColorType: CT_NONE; ColorVal: 0),

    { === ROW 6: Enemy markers cont + Deco === }
    (CharCode: $B0; Name: 'Block Lift';       Category: CAT_ENEMIES; AtlasCol:  0; AtlasRow: 6; IsMarker: True; MarkerLab: '='; MarkerCol: $CCFF8800; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $B1; Name: 'Falling Platform'; Category: CAT_ENEMIES; AtlasCol:  1; AtlasRow: 6; IsMarker: True; MarkerLab: 'O'; MarkerCol: $CCFF8800; ColorType: CT_NONE; ColorVal: 0),
    { Decoration: Design 1 (Overworld) }
    (CharCode: Ord('#'); Name: '#  Waterfall/D1';   Category: CAT_DECO; AtlasCol:  2; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('%'); Name: '%  Waterfall/D1';   Category: CAT_DECO; AtlasCol:  3; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: 'Fence (top)';      Category: CAT_DECO; AtlasCol:  4; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: 'Fence (body)';     Category: CAT_DECO; AtlasCol:  5; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Design 2 (Forest) }
    (CharCode: 0;        Name: '#  Tree/D2';       Category: CAT_DECO; AtlasCol:  6; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: '%  Tree/D2';       Category: CAT_DECO; AtlasCol:  7; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: 'Small Tree (top)'; Category: CAT_DECO; AtlasCol:  8; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: 'Small Tree (body)';Category: CAT_DECO; AtlasCol:  9; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Design 1 misc }
    (CharCode: 0;        Name: 'White Palm';       Category: CAT_DECO; AtlasCol: 10; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Design 3 (Castle) }
    (CharCode: 0;        Name: '#  Window/D3';     Category: CAT_DECO; AtlasCol: 11; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: '%  Window/D3';     Category: CAT_DECO; AtlasCol: 12; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Design 4 (Lava) }
    (CharCode: 0;        Name: '#  Lava/D4';       Category: CAT_DECO; AtlasCol: 13; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: '%  Lava/D4';       Category: CAT_DECO; AtlasCol: 14; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { === ROW 7: Deco cont (Palms) === }
    (CharCode: 0;        Name: 'Palm (center)';    Category: CAT_DECO; AtlasCol:  0; AtlasRow: 7; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: 'Palm (left)';      Category: CAT_DECO; AtlasCol:  1; AtlasRow: 7; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: 'Palm (top)';       Category: CAT_DECO; AtlasCol:  2; AtlasRow: 7; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 0;        Name: 'Palm (right)';     Category: CAT_DECO; AtlasCol:  3; AtlasRow: 7; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0)
  );

const
  { Enemy atlas catalog — defines every enemy/platform sprite }
  EnemyAtlas: array[0..ENEMY_ATLAS_COUNT - 1] of TEnemyAtlasEntry = (
    { Row 0: small enemies (20x14) }
    (CharCode: $80; Name: 'Goomba';            AtlasCol: 0; AtlasRow: 0; SprW: 20; SprH: 14),
    (CharCode: $83; Name: 'Grey Goomba';       AtlasCol: 1; AtlasRow: 0; SprW: 20; SprH: 14),
    (CharCode: $87; Name: 'Spiny';             AtlasCol: 2; AtlasRow: 0; SprW: 20; SprH: 14),
    (CharCode: $81; Name: 'Fish';              AtlasCol: 3; AtlasRow: 0; SprW: 20; SprH: 14),
    (CharCode: $82; Name: 'Fireball';          AtlasCol: 4; AtlasRow: 0; SprW: 20; SprH: 14),
    (CharCode: $B0; Name: 'Block Lift';        AtlasCol: 5; AtlasRow: 0; SprW: 20; SprH: 14),
    (CharCode: $B1; Name: 'Falling Platform';  AtlasCol: 6; AtlasRow: 0; SprW: 20; SprH: 14),
    { Row 1: tall/wide enemies }
    (CharCode: $84; Name: 'Green Piranha';     AtlasCol: 0; AtlasRow: 1; SprW: 24; SprH: 20),
    (CharCode: $85; Name: 'Green Piranha (2)'; AtlasCol: 1; AtlasRow: 1; SprW: 24; SprH: 20),
    (CharCode: $86; Name: 'Red Piranha';       AtlasCol: 2; AtlasRow: 1; SprW: 24; SprH: 20),
    (CharCode: $88; Name: 'Green Koopa';       AtlasCol: 3; AtlasRow: 1; SprW: 20; SprH: 24),
    (CharCode: $8A; Name: 'Fast Green Koopa';  AtlasCol: 4; AtlasRow: 1; SprW: 20; SprH: 24),
    (CharCode: $89; Name: 'Red Koopa';         AtlasCol: 5; AtlasRow: 1; SprW: 20; SprH: 24)
  );

var
  LevelTexture: GLuint;
  AtlasTexture: GLuint;
  SkyTexture: GLuint;
  EnemyAtlasTexture: GLuint;
  PlayerSprTexture: GLuint;
  PixelBuf: array[0..VIEW_W * VIEW_H - 1] of UInt32;
  AtlasBuf: array[0..ATLAS_PX_W * ATLAS_PX_H - 1] of UInt32;
  SkyBuf: array[0..SKY_PV_W * SKY_PV_H - 1] of UInt32;
  EnemyAtlasBuf: array[0..ENEMY_ATLAS_PX_W * ENEMY_ATLAS_PX_H - 1] of UInt32;
  PlayerSprBuf: array[0..PLAYER_SPR_W * PLAYER_SPR_H - 1] of UInt32;
  Initialized: Boolean;
  LevelLoaded: Boolean;

procedure EdRenderInit;
begin
  if Initialized then Exit;

  { Create OpenGL texture for the level viewport }
  glGenTextures(1, @LevelTexture);
  glBindTexture(GL_TEXTURE_2D, LevelTexture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  { Allocate texture storage }
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, VIEW_W, VIEW_H, 0,
    GL_RGBA, GL_UNSIGNED_BYTE, nil);

  glBindTexture(GL_TEXTURE_2D, 0);

  { Create OpenGL texture for the tile atlas }
  glGenTextures(1, @AtlasTexture);
  glBindTexture(GL_TEXTURE_2D, AtlasTexture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, ATLAS_PX_W, ATLAS_PX_H, 0,
    GL_RGBA, GL_UNSIGNED_BYTE, nil);
  glBindTexture(GL_TEXTURE_2D, 0);

  { Create OpenGL texture for the sky preview }
  glGenTextures(1, @SkyTexture);
  glBindTexture(GL_TEXTURE_2D, SkyTexture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, SKY_PV_W, SKY_PV_H, 0,
    GL_RGBA, GL_UNSIGNED_BYTE, nil);
  glBindTexture(GL_TEXTURE_2D, 0);

  { Create OpenGL texture for the enemy atlas }
  glGenTextures(1, @EnemyAtlasTexture);
  glBindTexture(GL_TEXTURE_2D, EnemyAtlasTexture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, ENEMY_ATLAS_PX_W, ENEMY_ATLAS_PX_H, 0,
    GL_RGBA, GL_UNSIGNED_BYTE, nil);
  glBindTexture(GL_TEXTURE_2D, 0);

  { Create OpenGL texture for the player sprite }
  glGenTextures(1, @PlayerSprTexture);
  glBindTexture(GL_TEXTURE_2D, PlayerSprTexture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, PLAYER_SPR_W, PLAYER_SPR_H, 0,
    GL_RGBA, GL_UNSIGNED_BYTE, nil);
  glBindTexture(GL_TEXTURE_2D, 0);

  { Initialize game world subsystems }
  InitWorlds;

  { Save pristine copies of sprites that get modified in-place
    by InitPipes / BuildWorld during level loads. }
  SaveSpriteBackups;

  Initialized := True;
  LevelLoaded := False;
end;

procedure EdRenderShutdown;
begin
  if not Initialized then Exit;
  if LevelTexture <> 0 then
    glDeleteTextures(1, @LevelTexture);
  if AtlasTexture <> 0 then
    glDeleteTextures(1, @AtlasTexture);
  if SkyTexture <> 0 then
    glDeleteTextures(1, @SkyTexture);
  if EnemyAtlasTexture <> 0 then
    glDeleteTextures(1, @EnemyAtlasTexture);
  if PlayerSprTexture <> 0 then
    glDeleteTextures(1, @PlayerSprTexture);
  LevelTexture := 0;
  AtlasTexture := 0;
  SkyTexture := 0;
  EnemyAtlasTexture := 0;
  PlayerSprTexture := 0;
  Initialized := False;
end;

procedure InitWaterfallPalette;
{ Initialize waterfall/lava palette entries 7-11 based on SkyType.
  During gameplay these are animated by BlinkPalette() every frame,
  but the editor needs a static snapshot for correct sprite colors. }
var
  i, j, k: Integer;
begin
  j := 0;  { static snapshot at animation frame 0 }
  for i := 0 to 4 do
  begin
    Dec(j);
    if j < 0 then j := 4;
    k := 5 - j;
    case Options.SkyType of
      0: OutPalette(7 + i, 40 + 3 * k, 50 + 2 * k, 53 + 2 * k);
      1: OutPalette(7 + i, 45 + 3 * k, 52 + 2 * k, 51 + 2 * k);
      2: OutPalette(7 + i, 44 + 3 * k, 53 + 2 * k, 53 + 2 * k);
      3: OutPalette(7 + i, 34 + 3 * k, 40 + 2 * k, 40 + 2 * k);
      4: OutPalette(7 + i, 38 + 3 * k, 47 + 2 * k, 47 + 2 * k);
      5: OutPalette(7 + i, 53 + 2 * k, 53 + 2 * k, 44 + 3 * k);
      6..8: OutPalette(7 + i, 42 + 4 * k, 5 + k * k, 2 * k);
      10: OutPalette(7 + i, 40 + 4 * k, 45 + 3 * k, 63 + 0 * k);
    else
      OutPalette(7 + i, 50 + 2 * k, 50 + 2 * k, 50 + 2 * k);
    end;
  end;
end;

procedure EdLoadLevel(WorldIdx: Integer; Sub: Char);
begin
  if not Initialized then Exit;

  { Restore sprite data to pristine originals before recoloring.
    InitPipes and BuildWorld modify Pipe/Block/Wood/XBlock sprites
    in-place; without this restore, loading a level whose options
    contain garbage (e.g. a dummy sub-B with a 1-byte record) can
    recolor sprites to values below $10, making them permanently
    invisible to subsequent ReColor passes. }
  RestoreSpriteBackups;

  { Load the world data into WorldMap + Options }
  LoadWorld(WorldIdx);

  { If requesting sub-level B, swap so B becomes active }
  if Sub in ['B', 'b'] then
    Swap;

  { Initialize rendering state from Options }
  with Options do
  begin
    InitSky(SkyType);
    InitWalls(WallType1, WallType2, WallType3);
    InitPipes(PipeColor);
    InitBackGr(BackGrType, Clouds);
  end;

  { Process the world map (build wall patterns, init colors) }
  BuildWorld;

  { Load the base palette }
  NewPalette(P256^);

  { Set sky palette colors }
  SetSkyPalette;

  { Set ground/grass colors from Options }
  InitGrass;

  { Set background decoration palette entries }
  DrawPalBackGr;

  { Set waterfall/lava palette entries (normally animated by BlinkPalette) }
  InitWaterfallPalette;

  { Sync the full palette to VGA256's internal PaletteR/G/B arrays
    so GetPaletteEntry returns correct values }
  ReadPalette(Palette);

  LevelLoaded := True;

  { Ensure Bricks[0..2] are populated (BuildWall mode skips them) }
  EnsureBricks;

  { Build the tile palette atlas with current theme colors }
  EdBuildTileAtlas;

  { Build the enemy atlas with current palette colors }
  EdBuildEnemyAtlas;

  { Build the player sprite texture }
  EdBuildPlayerSprite;

  { Build the sky & background preview texture }
  EdBuildSkyPreview;
end;

{ Normalize the framebuffer parallax region so PutBackGr's exact-match
  checks work correctly with SmoothFill sky types.

  SmoothFill (sky types 2, 5, 9, 10, 11, 12) writes gradient values
  $E0-$EF into the framebuffer, but PutBackGr's Fill mode only checks
  for exact $F0 and $E0 values. This causes small gaps in the parallax
  arch silhouette. Normalizing $E1-$EF to $E0 in the parallax region
  before DrawBackGr fixes the issue. }
procedure NormalizeParallaxRegion(ScrollX: Integer);
var
  BaseY, Row, Col: Integer;
  Pg: Integer;
  WX: Integer;
  Offs: LongInt;
  Pix: Byte;
const
  Height = 26;  { Same as BackGr.Height }
begin
  { Only needed for SmoothFill sky types + parallax backgrounds }
  if not (Options.SkyType in [2, 5, 9, 10, 11, 12]) then Exit;
  if not (Options.BackGrType in [1, 2, 3, 9, 10, 11]) then Exit;

  Pg := CurrentPage;
  BaseY := Options.Horizon - Height;

  for Row := 0 to Height do
  begin
    if (BaseY + Row >= 0) and (BaseY + Row < FB_HEIGHT) then
    begin
      for Col := ScrollX to ScrollX + (NH + 2) * W - 1 do
      begin
        WX := Col mod VIR_SCREEN_WIDTH;
        if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
        Offs := LongInt(BaseY + Row) * VIR_SCREEN_WIDTH + WX;
        Pix := FrameBuffer[Pg, Offs];
        { Normalize intermediate gradient values to $E0 so PutBackGr
          can distinguish background ($E0) from sky ($F0) }
        if (Pix >= $E0) and (Pix <= $EF) then
          FrameBuffer[Pg, Offs] := $E0;
      end;
    end;
  end;
end;

procedure EdRenderLevel(ScrollX: Integer);
var
  X, Y: Integer;
  TileX1, TileX2: Integer;
  i, j, Idx, FBIdx: Integer;
  WrapX: Integer;
  c: Byte;
  r, g, b: Byte;
  r32, g32, b32: UInt32;
  Pg: Integer;
begin
  if not LevelLoaded then Exit;

  { Use page 0 for editor rendering }
  Pg := CurrentPage;

  { Set view position for rendering.
    YView=0 because game content starts at row 0 in the framebuffer
    (tiles draw at Y*H, starting from pixel row 0). }
  SetView(ScrollX, 0);
  SetYOffset(0);

  { Clear the framebuffer page }
  FillChar(FrameBuffer[Pg], SizeOf(FrameBuffer[Pg]), 0);

  { Calculate which tiles are visible }
  TileX1 := ScrollX div W;
  if TileX1 < 0 then TileX1 := 0;
  TileX2 := TileX1 + NH + 1;  { +1 for partial tiles at edges }
  if TileX2 > Options.XSize then
    TileX2 := Options.XSize;

  { Draw sky background for the visible area }
  DrawSky(ScrollX, 0, (NH + 2) * W, NV * H);

  { Initialize LastXView so DrawBackGr/PutClouds see zero delta.
    The editor clears and re-renders the entire framebuffer each frame,
    so there is no "previous frame" state to delta against. }
  for i := 0 to MAX_PAGE do
    LastXView[i] := ScrollX;

  { Draw clouds }
  StartClouds;

  { Restore XView after StartClouds (it modifies XView during iteration) }
  XView := ScrollX;

  { Set LastXView again so DrawBackGr's PutClouds sees zero delta }
  LastXView[Pg] := ScrollX;

  { Draw all visible tiles }
  for X := TileX1 - 1 to TileX2 do
    for Y := 0 to NV - 1 do
      Redraw(X, Y);

  { Normalize the parallax region before DrawBackGr for SmoothFill skies }
  NormalizeParallaxRegion(ScrollX);

  { Draw background decorations }
  DrawBackGr(True);

  { Convert indexed framebuffer to RGBA for OpenGL.
    Read VIEW_H rows starting at row 0 (game tiles draw from row 0). }
  for j := 0 to VIEW_H - 1 do
  begin
    for i := 0 to VIEW_W - 1 do
    begin
      Idx := j * VIEW_W + i;

      { Wrap X coordinate like the game's PresentFrame does }
      WrapX := (ScrollX + i) mod VIR_SCREEN_WIDTH;
      if WrapX < 0 then Inc(WrapX, VIR_SCREEN_WIDTH);
      FBIdx := j * VIR_SCREEN_WIDTH + WrapX;

      { Read palette index from framebuffer }
      if (j >= 0) and (j < FB_HEIGHT) then
        c := FrameBuffer[Pg, FBIdx]
      else
        c := 0;

      { Convert VGA 6-bit palette to 8-bit RGBA }
      GetPaletteEntry(c, r, g, b);
      r32 := UInt32(r) shl 2;
      g32 := UInt32(g) shl 2;
      b32 := UInt32(b) shl 2;
      if r32 > 255 then r32 := 255;
      if g32 > 255 then g32 := 255;
      if b32 > 255 then b32 := 255;

      { Pack as RGBA (OpenGL format, not ARGB) }
      PixelBuf[Idx] := r32 or (g32 shl 8) or (b32 shl 16) or $FF000000;
    end;
  end;

  { Upload to OpenGL texture }
  glBindTexture(GL_TEXTURE_2D, LevelTexture);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, VIEW_W, VIEW_H,
    GL_RGBA, GL_UNSIGNED_BYTE, @PixelBuf[0]);
  glBindTexture(GL_TEXTURE_2D, 0);
end;

function EdGetLevelTexture: GLuint;
begin
  Result := LevelTexture;
end;

function EdGetLevelWidth: Integer;
begin
  if LevelLoaded then
    Result := Options.XSize * W
  else
    Result := 0;
end;

function EdGetViewWidth: Integer;
begin
  Result := VIEW_W;
end;

function EdGetViewHeight: Integer;
begin
  Result := VIEW_H;
end;

function EdGetTileAt(TileX, TileY: Integer): Char;
begin
  if LevelLoaded and (TileX >= 0) and (TileX < Options.XSize) and
     (TileY >= 0) and (TileY < NV) then
    Result := WorldMap^[TileX, TileY]
  else
    Result := ' ';
end;

function EdGetTileW: Integer;
begin
  Result := W;
end;

function EdGetTileH: Integer;
begin
  Result := H;
end;

function EdGetNV: Integer;
begin
  Result := NV;
end;

function EdGetPlayerStartX: Integer;
begin
  if LevelLoaded then
    Result := Options.InitX div W   { InitX is in pixels; convert to tile coords }
  else
    Result := 0;
end;

function EdGetPlayerStartY: Integer;
begin
  if LevelLoaded then
    Result := Options.InitY div H   { InitY is in pixels; convert to tile coords }
  else
    Result := 0;
end;

function EdGetLevelXSize: Integer;
begin
  if LevelLoaded then
    Result := Options.XSize
  else
    Result := 0;
end;

function EdGetSkyType: Integer;
begin
  if LevelLoaded then Result := Options.SkyType else Result := 0;
end;

function EdGetBackGrType: Integer;
begin
  if LevelLoaded then Result := Options.BackGrType else Result := 0;
end;

function EdGetClouds: Integer;
begin
  if LevelLoaded then Result := Options.Clouds else Result := 0;
end;

function EdGetHorizon: Integer;
begin
  if LevelLoaded then Result := Options.Horizon else Result := 0;
end;

{ Helper: render a sprite byte array into the atlas buffer at (Col, Row) }
procedure RenderSpriteToAtlas(SpritePtr: Pointer; Col, Row: Integer);
var
  px, py, SrcIdx, DstIdx: Integer;
  c, r, g, b: Byte;
  r32, g32, b32: UInt32;
begin
  for py := 0 to H - 1 do
    for px := 0 to W - 1 do
    begin
      SrcIdx := py * W + px;
      DstIdx := (Row * H + py) * ATLAS_PX_W + Col * W + px;
      c := PByte(PtrUInt(SpritePtr) + PtrUInt(SrcIdx))^;
      if c = 0 then
        AtlasBuf[DstIdx] := $00000000  { transparent }
      else
      begin
        GetPaletteEntry(c, r, g, b);
        r32 := UInt32(r) shl 2;
        g32 := UInt32(g) shl 2;
        b32 := UInt32(b) shl 2;
        if r32 > 255 then r32 := 255;
        if g32 > 255 then g32 := 255;
        if b32 > 255 then b32 := 255;
        AtlasBuf[DstIdx] := r32 or (g32 shl 8) or (b32 shl 16) or $FF000000;
      end;
    end;
end;

{ Helper: render a colored marker rectangle into the atlas buffer }
procedure RenderMarkerToAtlas(Col, Row: Integer; MarkerCol: LongWord);
var
  px, py, DstIdx: Integer;
  r8, g8, b8, a8: Byte;
  BorderCol: UInt32;
begin
  { Extract ABGR components from marker color }
  a8 := (MarkerCol shr 24) and $FF;
  b8 := (MarkerCol shr 16) and $FF;
  g8 := (MarkerCol shr 8) and $FF;
  r8 := MarkerCol and $FF;
  { Repack as RGBA for OpenGL }
  MarkerCol := UInt32(r8) or (UInt32(g8) shl 8) or (UInt32(b8) shl 16) or (UInt32(a8) shl 24);
  { Darker border }
  BorderCol := UInt32(r8 div 2) or (UInt32(g8 div 2) shl 8) or (UInt32(b8 div 2) shl 16) or (UInt32(a8) shl 24);

  for py := 0 to H - 1 do
    for px := 0 to W - 1 do
    begin
      DstIdx := (Row * H + py) * ATLAS_PX_W + Col * W + px;
      if (px = 0) or (px = W - 1) or (py = 0) or (py = H - 1) then
        AtlasBuf[DstIdx] := BorderCol
      else
        AtlasBuf[DstIdx] := MarkerCol;
    end;
end;

{ Decoration sprite lookup: maps sequential DecoIdx to GetSpritePtr keys }
const
  DECO_LOOKUP: array[0..16] of AnsiChar = (
    'a',  { Fall000 — waterfall '#' design 1 }
    'b',  { Fall001 — waterfall '%' design 1 }
    'F',  { Fence000 }
    'f',  { Fence001 }
    'T',  { Tree000 }
    't',  { Tree001 }
    'S',  { SmTree000 }
    's',  { SmTree001 }
    'P',  { WPalm000 }
    'w',  { Window000 }
    'v',  { Window001 }
    'L',  { Lava000 }
    'l',  { Lava001 }
    'p',  { Palm0000 — palm center }
    'q',  { Palm1000 — palm left }
    'r',  { Palm2000 — palm top }
    'u'   { Palm3000 — palm right }
  );

{ Set waterfall/lava palette entries 7-11 for a given SkyType.
  Same formula as InitWaterfallPalette / BlinkPalette but writes
  via SetPaletteEntry so GetPaletteEntry returns the right colors
  during atlas rendering.  Frame 0 (static snapshot). }
procedure SetWaterfallPalForSky(ASkyType: Integer);
var
  i, j, k: Integer;
begin
  j := 0;
  for i := 0 to 4 do
  begin
    Dec(j);
    if j < 0 then j := 4;
    k := 5 - j;
    case ASkyType of
      0: SetPaletteEntry(7+i, 40+3*k, 50+2*k, 53+2*k);
      1: SetPaletteEntry(7+i, 45+3*k, 52+2*k, 51+2*k);
      2: SetPaletteEntry(7+i, 44+3*k, 53+2*k, 53+2*k);
      3: SetPaletteEntry(7+i, 34+3*k, 40+2*k, 40+2*k);
      4: SetPaletteEntry(7+i, 38+3*k, 47+2*k, 47+2*k);
      5: SetPaletteEntry(7+i, 53+2*k, 53+2*k, 44+3*k);
   6..8: SetPaletteEntry(7+i, 42+4*k, 5+k*k,  2*k);
     10: SetPaletteEntry(7+i, 40+4*k, 45+3*k, 63);
    else SetPaletteEntry(7+i, 50+2*k, 50+2*k, 50+2*k);
    end;
  end;
end;

{ Set palette entries for Window sprites in the tile atlas.
  Level 1b (SkyType 8, BackGrType 4) is the canonical castle level. }
procedure SetWindowPalette;
begin
  { SkyType 8 with BackGrType 4: dark brown castle palette }
  SetPaletteEntry($F0, 17, 10, 10);
  SetPaletteEntry($FD, 17, 10, 10);
  SetPaletteEntry($FE, 11,  5,  5);
  SetPaletteEntry($FF, 20, 14, 14);
end;

procedure SavePalRange(First, Count: Integer; var Buf: array of Byte);
var n: Integer;
    r, g, b: Byte;
begin
  for n := 0 to Count - 1 do
  begin
    GetPaletteEntry(First + n, r, g, b);
    Buf[n * 3 + 0] := r;
    Buf[n * 3 + 1] := g;
    Buf[n * 3 + 2] := b;
  end;
end;

procedure RestorePalRange(First, Count: Integer; var Buf: array of Byte);
var n: Integer;
begin
  for n := 0 to Count - 1 do
    SetPaletteEntry(First + n, Buf[n*3+0], Buf[n*3+1], Buf[n*3+2]);
end;

procedure EdBuildTileAtlas;
var
  i, DecoIdx: Integer;
  Entry: TTileAtlasEntry;
  SprPtr: Pointer;
  TmpBuf: array[0..W * H - 1] of Byte;
  FirstDecoIdx: Integer;
  BrickPat: Integer;
  BrickSrc: Pointer;
  PalSave: array[0..47] of Byte;  { up to 16 entries * 3 bytes }
begin
  if not Initialized then Exit;

  { Clear atlas to transparent }
  FillChar(AtlasBuf, SizeOf(AtlasBuf), 0);

  { Find first deco entry index (search once) }
  FirstDecoIdx := -1;
  for i := 0 to TILE_ATLAS_COUNT - 1 do
    if TileAtlas[i].Category = CAT_DECO then
    begin
      FirstDecoIdx := i;
      Break;
    end;

  for i := 0 to TILE_ATLAS_COUNT - 1 do
  begin
    Entry := TileAtlas[i];

    if Entry.IsMarker then
    begin
      RenderMarkerToAtlas(Entry.AtlasCol, Entry.AtlasRow, Entry.MarkerCol);
      Continue;
    end;

    { Determine sprite pointer based on category and color type }
    SprPtr := nil;

    case Entry.Category of
      CAT_GROUND:
        begin
          { First 3 entries: current level's ground from FigList }
          if i <= 2 then
            case i of
              0: SprPtr := @FigList[1, 5];   { body }
              1: SprPtr := @FigList[1, 2];   { top }
              2: SprPtr := @FigList[1, 1];   { corner }
            end
          else
          begin
            { Wall type variants from original sprite data }
            case i of
               3: SprPtr := GetWallSpritePtr(0, 4);   { Green body }
               4: SprPtr := GetWallSpritePtr(0, 1);   { Green top }
               5: SprPtr := GetWallSpritePtr(0, 0);   { Green corner }
               6: SprPtr := GetWallSpritePtr(1, 4);   { Sand body }
               7: SprPtr := GetWallSpritePtr(1, 1);   { Sand top }
               8: SprPtr := GetWallSpritePtr(1, 0);   { Sand corner }
               9: SprPtr := GetWallSpritePtr(3, 4);   { Brown body }
              10: SprPtr := GetWallSpritePtr(3, 1);   { Brown top }
              11: SprPtr := GetWallSpritePtr(3, 0);   { Brown corner }
              12: SprPtr := GetWallSpritePtr(4, 4);   { Grass body }
              13: SprPtr := GetWallSpritePtr(4, 1);   { Grass top }
              14: SprPtr := GetWallSpritePtr(4, 0);   { Grass corner }
              15: SprPtr := GetWallSpritePtr(5, 4);   { Desert body }
              16: SprPtr := GetWallSpritePtr(5, 1);   { Desert top }
              17: SprPtr := GetWallSpritePtr(5, 0);   { Desert corner }
            end;
          end;
        end;

      CAT_BRICKS:
        begin
          { Brick entries have ColorType=CT_BRICK.
            Determine which base pattern from the name: 'Brick0..', 'Brick1..', 'Brick2..' }
          if Entry.ColorType = CT_BRICK then
          begin
            { Extract brick pattern index from name: 'Brick0...'=0, 'Brick1...'=1, 'Brick2...'=2 }
            if (Entry.Name <> nil) and (Length(Entry.Name) >= 6) then
              BrickPat := Ord(Entry.Name[5]) - Ord('0')
            else
              BrickPat := 0;
            if (BrickPat < 0) or (BrickPat > 2) then BrickPat := 0;
            BrickSrc := GetBrickSpritePtr(BrickPat);
            if BrickSrc <> nil then
            begin
              ReColor(BrickSrc, @TmpBuf, Entry.ColorVal);
              RenderSpriteToAtlas(@TmpBuf, Entry.AtlasCol, Entry.AtlasRow);
            end;
            Continue;
          end;
        end;

      CAT_PIPES:
        begin
          { Pipe entries have ColorType=CT_PIPE.
            Get the raw pipe sprite (already recolored with current level color)
            and re-apply ReColor with the target color. }
          if Entry.ColorType = CT_PIPE then
          begin
            SprPtr := GetSpritePtr(Chr(Entry.CharCode));
            if SprPtr <> nil then
            begin
              ReColor(SprPtr, @TmpBuf, Entry.ColorVal);
              RenderSpriteToAtlas(@TmpBuf, Entry.AtlasCol, Entry.AtlasRow);
            end;
            Continue;
          end;
        end;

      CAT_BLOCKS:
        begin
          { Color-variant blocks: J (CT_BRICK), W (CT_WOOD), X (CT_XBLOCK) }
          if Entry.ColorType <> CT_NONE then
          begin
            SprPtr := GetSpritePtr(Chr(Entry.CharCode));
            if SprPtr <> nil then
            begin
              ReColor(SprPtr, @TmpBuf, Entry.ColorVal);
              RenderSpriteToAtlas(@TmpBuf, Entry.AtlasCol, Entry.AtlasRow);
            end;
            Continue;
          end;
          { Static blocks (?, @, $, I, K): no recoloring }
          SprPtr := GetSpritePtr(Chr(Entry.CharCode));
        end;

      CAT_ITEMS, CAT_PLATFORM:
        SprPtr := GetSpritePtr(Chr(Entry.CharCode));

      CAT_DECO:
        begin
          if FirstDecoIdx >= 0 then
          begin
            DecoIdx := i - FirstDecoIdx;
            if (DecoIdx >= 0) and (DecoIdx <= High(DECO_LOOKUP)) then
            begin
              SprPtr := GetSpritePtr(DECO_LOOKUP[DecoIdx]);

              { Waterfall/lava/window sprites use palette entries that
                change per level.  Temporarily swap to the canonical
                palette for each design so the atlas is level-independent. }
              case DecoIdx of
                0, 1:   { Waterfall — use SkyType 2 (Stars/blue water) }
                  begin
                    SavePalRange(7, 5, PalSave);
                    SetWaterfallPalForSky(2);
                    if SprPtr <> nil then
                      RenderSpriteToAtlas(SprPtr, Entry.AtlasCol, Entry.AtlasRow);
                    RestorePalRange(7, 5, PalSave);
                    SprPtr := nil;  { already rendered }
                  end;
                9, 10:  { Window — use SkyType 8 (Castle) }
                  begin
                    SavePalRange($F0, 16, PalSave);  { $F0..$FF }
                    SetWindowPalette;
                    if SprPtr <> nil then
                      RenderSpriteToAtlas(SprPtr, Entry.AtlasCol, Entry.AtlasRow);
                    RestorePalRange($F0, 16, PalSave);
                    SprPtr := nil;
                  end;
                11, 12: { Lava — use SkyType 6 (Lava/orange) }
                  begin
                    SavePalRange(7, 5, PalSave);
                    SetWaterfallPalForSky(6);
                    if SprPtr <> nil then
                      RenderSpriteToAtlas(SprPtr, Entry.AtlasCol, Entry.AtlasRow);
                    RestorePalRange(7, 5, PalSave);
                    SprPtr := nil;
                  end;
              end;
            end;
          end;
        end;
    end;

    if SprPtr <> nil then
      RenderSpriteToAtlas(SprPtr, Entry.AtlasCol, Entry.AtlasRow);
  end;

  { Upload atlas to GL texture }
  glBindTexture(GL_TEXTURE_2D, AtlasTexture);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, ATLAS_PX_W, ATLAS_PX_H,
    GL_RGBA, GL_UNSIGNED_BYTE, @AtlasBuf[0]);
  glBindTexture(GL_TEXTURE_2D, 0);
end;

function EdGetAtlasTexture: GLuint;
begin
  Result := AtlasTexture;
end;

function EdGetTileAtlasCount: Integer;
begin
  Result := TILE_ATLAS_COUNT;
end;

function EdGetTileAtlasEntry(Index: Integer): TTileAtlasEntry;
begin
  if (Index >= 0) and (Index < TILE_ATLAS_COUNT) then
    Result := TileAtlas[Index]
  else
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.Name := '';
  end;
end;

{ --- Enemy Atlas --- }

procedure EdBuildEnemyAtlas;
var
  i: Integer;
  Entry: TEnemyAtlasEntry;
  SprPtr: Pointer;
  SprW, SprH: Integer;
  px, py, SrcIdx, DstIdx: Integer;
  OffX, OffY: Integer;
  c, r, g, b: Byte;
  r32, g32, b32: UInt32;
begin
  if not Initialized then Exit;

  { Clear atlas to transparent }
  FillChar(EnemyAtlasBuf, SizeOf(EnemyAtlasBuf), 0);

  for i := 0 to ENEMY_ATLAS_COUNT - 1 do
  begin
    Entry := EnemyAtlas[i];

    { Get sprite pointer and dimensions }
    SprPtr := GetEnemySpritePtr(Chr(Entry.CharCode), SprW, SprH);
    if SprPtr = nil then Continue;

    { Center sprite within its cell }
    OffX := (ENEMY_CELL_W - SprW) div 2;
    OffY := (ENEMY_CELL_H - SprH) div 2;

    { Render sprite pixels into atlas buffer }
    for py := 0 to SprH - 1 do
      for px := 0 to SprW - 1 do
      begin
        SrcIdx := py * SprW + px;
        DstIdx := (Entry.AtlasRow * ENEMY_CELL_H + OffY + py) * ENEMY_ATLAS_PX_W
                + Entry.AtlasCol * ENEMY_CELL_W + OffX + px;

        c := PByte(PtrUInt(SprPtr) + PtrUInt(SrcIdx))^;
        if c = 0 then
          EnemyAtlasBuf[DstIdx] := $00000000  { transparent }
        else
        begin
          GetPaletteEntry(c, r, g, b);
          r32 := UInt32(r) shl 2;
          g32 := UInt32(g) shl 2;
          b32 := UInt32(b) shl 2;
          if r32 > 255 then r32 := 255;
          if g32 > 255 then g32 := 255;
          if b32 > 255 then b32 := 255;
          EnemyAtlasBuf[DstIdx] := r32 or (g32 shl 8) or (b32 shl 16) or $FF000000;
        end;
      end;
  end;

  { Upload atlas to GL texture }
  glBindTexture(GL_TEXTURE_2D, EnemyAtlasTexture);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, ENEMY_ATLAS_PX_W, ENEMY_ATLAS_PX_H,
    GL_RGBA, GL_UNSIGNED_BYTE, @EnemyAtlasBuf[0]);
  glBindTexture(GL_TEXTURE_2D, 0);
end;

function EdGetEnemyAtlasTexture: GLuint;
begin
  Result := EnemyAtlasTexture;
end;

function EdGetEnemyAtlasCount: Integer;
begin
  Result := ENEMY_ATLAS_COUNT;
end;

function EdGetEnemyAtlasEntry(Index: Integer): TEnemyAtlasEntry;
begin
  if (Index >= 0) and (Index < ENEMY_ATLAS_COUNT) then
    Result := EnemyAtlas[Index]
  else
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.Name := '';
  end;
end;

function EdFindEnemyAtlasIndex(Ch: Char): Integer;
var
  i: Integer;
  Code, LookFor: Byte;
begin
  Result := -1;
  Code := Ord(Ch);
  { Map character code ranges to their primary atlas entry code }
  case Code of
    $80:       LookFor := $80;  { Goomba }
    $83:       LookFor := $83;  { Grey Goomba }
    $81:       LookFor := $81;  { Fish }
    $82:       LookFor := $82;  { Fireball }
    $84:       LookFor := $84;  { Green Piranha }
    $85:       LookFor := $85;  { Green Piranha (2) }
    $86:       LookFor := $86;  { Red Piranha }
    $87:       LookFor := $87;  { Spiny }
    $88:       LookFor := $88;  { Green Koopa }
    $89:       LookFor := $89;  { Red Koopa }
    $8A:       LookFor := $8A;  { Fast Green Koopa }
    $B0:       LookFor := $B0;  { Block Lift }
    $B1:       LookFor := $B1;  { Falling Platform }
  else
    Exit;
  end;
  for i := 0 to ENEMY_ATLAS_COUNT - 1 do
    if EnemyAtlas[i].CharCode = LookFor then
    begin
      Result := i;
      Exit;
    end;
end;

{ --- Player Sprite --- }

procedure EdBuildPlayerSprite;
var
  px, py, SrcIdx, DstIdx: Integer;
  c, r, g, b: Byte;
  r32, g32, b32: UInt32;
begin
  if not Initialized then Exit;

  FillChar(PlayerSprBuf, SizeOf(PlayerSprBuf), 0);

  for py := 0 to PLAYER_SPR_H - 1 do
    for px := 0 to PLAYER_SPR_W - 1 do
    begin
      SrcIdx := py * PLAYER_SPR_W + (PLAYER_SPR_W - 1 - px);  { flip horizontally }
      DstIdx := py * PLAYER_SPR_W + px;
      c := Swmar000[SrcIdx];
      if c = 0 then
        PlayerSprBuf[DstIdx] := $00000000
      else
      begin
        GetPaletteEntry(c, r, g, b);
        r32 := UInt32(r) shl 2;
        g32 := UInt32(g) shl 2;
        b32 := UInt32(b) shl 2;
        if r32 > 255 then r32 := 255;
        if g32 > 255 then g32 := 255;
        if b32 > 255 then b32 := 255;
        PlayerSprBuf[DstIdx] := r32 or (g32 shl 8) or (b32 shl 16) or $FF000000;
      end;
    end;

  glBindTexture(GL_TEXTURE_2D, PlayerSprTexture);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, PLAYER_SPR_W, PLAYER_SPR_H,
    GL_RGBA, GL_UNSIGNED_BYTE, @PlayerSprBuf[0]);
  glBindTexture(GL_TEXTURE_2D, 0);
end;

function EdGetPlayerSpriteTexture: GLuint;
begin
  Result := PlayerSprTexture;
end;

{ --- Camera Lock Markers --- }

function EdGetCameraLocks(out Entries: array of TCamLockEntry; MaxEntries: Integer): Integer;
var
  x: Integer;
  ch: Char;
begin
  Result := 0;
  if not LevelLoaded then Exit;
  { Scan the hidden row NV (row 13, below visible area) for lock markers }
  for x := 0 to Options.XSize - 1 do
  begin
    ch := WorldMap^[x, NV];
    if (ch = #254) or (ch = #255) then
    begin
      if Result < MaxEntries then
      begin
        if ch = #254 then
          Entries[Result].LockType := CAM_LOCK_LEFT
        else
          Entries[Result].LockType := CAM_LOCK_RIGHT;
        Entries[Result].Col := x;
        Inc(Result);
      end;
    end;
  end;
end;

{ --- Sky & Background Preview --- }

procedure EdBuildSkyPreview;
var
  SavedXView: Integer;
  SavedLastXView: array[0..MAX_PAGE] of Integer;
  Pg: Integer;
  i, j, Idx, FBIdx, WrapX: Integer;
  c, r, g, b: Byte;
  r32, g32, b32: UInt32;
begin
  if not Initialized then Exit;
  if not LevelLoaded then Exit;

  Pg := CurrentPage;

  { Save current view state (StartClouds and DrawBackGr modify XView/LastXView) }
  SavedXView := XView;
  Move(LastXView, SavedLastXView, SizeOf(LastXView));

  { Set view to scroll position 0 for a centered preview }
  SetView(0, 0);
  SetYOffset(0);

  { Initialize LastXView so DrawBackGr's delta mode sees zero delta }
  for i := 0 to MAX_PAGE do
    LastXView[i] := 0;

  { Clear the framebuffer page }
  FillChar(FrameBuffer[Pg], SizeOf(FrameBuffer[Pg]), 0);

  { Render sky gradient into framebuffer (full preview height) }
  DrawSky(0, 0, SKY_PV_W, SKY_PV_H);

  { Render clouds (StartClouds modifies XView internally but restores it) }
  StartClouds;

  { Ensure XView is back to 0 after StartClouds modified it }
  XView := 0;

  { Normalize parallax region for SmoothFill sky types before DrawBackGr }
  NormalizeParallaxRegion(0);

  { Render parallax background (arches, mountains, etc.) }
  DrawBackGr(True);

  { Update LastXView to match current state so cloud delta is zero }
  LastXView[Pg] := XView;

  { Extract pixels from framebuffer into SkyBuf }
  for j := 0 to SKY_PV_H - 1 do
    for i := 0 to SKY_PV_W - 1 do
    begin
      Idx := j * SKY_PV_W + i;

      { Wrap X coordinate like EdRenderLevel does }
      WrapX := i mod VIR_SCREEN_WIDTH;
      if WrapX < 0 then Inc(WrapX, VIR_SCREEN_WIDTH);
      FBIdx := j * VIR_SCREEN_WIDTH + WrapX;

      { Read palette index from framebuffer }
      if (j >= 0) and (j < FB_HEIGHT) then
        c := FrameBuffer[Pg, FBIdx]
      else
        c := 0;

      { Convert VGA 6-bit palette to 8-bit RGBA }
      GetPaletteEntry(c, r, g, b);
      r32 := UInt32(r) shl 2;
      g32 := UInt32(g) shl 2;
      b32 := UInt32(b) shl 2;
      if r32 > 255 then r32 := 255;
      if g32 > 255 then g32 := 255;
      if b32 > 255 then b32 := 255;

      SkyBuf[Idx] := r32 or (g32 shl 8) or (b32 shl 16) or $FF000000;
    end;

  { Upload to OpenGL texture }
  glBindTexture(GL_TEXTURE_2D, SkyTexture);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, SKY_PV_W, SKY_PV_H,
    GL_RGBA, GL_UNSIGNED_BYTE, @SkyBuf[0]);
  glBindTexture(GL_TEXTURE_2D, 0);

  { Restore view state }
  XView := SavedXView;
  Move(SavedLastXView, LastXView, SizeOf(LastXView));
end;

function EdGetSkyTexture: GLuint;
begin
  Result := SkyTexture;
end;

procedure EdBuildSkyPreviewForType(ASkyType, ABackGrType, AHorizon, AClouds: Integer);
var
  SavedSkyType: Byte;
  SavedBackGrType: Byte;
  SavedHorizon: Byte;
  SavedClouds: Byte;
begin
  if not Initialized then Exit;
  if not LevelLoaded then Exit;

  { Save current level settings }
  SavedSkyType := Options.SkyType;
  SavedBackGrType := Options.BackGrType;
  SavedHorizon := Options.Horizon;
  SavedClouds := Options.Clouds;

  { Temporarily override settings }
  Options.SkyType := ASkyType;
  Options.BackGrType := ABackGrType;
  Options.Horizon := AHorizon;
  Options.Clouds := AClouds;

  { Re-initialize sky and background with the override values }
  InitSky(ASkyType);
  InitBackGr(ABackGrType, AClouds);

  { Re-apply palette for the new sky type }
  NewPalette(P256^);
  SetSkyPalette;
  InitGrass;
  DrawPalBackGr;
  InitWaterfallPalette;
  ReadPalette(Palette);

  { Render the preview }
  EdBuildSkyPreview;

  { Restore original settings }
  Options.SkyType := SavedSkyType;
  Options.BackGrType := SavedBackGrType;
  Options.Horizon := SavedHorizon;
  Options.Clouds := SavedClouds;

  { Restore rendering state }
  InitSky(SavedSkyType);
  InitBackGr(SavedBackGrType, SavedClouds);
  NewPalette(P256^);
  SetSkyPalette;
  InitGrass;
  DrawPalBackGr;
  InitWaterfallPalette;
  ReadPalette(Palette);
end;

function EdGetSkyTypeName(ASkyType: Integer): PAnsiChar;
begin
  case ASkyType of
    0:  Result := 'Blue Sky';
    1:  Result := 'Overcast';
    2:  Result := 'Blue Gradient';
    3:  Result := 'Night';
    4:  Result := 'Light Blue';
    5:  Result := 'Sunset';
    6:  Result := 'Brown Brick';
    7:  Result := 'Gray Brick';
    8:  Result := 'Dark Brick';
    9:  Result := 'Orange Gradient';
    10: Result := 'Blue Gradient 2';
    11: Result := 'Cyan Gradient';
    12: Result := 'Cyan Gradient 2';
  else
    Result := 'Unknown';
  end;
end;

function EdGetBackGrTypeName(ABackGrType: Integer): PAnsiChar;
begin
  case ABackGrType of
    0:  Result := 'None (Solid)';
    1:  Result := 'Arches';
    2:  Result := 'Hills';
    3:  Result := 'Mountains';
    4:  Result := 'Small Bricks';
    5:  Result := 'Large Bricks';
    6:  Result := 'Pillars';
    7:  Result := 'Windows';
    9:  Result := 'Arches (var. 2)';
    10: Result := 'Arches (var. 3)';
  else
    Result := 'Unknown';
  end;
end;

begin
  Initialized := False;
  LevelLoaded := False;
  LevelTexture := 0;
  AtlasTexture := 0;
  EnemyAtlasTexture := 0;
  PlayerSprTexture := 0;
end.
