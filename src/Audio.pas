unit Audio;

  {  Consolidated audio unit for SDL2 port             }
  {  PC speaker emulation (square wave via SDL audio)   }
  {  Sound effect beep primitives                       }
  {  Music sequencer (note patterns for game events)    }
  {  Original (C) Copyright 1994-2001, Mike Wiering     }

  {$R-}

interface

  uses
    sdl2, ctypes;

  { ===== Audio State Variables ===== }

  const
    BeeperSound: Boolean = TRUE;
    BGMEnabled: Boolean = TRUE;

  var
    AudioFrequency: Integer;  { 0 = silence, >0 = freq in Hz }
    BeepAge: Integer;         { Sound effect frame counter:
                                0 = no active SFX beep,
                                1 = fresh beep (don't overwrite yet),
                                2+ = beep has been heard, can overwrite }
    SFXVolume: Integer;       { 0-10, user setting for PC speaker volume }
    BGMVolume: Integer;       { 0-10, user setting for BGM volume }
    SFXAmplitude: Integer;    { Computed from SFXVolume: 0..4000 }

  { ===== Beep Primitives ===== }

  procedure BeeperOn;
  procedure BeeperOff;
  procedure Beep (Freq: Word);
  procedure ApplySFXVolume;

  { ===== SDL Audio Device ===== }

  procedure InitAudio;
  procedure CloseAudio;

  { ===== Music Sequencer ===== }

  { Note constants for music sequences }
  const
    c0 = #01; d0 = #03; e0 = #05; f0 = #06; g0 = #08; a0 = #10; b0 = #12;
    c1 = #13; d1 = #15; e1 = #17; f1 = #18; g1 = #20; a1 = #22; b1 = #24;
    c2 = #25; d2 = #27; e2 = #29; f2 = #30; g2 = #32; a2 = #34; b2 = #36;
    c3 = #37; d3 = #39; e3 = #41; f3 = #42; g3 = #44; a3 = #46; b3 = #48;
    c4 = #49; d4 = #51; e4 = #53; f4 = #54; g4 = #56; a4 = #58; b4 = #60;
    c5 = #61; d5 = #63; e5 = #65; f5 = #66; g5 = #68; a5 = #70; b5 = #72;
    c6 = #73; d6 = #75; e6 = #77; f6 = #78; g6 = #80; a6 = #82; b6 = #84;

  { Pre-built music sequences for game events }
  const
    LifeMusic = #1+g4+#8+c5+#8+e5+#8+c5+#8+d5+#8+g5+#8+#0;
    GrowMusic = #1+c3+#4+ g3+#4+ c4+#4+
                 #38+#4+ #45+#4+ #50+#4+
                  d3+#4+ a3+#4+ d4+#4+#0;
    CoinMusic = #1+f5+#1+#0;
    PipeMusic = #1+c1+#0+c1+#8+c0+#0+c0+#16+
                   c1+#0+c1+#8+c0+#0+c0+#16+
                   c1+#0+c1+#8+c0+#0+c0+#16+#0;
    FireMusic = #1+e3+#1+a3+#1+#0;
    HitMusic = #1+c2+#2+c1+#3+c0+#4+c2+#1+c1+#2+c0+#3+#0;
    DeadMusic = #1+c2+#3+c1+#4+c0+#6+#0;
    NoteMusic = #1+c0+#3+c1+#2+c2+#1+#0;
    StarMusic = #1+c3+#4+ e3+#4+ g3+#4+
                   c4+#4+ e4+#4+ g4+#4+
                   c5+#4+ e5+#4+ g5+#4+ c6+#4 + #0;

  procedure StartMusic (S: String);
  procedure PlayMusic;
  procedure StopMusic;
  procedure PauseMusic;


implementation

  const
    HALF_NOTE = 1.059463094;  { HALF_NOTE ^ 12 = 2 }
    MAX_OCT = 7;
    SAMPLE_RATE = 44100;
    AUDIO_BUFFER_SIZE = 1024;
    SQUARE_WAVE_AMPLITUDE = 4000;

  var
    rTmp: Real;
    aiNote: array[1..MAX_OCT * 12] of Integer;
    i: Integer;
    sMusic: String;
    iPos: Integer;

    { SDL audio state }
    AudioDev: TSDL_AudioDeviceID;
    AudioOpened: Boolean;

    { Track the currently sustaining music note frequency.
      On the original PC speaker, Sound(freq) kept the speaker buzzing
      until NoSound was called.  PlayMusic only called Sound when a note
      started and NoSound between notes.  We must re-assert the frequency
      each frame while a note's duration is counting down. }
    MusicFreq: Integer;

  { Audio callback phase tracking }
  var
    SamplePhase: Double;

  { ===== SDL Audio Callback ===== }

  procedure AudioCallback(userdata: Pointer; stream: pcuint8; len: cint); cdecl;
  var
    Samples: PSmallInt;
    NumSamples: Integer;
    idx: Integer;
    Freq: Integer;
    Period: Double;
    Sample: SmallInt;
  begin
    Samples := PSmallInt(stream);
    NumSamples := len div 2;  { 16-bit samples = 2 bytes each }
    Freq := AudioFrequency;

    if Freq <= 0 then
    begin
      FillChar(stream^, len, #0);
      Exit;
    end;

    Period := SAMPLE_RATE / Freq;

    for idx := 0 to NumSamples - 1 do
    begin
      if SamplePhase < Period / 2.0 then
        Sample := SFXAmplitude
      else
        Sample := -SFXAmplitude;

      Samples[idx] := Sample;

      SamplePhase := SamplePhase + 1.0;
      if SamplePhase >= Period then
        SamplePhase := SamplePhase - Period;
    end;
  end;

  { ===== SDL Audio Device Management ===== }

  procedure InitAudio;
  var
    Desired, Obtained: TSDL_AudioSpec;
  begin
    if AudioOpened then Exit;

    FillChar(Desired, SizeOf(Desired), 0);
    Desired.freq := SAMPLE_RATE;
    Desired.format := AUDIO_S16SYS;
    Desired.channels := 1;
    Desired.samples := AUDIO_BUFFER_SIZE;
    Desired.callback := TSDL_AudioCallback(@AudioCallback);
    Desired.userdata := nil;

    AudioDev := SDL_OpenAudioDevice(nil, 0, @Desired, @Obtained, 0);
    if AudioDev > 1 then
    begin
      AudioOpened := True;
      SDL_PauseAudioDevice(AudioDev, 0);  { Start playback }
    end
    else
      AudioOpened := False;
  end;

  procedure CloseAudio;
  begin
    if AudioOpened then
    begin
      SDL_CloseAudioDevice(AudioDev);
      AudioOpened := False;
    end;
  end;

  { ===== Beep Primitives ===== }

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
        BeepAge := 1   { Mark as fresh -- PlayMusic won't overwrite until next frame }
      else
        BeepAge := 0;
    end
    else
    begin
      AudioFrequency := 0;
      BeepAge := 0;
    end;
  end;

  procedure ApplySFXVolume;
  begin
    SFXAmplitude := SFXVolume * 400;  { 0->0, 10->4000 }
  end;

  { ===== Music Sequencer ===== }

  procedure StartMusic (S: String);
  begin
    if not BeeperSound then Exit;
    sMusic := S;
    iPos := 1;
    MusicFreq := 0;
  end;

  procedure PlayMusic;
    var
      c: Char;
  begin
    if not BeeperSound then Exit;

    { If a sound effect Beep() was just called this frame (BeepAge=1),
      don't touch AudioFrequency -- let it survive one full frame so
      the SDL audio callback can pick it up and produce audible samples.
      Advance BeepAge so we can overwrite it next frame. }
    if BeepAge = 1 then
    begin
      BeepAge := 2;
      { Still advance the music sequence timing so it stays in sync }
      if (iPos > 0) and (iPos <= Length(sMusic)) then
      begin
        c := sMusic[iPos];
        if c > #1 then
          sMusic[iPos] := Pred(c)
        else
        begin
          Inc(iPos);
          if (iPos <= Length(sMusic)) then
          begin
            c := sMusic[iPos];
            if c > #0 then
              MusicFreq := aiNote[Ord(c)]
            else
              MusicFreq := 0;
          end;
          Inc(iPos);
        end;
      end;
      Exit;  { Keep the beep frequency playing }
    end;

    BeepAge := 0;
    AudioFrequency := 0;

    if (iPos = 0) or (iPos > Length(sMusic)) then
      Exit;
    c := sMusic[iPos];
    if c > #1 then
    begin
      { Duration counting down -- keep the current note sounding.
        On the real PC speaker the note was still buzzing from the
        original Sound() call; we must re-assert it each frame. }
      sMusic[iPos] := Pred(c);
      AudioFrequency := MusicFreq;
    end
    else
    begin
      { Duration expired (reached #1) -- advance to next note }
      Inc(iPos);
      c := sMusic[iPos];
      if c > #0 then
      begin
        MusicFreq := aiNote[Ord(c)];
        Beep(MusicFreq);
        BeepAge := 0;  { Music notes don't need SFX protection }
      end
      else
        MusicFreq := 0;  { end of music }
      Inc(iPos);
    end;
  end;

  procedure StopMusic;
  begin
    AudioFrequency := 0;
    MusicFreq := 0;
    BeepAge := 0;
    sMusic := '';
    iPos := 0;
  end;

  procedure PauseMusic;
  begin
    AudioFrequency := 0;
  end;

  { ===== Unit Initialization ===== }

begin
  { Initialize note frequency table }
  rTmp := HALF_NOTE * 55;
  for i := 1 to MAX_OCT * 12 do
  begin
    aiNote[i] := Round(rTmp);
    rTmp := rTmp * HALF_NOTE;
  end;
  sMusic := '';
  iPos := 0;
  MusicFreq := 0;
  BeepAge := 0;
  SamplePhase := 0;
  AudioOpened := False;
  AudioDev := 0;
  SFXVolume := 10;
  BGMVolume := 10;
  ApplySFXVolume;
end.
