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
  glad_gl, Buffers;

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
function EdIsLevelLoaded: Boolean;

{ Get level width in pixels }
function EdGetLevelWidth: Integer;

{ Get viewport dimensions }
function EdGetViewWidth: Integer;
function EdGetViewHeight: Integer;

{ Get tile character at world tile coordinates }
function EdGetTileAt(TileX, TileY: Integer): Char;

{ Set tile character at world tile coordinates; returns old char.
  Returns #0 if coordinates are out of bounds. }
function EdSetTileAt(TileX, TileY: Integer; NewChar: Char): Char;

{ Bulk tile operations for region copy/paste }
procedure EdGetTileRegion(X1, Y1, X2, Y2: Integer; out Buf: AnsiString);
function EdPasteTileRegion(DstX, DstY, W, H: Integer; const Buf: AnsiString): Integer;

{ Get tile width and height in pixels }
function EdGetTileW: Integer;
function EdGetTileH: Integer;

{ Get number of vertical tiles }
function EdGetNV: Integer;

{ Get/set player start position (tile coordinates) }
function EdGetPlayerStartX: Integer;
function EdGetPlayerStartY: Integer;
procedure EdSetPlayerStartX(TileX: Integer);
procedure EdSetPlayerStartY(TileY: Integer);

{ Get level XSize (number of horizontal tiles) }
function EdGetLevelXSize: Integer;

{ Get/set level theme options }
function EdGetSkyType: Integer;
function EdGetBackGrType: Integer;
function EdGetClouds: Integer;
function EdGetHorizon: Integer;
procedure EdSetSkyType(V: Integer);
procedure EdSetBackGrType(V: Integer);

{ Level metadata getters/setters }
function EdGetLevelName: AnsiString;
procedure EdSetLevelName(const S: AnsiString);
function EdGetLevelCreator: AnsiString;
procedure EdSetLevelCreator(const S: AnsiString);
function EdGetLevelDescription: AnsiString;
procedure EdSetLevelDescription(const S: AnsiString);
function EdGetMusicTrack: AnsiString;
procedure EdSetMusicTrack(const S: AnsiString);

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

{ Find tile atlas index for a given char code, or -1 if not found }
function EdFindTileAtlasIndex(CharCode: Byte): Integer;

{ Check if a tile char code needs overlay rendering (palette-dependent deco) }
function EdNeedsOverlay(CharCode: Byte): Boolean;

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

{ --- Save/Load (.mled binary format) --- }

{ Save current level to a .mled binary file. Returns True on success. }
function EdSaveLevel(const FileName: AnsiString): Boolean;

{ Load a level from a .mled binary file. Returns True on success.
  Re-initializes rendering (sky, walls, pipes, background, palette). }
function EdLoadLevelFromFile(const FileName: AnsiString): Boolean;

{ --- Save/Load (JSON format) --- }

{ Save current level to a JSON file. Returns True on success.
  v2 format: multi-sublevel (editor native format) }
function EdSaveLevelJSON(const FileName: AnsiString): Boolean;

{ Save current active sub-level to a single-level v3 JSON file.
  Compatible with game's manifest system. }
function EdSaveLevelV3(const FileName: AnsiString): Boolean;

{ Load a level from a JSON file. Returns True on success.
  Supports v1, v2 (editor), and v3 (single-level) formats.
  Re-initializes rendering (sky, walls, pipes, background, palette). }
function EdLoadLevelJSON(const FileName: AnsiString): Boolean;

{ --- Sub-Level Management --- }

const
  MAX_SUB_LEVELS = 8;

{ Get the number of sub-levels in the current level }
function EdGetNumSubLevels: Integer;

{ Get the index of the currently active sub-level (0-based) }
function EdGetActiveSubLevel: Integer;

{ Switch to a different sub-level (saves current, loads target, reinits rendering) }
procedure EdSwitchSubLevel(Index: Integer);

{ Add a new empty sub-level. Returns the index of the new sub-level, or -1 if full. }
function EdAddSubLevel: Integer;

{ Remove a sub-level by index. Cannot remove the last remaining sub-level. }
procedure EdRemoveSubLevel(Index: Integer);

{ Get/set the display name of a sub-level }
function EdGetSubLevelName(Index: Integer): AnsiString;
procedure EdSetSubLevelName(Index: Integer; const S: AnsiString);

{ Save the currently active sub-level's state to its buffer.
  Call this before saving to file or before any operation that needs
  all sub-level buffers to be up-to-date. }
procedure EdSaveActiveToBuffer;

implementation

uses
  SysUtils,
  VGA256, Figures, BackGr, Worlds, Palettes, Enemies,
  SpriteLoader, AssetPaths, LevelFormat;

var
  { Small Mario standing sprite — loaded from file to avoid pulling in Players unit.
    Sprite faces left; we flip it horizontally when building the texture. }
  SWMar000: array[0..559] of Byte;  { 20x28 }

procedure LoadEdMarioSprite;
var
  Spr: TSpriteData;
begin
  LoadSprite(SpritePath('players/swmar000.sprite'), Spr);
  if Length(Spr.Pixels) >= SizeOf(SWMar000) then
    Move(Spr.Pixels[0], SWMar000, SizeOf(SWMar000));
end;

{ --- Sub-Level Buffer Data --- }

type
  TSubLevelData = record
    WorldSnap: WorldBuffer;     { Full WorldBuffer snapshot }
    Opts: WorldOptions;         { Theme/options for this sub-level }
    TabName: AnsiString;        { Tab display name (e.g. "Level A") }
    SLMetaName: AnsiString;     { Level name }
    SLMetaCreator: AnsiString;
    SLMetaDescription: AnsiString;
    SLMusicTrack: AnsiString;   { Music track filename (e.g. "level1.ogg"), empty = default }
  end;
  PSubLevelData = ^TSubLevelData;

var
  SubLevels: array[0..MAX_SUB_LEVELS - 1] of PSubLevelData;
  NumSubLevels: Integer = 0;
  ActiveSubLevel: Integer = 0;

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
  TILE_ATLAS_COUNT = 138;
  TileAtlas: array[0..TILE_ATLAS_COUNT - 1] of TTileAtlasEntry = (
    { === ROW 0-2: Per-tile ground wall variants (5 styles x 9 variants = 45) === }
    { Variant order: TL(0) Top(1) TR(2) Left(3) Body(4) Right(5) BL(6) Bot(7) BR(8) }
    { Green style — codes #91..#99 (row 0, cols 0-8) }
    (CharCode:  91; Name: 'Green TL';      Category: CAT_GROUND; AtlasCol:  0; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode:  92; Name: 'Green Top';     Category: CAT_GROUND; AtlasCol:  1; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode:  93; Name: 'Green TR';      Category: CAT_GROUND; AtlasCol:  2; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode:  94; Name: 'Green Left';    Category: CAT_GROUND; AtlasCol:  3; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode:  95; Name: 'Green Body';    Category: CAT_GROUND; AtlasCol:  4; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode:  96; Name: 'Green Right';   Category: CAT_GROUND; AtlasCol:  5; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode:  97; Name: 'Green BL';      Category: CAT_GROUND; AtlasCol:  6; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode:  98; Name: 'Green Bot';     Category: CAT_GROUND; AtlasCol:  7; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode:  99; Name: 'Green BR';      Category: CAT_GROUND; AtlasCol:  8; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Sand style — codes #100..#108 (row 0 cols 9-15, row 1 cols 0-1) }
    (CharCode: 100; Name: 'Sand TL';       Category: CAT_GROUND; AtlasCol:  9; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 101; Name: 'Sand Top';      Category: CAT_GROUND; AtlasCol: 10; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 102; Name: 'Sand TR';       Category: CAT_GROUND; AtlasCol: 11; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 103; Name: 'Sand Left';     Category: CAT_GROUND; AtlasCol: 12; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 104; Name: 'Sand Body';     Category: CAT_GROUND; AtlasCol: 13; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 105; Name: 'Sand Right';    Category: CAT_GROUND; AtlasCol: 14; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 106; Name: 'Sand BL';       Category: CAT_GROUND; AtlasCol: 15; AtlasRow: 0; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 107; Name: 'Sand Bot';      Category: CAT_GROUND; AtlasCol:  0; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 108; Name: 'Sand BR';       Category: CAT_GROUND; AtlasCol:  1; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Brown style — codes #109..#117 (row 1 cols 2-10) }
    (CharCode: 109; Name: 'Brown TL';      Category: CAT_GROUND; AtlasCol:  2; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 110; Name: 'Brown Top';     Category: CAT_GROUND; AtlasCol:  3; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 111; Name: 'Brown TR';      Category: CAT_GROUND; AtlasCol:  4; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 112; Name: 'Brown Left';    Category: CAT_GROUND; AtlasCol:  5; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 113; Name: 'Brown Body';    Category: CAT_GROUND; AtlasCol:  6; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 114; Name: 'Brown Right';   Category: CAT_GROUND; AtlasCol:  7; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 115; Name: 'Brown BL';      Category: CAT_GROUND; AtlasCol:  8; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 116; Name: 'Brown Bot';     Category: CAT_GROUND; AtlasCol:  9; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 117; Name: 'Brown BR';      Category: CAT_GROUND; AtlasCol: 10; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Grass style — codes #118..#126 (row 1 cols 11-15, row 2 cols 0-3) }
    (CharCode: 118; Name: 'Grass TL';      Category: CAT_GROUND; AtlasCol: 11; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 119; Name: 'Grass Top';     Category: CAT_GROUND; AtlasCol: 12; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 120; Name: 'Grass TR';      Category: CAT_GROUND; AtlasCol: 13; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 121; Name: 'Grass Left';    Category: CAT_GROUND; AtlasCol: 14; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 122; Name: 'Grass Body';    Category: CAT_GROUND; AtlasCol: 15; AtlasRow: 1; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 123; Name: 'Grass Right';   Category: CAT_GROUND; AtlasCol:  0; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 124; Name: 'Grass BL';      Category: CAT_GROUND; AtlasCol:  1; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 125; Name: 'Grass Bot';     Category: CAT_GROUND; AtlasCol:  2; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 126; Name: 'Grass BR';      Category: CAT_GROUND; AtlasCol:  3; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Desert style — codes #139..#147 (row 2 cols 4-12) }
    (CharCode: 139; Name: 'Desert TL';     Category: CAT_GROUND; AtlasCol:  4; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 140; Name: 'Desert Top';    Category: CAT_GROUND; AtlasCol:  5; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 141; Name: 'Desert TR';     Category: CAT_GROUND; AtlasCol:  6; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 142; Name: 'Desert Left';   Category: CAT_GROUND; AtlasCol:  7; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 143; Name: 'Desert Body';   Category: CAT_GROUND; AtlasCol:  8; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 144; Name: 'Desert Right';  Category: CAT_GROUND; AtlasCol:  9; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 145; Name: 'Desert BL';     Category: CAT_GROUND; AtlasCol: 10; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 146; Name: 'Desert Bot';    Category: CAT_GROUND; AtlasCol: 11; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 147; Name: 'Desert BR';     Category: CAT_GROUND; AtlasCol: 12; AtlasRow: 2; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),

    { === ROW 3: Platforms + Static blocks + Items === }
    { Platforms (cols 0-3) }
    (CharCode: 14;       Name: 'Jump-thru TL';     Category: CAT_PLATFORM; AtlasCol: 0; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 15;       Name: 'Jump-thru Top';    Category: CAT_PLATFORM; AtlasCol: 1; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 16;       Name: 'Jump-thru TR';     Category: CAT_PLATFORM; AtlasCol: 2; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('='); Name: 'Spike';            Category: CAT_PLATFORM; AtlasCol: 3; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Static blocks (cols 4-8) }
    (CharCode: Ord('?'); Name: 'Question Block'; Category: CAT_BLOCKS; AtlasCol:  4; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('@'); Name: 'Used Block';     Category: CAT_BLOCKS; AtlasCol:  5; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('$'); Name: 'Hidden Block';   Category: CAT_BLOCKS; AtlasCol:  6; AtlasRow: 3; IsMarker: True;  MarkerLab: '?'; MarkerCol: $80FFFFFF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('I'); Name: 'Solid Block';    Category: CAT_BLOCKS; AtlasCol:  7; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('K'); Name: 'Note Block';     Category: CAT_BLOCKS; AtlasCol:  8; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Items (cols 9-11) }
    (CharCode: Ord('*'); Name: 'Coin';           Category: CAT_ITEMS; AtlasCol:  9; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 254;      Name: 'Flag (top)';     Category: CAT_ITEMS; AtlasCol: 10; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 254;      Name: 'Flag (pole)';    Category: CAT_ITEMS; AtlasCol: 11; AtlasRow: 3; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),

    { === ROW 4-5: Pipes — all 6 colors x 4 tiles = 24 entries === }
    { Per-tile colored pipes use unique char codes #178..#201 }
    { Pipe color $18 (Gray) — codes #178..#181 }
    (CharCode: 178; Name: 'Pipe TL Gray';    Category: CAT_PIPES; AtlasCol:  0; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $18),
    (CharCode: 179; Name: 'Pipe TR Gray';    Category: CAT_PIPES; AtlasCol:  1; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $18),
    (CharCode: 180; Name: 'Pipe BL Gray';    Category: CAT_PIPES; AtlasCol:  2; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $18),
    (CharCode: 181; Name: 'Pipe BR Gray';    Category: CAT_PIPES; AtlasCol:  3; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $18),
    { Pipe color $30 (Green) — codes #182..#185 }
    (CharCode: 182; Name: 'Pipe TL Green';   Category: CAT_PIPES; AtlasCol:  4; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $30),
    (CharCode: 183; Name: 'Pipe TR Green';   Category: CAT_PIPES; AtlasCol:  5; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $30),
    (CharCode: 184; Name: 'Pipe BL Green';   Category: CAT_PIPES; AtlasCol:  6; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $30),
    (CharCode: 185; Name: 'Pipe BR Green';   Category: CAT_PIPES; AtlasCol:  7; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $30),
    { Pipe color $50 (Teal) — codes #186..#189 }
    (CharCode: 186; Name: 'Pipe TL Teal';    Category: CAT_PIPES; AtlasCol:  8; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $50),
    (CharCode: 187; Name: 'Pipe TR Teal';    Category: CAT_PIPES; AtlasCol:  9; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $50),
    (CharCode: 188; Name: 'Pipe BL Teal';    Category: CAT_PIPES; AtlasCol: 10; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $50),
    (CharCode: 189; Name: 'Pipe BR Teal';    Category: CAT_PIPES; AtlasCol: 11; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $50),
    { Pipe color $70 (Lime) — codes #190..#193 }
    (CharCode: 190; Name: 'Pipe TL Lime';    Category: CAT_PIPES; AtlasCol: 12; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $70),
    (CharCode: 191; Name: 'Pipe TR Lime';    Category: CAT_PIPES; AtlasCol: 13; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $70),
    (CharCode: 192; Name: 'Pipe BL Lime';    Category: CAT_PIPES; AtlasCol: 14; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $70),
    (CharCode: 193; Name: 'Pipe BR Lime';    Category: CAT_PIPES; AtlasCol: 15; AtlasRow: 4; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $70),
    { Pipe color $80 (Purple) — codes #194..#197 }
    (CharCode: 194; Name: 'Pipe TL Purple';  Category: CAT_PIPES; AtlasCol:  0; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $80),
    (CharCode: 195; Name: 'Pipe TR Purple';  Category: CAT_PIPES; AtlasCol:  1; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $80),
    (CharCode: 196; Name: 'Pipe BL Purple';  Category: CAT_PIPES; AtlasCol:  2; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $80),
    (CharCode: 197; Name: 'Pipe BR Purple';  Category: CAT_PIPES; AtlasCol:  3; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $80),
    { Pipe color $B0 (Red) — codes #198..#201 }
    (CharCode: 198; Name: 'Pipe TL Red';     Category: CAT_PIPES; AtlasCol:  4; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $B0),
    (CharCode: 199; Name: 'Pipe TR Red';     Category: CAT_PIPES; AtlasCol:  5; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $B0),
    (CharCode: 200; Name: 'Pipe BL Red';     Category: CAT_PIPES; AtlasCol:  6; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $B0),
    (CharCode: 201; Name: 'Pipe BR Red';     Category: CAT_PIPES; AtlasCol:  7; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_PIPE; ColorVal: $B0),

    { === ROW 5 cols 8+, ROW 6: Bricks — 3 patterns x 4 colors = 12 entries === }
    { Per-tile colored bricks use unique char codes #202..#205 }
    { Brick Pattern 0 x 4 colors }
    (CharCode: 202; Name: 'Brick0 Gray';   Category: CAT_BRICKS; AtlasCol:  8; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $18),
    (CharCode: 203; Name: 'Brick0 Brown';  Category: CAT_BRICKS; AtlasCol:  9; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $30),
    (CharCode: 204; Name: 'Brick0 Blue';   Category: CAT_BRICKS; AtlasCol: 10; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $48),
    (CharCode: 205; Name: 'Brick0 Red';    Category: CAT_BRICKS; AtlasCol: 11; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $B0),
    { Brick Pattern 1 x 4 colors (same char codes — pattern is cosmetic) }
    (CharCode: 202; Name: 'Brick1 Gray';   Category: CAT_BRICKS; AtlasCol: 12; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $18),
    (CharCode: 203; Name: 'Brick1 Brown';  Category: CAT_BRICKS; AtlasCol: 13; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $30),
    (CharCode: 204; Name: 'Brick1 Blue';   Category: CAT_BRICKS; AtlasCol: 14; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $48),
    (CharCode: 205; Name: 'Brick1 Red';    Category: CAT_BRICKS; AtlasCol: 15; AtlasRow: 5; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $B0),
    { Brick Pattern 2 x 4 colors (same char codes — pattern is cosmetic) }
    (CharCode: 202; Name: 'Brick2 Gray';   Category: CAT_BRICKS; AtlasCol:  0; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $18),
    (CharCode: 203; Name: 'Brick2 Brown';  Category: CAT_BRICKS; AtlasCol:  1; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $30),
    (CharCode: 204; Name: 'Brick2 Blue';   Category: CAT_BRICKS; AtlasCol:  2; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $48),
    (CharCode: 205; Name: 'Brick2 Red';    Category: CAT_BRICKS; AtlasCol:  3; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $B0),

    { === ROW 6 cols 4+: Color-variant blocks === }
    { Breakable Block — per-tile colored: codes #213..#216 }
    (CharCode: 213; Name: 'Break Gray';    Category: CAT_BLOCKS; AtlasCol:  4; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $18),
    (CharCode: 214; Name: 'Break Brown';   Category: CAT_BLOCKS; AtlasCol:  5; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $30),
    (CharCode: 215; Name: 'Break Blue';    Category: CAT_BLOCKS; AtlasCol:  6; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $48),
    (CharCode: 216; Name: 'Break Red';     Category: CAT_BLOCKS; AtlasCol:  7; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_BRICK; ColorVal: $B0),
    { Wood — per-tile colored: codes #210..#212 }
    (CharCode: 210; Name: 'Wood Gray';     Category: CAT_BLOCKS; AtlasCol:  8; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_WOOD;  ColorVal: $18),
    (CharCode: 211; Name: 'Wood Brown';    Category: CAT_BLOCKS; AtlasCol:  9; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_WOOD;  ColorVal: $30),
    (CharCode: 212; Name: 'Wood Blue';     Category: CAT_BLOCKS; AtlasCol: 10; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_WOOD;  ColorVal: $48),
    { XBlock — per-tile colored: codes #206..#209 }
    (CharCode: 206; Name: 'XBlock Brown';  Category: CAT_BLOCKS; AtlasCol: 11; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_XBLOCK; ColorVal: $30),
    (CharCode: 207; Name: 'XBlock Orange'; Category: CAT_BLOCKS; AtlasCol: 12; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_XBLOCK; ColorVal: $68),
    (CharCode: 208; Name: 'XBlock Green';  Category: CAT_BLOCKS; AtlasCol: 13; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_XBLOCK; ColorVal: $A0),
    (CharCode: 209; Name: 'XBlock Red';    Category: CAT_BLOCKS; AtlasCol: 14; AtlasRow: 6; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_XBLOCK; ColorVal: $B0),

    { === ROW 7: Rewards + Enemy markers === }
    (CharCode: $E0; Name: 'Mushroom/Fire';     Category: CAT_REWARDS; AtlasCol:  0; AtlasRow: 7; IsMarker: True; MarkerLab: 'M'; MarkerCol: $CC0000FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E1; Name: '1-Up Mushroom';     Category: CAT_REWARDS; AtlasCol:  1; AtlasRow: 7; IsMarker: True; MarkerLab: '1'; MarkerCol: $CC00CC00; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E2; Name: 'Star';              Category: CAT_REWARDS; AtlasCol:  2; AtlasRow: 7; IsMarker: True; MarkerLab: 'S'; MarkerCol: $CC00FFFF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E3; Name: 'Multi-Coin (x2)';  Category: CAT_REWARDS; AtlasCol:  3; AtlasRow: 7; IsMarker: True; MarkerLab: '$'; MarkerCol: $CC00CCFF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $ED; Name: 'Poison Mushroom';   Category: CAT_REWARDS; AtlasCol:  4; AtlasRow: 7; IsMarker: True; MarkerLab: 'X'; MarkerCol: $CC0000AA; ColorType: CT_NONE; ColorVal: 0),
    { Pipe action markers }
    (CharCode: $E0; Name: 'Pipe: Warp';        Category: CAT_REWARDS; AtlasCol:  5; AtlasRow: 7; IsMarker: True; MarkerLab: 'W'; MarkerCol: $CC00CC00; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E1; Name: 'Pipe: World Swap';  Category: CAT_REWARDS; AtlasCol:  6; AtlasRow: 7; IsMarker: True; MarkerLab: 'S'; MarkerCol: $CCFFCC00; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $E7; Name: 'Pipe: Exit';        Category: CAT_REWARDS; AtlasCol:  7; AtlasRow: 7; IsMarker: True; MarkerLab: 'E'; MarkerCol: $CC0055FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $EF; Name: 'Note Block Jump';   Category: CAT_REWARDS; AtlasCol:  8; AtlasRow: 7; IsMarker: True; MarkerLab: 'N'; MarkerCol: $CC8888FF; ColorType: CT_NONE; ColorVal: 0),
    { Enemy markers (tile atlas only, actual sprites in enemy atlas) }
    (CharCode: $80; Name: 'Goomba';           Category: CAT_ENEMIES; AtlasCol:  9; AtlasRow: 7; IsMarker: True; MarkerLab: 'G'; MarkerCol: $CC0000FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $83; Name: 'Grey Goomba';      Category: CAT_ENEMIES; AtlasCol: 10; AtlasRow: 7; IsMarker: True; MarkerLab: 'G'; MarkerCol: $CC0000FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $81; Name: 'Fish';             Category: CAT_ENEMIES; AtlasCol: 11; AtlasRow: 7; IsMarker: True; MarkerLab: 'F'; MarkerCol: $CCFFCC00; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $82; Name: 'Fireball';         Category: CAT_ENEMIES; AtlasCol: 12; AtlasRow: 7; IsMarker: True; MarkerLab: '!'; MarkerCol: $CC0088FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $84; Name: 'Piranha Plant';    Category: CAT_ENEMIES; AtlasCol: 13; AtlasRow: 7; IsMarker: True; MarkerLab: 'P'; MarkerCol: $CCFF00FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $87; Name: 'Spiny';            Category: CAT_ENEMIES; AtlasCol: 14; AtlasRow: 7; IsMarker: True; MarkerLab: 'S'; MarkerCol: $CC0066FF; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $88; Name: 'Green Koopa';      Category: CAT_ENEMIES; AtlasCol: 15; AtlasRow: 7; IsMarker: True; MarkerLab: 'K'; MarkerCol: $CC00CC00; ColorType: CT_NONE; ColorVal: 0),

    { === ROW 8: Enemy markers cont + Deco === }
    (CharCode: $B0; Name: 'Block Lift';       Category: CAT_ENEMIES; AtlasCol:  0; AtlasRow: 8; IsMarker: True; MarkerLab: '='; MarkerCol: $CCFF8800; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: $B1; Name: 'Falling Platform'; Category: CAT_ENEMIES; AtlasCol:  1; AtlasRow: 8; IsMarker: True; MarkerLab: 'O'; MarkerCol: $CCFF8800; ColorType: CT_NONE; ColorVal: 0),
    { === ROW 8 cols 2+, ROW 9: Decoration tiles === }
    { Design 1: Waterfall (codes '#'=35 and '%'=37) }
    (CharCode: Ord('#'); Name: 'Waterfall (#)';    Category: CAT_DECO; AtlasCol:  2; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: Ord('%'); Name: 'Waterfall (%)';    Category: CAT_DECO; AtlasCol:  3; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Design 2: Tree (codes #148, #149) }
    (CharCode: 148;      Name: 'Tree trunk';       Category: CAT_DECO; AtlasCol:  4; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 149;      Name: 'Tree leaves';      Category: CAT_DECO; AtlasCol:  5; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Design 3: Window (codes #150, #151) }
    (CharCode: 150;      Name: 'Window (#)';       Category: CAT_DECO; AtlasCol:  6; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 151;      Name: 'Window (%)';       Category: CAT_DECO; AtlasCol:  7; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Design 4: Lava (codes #152, #153) }
    (CharCode: 152;      Name: 'Lava (#)';         Category: CAT_DECO; AtlasCol:  8; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 153;      Name: 'Lava (%)';         Category: CAT_DECO; AtlasCol:  9; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Fence (D1, code #240) and Small Tree (D2, code #154) }
    (CharCode: 240;      Name: 'Fence';            Category: CAT_DECO; AtlasCol: 10; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 154;      Name: 'Small Tree';       Category: CAT_DECO; AtlasCol: 11; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { Misc deco }
    (CharCode: 247;      Name: 'Grass';            Category: CAT_DECO; AtlasCol: 12; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 246;      Name: 'White Palm Trunk'; Category: CAT_DECO; AtlasCol: 13; AtlasRow: 8; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    { === ROW 9: Palms === }
    (CharCode: 250;      Name: 'Palm (center)';    Category: CAT_DECO; AtlasCol:  0; AtlasRow: 9; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 244;      Name: 'Palm (left)';      Category: CAT_DECO; AtlasCol:  1; AtlasRow: 9; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 249;      Name: 'Palm (top)';       Category: CAT_DECO; AtlasCol:  2; AtlasRow: 9; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0),
    (CharCode: 245;      Name: 'Palm (right)';     Category: CAT_DECO; AtlasCol:  3; AtlasRow: 9; IsMarker: False; MarkerLab: ' '; MarkerCol: 0; ColorType: CT_NONE; ColorVal: 0)
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

  { Level metadata }
  MetaName: AnsiString;
  MetaCreator: AnsiString;
  MetaDescription: AnsiString;
  MusicTrack: AnsiString;  { Music track filename, empty = default }

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

  { Load all sprite and data assets from files }
  LoadFiguresSprites;
  LoadEnemySprites;

  { Load Mario sprite for player position marker }
  LoadEdMarioSprite;

  { Load background data (palettes + terrain profiles) }
  LoadBackGrData;

  { Initialize game world subsystems (loads manifest + all levels from JSON) }
  InitWorlds;

  { Save pristine copies of sprites that get modified in-place
    by InitPipes / BuildWorld during level loads. }
  SaveSpriteBackups;
  InitColoredSprites;  { Populate pre-colored sprite arrays for per-tile colors }

  Initialized := True;
  LevelLoaded := False;
end;

{ Forward declarations for sub-level management (defined after EdLoadLevel) }
procedure AllocSubLevel(Index: Integer); forward;
procedure FreeSubLevel(Index: Integer); forward;
procedure FreeAllSubLevels; forward;
procedure LoadBufferToActive(Index: Integer); forward;

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
  FreeAllSubLevels;
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
var
  StartSub: Integer;
begin
  if not Initialized then Exit;

  { Free any existing sub-level buffers }
  FreeAllSubLevels;

  { Restore sprite data to pristine originals before recoloring.
    InitPipes and BuildWorld modify Pipe/Block/Wood/XBlock sprites
    in-place; without this restore, loading a level whose options
    contain garbage (e.g. a dummy sub-B with a 1-byte record) can
    recolor sprites to values below $10, making them permanently
    invisible to subsequent ReColor passes. }
  RestoreSpriteBackups;

  { Load the world data into WorldMap + Options.
    After LoadWorld: WorldMap=A, SaveWorldMap=B,
                     Options=A, SaveOptions=B }
  LoadWorld(WorldIdx);

  { Capture sub-level A (currently in WorldMap/Options) }
  AllocSubLevel(0);
  Move(WorldMap^, SubLevels[0]^.WorldSnap, SizeOf(WorldBuffer));
  SubLevels[0]^.Opts := Options;
  SubLevels[0]^.TabName := 'Level A';
  SubLevels[0]^.SLMetaName := '';
  SubLevels[0]^.SLMetaCreator := '';
  SubLevels[0]^.SLMetaDescription := '';
  SubLevels[0]^.SLMusicTrack := '';

  { Capture sub-level B (currently in SaveWorldMap/SaveOptions) }
  AllocSubLevel(1);
  Move(SaveWorldMap^, SubLevels[1]^.WorldSnap, SizeOf(WorldBuffer));
  SubLevels[1]^.Opts := SaveOptions;
  SubLevels[1]^.TabName := 'Level B';
  SubLevels[1]^.SLMetaName := '';
  SubLevels[1]^.SLMetaCreator := '';
  SubLevels[1]^.SLMetaDescription := '';
  SubLevels[1]^.SLMusicTrack := '';

  NumSubLevels := 2;

  { Determine which sub-level to display initially }
  if Sub in ['B', 'b'] then
    StartSub := 1
  else
    StartSub := 0;

  ActiveSubLevel := StartSub;
  LoadBufferToActive(StartSub);

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

  { Set fixed palette entries for design-independent deco sprites }
  InitDecoSpritePalette;

  { Sync the full palette to VGA256's internal PaletteR/G/B arrays
    so GetPaletteEntry returns correct values }
  ReadPalette(Palette);

  LevelLoaded := True;

  { Clear metadata (built-in levels have no user metadata) }
  MetaName := '';
  MetaCreator := '';
  MetaDescription := '';

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

  { Save WorldMap, run BuildWorld (converts A/B/C/D → #1..#26 for rendering),
    render tiles, then restore original WorldMap so editor keeps raw characters. }
  Move(WorldMap^, SaveWorldMap^, SizeOf(WorldBuffer));
  BuildWorld;

  { Draw all visible tiles }
  for X := TileX1 - 1 to TileX2 do
    for Y := 0 to NV - 1 do
      Redraw(X, Y);

  { Restore raw tile data (undo BuildWorld's destructive transforms) }
  Move(SaveWorldMap^, WorldMap^, SizeOf(WorldBuffer));

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

function EdIsLevelLoaded: Boolean;
begin
  Result := LevelLoaded;
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

function EdSetTileAt(TileX, TileY: Integer; NewChar: Char): Char;
begin
  if LevelLoaded and (TileX >= 0) and (TileX < Options.XSize) and
     (TileY >= 0) and (TileY < NV) then
  begin
    Result := WorldMap^[TileX, TileY];
    WorldMap^[TileX, TileY] := NewChar;
  end
  else
    Result := #0;
end;

procedure EdGetTileRegion(X1, Y1, X2, Y2: Integer; out Buf: AnsiString);
var RW, RH, X, Y, Idx: Integer;
begin
  RW := X2 - X1 + 1; RH := Y2 - Y1 + 1;
  SetLength(Buf, RW * RH);
  Idx := 1;
  for Y := Y1 to Y2 do
    for X := X1 to X2 do begin
      Buf[Idx] := EdGetTileAt(X, Y);
      Inc(Idx);
    end;
end;

function EdPasteTileRegion(DstX, DstY, W, H: Integer; const Buf: AnsiString): Integer;
var X, Y, Idx: Integer; OldCh: Char;
begin
  Result := 0; Idx := 1;
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do begin
      if Idx <= Length(Buf) then begin
        OldCh := EdSetTileAt(DstX + X, DstY + Y, Buf[Idx]);
        if (OldCh <> #0) and (OldCh <> Buf[Idx]) then Inc(Result);
      end;
      Inc(Idx);
    end;
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

procedure EdSetPlayerStartX(TileX: Integer);
begin
  if LevelLoaded then
    Options.InitX := TileX * W;
end;

procedure EdSetPlayerStartY(TileY: Integer);
begin
  if LevelLoaded then
    Options.InitY := TileY * H;
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

procedure EdSetSkyType(V: Integer);
begin
  if LevelLoaded then Options.SkyType := V;
end;

procedure EdSetBackGrType(V: Integer);
begin
  if LevelLoaded then Options.BackGrType := V;
end;

function EdGetClouds: Integer;
begin
  if LevelLoaded then Result := Options.Clouds else Result := 0;
end;

function EdGetHorizon: Integer;
begin
  if LevelLoaded then Result := Options.Horizon else Result := 0;
end;

{ --- Level metadata getters/setters --- }

function EdGetLevelName: AnsiString;
begin
  Result := MetaName;
end;

procedure EdSetLevelName(const S: AnsiString);
begin
  MetaName := S;
end;

function EdGetLevelCreator: AnsiString;
begin
  Result := MetaCreator;
end;

procedure EdSetLevelCreator(const S: AnsiString);
begin
  MetaCreator := S;
end;

function EdGetLevelDescription: AnsiString;
begin
  Result := MetaDescription;
end;

procedure EdSetLevelDescription(const S: AnsiString);
begin
  MetaDescription := S;
end;

function EdGetMusicTrack: AnsiString;
begin
  Result := MusicTrack;
end;

procedure EdSetMusicTrack(const S: AnsiString);
begin
  MusicTrack := S;
end;

{ --- Sub-Level Management --- }

procedure AllocSubLevel(Index: Integer);
begin
  if SubLevels[Index] = nil then
    New(SubLevels[Index]);
end;

procedure FreeSubLevel(Index: Integer);
begin
  if SubLevels[Index] <> nil then
  begin
    Dispose(SubLevels[Index]);
    SubLevels[Index] := nil;
  end;
end;

procedure FreeAllSubLevels;
var
  i: Integer;
begin
  for i := 0 to MAX_SUB_LEVELS - 1 do
    FreeSubLevel(i);
  NumSubLevels := 0;
  ActiveSubLevel := 0;
end;

{ Save the currently active WorldMap/Options/metadata into the active sub-level buffer }
procedure EdSaveActiveToBuffer;
begin
  if (ActiveSubLevel < 0) or (ActiveSubLevel >= NumSubLevels) then Exit;
  if SubLevels[ActiveSubLevel] = nil then Exit;
  Move(WorldMap^, SubLevels[ActiveSubLevel]^.WorldSnap, SizeOf(WorldBuffer));
  SubLevels[ActiveSubLevel]^.Opts := Options;
  SubLevels[ActiveSubLevel]^.SLMetaName := MetaName;
  SubLevels[ActiveSubLevel]^.SLMetaCreator := MetaCreator;
  SubLevels[ActiveSubLevel]^.SLMetaDescription := MetaDescription;
  SubLevels[ActiveSubLevel]^.SLMusicTrack := MusicTrack;
end;

{ Restore WorldMap/Options/metadata from a sub-level buffer }
procedure LoadBufferToActive(Index: Integer);
begin
  if (Index < 0) or (Index >= NumSubLevels) then Exit;
  if SubLevels[Index] = nil then Exit;
  Move(SubLevels[Index]^.WorldSnap, WorldMap^, SizeOf(WorldBuffer));
  Options := SubLevels[Index]^.Opts;
  MetaName := SubLevels[Index]^.SLMetaName;
  MetaCreator := SubLevels[Index]^.SLMetaCreator;
  MetaDescription := SubLevels[Index]^.SLMetaDescription;
  MusicTrack := SubLevels[Index]^.SLMusicTrack;
end;

{ Re-initialize all rendering state from current Options (same as EdLoadLevel tail) }
procedure ReinitRenderState;
begin
  RestoreSpriteBackups;
  with Options do
  begin
    InitSky(SkyType);
    InitWalls(WallType1, WallType2, WallType3);
    InitPipes(PipeColor);
    InitBackGr(BackGrType, Clouds);
  end;
  BuildWorld;
  NewPalette(P256^);
  SetSkyPalette;
  InitGrass;
  DrawPalBackGr;
  InitWaterfallPalette;
  InitDecoSpritePalette;
  ReadPalette(Palette);
  EnsureBricks;
  EdBuildTileAtlas;
  EdBuildEnemyAtlas;
  EdBuildPlayerSprite;
  EdBuildSkyPreview;
end;

function EdGetNumSubLevels: Integer;
begin
  Result := NumSubLevels;
end;

function EdGetActiveSubLevel: Integer;
begin
  Result := ActiveSubLevel;
end;

procedure EdSwitchSubLevel(Index: Integer);
begin
  if (Index < 0) or (Index >= NumSubLevels) then Exit;
  if Index = ActiveSubLevel then Exit;

  { Save current edits to the active buffer }
  EdSaveActiveToBuffer;

  { Switch to the target sub-level }
  ActiveSubLevel := Index;
  LoadBufferToActive(Index);
  ReinitRenderState;
end;

function EdAddSubLevel: Integer;
var
  NewIdx: Integer;
begin
  Result := -1;
  if NumSubLevels >= MAX_SUB_LEVELS then Exit;

  { Save current edits first }
  EdSaveActiveToBuffer;

  NewIdx := NumSubLevels;
  AllocSubLevel(NewIdx);

  { Initialize with empty level data }
  FillChar(SubLevels[NewIdx]^.WorldSnap, SizeOf(WorldBuffer), ' ');
  FillChar(SubLevels[NewIdx]^.Opts, SizeOf(WorldOptions), 0);
  with SubLevels[NewIdx]^.Opts do
  begin
    Design := 1;
    SkyType := 0;
    Horizon := 6;
    BackGrType := 1;
    Clouds := 3;
    C2r := 20; C2g := 30; C2b := 63;
    C3r := 40; C3g := 50; C3b := 60;
    BuildWall := True;
    XSize := 236;
    InitX := 2 * W;
    InitY := 10 * H;
  end;
  SubLevels[NewIdx]^.TabName := 'Sub-level ' + Chr(Ord('A') + NewIdx);
  SubLevels[NewIdx]^.SLMetaName := '';
  SubLevels[NewIdx]^.SLMetaCreator := '';
  SubLevels[NewIdx]^.SLMetaDescription := '';

  Inc(NumSubLevels);

  { Switch to the new sub-level }
  ActiveSubLevel := NewIdx;
  LoadBufferToActive(NewIdx);
  ReinitRenderState;

  Result := NewIdx;
end;

procedure EdRemoveSubLevel(Index: Integer);
var
  i: Integer;
begin
  if NumSubLevels <= 1 then Exit;
  if (Index < 0) or (Index >= NumSubLevels) then Exit;

  { Free the buffer being removed }
  FreeSubLevel(Index);

  { Shift remaining entries down }
  for i := Index to NumSubLevels - 2 do
    SubLevels[i] := SubLevels[i + 1];
  SubLevels[NumSubLevels - 1] := nil;
  Dec(NumSubLevels);

  { Adjust active index }
  if ActiveSubLevel >= NumSubLevels then
    ActiveSubLevel := NumSubLevels - 1;

  { Load the now-active sub-level }
  LoadBufferToActive(ActiveSubLevel);
  ReinitRenderState;
end;

function EdGetSubLevelName(Index: Integer): AnsiString;
begin
  if (Index >= 0) and (Index < NumSubLevels) and (SubLevels[Index] <> nil) then
    Result := SubLevels[Index]^.TabName
  else
    Result := '';
end;

procedure EdSetSubLevelName(Index: Integer; const S: AnsiString);
begin
  if (Index >= 0) and (Index < NumSubLevels) and (SubLevels[Index] <> nil) then
    SubLevels[Index]^.TabName := S;
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

{ (DECO_LOOKUP removed — deco entries now use GetSpritePtr(Chr(CharCode)) directly) }

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
  i: Integer;
  Entry: TTileAtlasEntry;
  SprPtr: Pointer;
  BrickPat: Integer;
  PalSave: array[0..47] of Byte;  { up to 16 entries * 3 bytes }
begin
  if not Initialized then Exit;

  { Clear atlas to transparent }
  FillChar(AtlasBuf, SizeOf(AtlasBuf), 0);

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
          { Ground wall variants: each CharCode maps to a unique style+variant
            in the WallVariants[style 0..4, variant 0..8] array.
            Style: 0=Green(#91-99), 1=Sand(#100-108), 2=Brown(#109-117),
                   3=Grass(#118-126), 4=Desert(#139-147) }
          if ColorSpritesReady then
          begin
            if (Entry.CharCode >= CWALL_GREEN) and (Entry.CharCode <= CWALL_GREEN + 8) then
              SprPtr := @WallVariants[0, Entry.CharCode - CWALL_GREEN]
            else if (Entry.CharCode >= CWALL_SAND) and (Entry.CharCode <= CWALL_SAND + 8) then
              SprPtr := @WallVariants[1, Entry.CharCode - CWALL_SAND]
            else if (Entry.CharCode >= CWALL_BROWN) and (Entry.CharCode <= CWALL_BROWN + 8) then
              SprPtr := @WallVariants[2, Entry.CharCode - CWALL_BROWN]
            else if (Entry.CharCode >= CWALL_GRASS) and (Entry.CharCode <= CWALL_GRASS + 8) then
              SprPtr := @WallVariants[3, Entry.CharCode - CWALL_GRASS]
            else if (Entry.CharCode >= CWALL_DESERT) and (Entry.CharCode <= CWALL_DESERT + 8) then
              SprPtr := @WallVariants[4, Entry.CharCode - CWALL_DESERT];

            if SprPtr <> nil then
            begin
              RenderSpriteToAtlas(SprPtr, Entry.AtlasCol, Entry.AtlasRow);
              Continue;
            end;
          end;
        end;

      CAT_BRICKS:
        begin
          { Brick entries: use pre-colored ColorBricks[colorIdx, pattern].
            ColorIdx = CharCode - CBRICK_BASE (0..3).
            Pattern extracted from name: 'Brick0...'=0, 'Brick1...'=1, 'Brick2...'=2. }
          if (Entry.ColorType = CT_BRICK) and ColorSpritesReady then
          begin
            if (Entry.Name <> nil) and (Length(Entry.Name) >= 6) then
              BrickPat := Ord(Entry.Name[5]) - Ord('0')
            else
              BrickPat := 0;
            if (BrickPat < 0) or (BrickPat > 2) then BrickPat := 0;
            RenderSpriteToAtlas(
              @ColorBricks[Entry.CharCode - CBRICK_BASE, BrickPat],
              Entry.AtlasCol, Entry.AtlasRow);
            Continue;
          end;
        end;

      CAT_PIPES:
        begin
          { Pipe entries: use pre-colored ColorPipes[colorIdx, shapeIdx].
            ColorIdx = (CharCode - CPIPE_BASE) div 4,
            ShapeIdx = (CharCode - CPIPE_BASE) mod 4. }
          if Entry.ColorType = CT_PIPE then
          begin
            if ColorSpritesReady then
              RenderSpriteToAtlas(
                @ColorPipes[(Entry.CharCode - CPIPE_BASE) div 4,
                             (Entry.CharCode - CPIPE_BASE) mod 4],
                Entry.AtlasCol, Entry.AtlasRow);
            Continue;
          end;
        end;

      CAT_BLOCKS:
        begin
          { Color-variant blocks: use pre-colored arrays }
          if (Entry.ColorType <> CT_NONE) and ColorSpritesReady then
          begin
            case Entry.ColorType of
              CT_BRICK:
                begin
                  { Breakable block: CharCode #213..#216 → ColorBreak[0..3] }
                  SprPtr := @ColorBreak[Entry.CharCode - CBREAK_BASE];
                end;
              CT_WOOD:
                begin
                  { Wood block: CharCode #210..#212 → ColorWood[0..2] }
                  SprPtr := @ColorWood[Entry.CharCode - CWOOD_BASE];
                end;
              CT_XBLOCK:
                begin
                  { XBlock: CharCode #206..#209 → ColorXBlocks[0..3] }
                  SprPtr := @ColorXBlocks[Entry.CharCode - CXBLOCK_BASE];
                end;
            else
              SprPtr := nil;
            end;
            if SprPtr <> nil then
              RenderSpriteToAtlas(SprPtr, Entry.AtlasCol, Entry.AtlasRow);
            Continue;
          end;
          { Static blocks (?, @, $, I, K): no recoloring }
          SprPtr := GetSpritePtr(Chr(Entry.CharCode));
        end;

      CAT_ITEMS:
        begin
          SprPtr := GetSpritePtr(Chr(Entry.CharCode));
          { Flag (pole) shares CharCode 254 with Flag (top).
            Detect by name and use Exit001 (pole) sprite instead. }
          if (Entry.CharCode = 254) and (Entry.Name <> nil) and
             (Pos('pole', Entry.Name) > 0) then
            SprPtr := GetSpritePtr(#255);  { Exit001 = pole }
        end;

      CAT_PLATFORM:
        begin
          { Jump-thru tiles #14-#16 render as wall top-row in the game
            (TL/Top/TR of current wall style). Use WallVariants if ready. }
          if (Entry.CharCode >= 14) and (Entry.CharCode <= 16) and ColorSpritesReady then
            SprPtr := @WallVariants[0, Entry.CharCode - 14]  { Green TL/Top/TR }
          else
            SprPtr := GetSpritePtr(Chr(Entry.CharCode));
        end;

      CAT_DECO:
        begin
          { Each deco variant has a unique CharCode.
            Some need temporary palette swaps for correct colors. }
          SprPtr := GetSpritePtr(Chr(Entry.CharCode));

          if (Entry.CharCode = Ord('#')) or (Entry.CharCode = Ord('%')) then
          begin
            { Waterfall — set blue water palette }
            SavePalRange(7, 5, PalSave);
            SetWaterfallPalForSky(2);
            if SprPtr <> nil then
              RenderSpriteToAtlas(SprPtr, Entry.AtlasCol, Entry.AtlasRow);
            RestorePalRange(7, 5, PalSave);
            SprPtr := nil;
          end
          else if (Entry.CharCode = 150) or (Entry.CharCode = 151) then
          begin
            { Window — set castle palette }
            SavePalRange($F0, 16, PalSave);
            SetWindowPalette;
            if SprPtr <> nil then
              RenderSpriteToAtlas(SprPtr, Entry.AtlasCol, Entry.AtlasRow);
            RestorePalRange($F0, 16, PalSave);
            SprPtr := nil;
          end
          else if (Entry.CharCode = 152) or (Entry.CharCode = 153) then
          begin
            { Lava — set orange/red lava palette }
            SavePalRange(7, 5, PalSave);
            SetWaterfallPalForSky(6);
            if SprPtr <> nil then
              RenderSpriteToAtlas(SprPtr, Entry.AtlasCol, Entry.AtlasRow);
            RestorePalRange(7, 5, PalSave);
            SprPtr := nil;
          end;
          { All other deco tiles (tree, fence, small tree, grass, palms)
            use default palette — SprPtr stays set for render below. }
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

function EdFindTileAtlasIndex(CharCode: Byte): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to TILE_ATLAS_COUNT - 1 do
    if TileAtlas[i].CharCode = CharCode then
    begin
      Result := i;
      Exit;
    end;
end;

function EdNeedsOverlay(CharCode: Byte): Boolean;
begin
  { Palette-dependent deco tiles that can't render correctly via Redraw
    because they use palette indices shared with sky/parallax/waterfall.
    These must be drawn as overlay sprites from the tile atlas (which was
    rendered with the correct palette). }
  case CharCode of
    150, 151,   { Window — uses $F0/$FF, shared with sky }
    152, 153:   { Lava — uses 7-11, shared with waterfall }
      Result := True;
  else
    Result := False;
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

{ --- Save/Load (.mled binary format) --- }

const
  MLED_MAGIC: array[0..3] of Char = ('M','L','E','D');
  MLED_VERSION: Byte = 1;

function EdSaveLevel(const FileName: AnsiString): Boolean;
var
  F: File;
  x, y: Integer;
  Ch: Char;
begin
  Result := False;
  if not LevelLoaded then Exit;

  AssignFile(F, FileName);
  {$I-}
  Rewrite(F, 1);
  {$I+}
  if IOResult <> 0 then Exit;

  { Write header: magic + version }
  BlockWrite(F, MLED_MAGIC, 4);
  BlockWrite(F, MLED_VERSION, 1);

  { Write Options record }
  BlockWrite(F, Options, SizeOf(WorldOptions));

  { Write tile data: XSize columns × NV rows, column-major }
  for x := 0 to Options.XSize - 1 do
    for y := 0 to NV - 1 do
    begin
      Ch := WorldMap^[x, y];
      BlockWrite(F, Ch, 1);
    end;

  { Write hidden row (row NV = 13, used for camera locks and pipe warps) }
  for x := 0 to Options.XSize - 1 do
  begin
    Ch := WorldMap^[x, NV];
    BlockWrite(F, Ch, 1);
  end;

  CloseFile(F);
  Result := True;
end;

function EdLoadLevelFromFile(const FileName: AnsiString): Boolean;
var
  F: File;
  Magic: array[0..3] of Char;
  Ver: Byte;
  x, y: Integer;
  Ch: Char;
  FileOpts: WorldOptions;
begin
  Result := False;
  if not Initialized then Exit;

  AssignFile(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then Exit;

  { Read and validate header }
  BlockRead(F, Magic, 4);
  if (Magic[0] <> 'M') or (Magic[1] <> 'L') or (Magic[2] <> 'E') or (Magic[3] <> 'D') then
  begin
    CloseFile(F);
    Exit;
  end;
  BlockRead(F, Ver, 1);
  if Ver <> 1 then
  begin
    CloseFile(F);
    Exit;
  end;

  { Read Options }
  BlockRead(F, FileOpts, SizeOf(WorldOptions));

  { Validate XSize }
  if (FileOpts.XSize < 1) or (FileOpts.XSize > MaxWorldSize) then
  begin
    CloseFile(F);
    Exit;
  end;

  { Free existing sub-level buffers }
  FreeAllSubLevels;

  { Restore sprites before re-initializing }
  RestoreSpriteBackups;

  { Apply Options }
  Options := FileOpts;

  { Clear WorldMap }
  FillChar(WorldMap^, SizeOf(WorldBuffer), ' ');

  { Read tile data: XSize columns × NV rows }
  for x := 0 to Options.XSize - 1 do
    for y := 0 to NV - 1 do
    begin
      BlockRead(F, Ch, 1);
      WorldMap^[x, y] := Ch;
    end;

  { Read hidden row }
  for x := 0 to Options.XSize - 1 do
  begin
    BlockRead(F, Ch, 1);
    WorldMap^[x, NV] := Ch;
  end;

  CloseFile(F);

  { Clear metadata (binary format has no metadata) }
  MetaName := '';
  MetaCreator := '';
  MetaDescription := '';

  { Initialize sub-level system with single sub-level }
  AllocSubLevel(0);
  Move(WorldMap^, SubLevels[0]^.WorldSnap, SizeOf(WorldBuffer));
  SubLevels[0]^.Opts := Options;
  SubLevels[0]^.TabName := 'Level A';
  SubLevels[0]^.SLMetaName := '';
  SubLevels[0]^.SLMetaCreator := '';
  SubLevels[0]^.SLMetaDescription := '';
  NumSubLevels := 1;
  ActiveSubLevel := 0;

  { Initialize rendering state from Options (same as EdLoadLevel) }
  with Options do
  begin
    InitSky(SkyType);
    InitWalls(WallType1, WallType2, WallType3);
    InitPipes(PipeColor);
    InitBackGr(BackGrType, Clouds);
  end;

  BuildWorld;
  NewPalette(P256^);
  SetSkyPalette;
  InitGrass;
  DrawPalBackGr;
  InitWaterfallPalette;
  InitDecoSpritePalette;
  ReadPalette(Palette);

  LevelLoaded := True;

  EnsureBricks;
  EdBuildTileAtlas;
  EdBuildEnemyAtlas;
  EdBuildPlayerSprite;
  EdBuildSkyPreview;

  Result := True;
end;

{ ===== JSON Save/Load ===== }

{ Helper: write a string to a text file }
procedure JSONWrite(var F: TextFile; const S: AnsiString);
begin
  Write(F, S);
end;

{ Helper: write a line to a text file }
procedure JSONWriteLn(var F: TextFile; const S: AnsiString);
begin
  WriteLn(F, S);
end;

{ Helper: escape a string for JSON output (escape " and \) }
function JSONEscapeStr(const S: AnsiString): AnsiString;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    if S[i] = '\' then
      Result := Result + '\\'
    else if S[i] = '"' then
      Result := Result + '\"'
    else
      Result := Result + S[i];
  end;
end;

{ Helper: encode a tile row into a JSON-safe string.
  Printable ASCII (32..126) -> as-is.
  Non-printable -> $XX hex escape. }
function EncodeTileRow(TileY, XSize: Integer): AnsiString;
var
  x: Integer;
  Ch: Char;
  b: Byte;
begin
  Result := '';
  for x := 0 to XSize - 1 do
  begin
    Ch := WorldMap^[x, TileY];
    b := Ord(Ch);
    if (b >= 32) and (b <= 126) and (Ch <> '$') then
    begin
      { Escape backslash and double-quote for JSON string safety }
      if Ch = '\' then
        Result := Result + '\\'
      else if Ch = '"' then
        Result := Result + '\"'
      else
        Result := Result + Ch;
    end
    else
      Result := Result + '$' + IntToHex(b, 2);
  end;
end;

{ Write one sub-level's options and tile data as a JSON object.
  Reads tile data from the current WorldMap^.
  Indent is the base indentation string (e.g. '    ' for nested in array). }
procedure WriteSubLevelJSON(var F: TextFile; const Indent: AnsiString;
  const Opts: WorldOptions; const TabName, SLName, SLCreator, SLDesc, SLMusic: AnsiString);
var
  y, GameY, BW: Integer;
begin
  JSONWriteLn(F, Indent + '{');
  JSONWriteLn(F, Indent + '  "name": "' + JSONEscapeStr(TabName) + '",');
  JSONWriteLn(F, Indent + '  "levelName": "' + JSONEscapeStr(SLName) + '",');
  JSONWriteLn(F, Indent + '  "creator": "' + JSONEscapeStr(SLCreator) + '",');
  JSONWriteLn(F, Indent + '  "description": "' + JSONEscapeStr(SLDesc) + '",');
  if SLMusic <> '' then
    JSONWriteLn(F, Indent + '  "musicTrack": "' + JSONEscapeStr(SLMusic) + '",');

  with Opts do
  begin
    JSONWriteLn(F, Indent + '  "design": ' + IntToStr(Design) + ',');
    JSONWriteLn(F, Indent + '  "skyType": ' + IntToStr(SkyType) + ',');
    JSONWriteLn(F, Indent + '  "wallType1": ' + IntToStr(WallType1) + ',');
    JSONWriteLn(F, Indent + '  "wallType2": ' + IntToStr(WallType2) + ',');
    JSONWriteLn(F, Indent + '  "wallType3": ' + IntToStr(WallType3) + ',');
    JSONWriteLn(F, Indent + '  "pipeColor": ' + IntToStr(PipeColor) + ',');
    JSONWriteLn(F, Indent + '  "groundColor1": ' + IntToStr(GroundColor1) + ',');
    JSONWriteLn(F, Indent + '  "groundColor2": ' + IntToStr(GroundColor2) + ',');
    JSONWriteLn(F, Indent + '  "horizon": ' + IntToStr(Horizon) + ',');
    JSONWriteLn(F, Indent + '  "backGrType": ' + IntToStr(BackGrType) + ',');
    JSONWriteLn(F, Indent + '  "backGrColor1": ' + IntToStr(BackGrColor1) + ',');
    JSONWriteLn(F, Indent + '  "backGrColor2": ' + IntToStr(BackGrColor2) + ',');
    JSONWriteLn(F, Indent + '  "stars": ' + IntToStr(Stars) + ',');
    JSONWriteLn(F, Indent + '  "clouds": ' + IntToStr(Clouds) + ',');
    JSONWriteLn(F, Indent + '  "c2r": ' + IntToStr(C2r) + ',');
    JSONWriteLn(F, Indent + '  "c2g": ' + IntToStr(C2g) + ',');
    JSONWriteLn(F, Indent + '  "c2b": ' + IntToStr(C2b) + ',');
    JSONWriteLn(F, Indent + '  "c3r": ' + IntToStr(C3r) + ',');
    JSONWriteLn(F, Indent + '  "c3g": ' + IntToStr(C3g) + ',');
    JSONWriteLn(F, Indent + '  "c3b": ' + IntToStr(C3b) + ',');
    JSONWriteLn(F, Indent + '  "brickColor": ' + IntToStr(BrickColor) + ',');
    JSONWriteLn(F, Indent + '  "woodColor": ' + IntToStr(WoodColor) + ',');
    JSONWriteLn(F, Indent + '  "xBlockColor": ' + IntToStr(XBlockColor) + ',');
    if BuildWall then BW := 1 else BW := 0;
    JSONWriteLn(F, Indent + '  "buildWall": ' + IntToStr(BW) + ',');
    JSONWriteLn(F, Indent + '  "startX": ' + IntToStr(InitX) + ',');
    JSONWriteLn(F, Indent + '  "startY": ' + IntToStr(InitY) + ',');
    JSONWriteLn(F, Indent + '  "width": ' + IntToStr(XSize) + ',');
  end;

  { Tiles — 13 rows, stored top-to-bottom }
  JSONWriteLn(F, Indent + '  "tiles": [');
  for y := 0 to NV - 1 do
  begin
    GameY := NV - 1 - y;
    JSONWrite(F, Indent + '    "' + EncodeTileRow(GameY, Opts.XSize) + '"');
    if y < NV - 1 then
      JSONWriteLn(F, ',')
    else
      JSONWriteLn(F, '');
  end;
  JSONWriteLn(F, Indent + '  ],');

  { Hidden row }
  JSONWriteLn(F, Indent + '  "hiddenRow": "' + EncodeTileRow(NV, Opts.XSize) + '"');

  JSONWriteLn(F, Indent + '}');
end;

function EdSaveLevelJSON(const FileName: AnsiString): Boolean;
var
  F: TextFile;
  i: Integer;
  SavedActive: Integer;
begin
  Result := False;
  if not LevelLoaded then Exit;

  { Ensure all sub-level buffers are up-to-date }
  EdSaveActiveToBuffer;

  AssignFile(F, FileName);
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult <> 0 then Exit;

  SavedActive := ActiveSubLevel;

  JSONWriteLn(F, '{');
  JSONWriteLn(F, '  "format": "mario-luigi-level",');
  JSONWriteLn(F, '  "version": 2,');

  { Root-level metadata from first sub-level }
  if (NumSubLevels > 0) and (SubLevels[0] <> nil) then
  begin
    JSONWriteLn(F, '  "name": "' + JSONEscapeStr(SubLevels[0]^.SLMetaName) + '",');
    JSONWriteLn(F, '  "creator": "' + JSONEscapeStr(SubLevels[0]^.SLMetaCreator) + '",');
    JSONWriteLn(F, '  "description": "' + JSONEscapeStr(SubLevels[0]^.SLMetaDescription) + '",');
  end
  else
  begin
    JSONWriteLn(F, '  "name": "",');
    JSONWriteLn(F, '  "creator": "",');
    JSONWriteLn(F, '  "description": "",');
  end;

  { Sub-levels array }
  JSONWriteLn(F, '  "sublevels": [');
  for i := 0 to NumSubLevels - 1 do
  begin
    if SubLevels[i] = nil then Continue;

    { Load this sub-level's data into WorldMap so EncodeTileRow can read it }
    LoadBufferToActive(i);

    WriteSubLevelJSON(F, '    ', SubLevels[i]^.Opts,
      SubLevels[i]^.TabName,
      SubLevels[i]^.SLMetaName,
      SubLevels[i]^.SLMetaCreator,
      SubLevels[i]^.SLMetaDescription,
      SubLevels[i]^.SLMusicTrack);

    if i < NumSubLevels - 1 then
      JSONWriteLn(F, '    ,');  { comma between array elements }
  end;
  JSONWriteLn(F, '  ]');

  JSONWriteLn(F, '}');

  CloseFile(F);

  { Restore the originally active sub-level }
  ActiveSubLevel := SavedActive;
  LoadBufferToActive(SavedActive);
  ReinitRenderState;

  Result := True;
end;

function EdSaveLevelV3(const FileName: AnsiString): Boolean;
var
  Lvl: TLevelData;
  Col, Row: Integer;
  XSz: Integer;
begin
  Result := False;
  if not LevelLoaded then Exit;
  EdSaveActiveToBuffer;

  { Build TLevelData from active sub-level }
  if SubLevels[ActiveSubLevel] = nil then Exit;

  Lvl.Name := SubLevels[ActiveSubLevel]^.SLMetaName;
  Lvl.Creator := SubLevels[ActiveSubLevel]^.SLMetaCreator;
  Lvl.Description := SubLevels[ActiveSubLevel]^.SLMetaDescription;
  Lvl.MusicTrack := SubLevels[ActiveSubLevel]^.SLMusicTrack;
  Lvl.Options := SubLevels[ActiveSubLevel]^.Opts;
  XSz := Lvl.Options.XSize;
  if XSz < 1 then XSz := 1;
  if XSz > MaxWorldSize then XSz := MaxWorldSize;
  Lvl.Width := XSz;

  { Convert WorldBuffer back to MapBuffer (reverse of MapToWorldBuffer) }
  FillChar(Lvl.Map, SizeOf(Lvl.Map), ' ');
  for Col := 0 to XSz - 1 do
    for Row := 1 to NV do
      Lvl.Map[Col + 1, Row] := SubLevels[ActiveSubLevel]^.WorldSnap[Col, NV - Row];

  { Set end terminator }
  if XSz < MaxWorldSize then
    Lvl.Map[XSz + 1, 1] := #0;

  FillChar(Lvl.HiddenRow, SizeOf(Lvl.HiddenRow), ' ');

  Result := LevelFormat.SaveLevelJSON(FileName, Lvl);
end;

{ ===== JSON Load ===== }

{ Helper: skip whitespace in buffer }
function SkipWS(const Buf: AnsiString; Pos: Integer): Integer;
begin
  while (Pos <= Length(Buf)) and (Buf[Pos] in [' ', #9, #10, #13]) do
    Inc(Pos);
  Result := Pos;
end;

{ Helper: find a JSON key in the buffer, returns position after the colon.
  Searches from StartPos. Returns 0 if not found. }
function FindKey(const Buf: AnsiString; const Key: AnsiString; StartPos: Integer): Integer;
var
  P, KLen: Integer;
  SearchStr: AnsiString;
begin
  Result := 0;
  SearchStr := '"' + Key + '"';
  KLen := Length(SearchStr);
  P := StartPos;
  while P <= Length(Buf) - KLen + 1 do
  begin
    if Copy(Buf, P, KLen) = SearchStr then
    begin
      P := P + KLen;
      P := SkipWS(Buf, P);
      if (P <= Length(Buf)) and (Buf[P] = ':') then
      begin
        Result := P + 1;
        Exit;
      end;
    end;
    Inc(P);
  end;
end;

{ Helper: read an integer value from buffer at Pos }
function ReadJSONInt(const Buf: AnsiString; Pos: Integer; out Value: Integer): Integer;
var
  Start: Integer;
  S: AnsiString;
begin
  Pos := SkipWS(Buf, Pos);
  Start := Pos;
  if (Pos <= Length(Buf)) and (Buf[Pos] = '-') then Inc(Pos);
  while (Pos <= Length(Buf)) and (Buf[Pos] in ['0'..'9']) do
    Inc(Pos);
  S := Copy(Buf, Start, Pos - Start);
  Value := StrToIntDef(S, 0);
  Result := Pos;
end;

{ Helper: read a JSON string value (between quotes) from buffer at Pos.
  Handles \" and \\ escapes. }
function ReadJSONStr(const Buf: AnsiString; Pos: Integer; out Value: AnsiString): Integer;
begin
  Value := '';
  Pos := SkipWS(Buf, Pos);
  if (Pos > Length(Buf)) or (Buf[Pos] <> '"') then
  begin
    Result := Pos;
    Exit;
  end;
  Inc(Pos); { skip opening quote }
  while (Pos <= Length(Buf)) and (Buf[Pos] <> '"') do
  begin
    if (Buf[Pos] = '\') and (Pos + 1 <= Length(Buf)) then
    begin
      Inc(Pos);
      Value := Value + Buf[Pos];
    end
    else
      Value := Value + Buf[Pos];
    Inc(Pos);
  end;
  if (Pos <= Length(Buf)) and (Buf[Pos] = '"') then
    Inc(Pos); { skip closing quote }
  Result := Pos;
end;

{ Helper: read a JSON key's integer value }
function GetJSONInt(const Buf: AnsiString; const Key: AnsiString; Default: Integer): Integer;
var
  P: Integer;
begin
  P := FindKey(Buf, Key, 1);
  if P = 0 then
  begin
    Result := Default;
    Exit;
  end;
  ReadJSONInt(Buf, P, Result);
end;

{ Helper: read a JSON key's string value }
function GetJSONStr(const Buf: AnsiString; const Key: AnsiString; const Default: AnsiString): AnsiString;
var
  P: Integer;
begin
  P := FindKey(Buf, Key, 1);
  if P = 0 then
  begin
    Result := Default;
    Exit;
  end;
  ReadJSONStr(Buf, P, Result);
end;

{ Helper: decode a tile row string into WorldMap.
  Printable chars → as-is. $XX → hex byte. }
procedure DecodeTileRow(const S: AnsiString; TileY, XSize: Integer);
var
  i, x: Integer;
  b: Byte;
  HexStr: AnsiString;
begin
  i := 1;
  x := 0;
  while (i <= Length(S)) and (x < XSize) do
  begin
    if (S[i] = '$') and (i + 2 <= Length(S)) then
    begin
      HexStr := Copy(S, i + 1, 2);
      b := StrToIntDef('$' + HexStr, 0);
      WorldMap^[x, TileY] := Chr(b);
      Inc(i, 3);
    end
    else
    begin
      WorldMap^[x, TileY] := S[i];
      Inc(i);
    end;
    Inc(x);
  end;
  { Fill remaining columns with spaces }
  while x < XSize do
  begin
    WorldMap^[x, TileY] := ' ';
    Inc(x);
  end;
end;

{ Find the tiles array in JSON and decode all rows }
procedure DecodeTilesArray(const Buf: AnsiString; XSize: Integer);
var
  P, RowIdx, GameY: Integer;
  RowStr: AnsiString;
begin
  P := FindKey(Buf, 'tiles', 1);
  if P = 0 then Exit;

  P := SkipWS(Buf, P);
  if (P > Length(Buf)) or (Buf[P] <> '[') then Exit;
  Inc(P); { skip '[' }

  for RowIdx := 0 to NV - 1 do
  begin
    P := SkipWS(Buf, P);
    if P > Length(Buf) then Exit;
    P := ReadJSONStr(Buf, P, RowStr);
    GameY := NV - 1 - RowIdx;  { JSON row 0 = top = game Y=12 }
    DecodeTileRow(RowStr, GameY, XSize);
    P := SkipWS(Buf, P);
    if (P <= Length(Buf)) and (Buf[P] = ',') then Inc(P);
  end;
end;

{ Decode the hidden row from JSON }
procedure DecodeHiddenRow(const Buf: AnsiString; XSize: Integer);
var
  P: Integer;
  RowStr: AnsiString;
begin
  P := FindKey(Buf, 'hiddenRow', 1);
  if P = 0 then Exit;
  ReadJSONStr(Buf, P, RowStr);
  DecodeTileRow(RowStr, NV, XSize);
end;

{ Forward declaration for v2 JSON loader }
function LoadJSONv2(const Buf: AnsiString): Boolean; forward;

{ Load a v3 single-level JSON file using shared LevelFormat unit }
function EdLoadLevelV3(const FileName: AnsiString): Boolean;
var
  Lvl: TLevelData;
begin
  Result := False;
  if not Initialized then Exit;
  if not LevelFormat.LoadLevelJSON(FileName, Lvl) then Exit;

  { Free existing sub-level buffers }
  FreeAllSubLevels;
  RestoreSpriteBackups;

  { Set up game state from loaded data }
  Options := Lvl.Options;
  FillChar(WorldMap^, SizeOf(WorldBuffer), ' ');
  MapToWorldBuffer(Lvl.Map, WorldMap, Options);

  { Create single sub-level }
  AllocSubLevel(0);
  Move(WorldMap^, SubLevels[0]^.WorldSnap, SizeOf(WorldBuffer));
  SubLevels[0]^.Opts := Options;
  SubLevels[0]^.TabName := 'Level A';
  SubLevels[0]^.SLMetaName := Lvl.Name;
  SubLevels[0]^.SLMetaCreator := Lvl.Creator;
  SubLevels[0]^.SLMetaDescription := Lvl.Description;
  SubLevels[0]^.SLMusicTrack := Lvl.MusicTrack;
  NumSubLevels := 1;
  ActiveSubLevel := 0;

  { Set metadata }
  MetaName := Lvl.Name;
  MetaCreator := Lvl.Creator;
  MetaDescription := Lvl.Description;

  { Initialize rendering state from loaded options }
  with Options do
  begin
    InitSky(SkyType);
    InitWalls(WallType1, WallType2, WallType3);
    InitPipes(PipeColor);
    InitBackGr(BackGrType, Clouds);
  end;
  BuildWorld;
  NewPalette(P256^);
  SetSkyPalette;
  InitGrass;
  DrawPalBackGr;
  InitWaterfallPalette;
  InitDecoSpritePalette;
  ReadPalette(Palette);

  LevelLoaded := True;

  { Build tile atlas for the loaded level's theme }
  EdBuildTileAtlas;
  EdBuildEnemyAtlas;
  EdBuildSkyPreview;
  EdBuildPlayerSprite;

  Result := True;
end;

function EdLoadLevelJSON(const FileName: AnsiString): Boolean;
var
  F: File;
  Buf: AnsiString;
  FileSize: LongInt;
  BytesRead: LongInt;
  XSz: Integer;
  JSONVer: Integer;
begin
  Result := False;
  if not Initialized then Exit;

  { Read entire file into buffer }
  AssignFile(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then Exit;

  FileSize := System.FileSize(F);
  if (FileSize < 10) or (FileSize > 1024 * 1024) then
  begin
    CloseFile(F);
    Exit;
  end;

  SetLength(Buf, FileSize);
  BlockRead(F, Buf[1], FileSize, BytesRead);
  CloseFile(F);
  if BytesRead <> FileSize then Exit;

  { Check for v3 format (single level, uses LevelFormat shared unit) }
  if Pos('"mario-luigi-level"', Buf) = 0 then
  begin
    Result := EdLoadLevelV3(FileName);
    Exit;
  end;

  { Free existing sub-level buffers }
  FreeAllSubLevels;

  { Check version — v2 has "sublevels" array, v1 is flat format }
  JSONVer := GetJSONInt(Buf, 'version', 1);

  if (JSONVer >= 2) and (FindKey(Buf, 'sublevels', 1) > 0) then
  begin
    { === JSON v2: Parse sublevels array === }
    Result := LoadJSONv2(Buf);
    Exit;
  end;

  { === JSON v1: Flat format — single sub-level === }

  { Parse metadata }
  MetaName := GetJSONStr(Buf, 'name', '');
  MetaCreator := GetJSONStr(Buf, 'creator', '');
  MetaDescription := GetJSONStr(Buf, 'description', '');

  { Restore sprites before re-initializing }
  RestoreSpriteBackups;

  { Parse theme options }
  with Options do
  begin
    Design := GetJSONInt(Buf, 'design', 1);
    SkyType := GetJSONInt(Buf, 'skyType', 0);
    WallType1 := GetJSONInt(Buf, 'wallType1', 0);
    WallType2 := GetJSONInt(Buf, 'wallType2', 0);
    WallType3 := GetJSONInt(Buf, 'wallType3', 0);
    PipeColor := GetJSONInt(Buf, 'pipeColor', 0);
    GroundColor1 := GetJSONInt(Buf, 'groundColor1', 0);
    GroundColor2 := GetJSONInt(Buf, 'groundColor2', 0);
    Horizon := GetJSONInt(Buf, 'horizon', 6);
    BackGrType := GetJSONInt(Buf, 'backGrType', 1);
    BackGrColor1 := GetJSONInt(Buf, 'backGrColor1', 0);
    BackGrColor2 := GetJSONInt(Buf, 'backGrColor2', 0);
    Stars := GetJSONInt(Buf, 'stars', 0);
    Clouds := GetJSONInt(Buf, 'clouds', 3);
    C2r := GetJSONInt(Buf, 'c2r', 20);
    C2g := GetJSONInt(Buf, 'c2g', 30);
    C2b := GetJSONInt(Buf, 'c2b', 63);
    C3r := GetJSONInt(Buf, 'c3r', 40);
    C3g := GetJSONInt(Buf, 'c3g', 50);
    C3b := GetJSONInt(Buf, 'c3b', 60);
    BrickColor := GetJSONInt(Buf, 'brickColor', 0);
    WoodColor := GetJSONInt(Buf, 'woodColor', 0);
    XBlockColor := GetJSONInt(Buf, 'xBlockColor', 0);
    BuildWall := GetJSONInt(Buf, 'buildWall', 1) <> 0;
    InitX := GetJSONInt(Buf, 'startX', 2);
    InitY := GetJSONInt(Buf, 'startY', 10);
  end;

  { Parse size }
  XSz := GetJSONInt(Buf, 'width', 236);
  if (XSz < 1) or (XSz > MaxWorldSize) then XSz := 236;
  Options.XSize := XSz;

  { Clear WorldMap }
  FillChar(WorldMap^, SizeOf(WorldBuffer), ' ');

  { Parse tile data }
  DecodeTilesArray(Buf, Options.XSize);

  { Parse hidden row }
  DecodeHiddenRow(Buf, Options.XSize);

  { Initialize sub-level system with single sub-level }
  AllocSubLevel(0);
  Move(WorldMap^, SubLevels[0]^.WorldSnap, SizeOf(WorldBuffer));
  SubLevels[0]^.Opts := Options;
  SubLevels[0]^.TabName := 'Level A';
  SubLevels[0]^.SLMetaName := MetaName;
  SubLevels[0]^.SLMetaCreator := MetaCreator;
  SubLevels[0]^.SLMetaDescription := MetaDescription;
  NumSubLevels := 1;
  ActiveSubLevel := 0;

  { Initialize rendering state from Options (same as EdLoadLevel) }
  with Options do
  begin
    InitSky(SkyType);
    InitWalls(WallType1, WallType2, WallType3);
    InitPipes(PipeColor);
    InitBackGr(BackGrType, Clouds);
  end;

  BuildWorld;
  NewPalette(P256^);
  SetSkyPalette;
  InitGrass;
  DrawPalBackGr;
  InitWaterfallPalette;
  InitDecoSpritePalette;
  ReadPalette(Palette);

  LevelLoaded := True;

  EnsureBricks;
  EdBuildTileAtlas;
  EdBuildEnemyAtlas;
  EdBuildPlayerSprite;
  EdBuildSkyPreview;

  Result := True;
end;

{ ===== JSON v2 Load (sublevels array) ===== }

// Find the end of a JSON object starting at Pos (should point to open-brace).
// Handles nested objects and strings. Returns position after closing brace.
function FindObjectEnd(const Buf: AnsiString; StartPos: Integer): Integer;
var
  P, Depth: Integer;
  InStr: Boolean;
begin
  Result := 0;
  P := StartPos;
  if (P > Length(Buf)) or (Buf[P] <> '{') then Exit;
  Depth := 0;
  InStr := False;
  while P <= Length(Buf) do
  begin
    if InStr then
    begin
      if (Buf[P] = '\') and (P + 1 <= Length(Buf)) then
        Inc(P)  { skip escaped char }
      else if Buf[P] = '"' then
        InStr := False;
    end
    else
    begin
      case Buf[P] of
        '"': InStr := True;
        '{': Inc(Depth);
        '}': begin
               Dec(Depth);
               if Depth = 0 then
               begin
                 Result := P + 1;
                 Exit;
               end;
             end;
      end;
    end;
    Inc(P);
  end;
end;

{ Find a JSON key within a bounded range [StartPos..EndPos).
  Returns position after the colon, or 0 if not found. }
function FindKeyInRange(const Buf: AnsiString; const Key: AnsiString;
  StartPos, EndPos: Integer): Integer;
var
  P, KLen: Integer;
  SearchStr: AnsiString;
begin
  Result := 0;
  SearchStr := '"' + Key + '"';
  KLen := Length(SearchStr);
  P := StartPos;
  while P <= EndPos - KLen do
  begin
    if Copy(Buf, P, KLen) = SearchStr then
    begin
      P := P + KLen;
      P := SkipWS(Buf, P);
      if (P <= EndPos) and (Buf[P] = ':') then
      begin
        Result := P + 1;
        Exit;
      end;
    end;
    Inc(P);
  end;
end;

{ Read an integer value within a range }
function GetJSONIntInRange(const Buf: AnsiString; const Key: AnsiString;
  StartPos, EndPos, Default: Integer): Integer;
var
  P: Integer;
begin
  P := FindKeyInRange(Buf, Key, StartPos, EndPos);
  if P = 0 then
  begin
    Result := Default;
    Exit;
  end;
  ReadJSONInt(Buf, P, Result);
end;

{ Read a string value within a range }
function GetJSONStrInRange(const Buf: AnsiString; const Key: AnsiString;
  StartPos, EndPos: Integer; const Default: AnsiString): AnsiString;
var
  P: Integer;
begin
  P := FindKeyInRange(Buf, Key, StartPos, EndPos);
  if P = 0 then
  begin
    Result := Default;
    Exit;
  end;
  ReadJSONStr(Buf, P, Result);
end;

{ Decode tiles array within a bounded range }
procedure DecodeTilesArrayInRange(const Buf: AnsiString; XSize: Integer;
  StartPos, EndPos: Integer);
var
  P, RowIdx, GameY: Integer;
  RowStr: AnsiString;
begin
  P := FindKeyInRange(Buf, 'tiles', StartPos, EndPos);
  if P = 0 then Exit;

  P := SkipWS(Buf, P);
  if (P > Length(Buf)) or (Buf[P] <> '[') then Exit;
  Inc(P);

  for RowIdx := 0 to NV - 1 do
  begin
    P := SkipWS(Buf, P);
    if P > Length(Buf) then Exit;
    P := ReadJSONStr(Buf, P, RowStr);
    GameY := NV - 1 - RowIdx;
    DecodeTileRow(RowStr, GameY, XSize);
    P := SkipWS(Buf, P);
    if (P <= Length(Buf)) and (Buf[P] = ',') then Inc(P);
  end;
end;

{ Decode hidden row within a bounded range }
procedure DecodeHiddenRowInRange(const Buf: AnsiString; XSize: Integer;
  StartPos, EndPos: Integer);
var
  P: Integer;
  RowStr: AnsiString;
begin
  P := FindKeyInRange(Buf, 'hiddenRow', StartPos, EndPos);
  if P = 0 then Exit;
  ReadJSONStr(Buf, P, RowStr);
  DecodeTileRow(RowStr, NV, XSize);
end;

{ Parse a sub-level object bounded by [ObjStart..ObjEnd) into
  the current WorldMap^ and Options. }
procedure ParseSubLevelObject(const Buf: AnsiString; ObjStart, ObjEnd: Integer);
var
  XSz: Integer;
begin
  with Options do
  begin
    Design := GetJSONIntInRange(Buf, 'design', ObjStart, ObjEnd, 1);
    SkyType := GetJSONIntInRange(Buf, 'skyType', ObjStart, ObjEnd, 0);
    WallType1 := GetJSONIntInRange(Buf, 'wallType1', ObjStart, ObjEnd, 0);
    WallType2 := GetJSONIntInRange(Buf, 'wallType2', ObjStart, ObjEnd, 0);
    WallType3 := GetJSONIntInRange(Buf, 'wallType3', ObjStart, ObjEnd, 0);
    PipeColor := GetJSONIntInRange(Buf, 'pipeColor', ObjStart, ObjEnd, 0);
    GroundColor1 := GetJSONIntInRange(Buf, 'groundColor1', ObjStart, ObjEnd, 0);
    GroundColor2 := GetJSONIntInRange(Buf, 'groundColor2', ObjStart, ObjEnd, 0);
    Horizon := GetJSONIntInRange(Buf, 'horizon', ObjStart, ObjEnd, 6);
    BackGrType := GetJSONIntInRange(Buf, 'backGrType', ObjStart, ObjEnd, 1);
    BackGrColor1 := GetJSONIntInRange(Buf, 'backGrColor1', ObjStart, ObjEnd, 0);
    BackGrColor2 := GetJSONIntInRange(Buf, 'backGrColor2', ObjStart, ObjEnd, 0);
    Stars := GetJSONIntInRange(Buf, 'stars', ObjStart, ObjEnd, 0);
    Clouds := GetJSONIntInRange(Buf, 'clouds', ObjStart, ObjEnd, 3);
    C2r := GetJSONIntInRange(Buf, 'c2r', ObjStart, ObjEnd, 20);
    C2g := GetJSONIntInRange(Buf, 'c2g', ObjStart, ObjEnd, 30);
    C2b := GetJSONIntInRange(Buf, 'c2b', ObjStart, ObjEnd, 63);
    C3r := GetJSONIntInRange(Buf, 'c3r', ObjStart, ObjEnd, 40);
    C3g := GetJSONIntInRange(Buf, 'c3g', ObjStart, ObjEnd, 50);
    C3b := GetJSONIntInRange(Buf, 'c3b', ObjStart, ObjEnd, 60);
    BrickColor := GetJSONIntInRange(Buf, 'brickColor', ObjStart, ObjEnd, 0);
    WoodColor := GetJSONIntInRange(Buf, 'woodColor', ObjStart, ObjEnd, 0);
    XBlockColor := GetJSONIntInRange(Buf, 'xBlockColor', ObjStart, ObjEnd, 0);
    BuildWall := GetJSONIntInRange(Buf, 'buildWall', ObjStart, ObjEnd, 1) <> 0;
    InitX := GetJSONIntInRange(Buf, 'startX', ObjStart, ObjEnd, 2);
    InitY := GetJSONIntInRange(Buf, 'startY', ObjStart, ObjEnd, 10);
  end;

  XSz := GetJSONIntInRange(Buf, 'width', ObjStart, ObjEnd, 236);
  if (XSz < 1) or (XSz > MaxWorldSize) then XSz := 236;
  Options.XSize := XSz;

  FillChar(WorldMap^, SizeOf(WorldBuffer), ' ');
  DecodeTilesArrayInRange(Buf, Options.XSize, ObjStart, ObjEnd);
  DecodeHiddenRowInRange(Buf, Options.XSize, ObjStart, ObjEnd);
end;

function LoadJSONv2(const Buf: AnsiString): Boolean;
var
  P, ArrStart, ObjStart, ObjEnd: Integer;
  SLIdx: Integer;
  TabName, SLName, SLCreator, SLDesc: AnsiString;
begin
  Result := False;

  RestoreSpriteBackups;

  { Find the sublevels array }
  P := FindKey(Buf, 'sublevels', 1);
  if P = 0 then Exit;
  P := SkipWS(Buf, P);
  if (P > Length(Buf)) or (Buf[P] <> '[') then Exit;
  ArrStart := P;
  Inc(P);

  SLIdx := 0;
  while (P <= Length(Buf)) and (SLIdx < MAX_SUB_LEVELS) do
  begin
    P := SkipWS(Buf, P);
    if (P > Length(Buf)) or (Buf[P] = ']') then Break;

    { Expect start of object }
    if Buf[P] <> '{' then Break;
    ObjStart := P;
    ObjEnd := FindObjectEnd(Buf, ObjStart);
    if ObjEnd = 0 then Break;

    { Parse this sub-level }
    TabName := GetJSONStrInRange(Buf, 'name', ObjStart, ObjEnd, 'Sub-level ' + Chr(Ord('A') + SLIdx));
    SLName := GetJSONStrInRange(Buf, 'levelName', ObjStart, ObjEnd, '');
    SLCreator := GetJSONStrInRange(Buf, 'creator', ObjStart, ObjEnd, '');
    SLDesc := GetJSONStrInRange(Buf, 'description', ObjStart, ObjEnd, '');

    ParseSubLevelObject(Buf, ObjStart, ObjEnd);

    { Snapshot into sub-level buffer }
    AllocSubLevel(SLIdx);
    Move(WorldMap^, SubLevels[SLIdx]^.WorldSnap, SizeOf(WorldBuffer));
    SubLevels[SLIdx]^.Opts := Options;
    SubLevels[SLIdx]^.TabName := TabName;
    SubLevels[SLIdx]^.SLMetaName := SLName;
    SubLevels[SLIdx]^.SLMetaCreator := SLCreator;
    SubLevels[SLIdx]^.SLMetaDescription := SLDesc;
    SubLevels[SLIdx]^.SLMusicTrack := GetJSONStrInRange(Buf, 'musicTrack', ObjStart, ObjEnd, '');

    Inc(SLIdx);
    P := ObjEnd;

    { Skip comma between array elements }
    P := SkipWS(Buf, P);
    if (P <= Length(Buf)) and (Buf[P] = ',') then Inc(P);
  end;

  if SLIdx = 0 then Exit;  { No sub-levels found }

  NumSubLevels := SLIdx;
  ActiveSubLevel := 0;

  { Load first sub-level as active }
  LoadBufferToActive(0);

  { Set metadata from first sub-level or root level }
  MetaName := GetJSONStr(Buf, 'name', SubLevels[0]^.SLMetaName);
  MetaCreator := GetJSONStr(Buf, 'creator', SubLevels[0]^.SLMetaCreator);
  MetaDescription := GetJSONStr(Buf, 'description', SubLevels[0]^.SLMetaDescription);

  { Initialize rendering }
  ReinitRenderState;
  LevelLoaded := True;

  Result := True;
end;

var
  _InitIdx: Integer;
begin
  Initialized := False;
  LevelLoaded := False;
  LevelTexture := 0;
  AtlasTexture := 0;
  EnemyAtlasTexture := 0;
  PlayerSprTexture := 0;
  for _InitIdx := 0 to MAX_SUB_LEVELS - 1 do
    SubLevels[_InitIdx] := nil;
  NumSubLevels := 0;
  ActiveSubLevel := 0;
end.
