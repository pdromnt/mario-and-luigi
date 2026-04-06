unit Worlds;

{  World/level data - loads levels from JSON asset files at runtime  }
{  Original (C) Copyright 1994-2001, Mike Wiering  }

interface

  uses
    Buffers, LevelFormat, AssetPaths;

  const
    NUM_WORLDS = 6;

  type
    WorldEntry = record
      LevelA:    TLevelData;
      OptA:      WorldOptions;   { turbo mode options for level A }
      LevelB:    TLevelData;
    end;

  var
    WorldList: array[0..NUM_WORLDS - 1] of WorldEntry;
    IntroLevel: TLevelData;
    GameManifest: TManifest;

  procedure InitWorlds;
  procedure LoadWorld (N: Integer);

  { PlayWorldByIndex: convenience wrapper that calls Play.PlayWorld with
    the correct level data from WorldList. N is 0-based world index. }
  function PlayWorldByIndex(N1, N2: Char; WorldIdx: Integer; Player: Byte): Boolean;

implementation

  uses
    SysUtils, Play;

  procedure InitWorlds;
  var
    i: Integer;
    LevDir: string;
  begin
    LevDir := LevelPath('');

    { Load manifest }
    if not LoadManifest(ManifestPath, GameManifest) then
    begin
      WriteLn('ERROR: Could not load manifest.json from ', ManifestPath);
      Halt(1);
    end;

    { Load intro level }
    if not LoadLevelJSON(LevDir + GameManifest.IntroFile, IntroLevel) then
    begin
      WriteLn('ERROR: Could not load intro level');
      Halt(1);
    end;

    { Load all world levels }
    for i := 0 to High(GameManifest.Worlds) do
    begin
      if i >= NUM_WORLDS then Break;

      if not LoadLevelJSON(LevDir + GameManifest.Worlds[i].LevelAFile, WorldList[i].LevelA) then
      begin
        WriteLn('ERROR: Could not load ', GameManifest.Worlds[i].LevelAFile);
        Halt(1);
      end;

      if not LoadLevelJSON(LevDir + GameManifest.Worlds[i].LevelBFile, WorldList[i].LevelB) then
      begin
        WriteLn('ERROR: Could not load ', GameManifest.Worlds[i].LevelBFile);
        Halt(1);
      end;

      { Compute turbo options for level A: start with normal options, apply overrides }
      WorldList[i].OptA := WorldList[i].LevelA.Options;
      if Length(GameManifest.Worlds[i].TurboOverrides) > 0 then
        ApplyTurboOverrides(WorldList[i].OptA, GameManifest.Worlds[i].TurboOverrides);
    end;
  end;

  procedure LoadWorld (N: Integer);
  { Load world N (0..NUM_WORLDS-1) into the active world buffers.
    Loads sub-level B first, swaps, then loads sub-level A so that
    A is the active world and B is the saved/swap world.
    Uses the normal (non-turbo) options. }
  var
    Idx: Integer;
  begin
    Idx := N mod NUM_WORLDS;

    { Load sub-level B into WorldMap }
    ReadWorld(WorldList[Idx].LevelB.Map, WorldMap, WorldList[Idx].LevelB.Options);

    { Swap B into SaveWorldMap }
    Swap;

    { Load sub-level A into WorldMap (now active) }
    ReadWorld(WorldList[Idx].LevelA.Map, WorldMap, WorldList[Idx].LevelA.Options);
  end;

  function PlayWorldByIndex(N1, N2: Char; WorldIdx: Integer; Player: Byte): Boolean;
  var
    Idx: Integer;
  begin
    Idx := WorldIdx mod NUM_WORLDS;
    PlayWorldByIndex := Play.PlayWorld(N1, N2,
      WorldList[Idx].LevelA.Map, WorldList[Idx].LevelA.Options, WorldList[Idx].OptA,
      WorldList[Idx].LevelB.Map, WorldList[Idx].LevelB.Options, WorldList[Idx].LevelB.Options,
      Player);
  end;

end.
