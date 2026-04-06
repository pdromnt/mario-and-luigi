program ExportAssets;

{$mode objfpc}{$H+}

{ Standalone converter: exports all compiled-in game data to individual asset files.
  No game unit dependencies - includes .inc files directly.
  Run once, then delete. }

uses
  SysUtils, Classes;

const
  NV = 13;  { Vertical tiles per level }
  MaxWorldSize = 236;

{ =====================================================================
  SPRITE DATA INCLUDES
  ===================================================================== }

{ Tiles (from Figures.PAS) }
{$I ..\sprites\GREEN000.inc} {$I ..\sprites\GREEN001.inc} {$I ..\sprites\GREEN002.inc}
{$I ..\sprites\GREEN003.inc} {$I ..\sprites\GREEN004.inc}
{$I ..\sprites\GROUND000.inc} {$I ..\sprites\GROUND001.inc} {$I ..\sprites\GROUND002.inc}
{$I ..\sprites\GROUND003.inc} {$I ..\sprites\GROUND004.inc}
{$I ..\sprites\SAND000.inc} {$I ..\sprites\SAND001.inc} {$I ..\sprites\SAND002.inc}
{$I ..\sprites\SAND003.inc} {$I ..\sprites\SAND004.inc}
{$I ..\sprites\BROWN000.inc} {$I ..\sprites\BROWN001.inc} {$I ..\sprites\BROWN002.inc}
{$I ..\sprites\BROWN003.inc} {$I ..\sprites\BROWN004.inc}
{$I ..\sprites\GRASS000.inc} {$I ..\sprites\GRASS001.inc} {$I ..\sprites\GRASS002.inc}
{$I ..\sprites\GRASS003.inc} {$I ..\sprites\GRASS004.inc}
{$I ..\sprites\DES000.inc} {$I ..\sprites\DES001.inc} {$I ..\sprites\DES002.inc}
{$I ..\sprites\DES003.inc} {$I ..\sprites\DES004.inc}
{$I ..\sprites\GRASS1000.inc} {$I ..\sprites\GRASS2000.inc} {$I ..\sprites\GRASS3000.inc}
{$I ..\sprites\GRASS1001.inc} {$I ..\sprites\GRASS2001.inc} {$I ..\sprites\GRASS3001.inc}
{$I ..\sprites\GRASS1002.inc} {$I ..\sprites\GRASS2002.inc} {$I ..\sprites\GRASS3002.inc}
{$I ..\sprites\PIPE000.inc} {$I ..\sprites\PIPE001.inc} {$I ..\sprites\PIPE002.inc} {$I ..\sprites\PIPE003.inc}
{$I ..\sprites\BLOCK000.inc} {$I ..\sprites\BLOCK001.inc}
{$I ..\sprites\QUEST000.inc} {$I ..\sprites\QUEST001.inc}
{$I ..\sprites\WPALM000.inc}
{$I ..\sprites\PALM0000.inc} {$I ..\sprites\PALM1000.inc} {$I ..\sprites\PALM2000.inc} {$I ..\sprites\PALM3000.inc}
{$I ..\sprites\PALM0001.inc} {$I ..\sprites\PALM1001.inc} {$I ..\sprites\PALM2001.inc} {$I ..\sprites\PALM3001.inc}
{$I ..\sprites\PALM0002.inc} {$I ..\sprites\PALM1002.inc} {$I ..\sprites\PALM2002.inc} {$I ..\sprites\PALM3002.inc}
{$I ..\sprites\FENCE000.inc} {$I ..\sprites\FENCE001.inc}
{$I ..\sprites\PIN000.inc}
{$I ..\sprites\FALL000.inc} {$I ..\sprites\FALL001.inc}
{$I ..\sprites\LAVA000.inc} {$I ..\sprites\LAVA001.inc}
{$I ..\sprites\LAVA2001.inc} {$I ..\sprites\LAVA2002.inc} {$I ..\sprites\LAVA2003.inc}
{$I ..\sprites\LAVA2004.inc} {$I ..\sprites\LAVA2005.inc}
{$I ..\sprites\TREE000.inc} {$I ..\sprites\TREE001.inc} {$I ..\sprites\TREE002.inc} {$I ..\sprites\TREE003.inc}
{$I ..\sprites\BRICK0000.inc} {$I ..\sprites\BRICK0001.inc} {$I ..\sprites\BRICK0002.inc}
{$I ..\sprites\BRICK1000.inc} {$I ..\sprites\BRICK1001.inc} {$I ..\sprites\BRICK1002.inc}
{$I ..\sprites\BRICK2000.inc} {$I ..\sprites\BRICK2001.inc} {$I ..\sprites\BRICK2002.inc}
{$I ..\sprites\EXIT000.inc} {$I ..\sprites\EXIT001.inc}
{$I ..\sprites\WOOD000.inc}
{$I ..\sprites\COIN000.inc}
{$I ..\sprites\NOTE000.inc}
{$I ..\sprites\WINDOW000.inc} {$I ..\sprites\WINDOW001.inc}
{$I ..\sprites\SMTREE000.inc} {$I ..\sprites\SMTREE001.inc}
{$I ..\sprites\XBLOCK000.inc}

{ Enemies (from Enemies.PAS) }
{$I ..\sprites\CHIBIBO000.inc} {$I ..\sprites\CHIBIBO001.inc}
{$I ..\sprites\CHIBIBO002.inc} {$I ..\sprites\CHIBIBO003.inc}
{$I ..\sprites\CHAMP000.inc}
{$I ..\sprites\POISON000.inc}
{$I ..\sprites\LIFE000.inc}
{$I ..\sprites\FLOWER000.inc}
{$I ..\sprites\STAR000.inc}
{$I ..\sprites\FISH001.inc}
{$I ..\sprites\PPLANT000.inc} {$I ..\sprites\PPLANT001.inc}
{$I ..\sprites\PPLANT002.inc} {$I ..\sprites\PPLANT003.inc}
{$I ..\sprites\RED000.inc} {$I ..\sprites\RED001.inc}
{$I ..\sprites\F000.inc} {$I ..\sprites\F001.inc} {$I ..\sprites\F002.inc} {$I ..\sprites\F003.inc}
{$I ..\sprites\HIT000.inc}
{$I ..\sprites\GRKOOPA000.inc} {$I ..\sprites\GRKOOPA001.inc}
{$I ..\sprites\RDKOOPA000.inc} {$I ..\sprites\RDKOOPA001.inc}
{$I ..\sprites\GRKP000.inc} {$I ..\sprites\GRKP001.inc}
{$I ..\sprites\RDKP000.inc} {$I ..\sprites\RDKP001.inc}
{$I ..\sprites\LIFT1000.inc}
{$I ..\sprites\DONUT000.inc} {$I ..\sprites\DONUT001.inc}
{$I ..\sprites\FIRE000.inc} {$I ..\sprites\FIRE001.inc}

{ Players (from Players.PAS) }
{$I ..\sprites\SWMAR000.inc} {$I ..\sprites\SWMAR001.inc}
{$I ..\sprites\SJMAR000.inc} {$I ..\sprites\SJMAR001.inc}
{$I ..\sprites\LWMAR000.inc} {$I ..\sprites\LWMAR001.inc}
{$I ..\sprites\LJMAR000.inc} {$I ..\sprites\LJMAR001.inc}
{$I ..\sprites\FWMAR000.inc} {$I ..\sprites\FWMAR001.inc}
{$I ..\sprites\FJMAR000.inc} {$I ..\sprites\FJMAR001.inc}
{$I ..\sprites\SWLUI000.inc} {$I ..\sprites\SWLUI001.inc}
{$I ..\sprites\SJLUI000.inc} {$I ..\sprites\SJLUI001.inc}
{$I ..\sprites\LWLUI000.inc} {$I ..\sprites\LWLUI001.inc}
{$I ..\sprites\LJLUI000.inc} {$I ..\sprites\LJLUI001.inc}
{$I ..\sprites\FWLUI000.inc} {$I ..\sprites\FWLUI001.inc}
{$I ..\sprites\FJLUI000.inc} {$I ..\sprites\FJLUI001.inc}

