unit HiScore;

{ Hi-score table management: read/write, insertion, default scores.
  Extracted from GAME.PAS. }

{$A+} {$B-} {$G+} {$I-} {$R-} {$S+} {$V-} {$X+}

interface

  const
    HI_SCORE_COUNT = 5;

  type
    {$A2}
    HiScoreEntry = record
      Initials: array[1..3] of Char;  { 3-letter arcade initials }
      Score: LongInt;                   { Player score }
    end;  { 8 bytes per entry with padding }

    HiScoreTable = record
      Entries: array[1..HI_SCORE_COUNT] of HiScoreEntry;
    end;  { 40 bytes total }
    {$A+}

  var
    HiScores: HiScoreTable;

  function GetHiScoreName: string;
  procedure SetInitials(var E: HiScoreEntry; C1, C2, C3: Char);
  procedure InitDefaultHiScores;
  procedure ReadHiScores;
  procedure WriteHiScores;
  function IsHiScore(Score: LongInt): Boolean;
  procedure InsertHiScore(var Entry: HiScoreEntry);

implementation

  uses
    Config;

  function GetHiScoreName: string;
  begin
    GetHiScoreName := GetUserDataDir + 'GAME.HIS';
  end;

  procedure SetInitials(var E: HiScoreEntry; C1, C2, C3: Char);
  begin
    E.Initials[1] := C1;
    E.Initials[2] := C2;
    E.Initials[3] := C3;
  end;

  procedure InitDefaultHiScores;
  begin
    with HiScores do
    begin
      SetInitials(Entries[1], 'M', '&', 'L');  Entries[1].Score := 5000;
      SetInitials(Entries[2], 'M', 'A', 'R');  Entries[2].Score := 4000;
      SetInitials(Entries[3], 'L', 'U', 'I');  Entries[3].Score := 3000;
      SetInitials(Entries[4], 'M', 'I', 'K');  Entries[4].Score := 2000;
      SetInitials(Entries[5], 'A', 'A', 'A');  Entries[5].Score := 1000;
    end;
  end;

  procedure ReadHiScores;
  var
    UF: File;
    ReadBytes: LongInt;
  begin
    IOResult;
    Assign(UF, GetHiScoreName);
    Reset(UF, 1);
    if IOResult = 0 then
    begin
      BlockRead(UF, HiScores, SizeOf(HiScoreTable), ReadBytes);
      Close(UF);
      IOResult;
      if ReadBytes = SizeOf(HiScoreTable) then
        Exit;
    end;
    InitDefaultHiScores;
  end;

  procedure WriteHiScores;
  var
    UF: File;
  begin
    IOResult;
    Assign(UF, GetHiScoreName);
    ReWrite(UF, 1);
    if IOResult = 0 then
    begin
      BlockWrite(UF, HiScores, SizeOf(HiScoreTable));
      Close(UF);
      IOResult;
    end;
  end;

  function IsHiScore(Score: LongInt): Boolean;
  begin
    IsHiScore := (Score > 0) and
      (Score > HiScores.Entries[HI_SCORE_COUNT].Score);
  end;

  procedure InsertHiScore(var Entry: HiScoreEntry);
  var
    i, Pos: Integer;
  begin
    Pos := HI_SCORE_COUNT + 1;
    for i := HI_SCORE_COUNT downto 1 do
      if Entry.Score > HiScores.Entries[i].Score then
        Pos := i;
    if Pos > HI_SCORE_COUNT then Exit;
    for i := HI_SCORE_COUNT downto Pos + 1 do
      HiScores.Entries[i] := HiScores.Entries[i - 1];
    HiScores.Entries[Pos] := Entry;
  end;

end.
