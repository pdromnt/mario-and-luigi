unit Worlds;

{  SDL2 port of world/level data  }
{  Original (C) Copyright 1994-2001, Mike Wiering  }
{  Data extracted from assembler db/dw blocks into typed constants  }

interface

  uses
    Buffers;

  { Include the auto-generated typed constant arrays from worlds.inc }
  {$I data\worlds.inc}

  { Number of worlds (levels) in the game }
  const
    NUM_WORLDS = 6;

  type
    PByteArray = ^TByteArray;
    TByteArray = array[0..65534] of Byte;

    WorldEntry = record
      LevelA:   PByteArray;
      OptionsA: PByteArray;
      OptA:     PByteArray;   { alternate options (turbo mode) }
      LevelB:   PByteArray;
      OptionsB: PByteArray;
    end;

  var
    WorldList: array[0..NUM_WORLDS - 1] of WorldEntry;

    { Intro data pointers (for title screen) }
    IntroLevel:   PByteArray;
    IntroOptions: PByteArray;

  procedure InitWorlds;
  procedure LoadWorld (N: Integer);

implementation

  procedure InitWorlds;
  begin
    { Intro / title screen }
    IntroLevel   := @Intro_0_Data;
    IntroOptions := @Options_0_Data;

    { World 1 (displayed as level "1") }
    WorldList[0].LevelA   := @Level_1a_Data;
    WorldList[0].OptionsA := @Options_1a_Data;
    WorldList[0].OptA     := @Opt_1a_Data;
    WorldList[0].LevelB   := @Level_1b_Data;
    WorldList[0].OptionsB := @Options_1b_Data;

    { World 2 (displayed as level "2") }
    WorldList[1].LevelA   := @Level_2a_Data;
    WorldList[1].OptionsA := @Options_2a_Data;
    WorldList[1].OptA     := @Opt_2a_Data;
    WorldList[1].LevelB   := @Level_2b_Data;
    WorldList[1].OptionsB := @Options_2b_Data;

    { World 3 (displayed as level "3") }
    WorldList[2].LevelA   := @Level_3a_Data;
    WorldList[2].OptionsA := @Options_3a_Data;
    WorldList[2].OptA     := @Opt_3a_Data;
    WorldList[2].LevelB   := @Level_3b_Data;
    WorldList[2].OptionsB := @Options_3b_Data;

    { World 4 (displayed as level "4") - originally Level_5x in source }
    WorldList[3].LevelA   := @Level_5a_Data;
    WorldList[3].OptionsA := @Options_5a_Data;
    WorldList[3].OptA     := @Opt_5a_Data;
    WorldList[3].LevelB   := @Level_5b_Data;
    WorldList[3].OptionsB := @Options_5b_Data;

    { World 5 (displayed as level "5") - originally Level_6x in source }
    WorldList[4].LevelA   := @Level_6a_Data;
    WorldList[4].OptionsA := @Options_6a_Data;
    WorldList[4].OptA     := @Opt_6a_Data;
    WorldList[4].LevelB   := @Level_6b_Data;
    WorldList[4].OptionsB := @Options_6b_Data;

    { World 6 (displayed as level "6") - originally Level_4x in source }
    WorldList[5].LevelA   := @Level_4a_Data;
    WorldList[5].OptionsA := @Options_4a_Data;
    WorldList[5].OptA     := @Opt_4a_Data;
    WorldList[5].LevelB   := @Level_4b_Data;
    WorldList[5].OptionsB := @Options_4b_Data;
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
    ReadWorld(WorldList[Idx].LevelB^, WorldMap, WorldList[Idx].OptionsB^);

    { Swap B into SaveWorldMap }
    Swap;

    { Load sub-level A into WorldMap (now active) }
    ReadWorld(WorldList[Idx].LevelA^, WorldMap, WorldList[Idx].OptionsA^);
  end;

end.