{ Title screen / misc (from Mario.PAS, TmpObj.PAS) }
{$I ..\sprites\INTRO000.inc} {$I ..\sprites\INTRO001.inc} {$I ..\sprites\INTRO002.inc}
{$I ..\sprites\START000.inc} {$I ..\sprites\START001.inc}
{$I ..\sprites\PART000.inc}
{$I ..\sprites\WHFIRE000.inc}
{$I ..\sprites\WHHIT000.inc}

{ Extra sprites found in directory but not yet included above }
{$I ..\sprites\FISH000.inc}
{$I ..\sprites\LAVA2000.inc}

{ =====================================================================
  PALETTE / BACKGROUND / FONT DATA INCLUDES
  ===================================================================== }

{$I ..\data\mpal256.inc}
{$I ..\data\palbrick.inc}
{$I ..\data\palpill.inc}
{$I ..\data\backgrounds.inc}
{$I ..\data\font.inc}
{$I ..\data\font8x8.inc}

{ =====================================================================
  LEVEL DATA INCLUDES
  ===================================================================== }

{$I ..\data\worlds.inc}

{ =====================================================================
  HELPER: Write a sprite to a .sprite binary file
  Format: [Word LE: Width] [Word LE: Height] [W*H bytes: pixel data]
  ===================================================================== }

procedure WriteSprite(const FilePath: string; W, H: Word; const Data; DataSize: Integer);
var
  F: TFileStream;
begin
  ForceDirectories(ExtractFileDir(FilePath));
  F := TFileStream.Create(FilePath, fmCreate);
  try
    F.WriteWord(W);
    F.WriteWord(H);
    F.WriteBuffer(Data, DataSize);
  finally
    F.Free;
  end;
end;

{ =====================================================================
  HELPER: Write raw binary data to a file
  ===================================================================== }

procedure WriteRawFile(const FilePath: string; const Data; DataSize: Integer);
var
  F: TFileStream;
begin
  ForceDirectories(ExtractFileDir(FilePath));
  F := TFileStream.Create(FilePath, fmCreate);
  try
    F.WriteBuffer(Data, DataSize);
  finally
    F.Free;
  end;
end;

{ =====================================================================
  EXPORT SPRITES
  ===================================================================== }

procedure ExportSprites;
var
  Base: string;
  Count: Integer;
