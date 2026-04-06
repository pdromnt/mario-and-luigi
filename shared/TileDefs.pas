unit TileDefs;

{ Tile character code definitions, collision sets, and sprite layout constants.
  Shared between game and editor. No rendering logic. }

{$mode objfpc}{$H+}
{$R-}

interface

const
  { Standard sprite tile dimensions (pixels) }
  TILE_W = 20;
  TILE_H = 14;
  W = TILE_W;  { Short alias used throughout game code }
  H = TILE_H;

  { Map dimensions }
  NV = 13;               { Vertical tiles per level column }
  NH = 16;               { Horizontal tiles visible on screen }
  MaxWorldSize = 236;    { Maximum level width in tiles }

  { WorldBuffer padding (for collision detection) }
  EX  = 1;               { Extra columns left/right }
  EY1 = 8;               { Extra rows above }
  EY2 = 3;               { Extra rows below }

  { Player constants }
  plPlayer1 = 0;
  plPlayer2 = 1;
  dirLeft  = 0;
  dirRight = 1;
  mdSmall = 0;
  mdLarge = 1;
  mdFire  = 2;

  { --- Colored variant tile code ranges --- }

  { Wall style base codes (9 variants each: TL, Top, TR, Left, Body, Right, BL, Bottom, BR) }
  CWALL_GREEN  = 91;     { #91..#99 }
  CWALL_SAND   = 100;    { #100..#108 }
  CWALL_BROWN  = 109;    { #109..#117 }
  CWALL_GRASS  = 118;    { #118..#126 }
  CWALL_DESERT = 139;    { #139..#147 }
  WALL_VARIANTS = 9;

  WALL_STYLE_BASES: array[0..4] of Byte = (
    CWALL_GREEN, CWALL_SAND, CWALL_BROWN, CWALL_GRASS, CWALL_DESERT
  );

  { Colored pipes: 6 colors x 4 shapes = 24 codes }
  CPIPE_BASE   = 178;    { #178..#201 }
  PIPE_SHAPES  = 4;
  PIPE_COLOR_COUNT = 6;

  { Colored bricks: 4 colors }
  CBRICK_BASE  = 202;    { #202..#205 }

  { Colored xblocks: 4 colors }
  CXBLOCK_BASE = 206;    { #206..#209 }

  { Colored wood: 3 colors }
  CWOOD_BASE   = 210;    { #210..#212 }

  { Colored breakable blocks: 4 colors }
  CBREAK_BASE  = 213;    { #213..#216 }

  { Design-independent deco tiles }
  CDECO_TREE_HASH = 148;
  CDECO_TREE_PCT  = 149;
  CDECO_WIN_HASH  = 150;
  CDECO_WIN_PCT   = 151;
  CDECO_LAVA_HASH = 152;
  CDECO_LAVA_PCT  = 153;
  CDECO_SMTREE    = 154;

  { Recolor palette offsets }
  PIPE_COLORS:   array[0..5] of Byte = ($18, $30, $50, $70, $80, $B0);
  BRICK_COLORS:  array[0..3] of Byte = ($18, $30, $48, $B0);
  XBLOCK_COLORS: array[0..3] of Byte = ($30, $68, $A0, $B0);
  WOOD_COLORS:   array[0..2] of Byte = ($18, $30, $48);

  { Collision sets — which tile chars are solid }
  CanHoldYou  = [#0..#13, '0'..'Z', #91..#126, #139..#147, #178..#216];
  CanStandOn  = [#14..#16, 'a'..'f'];
  Hidden      = ['$'];

  { Enemy tile codes (placed in map data) }
  ENEMY_CHIBIBO       = $80;  { Goomba }
  ENEMY_FISH          = $81;  { Vertical fish }
  ENEMY_FIREBALL      = $82;  { Fireball }
  ENEMY_RED_CHIBIBO   = $83;  { Red goomba }
  ENEMY_GREEN_PIRANHA = $84;  { Green piranha }
  ENEMY_GREEN_PIRANHA2= $85;
  ENEMY_RED_PIRANHA   = $86;  { Red piranha }
  ENEMY_SPINY         = $87;  { Spiny (red) }
  ENEMY_GREEN_KOOPA   = $88;  { Green koopa }
  ENEMY_RED_KOOPA     = $89;  { Red koopa }
  ENEMY_FAST_KOOPA    = $8A;  { Fast green koopa }
  ENEMY_BLOCK_LIFT    = $B0;  { Moving block platform }
  ENEMY_DONUT         = $B1;  { Falling platform }

implementation

end.
