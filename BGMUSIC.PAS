unit BGMusic;

  {  Background music playback via SDL2_mixer           }
  {  Coexists with PC speaker beeps in MUSIC.PAS        }
  {  Graceful failure: missing files = no music, no crash }

interface

  procedure InitBGMusic;
  procedure ShutdownBGMusic;

  procedure PlayMenuMusic;
  procedure PlayLevelMusic (LevelNum: Integer);
  procedure PlaySubLevelMusic;
  procedure PlayGameOverMusic;
  procedure StopBGMusic;
  procedure PauseBGMusic;
  procedure ResumeBGMusic;

  procedure PlayMusicByName (const filename: string);
  procedure ApplyBGMVolume;
  procedure ResetCurrentTrack;

implementation

  uses
    sdl2_mixer, Audio;

  const
    FADE_DURATION = 1000;  { milliseconds for fade in/out }

  var
    MixerReady: Boolean;
    CurrentMusic: PMix_Music;
    CurrentTrack: string[80];

  function GetMusicPath (filename: string): string;
  var
    dir: string;
    i: Integer;
  begin
    dir := ParamStr(0);
    { Strip executable name to get directory }
    i := Length(dir);
    while (i > 0) and (dir[i] <> '\') and (dir[i] <> '/') do
      Dec(i);
    if i > 0 then
      dir := Copy(dir, 1, i)
    else
      dir := '';
    GetMusicPath := dir + 'music/' + filename;
  end;

  procedure ApplyBGMVolume;
  var
    v128: Integer;
  begin
    if not MixerReady then Exit;
    v128 := Audio.BGMVolume * 13;  { 0->0, 10->130 }
    if v128 > 128 then v128 := 128;
    Mix_VolumeMusic(v128);
  end;

  procedure ResetCurrentTrack;
  begin
    CurrentTrack := '';
  end;

  procedure DoPlayTrack (filename: string; loops: Integer; fade: Boolean);
  var
    path: string;
    pathZ: array[0..255] of Char;
    mus: PMix_Music;
    i: Integer;
  begin
    if not MixerReady then Exit;

    { If BGM is disabled, don't play }
    if not Audio.BGMEnabled then Exit;

    { Already playing this track? Don't restart }
    if filename = CurrentTrack then Exit;

    { Stop and free current music if any }
    if CurrentMusic <> nil then
    begin
      if fade then
        Mix_FadeOutMusic(FADE_DURATION)
      else
        Mix_HaltMusic;
      Mix_FreeMusic(CurrentMusic);
      CurrentMusic := nil;
      CurrentTrack := '';
    end;

    { Load the new track }
    path := GetMusicPath(filename);
    { Convert ShortString to null-terminated for SDL }
    for i := 1 to Length(path) do
      pathZ[i - 1] := path[i];
    pathZ[Length(path)] := #0;
    mus := Mix_LoadMUS(@pathZ[0]);
    if mus = nil then Exit;  { File not found or error — silent fail }

    { Apply current volume before playing }
    ApplyBGMVolume;

    { Play with or without fade }
    if fade then
    begin
      if Mix_FadeInMusic(mus, loops, FADE_DURATION) < 0 then
      begin
        Mix_FreeMusic(mus);
        Exit;
      end;
    end
    else
    begin
      if Mix_PlayMusic(mus, loops) < 0 then
      begin
        Mix_FreeMusic(mus);
        Exit;
      end;
    end;

    CurrentMusic := mus;
    CurrentTrack := filename;
  end;

  procedure PlayTrack (filename: string; loops: Integer);
  begin
    DoPlayTrack(filename, loops, True);  { Default: with fade }
  end;

  procedure InitBGMusic;
  begin
    MixerReady := False;
    CurrentMusic := nil;
    CurrentTrack := '';

    Mix_Init(MIX_INIT_OGG);
    if Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 2048) < 0 then
      Exit;  { Mixer failed to open — music disabled }

    MixerReady := True;
    ApplyBGMVolume;
  end;

  procedure ShutdownBGMusic;
  begin
    if not MixerReady then Exit;

    Mix_HaltMusic;
    if CurrentMusic <> nil then
    begin
      Mix_FreeMusic(CurrentMusic);
      CurrentMusic := nil;
    end;
    CurrentTrack := '';

    Mix_CloseAudio;
    Mix_Quit;
    MixerReady := False;
  end;

  procedure PlayMusicByName (const filename: string);
  begin
    if filename = '' then Exit;
    PlayTrack(filename, -1);
  end;

  procedure PlayMenuMusic;
  begin
    PlayTrack('menu.ogg', -1);
  end;

  procedure PlayLevelMusic (LevelNum: Integer);
  var
    s: string[20];
    n: string[2];
  begin
    if (LevelNum < 1) or (LevelNum > 6) then Exit;
    Str(LevelNum, n);
    s := 'level' + n + '.ogg';
    PlayTrack(s, -1);
  end;

  procedure PlaySubLevelMusic;
  begin
    PlayTrack('sublevel.ogg', -1);
  end;

  procedure PlayGameOverMusic;
  begin
    { Play once, no fade per user request }
    DoPlayTrack('gameover.ogg', 0, False);
  end;

  procedure StopBGMusic;
  begin
    if not MixerReady then Exit;
    if CurrentMusic <> nil then
    begin
      Mix_FadeOutMusic(FADE_DURATION);
      { Non-blocking: fade runs async. DoPlayTrack or ShutdownBGMusic
        will free CurrentMusic when next track loads or at exit. }
    end;
    CurrentTrack := '';
  end;

  procedure PauseBGMusic;
  begin
    if not MixerReady then Exit;
    Mix_PauseMusic;
  end;

  procedure ResumeBGMusic;
  begin
    if not MixerReady then Exit;
    Mix_ResumeMusic;
  end;

end.