begin
  Base := '..' + DirectorySeparator + 'assets' + DirectorySeparator + 'sprites' + DirectorySeparator;
  Count := 0;

  { --- Walls --- }
  WriteSprite(Base+'walls/green000.sprite', Green000_W, Green000_H, Green000, SizeOf(Green000)); Inc(Count);
  WriteSprite(Base+'walls/green001.sprite', Green001_W, Green001_H, Green001, SizeOf(Green001)); Inc(Count);
  WriteSprite(Base+'walls/green002.sprite', Green002_W, Green002_H, Green002, SizeOf(Green002)); Inc(Count);
  WriteSprite(Base+'walls/green003.sprite', Green003_W, Green003_H, Green003, SizeOf(Green003)); Inc(Count);
  WriteSprite(Base+'walls/green004.sprite', Green004_W, Green004_H, Green004, SizeOf(Green004)); Inc(Count);

  WriteSprite(Base+'walls/ground000.sprite', Ground000_W, Ground000_H, Ground000, SizeOf(Ground000)); Inc(Count);
  WriteSprite(Base+'walls/ground001.sprite', Ground001_W, Ground001_H, Ground001, SizeOf(Ground001)); Inc(Count);
  WriteSprite(Base+'walls/ground002.sprite', Ground002_W, Ground002_H, Ground002, SizeOf(Ground002)); Inc(Count);
  WriteSprite(Base+'walls/ground003.sprite', Ground003_W, Ground003_H, Ground003, SizeOf(Ground003)); Inc(Count);
  WriteSprite(Base+'walls/ground004.sprite', Ground004_W, Ground004_H, Ground004, SizeOf(Ground004)); Inc(Count);

  WriteSprite(Base+'walls/sand000.sprite', Sand000_W, Sand000_H, Sand000, SizeOf(Sand000)); Inc(Count);
  WriteSprite(Base+'walls/sand001.sprite', Sand001_W, Sand001_H, Sand001, SizeOf(Sand001)); Inc(Count);
  WriteSprite(Base+'walls/sand002.sprite', Sand002_W, Sand002_H, Sand002, SizeOf(Sand002)); Inc(Count);
  WriteSprite(Base+'walls/sand003.sprite', Sand003_W, Sand003_H, Sand003, SizeOf(Sand003)); Inc(Count);
  WriteSprite(Base+'walls/sand004.sprite', Sand004_W, Sand004_H, Sand004, SizeOf(Sand004)); Inc(Count);

  WriteSprite(Base+'walls/brown000.sprite', Brown000_W, Brown000_H, Brown000, SizeOf(Brown000)); Inc(Count);
  WriteSprite(Base+'walls/brown001.sprite', Brown001_W, Brown001_H, Brown001, SizeOf(Brown001)); Inc(Count);
  WriteSprite(Base+'walls/brown002.sprite', Brown002_W, Brown002_H, Brown002, SizeOf(Brown002)); Inc(Count);
  WriteSprite(Base+'walls/brown003.sprite', Brown003_W, Brown003_H, Brown003, SizeOf(Brown003)); Inc(Count);
  WriteSprite(Base+'walls/brown004.sprite', Brown004_W, Brown004_H, Brown004, SizeOf(Brown004)); Inc(Count);

  WriteSprite(Base+'walls/grass000.sprite', Grass000_W, Grass000_H, Grass000, SizeOf(Grass000)); Inc(Count);
  WriteSprite(Base+'walls/grass001.sprite', Grass001_W, Grass001_H, Grass001, SizeOf(Grass001)); Inc(Count);
  WriteSprite(Base+'walls/grass002.sprite', Grass002_W, Grass002_H, Grass002, SizeOf(Grass002)); Inc(Count);
  WriteSprite(Base+'walls/grass003.sprite', Grass003_W, Grass003_H, Grass003, SizeOf(Grass003)); Inc(Count);
  WriteSprite(Base+'walls/grass004.sprite', Grass004_W, Grass004_H, Grass004, SizeOf(Grass004)); Inc(Count);

  WriteSprite(Base+'walls/des000.sprite', Des000_W, Des000_H, Des000, SizeOf(Des000)); Inc(Count);
  WriteSprite(Base+'walls/des001.sprite', Des001_W, Des001_H, Des001, SizeOf(Des001)); Inc(Count);
  WriteSprite(Base+'walls/des002.sprite', Des002_W, Des002_H, Des002, SizeOf(Des002)); Inc(Count);
  WriteSprite(Base+'walls/des003.sprite', Des003_W, Des003_H, Des003, SizeOf(Des003)); Inc(Count);
  WriteSprite(Base+'walls/des004.sprite', Des004_W, Des004_H, Des004, SizeOf(Des004)); Inc(Count);

  WriteSprite(Base+'walls/grass1000.sprite', Grass1000_W, Grass1000_H, Grass1000, SizeOf(Grass1000)); Inc(Count);
  WriteSprite(Base+'walls/grass2000.sprite', Grass2000_W, Grass2000_H, Grass2000, SizeOf(Grass2000)); Inc(Count);
  WriteSprite(Base+'walls/grass3000.sprite', Grass3000_W, Grass3000_H, Grass3000, SizeOf(Grass3000)); Inc(Count);
  WriteSprite(Base+'walls/grass1001.sprite', Grass1001_W, Grass1001_H, Grass1001, SizeOf(Grass1001)); Inc(Count);
  WriteSprite(Base+'walls/grass2001.sprite', Grass2001_W, Grass2001_H, Grass2001, SizeOf(Grass2001)); Inc(Count);
  WriteSprite(Base+'walls/grass3001.sprite', Grass3001_W, Grass3001_H, Grass3001, SizeOf(Grass3001)); Inc(Count);
  WriteSprite(Base+'walls/grass1002.sprite', Grass1002_W, Grass1002_H, Grass1002, SizeOf(Grass1002)); Inc(Count);
  WriteSprite(Base+'walls/grass2002.sprite', Grass2002_W, Grass2002_H, Grass2002, SizeOf(Grass2002)); Inc(Count);
  WriteSprite(Base+'walls/grass3002.sprite', Grass3002_W, Grass3002_H, Grass3002, SizeOf(Grass3002)); Inc(Count);

  { --- Tiles --- }
  WriteSprite(Base+'tiles/pipe000.sprite', Pipe000_W, Pipe000_H, Pipe000, SizeOf(Pipe000)); Inc(Count);
  WriteSprite(Base+'tiles/pipe001.sprite', Pipe001_W, Pipe001_H, Pipe001, SizeOf(Pipe001)); Inc(Count);
  WriteSprite(Base+'tiles/pipe002.sprite', Pipe002_W, Pipe002_H, Pipe002, SizeOf(Pipe002)); Inc(Count);
  WriteSprite(Base+'tiles/pipe003.sprite', Pipe003_W, Pipe003_H, Pipe003, SizeOf(Pipe003)); Inc(Count);

  WriteSprite(Base+'tiles/block000.sprite', Block000_W, Block000_H, Block000, SizeOf(Block000)); Inc(Count);
  WriteSprite(Base+'tiles/block001.sprite', Block001_W, Block001_H, Block001, SizeOf(Block001)); Inc(Count);

  WriteSprite(Base+'tiles/quest000.sprite', Quest000_W, Quest000_H, Quest000, SizeOf(Quest000)); Inc(Count);
  WriteSprite(Base+'tiles/quest001.sprite', Quest001_W, Quest001_H, Quest001, SizeOf(Quest001)); Inc(Count);

  WriteSprite(Base+'tiles/coin000.sprite', Coin000_W, Coin000_H, Coin000, SizeOf(Coin000)); Inc(Count);
  WriteSprite(Base+'tiles/note000.sprite', Note000_W, Note000_H, Note000, SizeOf(Note000)); Inc(Count);
  WriteSprite(Base+'tiles/wood000.sprite', Wood000_W, Wood000_H, Wood000, SizeOf(Wood000)); Inc(Count);
  WriteSprite(Base+'tiles/xblock000.sprite', Xblock000_W, Xblock000_H, Xblock000, SizeOf(Xblock000)); Inc(Count);
  WriteSprite(Base+'tiles/pin000.sprite', Pin000_W, Pin000_H, Pin000, SizeOf(Pin000)); Inc(Count);
  WriteSprite(Base+'tiles/exit000.sprite', Exit000_W, Exit000_H, Exit000, SizeOf(Exit000)); Inc(Count);
  WriteSprite(Base+'tiles/exit001.sprite', Exit001_W, Exit001_H, Exit001, SizeOf(Exit001)); Inc(Count);
  WriteSprite(Base+'tiles/lift1000.sprite', Lift1000_W, Lift1000_H, Lift1000, SizeOf(Lift1000)); Inc(Count);
  WriteSprite(Base+'tiles/donut000.sprite', Donut000_W, Donut000_H, Donut000, SizeOf(Donut000)); Inc(Count);
  WriteSprite(Base+'tiles/donut001.sprite', Donut001_W, Donut001_H, Donut001, SizeOf(Donut001)); Inc(Count);

  WriteSprite(Base+'tiles/brick0000.sprite', Brick0000_W, Brick0000_H, Brick0000, SizeOf(Brick0000)); Inc(Count);
  WriteSprite(Base+'tiles/brick0001.sprite', Brick0001_W, Brick0001_H, Brick0001, SizeOf(Brick0001)); Inc(Count);
  WriteSprite(Base+'tiles/brick0002.sprite', Brick0002_W, Brick0002_H, Brick0002, SizeOf(Brick0002)); Inc(Count);
  WriteSprite(Base+'tiles/brick1000.sprite', Brick1000_W, Brick1000_H, Brick1000, SizeOf(Brick1000)); Inc(Count);
  WriteSprite(Base+'tiles/brick1001.sprite', Brick1001_W, Brick1001_H, Brick1001, SizeOf(Brick1001)); Inc(Count);
  WriteSprite(Base+'tiles/brick1002.sprite', Brick1002_W, Brick1002_H, Brick1002, SizeOf(Brick1002)); Inc(Count);
  WriteSprite(Base+'tiles/brick2000.sprite', Brick2000_W, Brick2000_H, Brick2000, SizeOf(Brick2000)); Inc(Count);
  WriteSprite(Base+'tiles/brick2001.sprite', Brick2001_W, Brick2001_H, Brick2001, SizeOf(Brick2001)); Inc(Count);
  WriteSprite(Base+'tiles/brick2002.sprite', Brick2002_W, Brick2002_H, Brick2002, SizeOf(Brick2002)); Inc(Count);

  { --- Decorations --- }
  WriteSprite(Base+'decorations/fence000.sprite', Fence000_W, Fence000_H, Fence000, SizeOf(Fence000)); Inc(Count);
  WriteSprite(Base+'decorations/fence001.sprite', Fence001_W, Fence001_H, Fence001, SizeOf(Fence001)); Inc(Count);
  WriteSprite(Base+'decorations/fall000.sprite', Fall000_W, Fall000_H, Fall000, SizeOf(Fall000)); Inc(Count);
  WriteSprite(Base+'decorations/fall001.sprite', Fall001_W, Fall001_H, Fall001, SizeOf(Fall001)); Inc(Count);
  WriteSprite(Base+'decorations/lava000.sprite', Lava000_W, Lava000_H, Lava000, SizeOf(Lava000)); Inc(Count);
  WriteSprite(Base+'decorations/lava001.sprite', Lava001_W, Lava001_H, Lava001, SizeOf(Lava001)); Inc(Count);
  WriteSprite(Base+'decorations/lava2000.sprite', Lava2000_W, Lava2000_H, Lava2000, SizeOf(Lava2000)); Inc(Count);
  WriteSprite(Base+'decorations/lava2001.sprite', Lava2001_W, Lava2001_H, Lava2001, SizeOf(Lava2001)); Inc(Count);
  WriteSprite(Base+'decorations/lava2002.sprite', Lava2002_W, Lava2002_H, Lava2002, SizeOf(Lava2002)); Inc(Count);
  WriteSprite(Base+'decorations/lava2003.sprite', Lava2003_W, Lava2003_H, Lava2003, SizeOf(Lava2003)); Inc(Count);
  WriteSprite(Base+'decorations/lava2004.sprite', Lava2004_W, Lava2004_H, Lava2004, SizeOf(Lava2004)); Inc(Count);
  WriteSprite(Base+'decorations/lava2005.sprite', Lava2005_W, Lava2005_H, Lava2005, SizeOf(Lava2005)); Inc(Count);
  WriteSprite(Base+'decorations/tree000.sprite', Tree000_W, Tree000_H, Tree000, SizeOf(Tree000)); Inc(Count);
  WriteSprite(Base+'decorations/tree001.sprite', Tree001_W, Tree001_H, Tree001, SizeOf(Tree001)); Inc(Count);
  WriteSprite(Base+'decorations/tree002.sprite', Tree002_W, Tree002_H, Tree002, SizeOf(Tree002)); Inc(Count);
  WriteSprite(Base+'decorations/tree003.sprite', Tree003_W, Tree003_H, Tree003, SizeOf(Tree003)); Inc(Count);
  WriteSprite(Base+'decorations/window000.sprite', Window000_W, Window000_H, Window000, SizeOf(Window000)); Inc(Count);
  WriteSprite(Base+'decorations/window001.sprite', Window001_W, Window001_H, Window001, SizeOf(Window001)); Inc(Count);
  WriteSprite(Base+'decorations/smtree000.sprite', Smtree000_W, Smtree000_H, Smtree000, SizeOf(Smtree000)); Inc(Count);
  WriteSprite(Base+'decorations/smtree001.sprite', Smtree001_W, Smtree001_H, Smtree001, SizeOf(Smtree001)); Inc(Count);
  WriteSprite(Base+'decorations/wpalm000.sprite', Wpalm000_W, Wpalm000_H, Wpalm000, SizeOf(Wpalm000)); Inc(Count);
  WriteSprite(Base+'decorations/palm0000.sprite', Palm0000_W, Palm0000_H, Palm0000, SizeOf(Palm0000)); Inc(Count);
  WriteSprite(Base+'decorations/palm1000.sprite', Palm1000_W, Palm1000_H, Palm1000, SizeOf(Palm1000)); Inc(Count);
  WriteSprite(Base+'decorations/palm2000.sprite', Palm2000_W, Palm2000_H, Palm2000, SizeOf(Palm2000)); Inc(Count);
  WriteSprite(Base+'decorations/palm3000.sprite', Palm3000_W, Palm3000_H, Palm3000, SizeOf(Palm3000)); Inc(Count);
  WriteSprite(Base+'decorations/palm0001.sprite', Palm0001_W, Palm0001_H, Palm0001, SizeOf(Palm0001)); Inc(Count);
  WriteSprite(Base+'decorations/palm1001.sprite', Palm1001_W, Palm1001_H, Palm1001, SizeOf(Palm1001)); Inc(Count);
  WriteSprite(Base+'decorations/palm2001.sprite', Palm2001_W, Palm2001_H, Palm2001, SizeOf(Palm2001)); Inc(Count);
  WriteSprite(Base+'decorations/palm3001.sprite', Palm3001_W, Palm3001_H, Palm3001, SizeOf(Palm3001)); Inc(Count);
  WriteSprite(Base+'decorations/palm0002.sprite', Palm0002_W, Palm0002_H, Palm0002, SizeOf(Palm0002)); Inc(Count);
  WriteSprite(Base+'decorations/palm1002.sprite', Palm1002_W, Palm1002_H, Palm1002, SizeOf(Palm1002)); Inc(Count);
  WriteSprite(Base+'decorations/palm2002.sprite', Palm2002_W, Palm2002_H, Palm2002, SizeOf(Palm2002)); Inc(Count);
  WriteSprite(Base+'decorations/palm3002.sprite', Palm3002_W, Palm3002_H, Palm3002, SizeOf(Palm3002)); Inc(Count);

  { --- Enemies --- }
  WriteSprite(Base+'enemies/chibibo000.sprite', Chibibo000_W, Chibibo000_H, Chibibo000, SizeOf(Chibibo000)); Inc(Count);
  WriteSprite(Base+'enemies/chibibo001.sprite', Chibibo001_W, Chibibo001_H, Chibibo001, SizeOf(Chibibo001)); Inc(Count);
  WriteSprite(Base+'enemies/chibibo002.sprite', Chibibo002_W, Chibibo002_H, Chibibo002, SizeOf(Chibibo002)); Inc(Count);
  WriteSprite(Base+'enemies/chibibo003.sprite', Chibibo003_W, Chibibo003_H, Chibibo003, SizeOf(Chibibo003)); Inc(Count);
  WriteSprite(Base+'enemies/champ000.sprite', Champ000_W, Champ000_H, Champ000, SizeOf(Champ000)); Inc(Count);
  WriteSprite(Base+'enemies/poison000.sprite', Poison000_W, Poison000_H, Poison000, SizeOf(Poison000)); Inc(Count);
  WriteSprite(Base+'enemies/life000.sprite', Life000_W, Life000_H, Life000, SizeOf(Life000)); Inc(Count);
  WriteSprite(Base+'enemies/flower000.sprite', Flower000_W, Flower000_H, Flower000, SizeOf(Flower000)); Inc(Count);
  WriteSprite(Base+'enemies/star000.sprite', Star000_W, Star000_H, Star000, SizeOf(Star000)); Inc(Count);
  WriteSprite(Base+'enemies/fish000.sprite', Fish000_W, Fish000_H, Fish000, SizeOf(Fish000)); Inc(Count);
  WriteSprite(Base+'enemies/fish001.sprite', Fish001_W, Fish001_H, Fish001, SizeOf(Fish001)); Inc(Count);
  WriteSprite(Base+'enemies/pplant000.sprite', Pplant000_W, Pplant000_H, Pplant000, SizeOf(Pplant000)); Inc(Count);
  WriteSprite(Base+'enemies/pplant001.sprite', Pplant001_W, Pplant001_H, Pplant001, SizeOf(Pplant001)); Inc(Count);
  WriteSprite(Base+'enemies/pplant002.sprite', Pplant002_W, Pplant002_H, Pplant002, SizeOf(Pplant002)); Inc(Count);
  WriteSprite(Base+'enemies/pplant003.sprite', Pplant003_W, Pplant003_H, Pplant003, SizeOf(Pplant003)); Inc(Count);
  WriteSprite(Base+'enemies/red000.sprite', Red000_W, Red000_H, Red000, SizeOf(Red000)); Inc(Count);
  WriteSprite(Base+'enemies/red001.sprite', Red001_W, Red001_H, Red001, SizeOf(Red001)); Inc(Count);
  WriteSprite(Base+'enemies/f000.sprite', F000_W, F000_H, F000, SizeOf(F000)); Inc(Count);
  WriteSprite(Base+'enemies/f001.sprite', F001_W, F001_H, F001, SizeOf(F001)); Inc(Count);
  WriteSprite(Base+'enemies/f002.sprite', F002_W, F002_H, F002, SizeOf(F002)); Inc(Count);
  WriteSprite(Base+'enemies/f003.sprite', F003_W, F003_H, F003, SizeOf(F003)); Inc(Count);
  WriteSprite(Base+'enemies/hit000.sprite', Hit000_W, Hit000_H, Hit000, SizeOf(Hit000)); Inc(Count);
  WriteSprite(Base+'enemies/grkoopa000.sprite', Grkoopa000_W, Grkoopa000_H, Grkoopa000, SizeOf(Grkoopa000)); Inc(Count);
  WriteSprite(Base+'enemies/grkoopa001.sprite', Grkoopa001_W, Grkoopa001_H, Grkoopa001, SizeOf(Grkoopa001)); Inc(Count);
  WriteSprite(Base+'enemies/rdkoopa000.sprite', Rdkoopa000_W, Rdkoopa000_H, Rdkoopa000, SizeOf(Rdkoopa000)); Inc(Count);
  WriteSprite(Base+'enemies/rdkoopa001.sprite', Rdkoopa001_W, Rdkoopa001_H, Rdkoopa001, SizeOf(Rdkoopa001)); Inc(Count);
  WriteSprite(Base+'enemies/grkp000.sprite', Grkp000_W, Grkp000_H, Grkp000, SizeOf(Grkp000)); Inc(Count);
  WriteSprite(Base+'enemies/grkp001.sprite', Grkp001_W, Grkp001_H, Grkp001, SizeOf(Grkp001)); Inc(Count);
  WriteSprite(Base+'enemies/rdkp000.sprite', Rdkp000_W, Rdkp000_H, Rdkp000, SizeOf(Rdkp000)); Inc(Count);
  WriteSprite(Base+'enemies/rdkp001.sprite', Rdkp001_W, Rdkp001_H, Rdkp001, SizeOf(Rdkp001)); Inc(Count);
  WriteSprite(Base+'enemies/fire000.sprite', Fire000_W, Fire000_H, Fire000, SizeOf(Fire000)); Inc(Count);
  WriteSprite(Base+'enemies/fire001.sprite', Fire001_W, Fire001_H, Fire001, SizeOf(Fire001)); Inc(Count);

  { --- Players --- }
  WriteSprite(Base+'players/swmar000.sprite', Swmar000_W, Swmar000_H, Swmar000, SizeOf(Swmar000)); Inc(Count);
  WriteSprite(Base+'players/swmar001.sprite', Swmar001_W, Swmar001_H, Swmar001, SizeOf(Swmar001)); Inc(Count);
  WriteSprite(Base+'players/sjmar000.sprite', Sjmar000_W, Sjmar000_H, Sjmar000, SizeOf(Sjmar000)); Inc(Count);
  WriteSprite(Base+'players/sjmar001.sprite', Sjmar001_W, Sjmar001_H, Sjmar001, SizeOf(Sjmar001)); Inc(Count);
  WriteSprite(Base+'players/lwmar000.sprite', Lwmar000_W, Lwmar000_H, Lwmar000, SizeOf(Lwmar000)); Inc(Count);
  WriteSprite(Base+'players/lwmar001.sprite', Lwmar001_W, Lwmar001_H, Lwmar001, SizeOf(Lwmar001)); Inc(Count);
  WriteSprite(Base+'players/ljmar000.sprite', Ljmar000_W, Ljmar000_H, Ljmar000, SizeOf(Ljmar000)); Inc(Count);
  WriteSprite(Base+'players/ljmar001.sprite', Ljmar001_W, Ljmar001_H, Ljmar001, SizeOf(Ljmar001)); Inc(Count);
  WriteSprite(Base+'players/fwmar000.sprite', Fwmar000_W, Fwmar000_H, Fwmar000, SizeOf(Fwmar000)); Inc(Count);
  WriteSprite(Base+'players/fwmar001.sprite', Fwmar001_W, Fwmar001_H, Fwmar001, SizeOf(Fwmar001)); Inc(Count);
  WriteSprite(Base+'players/fjmar000.sprite', Fjmar000_W, Fjmar000_H, Fjmar000, SizeOf(Fjmar000)); Inc(Count);
  WriteSprite(Base+'players/fjmar001.sprite', Fjmar001_W, Fjmar001_H, Fjmar001, SizeOf(Fjmar001)); Inc(Count);

  WriteSprite(Base+'players/swlui000.sprite', Swlui000_W, Swlui000_H, Swlui000, SizeOf(Swlui000)); Inc(Count);
  WriteSprite(Base+'players/swlui001.sprite', Swlui001_W, Swlui001_H, Swlui001, SizeOf(Swlui001)); Inc(Count);
  WriteSprite(Base+'players/sjlui000.sprite', Sjlui000_W, Sjlui000_H, Sjlui000, SizeOf(Sjlui000)); Inc(Count);
  WriteSprite(Base+'players/sjlui001.sprite', Sjlui001_W, Sjlui001_H, Sjlui001, SizeOf(Sjlui001)); Inc(Count);
  WriteSprite(Base+'players/lwlui000.sprite', Lwlui000_W, Lwlui000_H, Lwlui000, SizeOf(Lwlui000)); Inc(Count);
  WriteSprite(Base+'players/lwlui001.sprite', Lwlui001_W, Lwlui001_H, Lwlui001, SizeOf(Lwlui001)); Inc(Count);
  WriteSprite(Base+'players/ljlui000.sprite', Ljlui000_W, Ljlui000_H, Ljlui000, SizeOf(Ljlui000)); Inc(Count);
  WriteSprite(Base+'players/ljlui001.sprite', Ljlui001_W, Ljlui001_H, Ljlui001, SizeOf(Ljlui001)); Inc(Count);
  WriteSprite(Base+'players/fwlui000.sprite', Fwlui000_W, Fwlui000_H, Fwlui000, SizeOf(Fwlui000)); Inc(Count);
  WriteSprite(Base+'players/fwlui001.sprite', Fwlui001_W, Fwlui001_H, Fwlui001, SizeOf(Fwlui001)); Inc(Count);
  WriteSprite(Base+'players/fjlui000.sprite', Fjlui000_W, Fjlui000_H, Fjlui000, SizeOf(Fjlui000)); Inc(Count);
  WriteSprite(Base+'players/fjlui001.sprite', Fjlui001_W, Fjlui001_H, Fjlui001, SizeOf(Fjlui001)); Inc(Count);

  { --- Effects / Title --- }
  WriteSprite(Base+'effects/part000.sprite', Part000_W, Part000_H, Part000, SizeOf(Part000)); Inc(Count);
  WriteSprite(Base+'effects/whfire000.sprite', Whfire000_W, Whfire000_H, Whfire000, SizeOf(Whfire000)); Inc(Count);
  WriteSprite(Base+'effects/whhit000.sprite', Whhit000_W, Whhit000_H, Whhit000, SizeOf(Whhit000)); Inc(Count);
  WriteSprite(Base+'effects/intro000.sprite', Intro000_W, Intro000_H, Intro000, SizeOf(Intro000)); Inc(Count);
  WriteSprite(Base+'effects/intro001.sprite', Intro001_W, Intro001_H, Intro001, SizeOf(Intro001)); Inc(Count);
  WriteSprite(Base+'effects/intro002.sprite', Intro002_W, Intro002_H, Intro002, SizeOf(Intro002)); Inc(Count);
  WriteSprite(Base+'effects/start000.sprite', Start000_W, Start000_H, Start000, SizeOf(Start000)); Inc(Count);
  WriteSprite(Base+'effects/start001.sprite', Start001_W, Start001_H, Start001, SizeOf(Start001)); Inc(Count);

  WriteLn('Exported ', Count, ' sprites.');
