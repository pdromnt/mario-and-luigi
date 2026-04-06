unit Music;

  {  Thin wrapper -- all audio code now lives in Audio.pas  }
  {  This unit re-exports symbols for backward compatibility }

interface

  uses
    Audio;

  { Re-export note constants so callers that "uses Music" still compile.
    These are identical to the ones in Audio. }
  const
    c0 = Audio.c0; d0 = Audio.d0; e0 = Audio.e0; f0 = Audio.f0;
    g0 = Audio.g0; a0 = Audio.a0; b0 = Audio.b0;
    c1 = Audio.c1; d1 = Audio.d1; e1 = Audio.e1; f1 = Audio.f1;
    g1 = Audio.g1; a1 = Audio.a1; b1 = Audio.b1;
    c2 = Audio.c2; d2 = Audio.d2; e2 = Audio.e2; f2 = Audio.f2;
    g2 = Audio.g2; a2 = Audio.a2; b2 = Audio.b2;
    c3 = Audio.c3; d3 = Audio.d3; e3 = Audio.e3; f3 = Audio.f3;
    g3 = Audio.g3; a3 = Audio.a3; b3 = Audio.b3;
    c4 = Audio.c4; d4 = Audio.d4; e4 = Audio.e4; f4 = Audio.f4;
    g4 = Audio.g4; a4 = Audio.a4; b4 = Audio.b4;
    c5 = Audio.c5; d5 = Audio.d5; e5 = Audio.e5; f5 = Audio.f5;
    g5 = Audio.g5; a5 = Audio.a5; b5 = Audio.b5;
    c6 = Audio.c6; d6 = Audio.d6; e6 = Audio.e6; f6 = Audio.f6;
    g6 = Audio.g6; a6 = Audio.a6; b6 = Audio.b6;

  { Re-export music sequences }
  const
    LifeMusic = Audio.LifeMusic;
    GrowMusic = Audio.GrowMusic;
    CoinMusic = Audio.CoinMusic;
    PipeMusic = Audio.PipeMusic;
    FireMusic = Audio.FireMusic;
    HitMusic  = Audio.HitMusic;
    DeadMusic = Audio.DeadMusic;
    NoteMusic = Audio.NoteMusic;
    StarMusic = Audio.StarMusic;

  { Re-export procedures as thin wrappers }
  procedure StartMusic (S: String);
  procedure PlayMusic;
  procedure StopMusic;
  procedure PauseMusic;
  procedure InitAudio;
  procedure CloseAudio;

implementation

  procedure StartMusic (S: String);
  begin
    Audio.StartMusic(S);
  end;

  procedure PlayMusic;
  begin
    Audio.PlayMusic;
  end;

  procedure StopMusic;
  begin
    Audio.StopMusic;
  end;

  procedure PauseMusic;
  begin
    Audio.PauseMusic;
  end;

  procedure InitAudio;
  begin
    Audio.InitAudio;
  end;

  procedure CloseAudio;
  begin
    Audio.CloseAudio;
  end;

end.