end;

{ =====================================================================
  EXPORT PALETTES
  ===================================================================== }

procedure ExportPalettes;
var
  Base: string;
begin
  Base := '..' + DirectorySeparator + 'assets' + DirectorySeparator + 'palettes' + DirectorySeparator;
  WriteRawFile(Base + 'main.pal', Pal256Data, SizeOf(Pal256Data));
  WriteRawFile(Base + 'brick.pal', Palbrick000Data, SizeOf(Palbrick000Data));
  WriteRawFile(Base + 'pill_0.pal', Palpill000Data, SizeOf(Palpill000Data));
  WriteRawFile(Base + 'pill_1.pal', Palpill001Data, SizeOf(Palpill001Data));
  WriteRawFile(Base + 'pill_2.pal', Palpill002Data, SizeOf(Palpill002Data));
  WriteLn('Exported 5 palette files.');
end;

{ =====================================================================
  EXPORT BACKGROUNDS
  ===================================================================== }

procedure ExportBackgrounds;
var
  Base: string;
begin
  Base := '..' + DirectorySeparator + 'assets' + DirectorySeparator + 'backgrounds' + DirectorySeparator;
  WriteRawFile(Base + 'bogen.bg', BogenData, SizeOf(BogenData));
  WriteRawFile(Base + 'bogen7.bg', Bogen7Data, SizeOf(Bogen7Data));
  WriteRawFile(Base + 'bogen26.bg', Bogen26Data, SizeOf(Bogen26Data));
  WriteRawFile(Base + 'mount.bg', MountData, SizeOf(MountData));
  WriteLn('Exported 4 background files.');
end;

{ =====================================================================
  EXPORT FONTS
  ===================================================================== }

procedure ExportFonts;
var
  Base: string;
begin
  Base := '..' + DirectorySeparator + 'assets' + DirectorySeparator + 'fonts' + DirectorySeparator;
  WriteRawFile(Base + 'swiss.font', SwissFontData, SizeOf(SwissFontData));
  WriteRawFile(Base + 'font8x8.font', Font8x8Data, SizeOf(Font8x8Data));
  WriteLn('Exported 2 font files.');
end;

{ =====================================================================
  LEVEL EXPORT HELPERS
  ===================================================================== }

type
  PByteArr = ^TByteArr;
  TByteArr = array[0..65534] of Byte;

function EncodeTileChar(Ch: Char): string;
var
  B: Byte;
begin
  B := Ord(Ch);
  if (B >= 32) and (B <= 126) and (Ch <> '$') and (Ch <> '\') and (Ch <> '"') then
  begin
    if Ch = '\' then
      Result := '\\'
    else if Ch = '"' then
      Result := '\"'
    else
      Result := Ch;
  end
  else
    Result := '$' + IntToHex(B, 2);
end;

procedure ExportOneLevel(const FilePath, LevelName: string;
  LevelData: PByteArr; LevelSize: Integer;
  OptData: PByteArr);
var
  SL: TStringList;
  XSize, Col, Row: Integer;
  RowStr: string;
  InitX, InitY: Word;
begin
  { Determine level width: each column is NV bytes, terminated by first byte = 0 }
  XSize := 0;
  while (XSize * NV < LevelSize) and (XSize < MaxWorldSize) do
  begin
    if LevelData^[XSize * NV] = 0 then
      Break;
    Inc(XSize);
  end;

  { Parse options from the 27-byte array }
  InitX := LevelData^[0]; { Wait - options are separate }
  InitX := PWord(@OptData^[0])^;
  InitY := PWord(@OptData^[2])^;

  SL := TStringList.Create;
  try
    SL.Add('{');
    SL.Add('  "version": 3,');
    SL.Add('  "name": "' + LevelName + '",');
    SL.Add('  "creator": "",');
    SL.Add('  "description": "",');
    SL.Add('  "musicTrack": "",');
    SL.Add('  "options": {');
    SL.Add('    "startX": ' + IntToStr(InitX) + ',');
    SL.Add('    "startY": ' + IntToStr(InitY) + ',');
    SL.Add('    "skyType": ' + IntToStr(OptData^[4]) + ',');
    SL.Add('    "wallType1": ' + IntToStr(OptData^[5]) + ',');
    SL.Add('    "wallType2": ' + IntToStr(OptData^[6]) + ',');
    SL.Add('    "wallType3": ' + IntToStr(OptData^[7]) + ',');
    SL.Add('    "pipeColor": ' + IntToStr(OptData^[8]) + ',');
    SL.Add('    "groundColor1": ' + IntToStr(OptData^[9]) + ',');
    SL.Add('    "groundColor2": ' + IntToStr(OptData^[10]) + ',');
    SL.Add('    "horizon": ' + IntToStr(OptData^[11]) + ',');
    SL.Add('    "backgrType": ' + IntToStr(OptData^[12]) + ',');
    SL.Add('    "backgrColor1": ' + IntToStr(OptData^[13]) + ',');
    SL.Add('    "backgrColor2": ' + IntToStr(OptData^[14]) + ',');
    SL.Add('    "stars": ' + IntToStr(OptData^[15]) + ',');
    SL.Add('    "clouds": ' + IntToStr(OptData^[16]) + ',');
    SL.Add('    "design": ' + IntToStr(OptData^[17]) + ',');
    SL.Add('    "c2r": ' + IntToStr(OptData^[18]) + ',');
    SL.Add('    "c2g": ' + IntToStr(OptData^[19]) + ',');
    SL.Add('    "c2b": ' + IntToStr(OptData^[20]) + ',');
    SL.Add('    "c3r": ' + IntToStr(OptData^[21]) + ',');
    SL.Add('    "c3g": ' + IntToStr(OptData^[22]) + ',');
    SL.Add('    "c3b": ' + IntToStr(OptData^[23]) + ',');
    SL.Add('    "brickColor": ' + IntToStr(OptData^[24]) + ',');
    SL.Add('    "woodColor": ' + IntToStr(OptData^[25]) + ',');
    SL.Add('    "xblockColor": ' + IntToStr(OptData^[26]));
    SL.Add('  },');
    SL.Add('  "width": ' + IntToStr(XSize) + ',');
    SL.Add('  "tiles": [');

    { Export rows: row 0 = top of level = map row index 0 (first byte of each column) }
    { Map layout: column-major, each column is NV bytes, row 0 = top (visually) }
    { ReadWorld flips: W^[X, NV-i] := M^[X+1, i], so map row 1 (index 0) = top }
    for Row := 0 to NV - 1 do
    begin
      RowStr := '    "';
      for Col := 0 to XSize - 1 do
        RowStr := RowStr + EncodeTileChar(Chr(LevelData^[Col * NV + Row]));
      if Row < NV - 1 then
        RowStr := RowStr + '",'
      else
        RowStr := RowStr + '"';
      SL.Add(RowStr);
    end;

    SL.Add('  ]');
    SL.Add('}');

    ForceDirectories(ExtractFileDir(FilePath));
    SL.SaveToFile(FilePath);
  finally
    SL.Free;
  end;
end;

{ =====================================================================
  EXPORT LEVELS + MANIFEST
  ===================================================================== }

procedure ExportLevels;
var
  Base: string;

  { Helper: returns the turbo options as a JSON fragment showing only fields
    that differ from the normal options. }
  function TurboOverrides(NormalOpt, TurboOpt: PByteArr): string;
  var
    Fields: TStringList;
    FieldNames: array[0..22] of string;
    i: Integer;
  begin
    FieldNames[0] := 'skyType';
    FieldNames[1] := 'wallType1';
    FieldNames[2] := 'wallType2';
    FieldNames[3] := 'wallType3';
    FieldNames[4] := 'pipeColor';
    FieldNames[5] := 'groundColor1';
    FieldNames[6] := 'groundColor2';
    FieldNames[7] := 'horizon';
    FieldNames[8] := 'backgrType';
    FieldNames[9] := 'backgrColor1';
    FieldNames[10] := 'backgrColor2';
    FieldNames[11] := 'stars';
    FieldNames[12] := 'clouds';
    FieldNames[13] := 'design';
    FieldNames[14] := 'c2r';
    FieldNames[15] := 'c2g';
    FieldNames[16] := 'c2b';
    FieldNames[17] := 'c3r';
    FieldNames[18] := 'c3g';
    FieldNames[19] := 'c3b';
    FieldNames[20] := 'brickColor';
    FieldNames[21] := 'woodColor';
    FieldNames[22] := 'xblockColor';

    Fields := TStringList.Create;
    try
      { Compare startX/startY (words at offset 0-3) }
      if PWord(@NormalOpt^[0])^ <> PWord(@TurboOpt^[0])^ then
        Fields.Add('"startX": ' + IntToStr(PWord(@TurboOpt^[0])^));
      if PWord(@NormalOpt^[2])^ <> PWord(@TurboOpt^[2])^ then
        Fields.Add('"startY": ' + IntToStr(PWord(@TurboOpt^[2])^));

      { Compare byte fields at offset 4..26 }
      for i := 0 to 22 do
        if NormalOpt^[4 + i] <> TurboOpt^[4 + i] then
          Fields.Add('"' + FieldNames[i] + '": ' + IntToStr(TurboOpt^[4 + i]));

      if Fields.Count = 0 then
        Result := '{}'
      else
      begin
        Result := '{ ';
        for i := 0 to Fields.Count - 1 do
        begin
          if i > 0 then Result := Result + ', ';
          Result := Result + Fields[i];
        end;
        Result := Result + ' }';
      end;
    finally
      Fields.Free;
    end;
  end;

type
  TWorldDef = record
    Name: string;
    LevelAName, LevelBName: string;
    LevelAData: PByteArr; LevelASize: Integer;
    OptionsAData: PByteArr;
    OptAData: PByteArr;
    LevelBData: PByteArr; LevelBSize: Integer;
    OptionsBData: PByteArr;
  end;

var
  Worlds: array[0..5] of TWorldDef;
  i: Integer;
  ManifestSL: TStringList;
  Turbo: string;

begin
  Base := '..' + DirectorySeparator + 'assets' + DirectorySeparator + 'levels' + DirectorySeparator;

  { Export intro level }
  ExportOneLevel(Base + 'intro.json', 'Intro',
    @Intro_0_Data, SizeOf(Intro_0_Data),
    @Options_0_Data);
  WriteLn('Exported intro level.');

  { Define worlds (matching WORLDS.PAS InitWorlds mapping) }
  Worlds[0].Name := 'World 1';
  Worlds[0].LevelAName := 'World 1-A'; Worlds[0].LevelBName := 'World 1-B';
  Worlds[0].LevelAData := @Level_1a_Data; Worlds[0].LevelASize := SizeOf(Level_1a_Data);
  Worlds[0].OptionsAData := @Options_1a_Data; Worlds[0].OptAData := @Opt_1a_Data;
  Worlds[0].LevelBData := @Level_1b_Data; Worlds[0].LevelBSize := SizeOf(Level_1b_Data);
  Worlds[0].OptionsBData := @Options_1b_Data;

  Worlds[1].Name := 'World 2';
  Worlds[1].LevelAName := 'World 2-A'; Worlds[1].LevelBName := 'World 2-B';
  Worlds[1].LevelAData := @Level_2a_Data; Worlds[1].LevelASize := SizeOf(Level_2a_Data);
  Worlds[1].OptionsAData := @Options_2a_Data; Worlds[1].OptAData := @Opt_2a_Data;
  Worlds[1].LevelBData := @Level_2b_Data; Worlds[1].LevelBSize := SizeOf(Level_2b_Data);
  Worlds[1].OptionsBData := @Options_2b_Data;

  Worlds[2].Name := 'World 3';
  Worlds[2].LevelAName := 'World 3-A'; Worlds[2].LevelBName := 'World 3-B';
  Worlds[2].LevelAData := @Level_3a_Data; Worlds[2].LevelASize := SizeOf(Level_3a_Data);
  Worlds[2].OptionsAData := @Options_3a_Data; Worlds[2].OptAData := @Opt_3a_Data;
  Worlds[2].LevelBData := @Level_3b_Data; Worlds[2].LevelBSize := SizeOf(Level_3b_Data);
  Worlds[2].OptionsBData := @Options_3b_Data;

  { World 4 uses Level_5x in source (originally level 5) }
  Worlds[3].Name := 'World 4';
  Worlds[3].LevelAName := 'World 4-A'; Worlds[3].LevelBName := 'World 4-B';
  Worlds[3].LevelAData := @Level_5a_Data; Worlds[3].LevelASize := SizeOf(Level_5a_Data);
  Worlds[3].OptionsAData := @Options_5a_Data; Worlds[3].OptAData := @Opt_5a_Data;
  Worlds[3].LevelBData := @Level_5b_Data; Worlds[3].LevelBSize := SizeOf(Level_5b_Data);
  Worlds[3].OptionsBData := @Options_5b_Data;

  { World 5 uses Level_6x in source (originally level 6) }
  Worlds[4].Name := 'World 5';
  Worlds[4].LevelAName := 'World 5-A'; Worlds[4].LevelBName := 'World 5-B';
  Worlds[4].LevelAData := @Level_6a_Data; Worlds[4].LevelASize := SizeOf(Level_6a_Data);
  Worlds[4].OptionsAData := @Options_6a_Data; Worlds[4].OptAData := @Opt_6a_Data;
  Worlds[4].LevelBData := @Level_6b_Data; Worlds[4].LevelBSize := SizeOf(Level_6b_Data);
  Worlds[4].OptionsBData := @Options_6b_Data;

  { World 6 uses Level_4x in source (originally level 4) }
  Worlds[5].Name := 'World 6';
  Worlds[5].LevelAName := 'World 6-A'; Worlds[5].LevelBName := 'World 6-B';
  Worlds[5].LevelAData := @Level_4a_Data; Worlds[5].LevelASize := SizeOf(Level_4a_Data);
  Worlds[5].OptionsAData := @Options_4a_Data; Worlds[5].OptAData := @Opt_4a_Data;
  Worlds[5].LevelBData := @Level_4b_Data; Worlds[5].LevelBSize := SizeOf(Level_4b_Data);
  Worlds[5].OptionsBData := @Options_4b_Data;

  { Export all world levels }
  for i := 0 to 5 do
  begin
    ExportOneLevel(Base + 'world' + IntToStr(i+1) + 'a.json',
      Worlds[i].LevelAName,
      Worlds[i].LevelAData, Worlds[i].LevelASize,
      Worlds[i].OptionsAData);

    ExportOneLevel(Base + 'world' + IntToStr(i+1) + 'b.json',
      Worlds[i].LevelBName,
      Worlds[i].LevelBData, Worlds[i].LevelBSize,
      Worlds[i].OptionsBData);
  end;
  WriteLn('Exported 12 world levels.');

  { Generate manifest.json }
  ManifestSL := TStringList.Create;
  try
    ManifestSL.Add('{');
    ManifestSL.Add('  "intro": "intro.json",');
    ManifestSL.Add('  "worlds": [');

    for i := 0 to 5 do
    begin
      Turbo := TurboOverrides(Worlds[i].OptionsAData, Worlds[i].OptAData);
      ManifestSL.Add('    {');
      ManifestSL.Add('      "name": "' + Worlds[i].Name + '",');
      ManifestSL.Add('      "levelA": "world' + IntToStr(i+1) + 'a.json",');
      ManifestSL.Add('      "levelB": "world' + IntToStr(i+1) + 'b.json",');
      ManifestSL.Add('      "turboOptions": ' + Turbo);
      if i < 5 then
        ManifestSL.Add('    },')
      else
        ManifestSL.Add('    }');
    end;

    ManifestSL.Add('  ]');
    ManifestSL.Add('}');
    ManifestSL.SaveToFile(Base + 'manifest.json');
  finally
    ManifestSL.Free;
  end;
  WriteLn('Exported manifest.json.');
end;

{ =====================================================================
  EXPORT SPRITE CATALOG
  ===================================================================== }

procedure ExportCatalog;
var
  SL: TStringList;
  Base: string;
begin
  Base := '..' + DirectorySeparator + 'assets' + DirectorySeparator + 'sprites' + DirectorySeparator;
  SL := TStringList.Create;
  try
    SL.Add('{');
    SL.Add('  "tiles": {');
    SL.Add('    "63":  { "file": "tiles/quest000.sprite", "name": "question_block" },');
    SL.Add('    "64":  { "file": "tiles/quest001.sprite", "name": "question_block_alt" },');
    SL.Add('    "73":  { "file": "tiles/block000.sprite", "name": "solid_block" },');
    SL.Add('    "74":  { "file": "tiles/block001.sprite", "name": "breakable_block" },');
    SL.Add('    "75":  { "file": "tiles/note000.sprite", "name": "note_block" },');
    SL.Add('    "88":  { "file": "tiles/xblock000.sprite", "name": "xblock" },');
    SL.Add('    "87":  { "file": "tiles/wood000.sprite", "name": "wood" },');
    SL.Add('    "42":  { "file": "tiles/coin000.sprite", "name": "coin" },');
    SL.Add('    "61":  { "file": "tiles/pin000.sprite", "name": "pin" },');
    SL.Add('    "48":  { "file": "tiles/pipe000.sprite", "name": "pipe_0" },');
    SL.Add('    "49":  { "file": "tiles/pipe001.sprite", "name": "pipe_1" },');
    SL.Add('    "50":  { "file": "tiles/pipe002.sprite", "name": "pipe_2" },');
    SL.Add('    "51":  { "file": "tiles/pipe003.sprite", "name": "pipe_3" },');
    SL.Add('    "70":  { "file": "decorations/fence000.sprite", "name": "fence" },');
    SL.Add('    "102": { "file": "decorations/fence001.sprite", "name": "fence_alt" },');
    SL.Add('    "83":  { "file": "decorations/smtree000.sprite", "name": "small_tree_top" },');
    SL.Add('    "115": { "file": "decorations/smtree001.sprite", "name": "small_tree_bottom" },');
    SL.Add('    "80":  { "file": "decorations/wpalm000.sprite", "name": "white_palm_trunk" },');
    SL.Add('    "97":  { "file": "decorations/fall000.sprite", "name": "waterfall_top" },');
    SL.Add('    "98":  { "file": "decorations/fall001.sprite", "name": "waterfall_bottom" },');
    SL.Add('    "84":  { "file": "decorations/tree000.sprite", "name": "tree_bottom" },');
    SL.Add('    "116": { "file": "decorations/tree001.sprite", "name": "tree_trunk" },');
    SL.Add('    "76":  { "file": "decorations/lava000.sprite", "name": "lava_safe" },');
    SL.Add('    "108": { "file": "decorations/lava001.sprite", "name": "lava_bottom" },');
    SL.Add('    "119": { "file": "decorations/window000.sprite", "name": "window_left" },');
    SL.Add('    "118": { "file": "decorations/window001.sprite", "name": "window_right" },');
    SL.Add('    "112": { "file": "decorations/palm0000.sprite", "name": "palm_center" },');
    SL.Add('    "113": { "file": "decorations/palm1000.sprite", "name": "palm_leaf_left" },');
    SL.Add('    "114": { "file": "decorations/palm2000.sprite", "name": "palm_leaf_top" },');
    SL.Add('    "117": { "file": "decorations/palm3000.sprite", "name": "palm_leaf_right" },');
    SL.Add('    "254": { "file": "tiles/exit000.sprite", "name": "exit_top" },');
    SL.Add('    "255": { "file": "tiles/exit001.sprite", "name": "exit_bottom" }');
    SL.Add('  },');

    SL.Add('  "enemies": {');
    SL.Add('    "128": { "file": "enemies/chibibo000.sprite", "w": 20, "h": 14, "name": "goomba" },');
    SL.Add('    "131": { "file": "enemies/chibibo002.sprite", "w": 20, "h": 14, "name": "red_goomba" },');
    SL.Add('    "129": { "file": "enemies/fish001.sprite", "w": 20, "h": 14, "name": "fish" },');
    SL.Add('    "130": { "file": "enemies/f000.sprite", "w": 20, "h": 14, "name": "fireball" },');
    SL.Add('    "132": { "file": "enemies/pplant002.sprite", "w": 24, "h": 20, "name": "green_piranha" },');
    SL.Add('    "133": { "file": "enemies/pplant002.sprite", "w": 24, "h": 20, "name": "green_piranha_alt" },');
    SL.Add('    "134": { "file": "enemies/pplant000.sprite", "w": 24, "h": 20, "name": "red_piranha" },');
    SL.Add('    "135": { "file": "enemies/red000.sprite", "w": 20, "h": 14, "name": "spiny" },');
    SL.Add('    "136": { "file": "enemies/grkoopa000.sprite", "w": 20, "h": 24, "name": "green_koopa" },');
    SL.Add('    "137": { "file": "enemies/rdkoopa000.sprite", "w": 20, "h": 24, "name": "red_koopa" },');
    SL.Add('    "138": { "file": "enemies/grkoopa000.sprite", "w": 20, "h": 24, "name": "fast_green_koopa" },');
    SL.Add('    "176": { "file": "tiles/lift1000.sprite", "w": 20, "h": 14, "name": "block_lift" },');
    SL.Add('    "177": { "file": "tiles/donut000.sprite", "w": 20, "h": 14, "name": "falling_platform" }');
    SL.Add('  },');

    SL.Add('  "walls": {');
    SL.Add('    "green":  { "files": ["walls/green000.sprite","walls/green001.sprite","walls/green002.sprite","walls/green003.sprite","walls/green004.sprite"] },');
    SL.Add('    "ground": { "files": ["walls/ground000.sprite","walls/ground001.sprite","walls/ground002.sprite","walls/ground003.sprite","walls/ground004.sprite"] },');
    SL.Add('    "sand":   { "files": ["walls/sand000.sprite","walls/sand001.sprite","walls/sand002.sprite","walls/sand003.sprite","walls/sand004.sprite"] },');
    SL.Add('    "brown":  { "files": ["walls/brown000.sprite","walls/brown001.sprite","walls/brown002.sprite","walls/brown003.sprite","walls/brown004.sprite"] },');
    SL.Add('    "grass":  { "files": ["walls/grass000.sprite","walls/grass001.sprite","walls/grass002.sprite","walls/grass003.sprite","walls/grass004.sprite"] },');
    SL.Add('    "desert": { "files": ["walls/des000.sprite","walls/des001.sprite","walls/des002.sprite","walls/des003.sprite","walls/des004.sprite"] }');
    SL.Add('  },');

    SL.Add('  "bricks": {');
    SL.Add('    "pattern0": ["tiles/brick0000.sprite","tiles/brick0001.sprite","tiles/brick0002.sprite"],');
    SL.Add('    "pattern1": ["tiles/brick1000.sprite","tiles/brick1001.sprite","tiles/brick1002.sprite"],');
    SL.Add('    "pattern2": ["tiles/brick2000.sprite","tiles/brick2001.sprite","tiles/brick2002.sprite"]');
    SL.Add('  },');

    SL.Add('  "colorVariants": {');
    SL.Add('    "pipeColors":   [24, 48, 80, 112, 128, 176],');
    SL.Add('    "brickColors":  [24, 48, 72, 176],');
    SL.Add('    "xblockColors": [48, 104, 160, 176],');
    SL.Add('    "woodColors":   [24, 48, 72],');
    SL.Add('    "wallCodeBases": {');
    SL.Add('      "green": 91, "sand": 100, "brown": 109, "grass": 118, "desert": 139');
    SL.Add('    },');
    SL.Add('    "pipeBase": 178,');
    SL.Add('    "brickBase": 202,');
    SL.Add('    "xblockBase": 206,');
    SL.Add('    "woodBase": 210,');
    SL.Add('    "breakBase": 213');
    SL.Add('  },');

    SL.Add('  "grassOverlays": {');
    SL.Add('    "variants": [');
    SL.Add('      ["walls/grass1000.sprite","walls/grass2000.sprite","walls/grass3000.sprite"],');
    SL.Add('      ["walls/grass1001.sprite","walls/grass2001.sprite","walls/grass3001.sprite"],');
    SL.Add('      ["walls/grass1002.sprite","walls/grass2002.sprite","walls/grass3002.sprite"]');
    SL.Add('    ]');
    SL.Add('  }');

    SL.Add('}');

    SL.SaveToFile(Base + 'catalog.json');
  finally
    SL.Free;
  end;
  WriteLn('Exported sprite catalog.');
end;

{ =====================================================================
  MAIN
  ===================================================================== }

begin
  WriteLn('Mario & Luigi Asset Exporter');
  WriteLn('============================');
  WriteLn;
  ExportSprites;
  ExportPalettes;
  ExportBackgrounds;
  ExportFonts;
  ExportLevels;
  ExportCatalog;
  WriteLn;
  WriteLn('Done! All assets exported to ../assets/');
end.
