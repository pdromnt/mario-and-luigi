Program Editor;
{
  Leaper - Level Editor
  Uses Dear ImGui (via ImGui-Pascal) + SDL2 + OpenGL3

  This is the main program: sets up SDL2 window with OpenGL context,
  initializes ImGui with docking, loads a level via the game's own
  rendering pipeline, and displays it in an ImGui viewport.
}

{$IFDEF FPC}
  {$mode Delphi}{$H+}{$J-}
{$ENDIF}

{$IFDEF WINDOWS}
  {$APPTYPE GUI}
  {$R resources\editor.res}
{$ENDIF}

{$IFDEF LINUX}
  {$IFDEF FPC}
    {$LinkLib m}
  {$ENDIF}
{$ENDIF}

Uses
  {$IFDEF FPC}
  cmem,
  {$ENDIF}
  Math,
  SysUtils, ctypes,
  {$IFDEF WINDOWS}
  windows,
  {$ENDIF}
  sdl2,
  glad_gl,
  PasImGui,
  PasImGui.Utils,
  PasImGui.Backend.SDL2,
  PasImGui.Renderer.OpenGL3,
  EdRender;

const
  BUILD_DATE = {$I %DATE%};
  BUILD_TIME = {$I %TIME%};

  PaletteTabNames: array[0..8] of PAnsiChar = (
    'Ground', 'Bricks', 'Pipes', 'Blocks',
    'Items', 'Enemies', 'Deco', 'Platforms', 'Rewards'
  );

  LevelNames: array[0..5] of PAnsiChar = (
    'Level 1', 'Level 2', 'Level 3',
    'Level 4', 'Level 5', 'Level 6'
  );

var
  IO: PImGuiIO;
  Quit: Boolean;
  Window: PSDL_Window;
  Event: TSDL_Event;
  GLContext: TSDL_GLContext;
  GLSLVersion: PAnsiChar = '';
  ClearColor: ImVec4;
  StartingTick: CUInt64;
  ElapsedMS: Single;
  SleepTime: Integer;
  FrameRate: Single = 60.0;

  { Editor state }
  ShowDemoWindow: Boolean = False;
  CurrentLevel: Integer = 0;  { 0..5: world index into LevelNames }
  ScrollX: Integer = 0;
  ZoomLevel: Integer = 2;     { 1x, 2x, 3x }
  NeedRerender: Boolean = True;
  ShowGrid: Boolean = False;
  ShowMarkers: Boolean = True;  { Show enemy/item/player start markers }
  IsDragging: Boolean = False; { True while middle-click dragging viewport }
  DragLastX: Integer = -1;    { Last mouse X during drag (SDL screen coords) }
  DragCurX: Integer = 0;      { Current mouse X (temp) }
  DragCurY: Integer = 0;      { Current mouse Y (temp) }
  DragDeltaX: Integer = 0;    { Delta X per frame (temp) }
  ShowAbout: Boolean = False;   { Show About dialog }
  { Sky browser state }
  BrowseSkyType: Integer = 0;   { Currently browsed sky type (0-12) }
  BrowseBgType: Integer = 0;    { Currently browsed background type }
  SkyBrowserDirty: Boolean = False; { True when browser selection changed }

  { --- Sprint 2: Tile Editing State --- }
  SelectedTileIdx: Integer = -1;      { Index into TileAtlas (-1 = none selected) }
  SelectedEnemyIdx: Integer = -1;     { Index into EnemyAtlas (-1 = none selected) }
  SelectedCharCode: Byte = 0;         { CharCode to write when painting }
  SelectedTileName: AnsiString = '';   { Display name of selected tile }
  SelectedIsEnemy: Boolean = False;    { True if selected from enemy palette }
  IsPainting: Boolean = False;         { True while left-click dragging to paint }
  IsErasing: Boolean = False;          { True while right-click dragging to erase }
  LastPaintTileX: Integer = -1;        { Prevent redundant writes on same tile }
  LastPaintTileY: Integer = -1;
  EditorDirty: Boolean = False;        { Unsaved modifications flag }
  ShowUnsavedPopup: Boolean = False;   { True when showing unsaved changes popup }
  PendingLevelSwitch: Integer = -1;    { Level index to switch to after confirmation }

  { Enemy drag-to-reposition state }
  DraggingEnemy: Boolean = False;
  DragEnemySrcX: Integer = -1;
  DragEnemySrcY: Integer = -1;
  DragEnemyChar: Char = #0;

  { Player start drag-to-reposition state }
  DraggingPlayerStart: Boolean = False;

  { Region selection state }
  SelectionActive: Boolean = False;
  SelectionDragging: Boolean = False;
  SelStartX, SelStartY: Integer;
  SelEndX, SelEndY: Integer;
  SelMinX, SelMinY, SelMaxX, SelMaxY: Integer;

  { Clipboard }
  ClipBuf: AnsiString;
  ClipWidth: Integer = 0;
  ClipHeight: Integer = 0;
  PastePreviewActive: Boolean = False;

  { File dialog state }
  FileDialogActive: Boolean = False;
  FileDialogIsSave: Boolean = False;
  FileDialogDir: AnsiString;
  FileDialogFiles: array of AnsiString;
  FileDialogDirs: array of AnsiString;
  FileDialogSelected: Integer = -1;
  FileDialogNameBuf: array[0..255] of AnsiChar;
  FileDialogTitle: AnsiString;
  FileDialogResult: AnsiString;
  FileDialogConfirmed: Boolean = False;

  { Current file path (empty = unsaved) }
  CurrentFilePath: AnsiString = '';

  { Shortcuts window }
  ShowShortcutsWindow: Boolean = False;

  { Pipe match code popup state }
  ShowPipePopup: Boolean = False;
  PipePopupTX: Integer = -1;
  PipePopupTY: Integer = -1;
  PipePopupMatchBuf: array[0..3] of AnsiChar;

  { Level metadata char buffers (for ImGui.InputText) }
  MetaNameBuf: array[0..127] of AnsiChar;
  MetaCreatorBuf: array[0..63] of AnsiChar;
  MetaDescBuf: array[0..255] of AnsiChar;

  { F5 test play state }
  {$IFDEF WINDOWS}
  TestPlayActive: Boolean = False;
  TestPlayProcessHandle: THandle = 0;
  {$ENDIF}

const
  MAX_UNDO_STEPS = 200;
  MAX_CHANGES_PER_STROKE = 4096;
  SAVE_FILE_NAME = 'level_edit.json';

type
  TTileChange = record
    TileX, TileY: Integer;
    OldChar, NewChar: Char;
  end;

  TUndoAction = record
    Changes: array[0..MAX_CHANGES_PER_STROKE - 1] of TTileChange;
    Count: Integer;
  end;

var
  UndoStack: array[0..MAX_UNDO_STEPS - 1] of TUndoAction;
  UndoTop: Integer = 0;        { Next free slot }
  UndoBase: Integer = 0;       { Oldest valid entry }
  RedoCount: Integer = 0;      { Redo-able actions above UndoTop }
  CurrentStroke: TUndoAction;   { Accumulates changes during one paint drag }
  StrokeActive: Boolean = False;

{ Pascal memory allocators for ImGui }
function PasAllocMem(sz: NativeUInt; {%H-}user_data: Pointer): Pointer; cdecl;
begin
  Result := cmem.Malloc(sz);
end;

procedure PasFreeMem(ptr: Pointer; {%H-}user_data: Pointer); cdecl;
begin
  cmem.Free(ptr);
end;

const
  WindowIniFile = 'editor_window.ini';

{ Load saved window position and size from ini file.
  Returns True if values were loaded, False if file doesn't exist. }
function LoadWindowState(out WinX, WinY, WinW, WinH: Integer; out Maximized: Boolean): Boolean;
var
  F: TextFile;
  Line: AnsiString;
  EqPos: Integer;
  Key, Val: AnsiString;
  Code: Integer;
begin
  Result := False;
  Maximized := False;
  WinX := SDL_WINDOWPOS_CENTERED;
  WinY := SDL_WINDOWPOS_CENTERED;
  WinW := 1280;
  WinH := 720;
  if not FileExists(WindowIniFile) then Exit;
  AssignFile(F, WindowIniFile);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then Exit;
  Result := True;
  while not Eof(F) do
  begin
    ReadLn(F, Line);
    EqPos := Pos('=', Line);
    if EqPos < 2 then Continue;
    Key := Copy(Line, 1, EqPos - 1);
    Val := Copy(Line, EqPos + 1, Length(Line));
    if Key = 'X' then begin System.Val(Val, WinX, Code); if Code <> 0 then WinX := SDL_WINDOWPOS_CENTERED; end
    else if Key = 'Y' then begin System.Val(Val, WinY, Code); if Code <> 0 then WinY := SDL_WINDOWPOS_CENTERED; end
    else if Key = 'W' then begin System.Val(Val, WinW, Code); if Code <> 0 then WinW := 1280; end
    else if Key = 'H' then begin System.Val(Val, WinH, Code); if Code <> 0 then WinH := 720; end
    else if Key = 'Max' then Maximized := (Val = '1');
  end;
  CloseFile(F);
end;

{ Save current window position and size to ini file }
procedure SaveWindowState(AWin: PSDL_Window);
var
  F: TextFile;
  WX, WY, WW, WH: CInt;
  Flags: UInt32;
begin
  Flags := SDL_GetWindowFlags(AWin);
  AssignFile(F, WindowIniFile);
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult <> 0 then Exit;
  if (Flags and SDL_WINDOW_MAXIMIZED) <> 0 then
  begin
    WriteLn(F, 'Max=1');
    { Save the restore position/size before maximizing isn't available via SDL2,
      so just save current as fallback }
    SDL_GetWindowPosition(AWin, @WX, @WY);
    SDL_GetWindowSize(AWin, @WW, @WH);
  end
  else
  begin
    WriteLn(F, 'Max=0');
    SDL_GetWindowPosition(AWin, @WX, @WY);
    SDL_GetWindowSize(AWin, @WW, @WH);
  end;
  WriteLn(F, 'X=', WX);
  WriteLn(F, 'Y=', WY);
  WriteLn(F, 'W=', WW);
  WriteLn(F, 'H=', WH);
  CloseFile(F);
end;

{ Reset all editing state (undo stack, selection, dirty flag) }
procedure ResetEditingState;
begin
  UndoTop := 0;
  UndoBase := 0;
  RedoCount := 0;
  StrokeActive := False;
  CurrentStroke.Count := 0;
  SelectedTileIdx := -1;
  SelectedEnemyIdx := -1;
  SelectedCharCode := 0;
  SelectedTileName := '';
  SelectedIsEnemy := False;
  IsPainting := False;
  IsErasing := False;
  LastPaintTileX := -1;
  LastPaintTileY := -1;
  SelectionActive := False;
  SelectionDragging := False;
  PastePreviewActive := False;
  EditorDirty := False;
end;

{ Forward declarations }
procedure UpdateWindowTitle; forward;

{ Copy metadata from EdRender's AnsiString vars into char buffers for ImGui.InputText }
procedure SyncMetaBuffersFromEdRender;
var
  S: AnsiString;
  L: Integer;
begin
  S := EdGetLevelName;
  L := Length(S);
  if L > SizeOf(MetaNameBuf) - 1 then L := SizeOf(MetaNameBuf) - 1;
  FillChar(MetaNameBuf, SizeOf(MetaNameBuf), 0);
  if L > 0 then Move(S[1], MetaNameBuf[0], L);

  S := EdGetLevelCreator;
  L := Length(S);
  if L > SizeOf(MetaCreatorBuf) - 1 then L := SizeOf(MetaCreatorBuf) - 1;
  FillChar(MetaCreatorBuf, SizeOf(MetaCreatorBuf), 0);
  if L > 0 then Move(S[1], MetaCreatorBuf[0], L);

  S := EdGetLevelDescription;
  L := Length(S);
  if L > SizeOf(MetaDescBuf) - 1 then L := SizeOf(MetaDescBuf) - 1;
  FillChar(MetaDescBuf, SizeOf(MetaDescBuf), 0);
  if L > 0 then Move(S[1], MetaDescBuf[0], L);
end;

{ Copy metadata from char buffers back to EdRender's AnsiString vars }
procedure SyncMetaBuffersToEdRender;
begin
  EdSetLevelName(AnsiString(PAnsiChar(@MetaNameBuf[0])));
  EdSetLevelCreator(AnsiString(PAnsiChar(@MetaCreatorBuf[0])));
  EdSetLevelDescription(AnsiString(PAnsiChar(@MetaDescBuf[0])));
end;

procedure LoadSelectedLevel;
begin
  EdLoadLevel(CurrentLevel, 'A');
  ScrollX := 0;
  NeedRerender := True;
  { Sync sky browser to the loaded level's settings }
  BrowseSkyType := EdGetSkyType;
  BrowseBgType := EdGetBackGrType;
  SkyBrowserDirty := False;
  { Reset editing state on level switch }
  ResetEditingState;
  CurrentFilePath := '';
  { Sync metadata buffers from EdRender }
  SyncMetaBuffersFromEdRender;
  UpdateWindowTitle;
end;

{ --- Undo/Redo System --- }

procedure BeginStroke;
begin
  if not StrokeActive then
  begin
    CurrentStroke.Count := 0;
    StrokeActive := True;
  end;
end;

procedure FinalizeStroke;
begin
  if StrokeActive and (CurrentStroke.Count > 0) then
  begin
    UndoStack[UndoTop] := CurrentStroke;
    UndoTop := (UndoTop + 1) mod MAX_UNDO_STEPS;
    { If we wrapped around and caught up with UndoBase, advance base }
    if UndoTop = UndoBase then
      UndoBase := (UndoBase + 1) mod MAX_UNDO_STEPS;
    RedoCount := 0;  { New action clears redo stack }
  end;
  StrokeActive := False;
  CurrentStroke.Count := 0;
end;

procedure RecordTileChange(TileX, TileY: Integer; OldChar, NewChar: Char);
begin
  if CurrentStroke.Count < MAX_CHANGES_PER_STROKE then
  begin
    CurrentStroke.Changes[CurrentStroke.Count].TileX := TileX;
    CurrentStroke.Changes[CurrentStroke.Count].TileY := TileY;
    CurrentStroke.Changes[CurrentStroke.Count].OldChar := OldChar;
    CurrentStroke.Changes[CurrentStroke.Count].NewChar := NewChar;
    Inc(CurrentStroke.Count);
  end;
end;

function CanUndo: Boolean;
begin
  Result := UndoTop <> UndoBase;
end;

function CanRedo: Boolean;
begin
  Result := RedoCount > 0;
end;

procedure DoUndo;
var
  Idx, i: Integer;
begin
  if not CanUndo then Exit;
  { Move back one position }
  Idx := (UndoTop - 1 + MAX_UNDO_STEPS) mod MAX_UNDO_STEPS;
  UndoTop := Idx;
  Inc(RedoCount);
  { Apply changes in reverse }
  for i := UndoStack[Idx].Count - 1 downto 0 do
    EdSetTileAt(UndoStack[Idx].Changes[i].TileX,
                UndoStack[Idx].Changes[i].TileY,
                UndoStack[Idx].Changes[i].OldChar);
  NeedRerender := True;
  EditorDirty := True;
end;

procedure DoRedo;
var
  Idx, i: Integer;
begin
  if not CanRedo then Exit;
  Idx := UndoTop;
  { Re-apply changes }
  for i := 0 to UndoStack[Idx].Count - 1 do
    EdSetTileAt(UndoStack[Idx].Changes[i].TileX,
                UndoStack[Idx].Changes[i].TileY,
                UndoStack[Idx].Changes[i].NewChar);
  UndoTop := (UndoTop + 1) mod MAX_UNDO_STEPS;
  Dec(RedoCount);
  NeedRerender := True;
  EditorDirty := True;
end;

{ Place a tile at (TileX, TileY), recording for undo }
procedure PlaceTile(TileX, TileY: Integer; NewChar: Char);
var
  OldChar: Char;
begin
  OldChar := EdGetTileAt(TileX, TileY);
  if OldChar = NewChar then Exit;  { No change }
  EdSetTileAt(TileX, TileY, NewChar);
  RecordTileChange(TileX, TileY, OldChar, NewChar);
  NeedRerender := True;
  EditorDirty := True;
end;

{ Eyedropper: pick the tile under cursor and make it the selected tile }
procedure EyedropperPick(TileX, TileY: Integer);
var
  Ch: Char;
  i: Integer;
  Entry: TTileAtlasEntry;
  EnemyEntry: TEnemyAtlasEntry;
begin
  Ch := EdGetTileAt(TileX, TileY);
  if Ch = ' ' then
  begin
    { Picked empty — deselect }
    SelectedTileIdx := -1;
    SelectedEnemyIdx := -1;
    SelectedCharCode := 0;
    SelectedTileName := 'Empty';
    SelectedIsEnemy := False;
    Exit;
  end;

  { Search enemy atlas first }
  for i := 0 to EdGetEnemyAtlasCount - 1 do
  begin
    EnemyEntry := EdGetEnemyAtlasEntry(i);
    if Chr(EnemyEntry.CharCode) = Ch then
    begin
      SelectedEnemyIdx := i;
      SelectedTileIdx := -1;
      SelectedCharCode := EnemyEntry.CharCode;
      SelectedTileName := EnemyEntry.Name;
      SelectedIsEnemy := True;
      Exit;
    end;
  end;

  { Search tile atlas }
  for i := 0 to EdGetTileAtlasCount - 1 do
  begin
    Entry := EdGetTileAtlasEntry(i);
    if Chr(Entry.CharCode) = Ch then
    begin
      SelectedTileIdx := i;
      SelectedEnemyIdx := -1;
      SelectedCharCode := Entry.CharCode;
      SelectedTileName := Entry.Name;
      SelectedIsEnemy := False;
      Exit;
    end;
  end;

  { Not found in either atlas — select raw char code }
  SelectedTileIdx := -1;
  SelectedEnemyIdx := -1;
  SelectedCharCode := Ord(Ch);
  SelectedTileName := '#' + IntToStr(Ord(Ch));
  SelectedIsEnemy := False;
end;

{ --- Selection helpers --- }

procedure NormalizeSelection;
begin
  if SelStartX <= SelEndX then begin SelMinX := SelStartX; SelMaxX := SelEndX; end
  else begin SelMinX := SelEndX; SelMaxX := SelStartX; end;
  if SelStartY <= SelEndY then begin SelMinY := SelStartY; SelMaxY := SelEndY; end
  else begin SelMinY := SelEndY; SelMaxY := SelStartY; end;
  if SelMinX < 0 then SelMinX := 0;
  if SelMinY < 0 then SelMinY := 0;
  if SelMaxX >= EdGetLevelXSize then SelMaxX := EdGetLevelXSize - 1;
  if SelMaxY >= EdGetNV then SelMaxY := EdGetNV - 1;
end;

procedure ClearSelection;
begin
  SelectionActive := False;
  SelectionDragging := False;
end;

{ --- Clipboard operations --- }

procedure DoCopy;
begin
  if not SelectionActive then Exit;
  ClipWidth := SelMaxX - SelMinX + 1;
  ClipHeight := SelMaxY - SelMinY + 1;
  EdGetTileRegion(SelMinX, SelMinY, SelMaxX, SelMaxY, ClipBuf);
end;

procedure DoCut;
var X, Y: Integer;
begin
  if not SelectionActive then Exit;
  DoCopy;
  BeginStroke;
  for Y := SelMinY to SelMaxY do
    for X := SelMinX to SelMaxX do
      PlaceTile(X, Y, ' ');
  FinalizeStroke;
  ClearSelection;
end;

procedure DoPaste;
begin
  if (ClipWidth <= 0) or (ClipHeight <= 0) then Exit;
  PastePreviewActive := True;
  ClearSelection;
end;

procedure CommitPaste(AtX, AtY: Integer);
var X, Y, Idx: Integer; Ch: Char;
begin
  BeginStroke;
  Idx := 1;
  for Y := 0 to ClipHeight - 1 do
    for X := 0 to ClipWidth - 1 do begin
      if Idx <= Length(ClipBuf) then begin
        Ch := ClipBuf[Idx];
        PlaceTile(AtX + X, AtY + Y, Ch);
      end;
      Inc(Idx);
    end;
  FinalizeStroke;
  PastePreviewActive := False;
end;

procedure DoFill;
var X, Y: Integer;
begin
  if (not SelectionActive) or (SelectedCharCode = 0) then Exit;
  BeginStroke;
  for Y := SelMinY to SelMaxY do
    for X := SelMinX to SelMaxX do
      PlaceTile(X, Y, Chr(SelectedCharCode));
  FinalizeStroke;
end;

procedure DoDeleteSelection;
var X, Y: Integer;
begin
  if not SelectionActive then Exit;
  BeginStroke;
  for Y := SelMinY to SelMaxY do
    for X := SelMinX to SelMaxX do
      PlaceTile(X, Y, ' ');
  FinalizeStroke;
  ClearSelection;
end;

{ --- File dialog helpers --- }

procedure FileDialogScanDir;
var SR: TSearchRec; Dir: AnsiString;
begin
  SetLength(FileDialogFiles, 0);
  SetLength(FileDialogDirs, 0);
  FileDialogSelected := -1;
  Dir := IncludeTrailingPathDelimiter(FileDialogDir);

  if FindFirst(Dir + '*', faDirectory, SR) = 0 then begin
    repeat
      if ((SR.Attr and faDirectory) <> 0) and (SR.Name <> '.') then begin
        SetLength(FileDialogDirs, Length(FileDialogDirs) + 1);
        FileDialogDirs[High(FileDialogDirs)] := SR.Name;
      end;
    until FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;

  if FindFirst(Dir + '*.json', faAnyFile, SR) = 0 then begin
    repeat
      if (SR.Attr and faDirectory) = 0 then begin
        SetLength(FileDialogFiles, Length(FileDialogFiles) + 1);
        FileDialogFiles[High(FileDialogFiles)] := SR.Name;
      end;
    until FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;
end;

procedure OpenFileDialog(IsSave: Boolean; const Title, DefaultDir, DefaultName: AnsiString);
begin
  FileDialogIsSave := IsSave;
  FileDialogTitle := Title;
  FileDialogConfirmed := False;
  FileDialogResult := '';
  FileDialogActive := True;

  if DefaultDir <> '' then
    FileDialogDir := DefaultDir
  else if CurrentFilePath <> '' then
    FileDialogDir := ExtractFilePath(CurrentFilePath)
  else
    FileDialogDir := GetCurrentDir;

  FillChar(FileDialogNameBuf, SizeOf(FileDialogNameBuf), 0);
  if DefaultName <> '' then
    StrLCopy(@FileDialogNameBuf[0], PAnsiChar(DefaultName), 255);

  FileDialogScanDir;
end;

{ Update the window title to reflect dirty state and current file }
procedure UpdateWindowTitle;
var
  Title: AnsiString;
begin
  if CurrentFilePath <> '' then
    Title := 'Leaper - Level Editor - ' + ExtractFileName(CurrentFilePath)
  else
    Title := 'Leaper - Level Editor';
  if EditorDirty then
    Title := '* ' + Title;
  SDL_SetWindowTitle(Window, PAnsiChar(Title));
end;

{$IFDEF WINDOWS}
{ Launch the game for test play — saves current level to temp file, runs GAME.exe -T }
procedure LaunchTestPlay;
var
  SI: STARTUPINFOA;
  PI: PROCESS_INFORMATION;
  TempDir, TempFile, GameExe, CmdLine, WorkDir: AnsiString;
  EditorDir: AnsiString;
begin
  if TestPlayActive then Exit;

  { Save active sub-level to buffer first }
  EdSaveActiveToBuffer;
  SyncMetaBuffersToEdRender;

  { Determine temp file path }
  TempDir := SysUtils.GetEnvironmentVariable('TEMP');
  if TempDir = '' then
    TempDir := SysUtils.GetEnvironmentVariable('TMP');
  if TempDir = '' then
    TempDir := '.';
  TempFile := IncludeTrailingPathDelimiter(TempDir) + 'ml_editor_test.json';

  { Save all sub-levels to temp JSON }
  if not EdSaveLevelJSON(TempFile) then Exit;

  { Find game executable relative to editor location }
  { Editor is in sdl2_port/editor/OUT/EDITOR.exe }
  { Game is in sdl2_port/OUT/GAME.exe }
  EditorDir := ExtractFilePath(ParamStr(0));
  GameExe := EditorDir + '..\OUT\GAME.exe';
  if not FileExists(GameExe) then
    GameExe := EditorDir + '..\..\OUT\GAME.exe';
  if not FileExists(GameExe) then
    GameExe := EditorDir + '..\GAME.exe';
  if not FileExists(GameExe) then
  begin
    { Try current directory }
    GameExe := 'GAME.exe';
    if not FileExists(GameExe) then Exit;
  end;
  GameExe := ExpandFileName(GameExe);

  { Build command line }
  CmdLine := '"' + GameExe + '" -T "' + TempFile + '"';
  WorkDir := ExtractFilePath(GameExe);

  { Launch the game process }
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  FillChar(PI, SizeOf(PI), 0);

  if CreateProcessA(nil, PAnsiChar(CmdLine), nil, nil, False,
    0, nil, PAnsiChar(WorkDir), @SI, @PI) then
  begin
    TestPlayActive := True;
    TestPlayProcessHandle := PI.hProcess;
    CloseHandle(PI.hThread);
  end;
end;

{ Check if the test play process has exited }
procedure CheckTestPlayProcess;
begin
  if not TestPlayActive then Exit;
  if WaitForSingleObject(TestPlayProcessHandle, 0) <> WAIT_TIMEOUT then
  begin
    CloseHandle(TestPlayProcessHandle);
    TestPlayProcessHandle := 0;
    TestPlayActive := False;
  end;
end;
{$ENDIF}

var
  { Hover info updated each frame }
  HoverTileX: Integer = -1;
  HoverTileY: Integer = -1;
  HoverTileChar: Char = ' ';
  LastDirtyState: Boolean = False;  { Track dirty state changes for window title }

{ Check if the tile below (TileX, TileY) is a pipe top.
  Pipe action codes (#$E0..#$EF) are stored above pipe tops as paired markers. }
function IsPipeActionMarker(TileX, TileY: Integer): Boolean;
var
  Below: Char;
begin
  Result := False;
  if TileY >= EdGetNV - 1 then Exit;  { No tile below bottom row }
  Below := EdGetTileAt(TileX, TileY + 1);
  Result := Below in ['0', '1'];
end;

{ Return the pipe action name for a code placed above a pipe }
function GetPipeActionName(Code: Char): AnsiString;
begin
  case Code of
    #$E0: Result := 'Pipe: Warp';
    #$E1: Result := 'Pipe: World Swap';
    #$E7: Result := 'Pipe: Level Exit';
  else
    Result := 'Pipe: Link #' + IntToStr(Ord(Code));
  end;
end;

{ Return a descriptive name for a tile character, or empty string if not special.
  TileX/TileY are used for context-aware naming (e.g. pipe action codes vs rewards). }
function GetTileName(Ch: Char; TileX, TileY: Integer): AnsiString;
begin
  case Ch of
    #$80: Result := 'Goomba';
    #$83: Result := 'Grey Goomba';
    #$81: Result := 'Fish';
    #$82: Result := 'Fireball';
    #$84: Result := 'Green Piranha';
    #$85: Result := 'Green Piranha (2)';
    #$86: Result := 'Red Piranha';
    #$87: Result := 'Spiny';
    #$88: Result := 'Green Koopa';
    #$89: Result := 'Red Koopa';
    #$8A: Result := 'Green Koopa (fast)';
    #$B0: Result := 'Block Lift';
    #$B1: Result := 'Falling Platform';
    '$':  Result := 'Hidden Block';
    '?':  Result := 'Question Block';
    '@':  Result := 'Used Block';
    '*':  Result := 'Coin';
    'A','B': Result := 'Brick';
    'C','D': Result := 'Ground';
    'I':  Result := 'Solid Block';
    'J':  Result := 'Breakable Block';
    'K':  Result := 'Note Block';
    'X':  Result := 'X-Block';
    'W':  Result := 'Wood';
    '=':  Result := 'Pin';
    '0'..'3': Result := 'Pipe';
    '#':  Result := 'Decoration (#)';
    '%':  Result := 'Decoration (%)';
    #14, #15, #16: Result := 'Platform';
    #240: Result := 'Fence / Small Tree';
    #244: Result := 'Palm Leaf (left)';
    #245: Result := 'Palm Leaf (right)';
    #246: Result := 'Palm Trunk';
    #247: Result := 'Platform (grass)';
    #249: Result := 'Palm Leaf (top)';
    #250: Result := 'Palm Leaf (center)';
    #254: Result := 'Flag Pole (top)';
    #255: Result := 'Flag Pole';
    ' ':  Result := 'Empty';
    { #$E0..#$EF: Context-dependent — pipe action above pipes, reward above blocks }
    #$E0..#$EF:
      begin
        if IsPipeActionMarker(TileX, TileY) then
          Result := GetPipeActionName(Ch)
        else
          case Ch of
            #$E0: Result := 'Reward: Mushroom';
            #$E1: Result := 'Reward: 1-Up';
            #$E2: Result := 'Reward: Star';
            #$E3..#$EC: Result := 'Reward: Multi-Coin';
            #$ED: Result := 'Reward: Poison Mushroom';
            #$EF: Result := 'Reward: Note Block';
          else
            Result := 'Marker #$' + IntToHex(Ord(Ch), 2);
          end;
      end;
  else
    Result := '';
  end;
end;

{ Return the content description for a '?' or '$' block by reading the tile above it.
  The game stores reward markers at WorldMap[x, y-1]. Returns empty if no content. }
function GetBlockContent(TileX, TileY: Integer): AnsiString;
var
  Above: Char;
begin
  Result := '';
  if TileY <= 0 then Exit;  { No tile above row 0 }
  Above := EdGetTileAt(TileX, TileY - 1);
  case Above of
    #$E0: Result := 'Mushroom / Fire Flower';
    #$E1: Result := '1-Up Mushroom';
    #$E2: Result := 'Star';
    #$E3..#$EC: Result := 'Coins (x' + IntToStr(Ord(Above) - $E3 + 2) + ')';
    #$ED: Result := 'Poison Mushroom';
    #$EF: Result := 'Note Block';
    ' ':  Result := 'Coin';
    '*':  Result := 'Coin';
  else
    Result := '';
  end;
end;

{ Return marker info for enemy/item tiles: label char and ABGR color.
  Returns False if the tile doesn't need a marker. }
function GetMarkerInfo(Ch: Char; out Lab: AnsiChar; out Col: LongWord; out IsRect: Boolean): Boolean;
begin
  IsRect := False;
  Result := True;
  case Ch of
    #$80, #$83:         begin Lab := 'G'; Col := $CC0000FF; end;  { Goomba: red }
    #$87:               begin Lab := 'S'; Col := $CC0066FF; end;  { Spiny: red-orange }
    #$88, #$89, #$8A:   begin Lab := 'K'; Col := $CC00CC00; end;  { Green Koopa: green }
    #$84, #$85, #$86:   begin Lab := 'P'; Col := $CCFF00FF; end;  { Piranha: magenta }
    #$81:               begin Lab := 'F'; Col := $CCFFCC00; end;  { Fish: cyan }
    #$82:               begin Lab := '!'; Col := $CC0088FF; end;  { Fireball: orange }
    #$B0:               begin Lab := '='; Col := $CCFF8800; IsRect := True; end;  { Block Lift: blue }
    #$B1:               begin Lab := 'O'; Col := $CCFF8800; IsRect := True; end;  { Donut Lift: blue }
    '$':                begin Lab := '?'; Col := $80FFFFFF; IsRect := True; end;  { Hidden Block: white outline }
  else
    begin Lab := ' '; Col := 0; Result := False; end;
  end;
end;

{ Draw all ImGui content }
procedure DrawGUI;
var
  BackupWindow: PSDL_Window;
  BackupContext: TSDL_GLContext;
  TexID: Pointer;
  TexSize: ImVec2;
  UV0, UV1: ImVec2;
  Tint, Border: ImVec4;
  LevelW: Integer;
  i: Integer;
  ViewportFlags: ImGuiWindowFlags;
  ImgMin, ImgMax: ImVec2;
  DrawList: PImDrawList;
  GridCol: ImU32;
  HighlightCol: ImU32;
  P1, P2: ImVec2;
  TileW, TileH: Single;
  SubTileOff: Single;  { Sub-tile pixel offset for grid alignment }
  MousePos: ImVec2;
  RelX, RelY: Single;
  PixInLevel: Single;  { Mouse pixel position within the full level }
  HighRect1, HighRect2: ImVec2;
  MouseInViewport: Boolean;
  { Tile palette }
  TabIdx, PalTileIdx, PalColCount, PalTilesPerRow: Integer;
  PalEntry: TTileAtlasEntry;
  PalUV0, PalUV1, PalTileSize: ImVec2;
  PalAvail: ImVec2;
  { Marker / enemy sprite drawing }
  FirstTileX, LastTileX: Integer;
  tx, ty: Integer;
  MarkerCh: Char;
  MarkerLab: AnsiChar;
  MarkerCol: LongWord;
  MarkerIsRect: Boolean;
  MarkerCenter: ImVec2;
  MarkerRadius: Single;
  MarkerR1, MarkerR2: ImVec2;
  MarkerLabel: array[0..1] of AnsiChar;
  TextSize: ImVec2;
  TextPos: ImVec2;
  EnemyIdx: Integer;
  EnemyEntry: TEnemyAtlasEntry;
  EnemyTexID: Pointer;
  SprP1, SprP2: ImVec2;
  SprUV0, SprUV1: ImVec2;
  SprDispW, SprDispH: Single;
  ArrowTip, ArrowTop, ArrowBot: ImVec2;  { Enemy direction arrow }
  OverlayAtlasIdx: Integer;
  OverlayEntry: TTileAtlasEntry;
  AtlasTexID: Pointer;
  PlayerTX, PlayerTY: Integer;
  TileName: AnsiString;
  BlockContent: AnsiString;
  ContentLabel: array[0..1] of AnsiChar;
  ContentCenter: ImVec2;
  ContentR: Single;
  { Pipe action markers }
  PipeAbove: Char;
  PipeActionLabel: AnsiString;
  PipeActionBuf: array[0..15] of AnsiChar;
  PipeActionCol: LongWord;
  PipeArrowTop, PipeArrowBL, PipeArrowBR: ImVec2;
  PipeBgR1, PipeBgR2: ImVec2;
  PipeLabelLen: Integer;
  { Pipe warp connections }
  PipeInfoMatch: array[0..63] of Char;
  PipeInfoCX: array[0..63] of Single;
  PipeInfoCY: array[0..63] of Single;
  PipeCount: Integer;
  PipeI, PipeJ: Integer;
  BezP1, BezP2, BezC1, BezC2: ImVec2;
  BezMid: ImVec2;
  BezDist: Single;
  PipeMatchLabel: array[0..3] of AnsiChar;
  PipeConnColors: array[0..7] of LongWord;
  PipeColorIdx: Integer;
  { Camera lock markers }
  CamLocks: array[0..31] of TCamLockEntry;
  CamLockCount: Integer;
  CamLockIdx: Integer;
  CamLockX: Single;
  CamLockLabel: AnsiString;
  CamLockBuf: array[0..15] of AnsiChar;
  CamLockCol: LongWord;
  CamLockBgR1, CamLockBgR2: ImVec2;
  CamLockLineTop, CamLockLineBot: ImVec2;
  { Tile editing — palette button IDs }
  PalBtnID: AnsiString;
  PalBgCol, PalTintCol: ImVec4;
  IsSelected: Boolean;
  { Tile editing — cursor preview }
  PreviewUV0, PreviewUV1: ImVec2;
  PreviewTexID: Pointer;
  { Key modifier state }
  KeyMods: Integer;
  { Sub-level tab bar }
  SubTabIdx: Integer;
  SubTabOpen: Boolean;
  SubTabName: AnsiString;
  SubTabFlags: ImGuiTabItemFlags;
  { Selection + paste overlays }
  SelP1, SelP2: ImVec2;
  PasteX, PasteY: Integer;
  PasteCh: Char;
  PasteTileIdx: Integer;
  PasteEntry: TTileAtlasEntry;
  PasteP1, PasteP2, PasteUV0, PasteUV1: ImVec2;
  { File dialog }
  FDI: Integer;
  FDEntry: AnsiString;
  FDFullPath: AnsiString;
  { Music track combo }
  CurMusic: AnsiString;
  MusicPreview: AnsiString;
  MusicChanged: Boolean;
begin
  { Start ImGui frame }
  ImGui_OpenGL3_NewFrame();
  ImGui_ImplSDL2_NewFrame_Pas();
  ImGui.NewFrame();

  { --- Main Dockspace --- }
  ImGui.DockSpaceOverViewport(0, ImGui.GetMainViewport(), ImGuiDockNodeFlags_None, nil);

  { --- Menu Bar --- }
  if ImGui.BeginMainMenuBar() then
  begin
    if ImGui.BeginMenu('File', True) then
    begin
      if ImGui.BeginMenu('Open Built-In', True) then
      begin
        for i := 0 to 5 do
        begin
          if ImGui.MenuItem(LevelNames[i], nil, i = CurrentLevel, True) then
          begin
            if EditorDirty then
            begin
              PendingLevelSwitch := i;
              ShowUnsavedPopup := True;
            end
            else
            begin
              CurrentLevel := i;
              LoadSelectedLevel;
            end;
          end;
        end;
        ImGui.EndMenu();
      end;
      ImGui.Separator();
      if ImGui.MenuItem('Save', 'Ctrl+S', False, EdIsLevelLoaded) then
      begin
        SyncMetaBuffersToEdRender;
        if CurrentFilePath <> '' then begin
          if EdSaveLevelJSON(CurrentFilePath) then begin
            EditorDirty := False; UpdateWindowTitle; end;
        end else
          OpenFileDialog(True, 'Save Level', '', 'level.json');
      end;
      if ImGui.MenuItem('Save As...', 'Ctrl+Shift+S', False, EdIsLevelLoaded) then
      begin
        SyncMetaBuffersToEdRender;
        OpenFileDialog(True, 'Save Level As', '', ExtractFileName(CurrentFilePath));
      end;
      ImGui.Separator();
      if ImGui.MenuItem('Open Level...', 'Ctrl+O', False, True) then
        OpenFileDialog(False, 'Open Level', '', '');
      {$IFDEF WINDOWS}
      ImGui.Separator();
      if ImGui.MenuItem('Test Play', 'F5', False, EdIsLevelLoaded and (not TestPlayActive)) then
        LaunchTestPlay;
      {$ENDIF}
      ImGui.Separator();
      if ImGui.MenuItem('Quit', 'Alt+F4', False, True) then
        Quit := True;
      ImGui.EndMenu();
    end;

    if ImGui.BeginMenu('Edit', True) then
    begin
      if ImGui.MenuItem('Undo', 'Ctrl+Z', False, CanUndo) then
        DoUndo;
      if ImGui.MenuItem('Redo', 'Ctrl+Y', False, CanRedo) then
        DoRedo;
      ImGui.Separator();
      if ImGui.MenuItem('Copy', 'Ctrl+C', False, SelectionActive) then
        DoCopy;
      if ImGui.MenuItem('Cut', 'Ctrl+X', False, SelectionActive) then
        DoCut;
      if ImGui.MenuItem('Paste', 'Ctrl+V', False, ClipWidth > 0) then
        DoPaste;
      if ImGui.MenuItem('Fill Selection', 'Ctrl+F', False, SelectionActive and (SelectedCharCode > 0)) then
        DoFill;
      if ImGui.MenuItem('Delete Selection', 'Del', False, SelectionActive) then
        DoDeleteSelection;
      ImGui.EndMenu();
    end;

    if ImGui.BeginMenu('View', True) then
    begin
      if ImGui.MenuItem('Zoom 1x', '1', ZoomLevel = 1, True) then
      begin
        ZoomLevel := 1;
        NeedRerender := True;
      end;
      if ImGui.MenuItem('Zoom 2x', '2', ZoomLevel = 2, True) then
      begin
        ZoomLevel := 2;
        NeedRerender := True;
      end;
      if ImGui.MenuItem('Zoom 3x', '3', ZoomLevel = 3, True) then
      begin
        ZoomLevel := 3;
        NeedRerender := True;
      end;
      ImGui.Separator();
      ImGui.MenuItem('Show Grid', 'G', @ShowGrid, True);
      ImGui.MenuItem('Show Markers', 'M', @ShowMarkers, True);
      ImGui.Separator();
      ImGui.MenuItem('ImGui Demo', nil, @ShowDemoWindow, True);
      ImGui.EndMenu();
    end;

    if ImGui.BeginMenu('Help', True) then
    begin
      if ImGui.MenuItem('Keyboard Shortcuts...', nil, False, True) then
        ShowShortcutsWindow := True;
      if ImGui.MenuItem('About...', nil, False, True) then
        ShowAbout := True;
      ImGui.EndMenu();
    end;
    ImGui.EndMainMenuBar();
  end;

  { --- About Dialog --- }
  if ShowAbout then
  begin
    ImGui.OpenPopup('About##popup', ImGuiPopupFlags_None);
    ShowAbout := False;
  end;
  if ImGui.BeginPopupModal('About##popup', nil, ImGuiWindowFlags_AlwaysAutoResize) then
  begin
    ImGui.Text('Leaper - Level Editor');
    ImGui.Separator();
    ImGui.Text(AnsiString('Build: ' + BUILD_DATE + '-' + BUILD_TIME));
    ImGui.Text('Engine: SDL2 + OpenGL3 + Dear ImGui');
    ImGui.Separator();
    if ImGui.Button('OK', ImVec2.New(120, 0)) then
      ImGui.CloseCurrentPopup();
    ImGui.EndPopup();
  end;

  { --- Unsaved Changes Popup --- }
  if ShowUnsavedPopup then
  begin
    ImGui.OpenPopup('Unsaved Changes##popup', ImGuiPopupFlags_None);
    ShowUnsavedPopup := False;
  end;
  if ImGui.BeginPopupModal('Unsaved Changes##popup', nil, ImGuiWindowFlags_AlwaysAutoResize) then
  begin
    ImGui.Text('You have unsaved changes.');
    ImGui.Text('Switch level anyway?');
    ImGui.Separator();
    if ImGui.Button('Yes, switch', ImVec2.New(120, 0)) then
    begin
      if PendingLevelSwitch >= 0 then
      begin
        CurrentLevel := PendingLevelSwitch;
        PendingLevelSwitch := -1;
        LoadSelectedLevel;
      end;
      ImGui.CloseCurrentPopup();
    end;
    ImGui.SameLine(0, 8);
    if ImGui.Button('Cancel', ImVec2.New(120, 0)) then
    begin
      PendingLevelSwitch := -1;
      ImGui.CloseCurrentPopup();
    end;
    ImGui.EndPopup();
  end;

  { --- Pipe Match Code Popup --- }
  if ShowPipePopup then
  begin
    ImGui.OpenPopup('PipeMatchPopup', ImGuiPopupFlags_None);
    ShowPipePopup := False;
  end;
  if ImGui.BeginPopup('PipeMatchPopup', ImGuiWindowFlags_AlwaysAutoResize) then
  begin
    ImGui.Text(AnsiString('Pipe at (' + IntToStr(PipePopupTX) + ', ' + IntToStr(PipePopupTY) + ')'));
    { Show current action code }
    if PipePopupTY > 0 then
    begin
      PipeAbove := EdGetTileAt(PipePopupTX, PipePopupTY - 1);
      case PipeAbove of
        #$E0: ImGui.Text('Action: WARP');
        #$E1: ImGui.Text('Action: SWAP');
        #$E7: ImGui.Text('Action: EXIT');
      else
        ImGui.Text('Action: None');
      end;
    end;
    ImGui.Separator();
    ImGui.Text('Match Code (1 char):');
    ImGui.PushItemWidth(60);
    ImGui.InputText('##MatchCode', @PipePopupMatchBuf[0], 2,
      ImGuiInputTextFlags_None, nil, nil);
    ImGui.PopItemWidth();
    ImGui.SameLine(0, 8);
    if ImGui.Button('Apply', ImVec2.New(60, 0)) then
    begin
      if (PipePopupTY > 0) and (PipePopupMatchBuf[0] <> #0) then
      begin
        BeginStroke;
        PlaceTile(PipePopupTX + 1, PipePopupTY - 1, PipePopupMatchBuf[0]);
        FinalizeStroke;
        NeedRerender := True;
      end;
      ImGui.CloseCurrentPopup();
    end;
    ImGui.SameLine(0, 8);
    if ImGui.Button('Clear', ImVec2.New(60, 0)) then
    begin
      if PipePopupTY > 0 then
      begin
        BeginStroke;
        PlaceTile(PipePopupTX + 1, PipePopupTY - 1, ' ');
        FinalizeStroke;
        NeedRerender := True;
      end;
      ImGui.CloseCurrentPopup();
    end;
    ImGui.EndPopup();
  end;

  { --- File Dialog --- }
  if FileDialogActive then
  begin
    ImGui.OpenPopup(PAnsiChar(FileDialogTitle), ImGuiPopupFlags_None);
    ImGui.SetNextWindowSize(ImVec2.New(600, 400), ImGuiCond_FirstUseEver);
    if ImGui.BeginPopupModal(PAnsiChar(FileDialogTitle), nil, ImGuiWindowFlags_None) then
    begin
      ImGui.Text(PAnsiChar(AnsiString('Directory: ' + FileDialogDir)));
      ImGui.Separator();

      if ImGui.BeginChild('FileList', ImVec2.New(0, -60), ImGuiChildFlags_Border, ImGuiWindowFlags_None) then
      begin
        { Directories }
        for FDI := 0 to Length(FileDialogDirs) - 1 do
        begin
          FDEntry := '[' + FileDialogDirs[FDI] + ']';
          if ImGui.Selectable(PAnsiChar(AnsiString(FDEntry + '##dir' + IntToStr(FDI))),
             False, ImGuiSelectableFlags_AllowDoubleClick) then
          begin
            if ImGui.IsMouseDoubleClicked(ImGuiMouseButton_Left) then
            begin
              if FileDialogDirs[FDI] = '..' then
                FileDialogDir := ExtractFilePath(ExcludeTrailingPathDelimiter(FileDialogDir))
              else
                FileDialogDir := IncludeTrailingPathDelimiter(FileDialogDir) + FileDialogDirs[FDI];
              FileDialogDir := ExpandFileName(FileDialogDir);
              FileDialogScanDir;
            end;
          end;
        end;

        { Files }
        for FDI := 0 to Length(FileDialogFiles) - 1 do
        begin
          FDEntry := FileDialogFiles[FDI];
          if ImGui.Selectable(PAnsiChar(AnsiString(FDEntry + '##file' + IntToStr(FDI))),
             FDI = FileDialogSelected, ImGuiSelectableFlags_AllowDoubleClick) then
          begin
            FileDialogSelected := FDI;
            if FileDialogIsSave then
              StrLCopy(@FileDialogNameBuf[0], PAnsiChar(FDEntry), 255);

            if (not FileDialogIsSave) and ImGui.IsMouseDoubleClicked(ImGuiMouseButton_Left) then
            begin
              FileDialogResult := IncludeTrailingPathDelimiter(FileDialogDir) + FDEntry;
              FileDialogConfirmed := True;
              FileDialogActive := False;
              ImGui.CloseCurrentPopup();
            end;
          end;
        end;
        ImGui.EndChild();
      end;

      if FileDialogIsSave then
      begin
        ImGui.Text('Filename:');
        ImGui.SameLine(0, 8);
        ImGui.PushItemWidth(-160);
        ImGui.InputText('##FileName', @FileDialogNameBuf[0], 256,
          ImGuiInputTextFlags_None, nil, nil);
        ImGui.PopItemWidth();
      end;

      ImGui.Separator();
      if FileDialogIsSave then
      begin
        if ImGui.Button('Save', ImVec2.New(100, 0)) then
        begin
          if FileDialogNameBuf[0] <> #0 then begin
            FDFullPath := IncludeTrailingPathDelimiter(FileDialogDir) +
              AnsiString(PAnsiChar(@FileDialogNameBuf[0]));
            if LowerCase(ExtractFileExt(FDFullPath)) <> '.json' then
              FDFullPath := FDFullPath + '.json';
            FileDialogResult := FDFullPath;
            FileDialogConfirmed := True;
            FileDialogActive := False;
            ImGui.CloseCurrentPopup();
          end;
        end;
      end
      else begin
        if ImGui.Button('Open', ImVec2.New(100, 0)) then
        begin
          if (FileDialogSelected >= 0) and (FileDialogSelected < Length(FileDialogFiles)) then
          begin
            FileDialogResult := IncludeTrailingPathDelimiter(FileDialogDir) +
              FileDialogFiles[FileDialogSelected];
            FileDialogConfirmed := True;
            FileDialogActive := False;
            ImGui.CloseCurrentPopup();
          end;
        end;
      end;

      ImGui.SameLine(0, 8);
      if ImGui.Button('Cancel', ImVec2.New(100, 0)) then
      begin
        FileDialogActive := False;
        ImGui.CloseCurrentPopup();
      end;

      ImGui.EndPopup();
    end;
  end;

  { Handle file dialog result }
  if FileDialogConfirmed then
  begin
    FileDialogConfirmed := False;
    if FileDialogIsSave then
    begin
      SyncMetaBuffersToEdRender;
      if EdSaveLevelJSON(FileDialogResult) then begin
        CurrentFilePath := FileDialogResult;
        EditorDirty := False;
        UpdateWindowTitle;
      end;
    end
    else begin
      if EdLoadLevelJSON(FileDialogResult) then begin
        CurrentFilePath := FileDialogResult;
        NeedRerender := True;
        BrowseSkyType := EdGetSkyType;
        BrowseBgType := EdGetBackGrType;
        SkyBrowserDirty := False;
        ResetEditingState;
        SyncMetaBuffersFromEdRender;
        UpdateWindowTitle;
      end;
    end;
  end;

  { --- Keyboard Shortcuts Window --- }
  if ShowShortcutsWindow then
  begin
    ImGui.SetNextWindowSize(ImVec2.New(420, 500), ImGuiCond_FirstUseEver);
    if ImGui.Begin_('Keyboard Shortcuts', @ShowShortcutsWindow, ImGuiWindowFlags_None) then
    begin
      if ImGui.BeginTable('Shortcuts', 2,
         ImGuiTableFlags_RowBg or ImGuiTableFlags_Borders) then
      begin
        ImGui.TableSetupColumn('Shortcut', ImGuiTableColumnFlags_WidthFixed, 140, 0);
        ImGui.TableSetupColumn('Action', ImGuiTableColumnFlags_WidthStretch, 0, 0);
        ImGui.TableHeadersRow();

        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Ctrl+S'); ImGui.TableSetColumnIndex(1); ImGui.Text('Save level');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Ctrl+Shift+S'); ImGui.TableSetColumnIndex(1); ImGui.Text('Save level as...');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Ctrl+O'); ImGui.TableSetColumnIndex(1); ImGui.Text('Open level...');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Ctrl+Z'); ImGui.TableSetColumnIndex(1); ImGui.Text('Undo');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Ctrl+Y'); ImGui.TableSetColumnIndex(1); ImGui.Text('Redo');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Ctrl+C'); ImGui.TableSetColumnIndex(1); ImGui.Text('Copy selection');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Ctrl+X'); ImGui.TableSetColumnIndex(1); ImGui.Text('Cut selection');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Ctrl+V'); ImGui.TableSetColumnIndex(1); ImGui.Text('Paste');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Ctrl+F'); ImGui.TableSetColumnIndex(1); ImGui.Text('Fill selection with tile');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Delete'); ImGui.TableSetColumnIndex(1); ImGui.Text('Delete selection');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Escape'); ImGui.TableSetColumnIndex(1); ImGui.Text('Cancel paste / clear selection / deselect');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('1 / 2 / 3'); ImGui.TableSetColumnIndex(1); ImGui.Text('Zoom 1x / 2x / 3x');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('G'); ImGui.TableSetColumnIndex(1); ImGui.Text('Toggle grid');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('M'); ImGui.TableSetColumnIndex(1); ImGui.Text('Toggle markers');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('F5'); ImGui.TableSetColumnIndex(1); ImGui.Text('Test play level');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Shift+Drag'); ImGui.TableSetColumnIndex(1); ImGui.Text('Select tile region');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Left / Right'); ImGui.TableSetColumnIndex(1); ImGui.Text('Scroll viewport');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Middle Drag'); ImGui.TableSetColumnIndex(1); ImGui.Text('Pan viewport');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Left Click'); ImGui.TableSetColumnIndex(1); ImGui.Text('Paint tile / commit paste');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Right Click'); ImGui.TableSetColumnIndex(1); ImGui.Text('Erase tile / cancel paste');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Alt+Click'); ImGui.TableSetColumnIndex(1); ImGui.Text('Eyedropper (pick tile)');
        ImGui.TableNextRow(ImGuiTableRowFlags_None, 0); ImGui.TableSetColumnIndex(0); ImGui.Text('Shift+Click Pipe'); ImGui.TableSetColumnIndex(1); ImGui.Text('Set pipe match code');

        ImGui.EndTable();
      end;
    end;
    ImGui.End_();
  end;

  { --- Update window title when dirty state changes --- }
  if EditorDirty <> LastDirtyState then
  begin
    LastDirtyState := EditorDirty;
    UpdateWindowTitle;
  end;

  { --- Tile Palette Panel (left column, top) --- }
  PalAvail.x := 280; PalAvail.y := 360;
  ImGui.SetNextWindowSize(PalAvail, ImGuiCond_FirstUseEver);
  ImGui.Begin_('Tile Palette', nil, ImGuiWindowFlags_None);
  if EdGetAtlasTexture <> 0 then
  begin
    PalTileSize.x := 40;  { 20 * 2x zoom }
    PalTileSize.y := 28;  { 14 * 2x zoom }

    if ImGui.BeginTabBar('TilePaletteTabs', ImGuiTabBarFlags_None) then
    begin
      for TabIdx := 0 to 8 do
      begin
        { Skip Enemies tab — now has a dedicated Enemy Palette window }
        if TabIdx = CAT_ENEMIES then Continue;
        if ImGui.BeginTabItem(PaletteTabNames[TabIdx], nil, ImGuiTabItemFlags_None) then
        begin
          { Recalculate columns inside tab content area.
            Use zero frame padding on buttons so width = image size exactly.
            Each slot = image width + 2*1px border + gap. }
          PalAvail := ImGui.GetContentRegionAvail();
          ImGui.PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2.New(1, 1));
          PalTilesPerRow := Trunc(PalAvail.x / (PalTileSize.x + 2 + 4));
          if PalTilesPerRow < 1 then PalTilesPerRow := 1;
          PalColCount := 0;
          for PalTileIdx := 0 to EdGetTileAtlasCount - 1 do
          begin
            PalEntry := EdGetTileAtlasEntry(PalTileIdx);
            if PalEntry.Category <> TabIdx then Continue;

            { Calculate UV coordinates for this tile in the atlas }
            PalUV0.x := PalEntry.AtlasCol / ATLAS_COLS;
            PalUV0.y := PalEntry.AtlasRow / ATLAS_ROWS;
            PalUV1.x := (PalEntry.AtlasCol + 1) / ATLAS_COLS;
            PalUV1.y := (PalEntry.AtlasRow + 1) / ATLAS_ROWS;

            TexID := Pointer(PtrUInt(EdGetAtlasTexture));
            PalTintCol := ImVec4.New(1, 1, 1, 1);

            { Highlight selected tile with yellow border }
            IsSelected := (not SelectedIsEnemy) and (SelectedTileIdx = PalTileIdx);
            if IsSelected then
              PalBgCol := ImVec4.New(1.0, 0.9, 0.0, 1.0)
            else
              PalBgCol := ImVec4.New(0.3, 0.3, 0.3, 1.0);

            { Use ImageButton for click-to-select }
            PalBtnID := 'tile_' + IntToStr(PalTileIdx);
            if ImGui.ImageButton(PAnsiChar(PalBtnID), TexID, PalTileSize,
              PalUV0, PalUV1, PalBgCol, PalTintCol) then
            begin
              SelectedTileIdx := PalTileIdx;
              SelectedEnemyIdx := -1;
              SelectedCharCode := PalEntry.CharCode;
              SelectedTileName := PalEntry.Name;
              SelectedIsEnemy := False;
            end;

            { Tooltip on hover }
            if ImGui.IsItemHovered(ImGuiHoveredFlags_None) then
            begin
              ImGui.BeginTooltip();
              ImGui.Text(PalEntry.Name);
              if PalEntry.CharCode >= 32 then
                ImGui.Text(AnsiString('''' + Chr(PalEntry.CharCode) + ''' #' + IntToStr(PalEntry.CharCode)))
              else if PalEntry.CharCode > 0 then
                ImGui.Text(AnsiString('#' + IntToStr(PalEntry.CharCode) + ' $' + IntToHex(PalEntry.CharCode, 2)));
              if PalEntry.ColorType <> CT_NONE then
                ImGui.Text(AnsiString('Color: $' + IntToHex(PalEntry.ColorVal, 2)));
              ImGui.EndTooltip();
            end;

            { Grid layout: wrap after fitting columns }
            Inc(PalColCount);
            if PalColCount < PalTilesPerRow then
              ImGui.SameLine(0, 4)
            else
              PalColCount := 0;
          end;

          ImGui.PopStyleVar(1);
          ImGui.EndTabItem();
        end;
      end;
      ImGui.EndTabBar();
    end;
  end
  else
    ImGui.Text('No level loaded.');
  ImGui.End_();

  { --- Level Viewport (center, main area) --- }
  ViewportFlags := ImGuiWindowFlags_NoScrollbar or ImGuiWindowFlags_NoScrollWithMouse;
  PalAvail.x := 720; PalAvail.y := 500;
  ImGui.SetNextWindowSize(PalAvail, ImGuiCond_FirstUseEver);
  ImGui.Begin_('Level Viewport', nil, ViewportFlags);

  { --- Sub-level tab bar --- }
  if EdGetNumSubLevels > 0 then
  begin
    if ImGui.BeginTabBar('SubLevelTabs', ImGuiTabBarFlags_AutoSelectNewTabs or
                                          ImGuiTabBarFlags_Reorderable or
                                          ImGuiTabBarFlags_FittingPolicyResizeDown) then
    begin
      for SubTabIdx := 0 to EdGetNumSubLevels - 1 do
      begin
        SubTabOpen := True;
        SubTabName := EdGetSubLevelName(SubTabIdx);
        if SubTabName = '' then
          SubTabName := 'Sub-level ' + Chr(Ord('A') + SubTabIdx);

        { Allow closing tabs only if more than 1 sub-level }
        if EdGetNumSubLevels > 1 then
          SubTabFlags := ImGuiTabItemFlags_None
        else
          SubTabFlags := ImGuiTabItemFlags_NoCloseWithMiddleMouseButton;

        if ImGui.BeginTabItem(PAnsiChar(SubTabName), @SubTabOpen, SubTabFlags) then
        begin
          { This tab is selected — switch sub-level if needed }
          if SubTabIdx <> EdGetActiveSubLevel then
          begin
            EdSwitchSubLevel(SubTabIdx);
            NeedRerender := True;
            ScrollX := 0;
            { Reset undo stack }
            UndoTop := 0;
            UndoBase := 0;
            RedoCount := 0;
            StrokeActive := False;
            { Reset selection state }
            SelectedTileIdx := -1;
            SelectedEnemyIdx := -1;
            SelectedCharCode := 0;
            SelectedTileName := '';
            SelectedIsEnemy := False;
            DraggingEnemy := False;
            DraggingPlayerStart := False;
            { Sync metadata buffers }
            SyncMetaBuffersFromEdRender;
          end;
          ImGui.EndTabItem;
        end;

        { Handle tab close (X button via middle-click or p_open going false) }
        if (not SubTabOpen) and (EdGetNumSubLevels > 1) then
        begin
          EdRemoveSubLevel(SubTabIdx);
          NeedRerender := True;
          UndoTop := 0;
          UndoBase := 0;
          RedoCount := 0;
          StrokeActive := False;
          SyncMetaBuffersFromEdRender;
          Break;  { Tab indices shifted, re-render next frame }
        end;
      end;

      { [+] button to add new sub-level }
      if igTabItemButton('+', ImGuiTabItemFlags_Trailing or
                               ImGuiTabItemFlags_NoTooltip) then
      begin
        if EdGetNumSubLevels < MAX_SUB_LEVELS then
        begin
          EdAddSubLevel;
          NeedRerender := True;
          ScrollX := 0;
          UndoTop := 0;
          UndoBase := 0;
          RedoCount := 0;
          StrokeActive := False;
          SyncMetaBuffersFromEdRender;
        end;
      end;

      ImGui.EndTabBar;
    end;
  end;

  LevelW := EdGetLevelWidth;

  { Re-render the level when scrolling or after loading }
  if NeedRerender then
  begin
    EdRenderLevel(ScrollX);
    NeedRerender := False;
  end;

  { Display the level texture }
  if EdGetLevelTexture <> 0 then
  begin
    TexID := Pointer(PtrUInt(EdGetLevelTexture));
    TexSize.x := EdGetViewWidth * ZoomLevel;
    TexSize.y := EdGetViewHeight * ZoomLevel;
    UV0.x := 0; UV0.y := 0;
    UV1.x := 1; UV1.y := 1;
    Tint.x := 1; Tint.y := 1; Tint.z := 1; Tint.w := 1;
    Border.x := 0; Border.y := 0; Border.z := 0; Border.w := 0;

    { Get screen position BEFORE placing the widget — guaranteed correct }
    ImgMin := ImGui.GetCursorScreenPos();
    ImgMax.x := ImgMin.x + TexSize.x;
    ImgMax.y := ImgMin.y + TexSize.y;
    DrawList := ImGui.GetWindowDrawList();

    { InvisibleButton for reliable hover + click detection in docked windows }
    ImGui.InvisibleButton('##viewport', TexSize);
    DrawList^.AddImage(TexID, ImgMin, ImgMax, UV0, UV1, $FFFFFFFF);

    { Handle scrolling with mouse wheel when hovering the viewport image }
    if ImGui.IsItemHovered(ImGuiHoveredFlags_None) then
    begin
      { Vertical mouse wheel -> horizontal level scroll }
      if IO^.MouseWheel <> 0 then
      begin
        ScrollX := ScrollX - Trunc(IO^.MouseWheel * 40);
        if ScrollX < 0 then ScrollX := 0;
        if LevelW > EdGetViewWidth then
        begin
          if ScrollX > LevelW - EdGetViewWidth then
            ScrollX := LevelW - EdGetViewWidth;
        end
        else
          ScrollX := 0;
        NeedRerender := True;
      end;
      { Horizontal mouse wheel (tilt) -> horizontal level scroll }
      if IO^.MouseWheelH <> 0 then
      begin
        ScrollX := ScrollX + Trunc(IO^.MouseWheelH * 40);
        if ScrollX < 0 then ScrollX := 0;
        if LevelW > EdGetViewWidth then
        begin
          if ScrollX > LevelW - EdGetViewWidth then
            ScrollX := LevelW - EdGetViewWidth;
        end
        else
          ScrollX := 0;
        NeedRerender := True;
      end;
    end;

    { Middle-click drag for panning — use SDL mouse position directly }
    if IsDragging and (DragLastX >= 0) then
    begin
      SDL_GetMouseState(@DragCurX, @DragCurY);
      DragDeltaX := DragCurX - DragLastX;
      if DragDeltaX <> 0 then
      begin
        ScrollX := ScrollX - Trunc(DragDeltaX / ZoomLevel);
        if ScrollX < 0 then ScrollX := 0;
        if LevelW > EdGetViewWidth then
        begin
          if ScrollX > LevelW - EdGetViewWidth then
            ScrollX := LevelW - EdGetViewWidth;
        end
        else
          ScrollX := 0;
        NeedRerender := True;
      end;
      DragLastX := DragCurX;

    end;

    { Tile size in screen pixels }
    TileW := EdGetTileW * ZoomLevel;
    TileH := EdGetTileH * ZoomLevel;

    { Sub-tile offset for grid alignment when scrolled mid-tile }
    SubTileOff := (ScrollX mod EdGetTileW) * ZoomLevel;

    { Compute hovered tile from mouse position }
    HoverTileX := -1;
    HoverTileY := -1;
    HoverTileChar := ' ';

    { Get mouse position — use ImGui.GetMousePos(), NOT IO^.MousePos which is broken (always 0,0) }
    MousePos := ImGui.GetMousePos();
    RelX := MousePos.x - ImgMin.x;
    RelY := MousePos.y - ImgMin.y;

    { Bounds check: is the mouse within the viewport image? }
    MouseInViewport := (MousePos.x >= ImgMin.x) and (MousePos.x < ImgMax.x) and
                        (MousePos.y >= ImgMin.y) and (MousePos.y < ImgMax.y);

    if MouseInViewport then
    begin
        { Convert mouse pixel position to level pixel coordinate, then to tile }
        PixInLevel := ScrollX + RelX / ZoomLevel;
        HoverTileX := Trunc(PixInLevel / EdGetTileW);
        HoverTileY := Trunc(RelY / TileH);
        if (HoverTileY >= EdGetNV) then
          HoverTileY := EdGetNV - 1;
        if (HoverTileY < 0) then
          HoverTileY := 0;
        if (HoverTileX < 0) then
          HoverTileX := 0;
        if (HoverTileX >= EdGetLevelXSize) then
          HoverTileX := EdGetLevelXSize - 1;
        HoverTileChar := EdGetTileAt(HoverTileX, HoverTileY);

        { Highlight hovered tile — cursor preview or plain highlight }
        HighRect1.x := ImgMin.x + (HoverTileX * EdGetTileW - ScrollX) * ZoomLevel;
        HighRect1.y := ImgMin.y + HoverTileY * TileH;
        HighRect2.x := HighRect1.x + TileW;
        HighRect2.y := HighRect1.y + TileH;

        if (SelectedCharCode > 0) and (not SelectedIsEnemy) and (SelectedTileIdx >= 0) then
        begin
          { Show semi-transparent preview of selected tile }
          PalEntry := EdGetTileAtlasEntry(SelectedTileIdx);
          PreviewUV0.x := PalEntry.AtlasCol / ATLAS_COLS;
          PreviewUV0.y := PalEntry.AtlasRow / ATLAS_ROWS;
          PreviewUV1.x := (PalEntry.AtlasCol + 1) / ATLAS_COLS;
          PreviewUV1.y := (PalEntry.AtlasRow + 1) / ATLAS_ROWS;
          PreviewTexID := Pointer(PtrUInt(EdGetAtlasTexture));
          DrawList^.AddImage(PreviewTexID, HighRect1, HighRect2,
            PreviewUV0, PreviewUV1, $80FFFFFF);
          DrawList^.AddRect(HighRect1, HighRect2, $FF00FFFF, 0, ImDrawFlags_None, 2.0);  { cyan border }
        end
        else if SelectedIsEnemy and (SelectedEnemyIdx >= 0) then
        begin
          { Show selected enemy sprite preview }
          EnemyEntry := EdGetEnemyAtlasEntry(SelectedEnemyIdx);
          PreviewUV0.x := (EnemyEntry.AtlasCol * ENEMY_CELL_W
                          + (ENEMY_CELL_W - EnemyEntry.SprW) div 2) / ENEMY_ATLAS_PX_W;
          PreviewUV0.y := (EnemyEntry.AtlasRow * ENEMY_CELL_H
                          + (ENEMY_CELL_H - EnemyEntry.SprH) div 2) / ENEMY_ATLAS_PX_H;
          PreviewUV1.x := PreviewUV0.x + EnemyEntry.SprW / ENEMY_ATLAS_PX_W;
          PreviewUV1.y := PreviewUV0.y + EnemyEntry.SprH / ENEMY_ATLAS_PX_H;
          PreviewTexID := Pointer(PtrUInt(EdGetEnemyAtlasTexture));
          DrawList^.AddImage(PreviewTexID, HighRect1, HighRect2,
            PreviewUV0, PreviewUV1, $80FFFFFF);
          DrawList^.AddRect(HighRect1, HighRect2, $FF00FFFF, 0, ImDrawFlags_None, 2.0);
        end
        else if DraggingEnemy then
        begin
          { Show semi-transparent enemy sprite at cursor during drag }
          EnemyIdx := EdFindEnemyAtlasIndex(DragEnemyChar);
          if EnemyIdx >= 0 then
          begin
            EnemyEntry := EdGetEnemyAtlasEntry(EnemyIdx);
            PreviewUV0.x := (EnemyEntry.AtlasCol * ENEMY_CELL_W
                            + (ENEMY_CELL_W - EnemyEntry.SprW) div 2) / ENEMY_ATLAS_PX_W;
            PreviewUV0.y := (EnemyEntry.AtlasRow * ENEMY_CELL_H
                            + (ENEMY_CELL_H - EnemyEntry.SprH) div 2) / ENEMY_ATLAS_PX_H;
            PreviewUV1.x := PreviewUV0.x + EnemyEntry.SprW / ENEMY_ATLAS_PX_W;
            PreviewUV1.y := PreviewUV0.y + EnemyEntry.SprH / ENEMY_ATLAS_PX_H;
            PreviewTexID := Pointer(PtrUInt(EdGetEnemyAtlasTexture));
            DrawList^.AddImage(PreviewTexID, HighRect1, HighRect2,
              PreviewUV0, PreviewUV1, $80FFFFFF);
          end;
          DrawList^.AddRect(HighRect1, HighRect2, $FF00FF00, 0, ImDrawFlags_None, 2.0);  { green border }
        end
        else if DraggingPlayerStart then
        begin
          { Show semi-transparent player sprite at cursor during drag }
          if EdGetPlayerSpriteTexture <> 0 then
          begin
            SprUV0.x := 0; SprUV0.y := 0;
            SprUV1.x := 1; SprUV1.y := 1;
            DrawList^.AddImage(Pointer(PtrUInt(EdGetPlayerSpriteTexture)),
              HighRect1, HighRect2, SprUV0, SprUV1, $80FFFFFF);
          end;
          DrawList^.AddRect(HighRect1, HighRect2, $FF00FF00, 0, ImDrawFlags_None, 2.0);  { green border }
        end
        else
        begin
          { No tile selected — plain yellow highlight }
          HighlightCol := $8000FFFF;  { semi-transparent yellow (ABGR) }
          DrawList^.AddRectFilled(HighRect1, HighRect2, HighlightCol);
        end;

        { --- Paint / Erase / Eyedropper / Selection --- }
        KeyMods := Integer(SDL_GetModState());

        { Alt+Left-click = eyedropper }
        if ((KeyMods and Integer(KMOD_ALT)) <> 0) and ImGui.IsMouseClicked(ImGuiMouseButton_Left) then
        begin
          EyedropperPick(HoverTileX, HoverTileY);
        end
        { Paste preview: left-click commits, right-click cancels }
        else if PastePreviewActive and ImGui.IsMouseClicked(ImGuiMouseButton_Left) and
           (not IsDragging) then
        begin
          CommitPaste(HoverTileX, HoverTileY);
        end
        else if PastePreviewActive and ImGui.IsMouseClicked(ImGuiMouseButton_Right) then
        begin
          PastePreviewActive := False;
        end
        { Shift+drag = region selection (unless on pipe top-left which opens pipe popup) }
        else if ((KeyMods and Integer(KMOD_SHIFT)) <> 0) and
           ImGui.IsMouseDown(ImGuiMouseButton_Left) and
           (not IsDragging) and (not PastePreviewActive) then
        begin
          if not SelectionDragging then
          begin
            if ImGui.IsMouseClicked(ImGuiMouseButton_Left) then
            begin
              { Check if clicking on a pipe top-left tile — if so, open pipe popup instead }
              if (HoverTileChar = '0') or
                 ((HoverTileChar = '1') and (HoverTileX > 0) and (EdGetTileAt(HoverTileX - 1, HoverTileY) = '0')) then
              begin
                if HoverTileChar = '1' then
                  PipePopupTX := HoverTileX - 1
                else
                  PipePopupTX := HoverTileX;
                PipePopupTY := HoverTileY;
                if PipePopupTY > 0 then
                begin
                  FillChar(PipePopupMatchBuf, SizeOf(PipePopupMatchBuf), 0);
                  PipeAbove := EdGetTileAt(PipePopupTX + 1, PipePopupTY - 1);
                  if (PipeAbove <> ' ') and (PipeAbove <> #0) then
                    PipePopupMatchBuf[0] := PipeAbove;
                  ShowPipePopup := True;
                  ImGui.OpenPopup('PipeMatchPopup', ImGuiPopupFlags_None);
                end;
              end
              else
              begin
                { Start region selection }
                SelectionDragging := True;
                SelectionActive := True;
                SelStartX := HoverTileX; SelStartY := HoverTileY;
                SelEndX := HoverTileX; SelEndY := HoverTileY;
                NormalizeSelection;
              end;
            end;
          end
          else
          begin
            { Continue dragging — update end point }
            SelEndX := HoverTileX; SelEndY := HoverTileY;
            NormalizeSelection;
          end;
        end
        { Left-click drag = paint selected tile OR drag-reposition enemy/player start }
        else if ImGui.IsMouseDown(ImGuiMouseButton_Left) and (not IsDragging) and
           (not DraggingEnemy) and (not DraggingPlayerStart) and
           (not SelectionDragging) and (not PastePreviewActive) and
           ((KeyMods and Integer(KMOD_ALT)) = 0) then
        begin
          if SelectedCharCode > 0 then
          begin
            { Normal painting mode }
            if not IsPainting then
            begin
              BeginStroke;
              IsPainting := True;
              LastPaintTileX := -1;
              LastPaintTileY := -1;
            end;
            if (HoverTileX <> LastPaintTileX) or (HoverTileY <> LastPaintTileY) then
            begin
              PlaceTile(HoverTileX, HoverTileY, Chr(SelectedCharCode));
              LastPaintTileX := HoverTileX;
              LastPaintTileY := HoverTileY;
            end;
          end
          else if ImGui.IsMouseClicked(ImGuiMouseButton_Left) then
          begin
            { No tile selected: check if clicking on player start or enemy to drag }
            if (HoverTileX = EdGetPlayerStartX) and (HoverTileY = EdGetPlayerStartY) then
            begin
              DraggingPlayerStart := True;
            end
            else if HoverTileChar in [#$80, #$81, #$82, #$83,
                                 #$84, #$85, #$86, #$87,
                                 #$88, #$89, #$8A,
                                 #$B0, #$B1] then
            begin
              DraggingEnemy := True;
              DragEnemySrcX := HoverTileX;
              DragEnemySrcY := HoverTileY;
              DragEnemyChar := HoverTileChar;
            end;
          end;
        end
        { Continue dragging enemy or player start }
        else if (DraggingEnemy or DraggingPlayerStart) and
                ImGui.IsMouseDown(ImGuiMouseButton_Left) then
        begin
          { Visual feedback is handled below in the overlay section }
        end;

        { Right-click drag = erase (place space) }
        if ImGui.IsMouseDown(ImGuiMouseButton_Right) and (not IsDragging) and
           (not SelectionDragging) and (not PastePreviewActive) then
        begin
          if not IsErasing then
          begin
            BeginStroke;
            IsErasing := True;
            LastPaintTileX := -1;
            LastPaintTileY := -1;
          end;
          if (HoverTileX <> LastPaintTileX) or (HoverTileY <> LastPaintTileY) then
          begin
            PlaceTile(HoverTileX, HoverTileY, ' ');
            LastPaintTileX := HoverTileX;
            LastPaintTileY := HoverTileY;
          end;
        end;

        { Tooltip with tile info }
        if (not IsPainting) and (not IsErasing) then
        begin
          ImGui.BeginTooltip();
          TileName := GetTileName(HoverTileChar, HoverTileX, HoverTileY);
          if TileName <> '' then
            ImGui.Text(AnsiString(TileName));
          ImGui.Text(AnsiString('(' + IntToStr(HoverTileX) + ', ' + IntToStr(HoverTileY) + ')'));
          if Ord(HoverTileChar) >= 32 then
            ImGui.Text(AnsiString('''' + HoverTileChar + ''' #' + IntToStr(Ord(HoverTileChar))))
          else
            ImGui.Text(AnsiString('#' + IntToStr(Ord(HoverTileChar)) + ' $' + IntToHex(Ord(HoverTileChar), 2)));
          { Show block content for ? and $ blocks }
          if HoverTileChar in ['?', '$'] then
          begin
            BlockContent := GetBlockContent(HoverTileX, HoverTileY);
            if BlockContent <> '' then
              ImGui.TextColored(ImVec4.New(1.0, 0.9, 0.3, 1.0), AnsiString('Contains: ' + BlockContent))
            else
              ImGui.TextColored(ImVec4.New(0.6, 0.6, 0.6, 1.0), 'Contains: Coin');
          end;
          { Show selected tile info }
          if SelectedCharCode > 0 then
            ImGui.TextColored(ImVec4.New(0.3, 1.0, 0.3, 1.0), AnsiString('Paint: ' + SelectedTileName));
          ImGui.EndTooltip();
        end;
    end;

    { Finalize strokes when mouse released }
    if IsPainting and (not ImGui.IsMouseDown(ImGuiMouseButton_Left)) then
    begin
      FinalizeStroke;
      IsPainting := False;
      LastPaintTileX := -1;
      LastPaintTileY := -1;
    end;
    if IsErasing and (not ImGui.IsMouseDown(ImGuiMouseButton_Right)) then
    begin
      FinalizeStroke;
      IsErasing := False;
      LastPaintTileX := -1;
      LastPaintTileY := -1;
    end;
    { Finalize enemy drag when mouse released }
    if DraggingEnemy and (not ImGui.IsMouseDown(ImGuiMouseButton_Left)) then
    begin
      { Drop enemy at current hover tile (if valid and different from source) }
      if (HoverTileX >= 0) and (HoverTileY >= 0) and
         ((HoverTileX <> DragEnemySrcX) or (HoverTileY <> DragEnemySrcY)) then
      begin
        BeginStroke;
        PlaceTile(DragEnemySrcX, DragEnemySrcY, ' ');
        PlaceTile(HoverTileX, HoverTileY, DragEnemyChar);
        FinalizeStroke;
      end;
      DraggingEnemy := False;
      DragEnemySrcX := -1;
      DragEnemySrcY := -1;
      DragEnemyChar := #0;
    end;
    { Finalize player start drag when mouse released }
    if DraggingPlayerStart and (not ImGui.IsMouseDown(ImGuiMouseButton_Left)) then
    begin
      if (HoverTileX >= 0) and (HoverTileY >= 0) and
         (HoverTileX < EdGetLevelXSize) and (HoverTileY < EdGetNV) and
         ((HoverTileX <> EdGetPlayerStartX) or (HoverTileY <> EdGetPlayerStartY)) then
      begin
        EdSetPlayerStartX(HoverTileX);
        EdSetPlayerStartY(HoverTileY);
        NeedRerender := True;
        EditorDirty := True;
      end;
      DraggingPlayerStart := False;
    end;
    { Finalize selection drag when mouse released }
    if SelectionDragging and (not ImGui.IsMouseDown(ImGuiMouseButton_Left)) then
      SelectionDragging := False;

    { Draw grid overlay — lines align to tile boundaries accounting for scroll }
    if ShowGrid then
    begin
      GridCol := $40FFFFFF;  { semi-transparent white }

      { Vertical lines — offset by sub-tile scroll amount }
      for i := 0 to EdGetViewWidth div EdGetTileW + 1 do
      begin
        P1.x := ImgMin.x + i * TileW - SubTileOff;
        if (P1.x >= ImgMin.x) and (P1.x <= ImgMax.x) then
        begin
          P1.y := ImgMin.y;
          P2.x := P1.x;
          P2.y := ImgMax.y;
          DrawList^.AddLine(P1, P2, GridCol, 1.0);
        end;
      end;

      { Horizontal lines }
      for i := 0 to EdGetNV do
      begin
        P1.x := ImgMin.x;
        P1.y := ImgMin.y + i * TileH;
        P2.x := ImgMax.x;
        P2.y := P1.y;
        DrawList^.AddLine(P1, P2, GridCol, 1.0);
      end;
    end;

    { --- Draw enemy/item/player markers --- }
    if ShowMarkers then
    begin
      DrawList^.PushClipRect(ImgMin, ImgMax, True);

      { Calculate visible tile range }
      FirstTileX := ScrollX div EdGetTileW;
      if FirstTileX < 0 then FirstTileX := 0;
      LastTileX := FirstTileX + EdGetViewWidth div EdGetTileW + 2;
      if LastTileX >= EdGetLevelXSize then
        LastTileX := EdGetLevelXSize - 1;

      if TileW < TileH then MarkerRadius := TileW * 0.35
      else MarkerRadius := TileH * 0.35;
      MarkerLabel[1] := #0;  { null terminator for label string }
      EnemyTexID := Pointer(PtrUInt(EdGetEnemyAtlasTexture));

      for tx := FirstTileX to LastTileX do
        for ty := 0 to EdGetNV - 1 do
        begin
          MarkerCh := EdGetTileAt(tx, ty);

          { First try to render as an enemy sprite }
          EnemyIdx := EdFindEnemyAtlasIndex(MarkerCh);
          if EnemyIdx >= 0 then
          begin
            EnemyEntry := EdGetEnemyAtlasEntry(EnemyIdx);

            { Compute screen position of this tile's top-left }
            SprP1.x := ImgMin.x + (tx * EdGetTileW - ScrollX) * ZoomLevel;
            SprP1.y := ImgMin.y + ty * EdGetTileH * ZoomLevel;

            { Sprite display size at current zoom }
            SprDispW := EnemyEntry.SprW * ZoomLevel;
            SprDispH := EnemyEntry.SprH * ZoomLevel;

            { Horizontal positioning }
            if MarkerCh in [#$84, #$85, #$86] then
              { Piranha Plants: center across 2-tile-wide pipe }
              SprP1.x := SprP1.x + (EdGetTileW * 2 * ZoomLevel - SprDispW) * 0.5
            else
              { Default: center within single tile }
              SprP1.x := SprP1.x + (EdGetTileW * ZoomLevel - SprDispW) * 0.5;

            { Vertical positioning depends on enemy type }
            if MarkerCh in [#$84, #$85, #$86] then
              { Piranha Plants: tile code is above pipe; shift down so
                sprite sits on the pipe top (align bottom to next tile's bottom) }
              SprP1.y := SprP1.y + (EdGetTileH * 2 * ZoomLevel - SprDispH)
            else if EnemyEntry.SprH > EdGetTileH then
              { Tall sprites (Koopa) extend upward from tile bottom }
              SprP1.y := SprP1.y + (EdGetTileH * ZoomLevel - SprDispH)
            else
              { Normal sprites center vertically }
              SprP1.y := SprP1.y + (EdGetTileH * ZoomLevel - SprDispH) * 0.5;

            SprP2.x := SprP1.x + SprDispW;
            SprP2.y := SprP1.y + SprDispH;

            { Skip if outside viewport }
            if (SprP2.x < ImgMin.x) or (SprP1.x > ImgMax.x) then
              Continue;

            { Compute UV coordinates for this sprite in the enemy atlas }
            SprUV0.x := (EnemyEntry.AtlasCol * ENEMY_CELL_W
                        + (ENEMY_CELL_W - EnemyEntry.SprW) div 2) / ENEMY_ATLAS_PX_W;
            SprUV0.y := (EnemyEntry.AtlasRow * ENEMY_CELL_H
                        + (ENEMY_CELL_H - EnemyEntry.SprH) div 2) / ENEMY_ATLAS_PX_H;
            SprUV1.x := SprUV0.x + EnemyEntry.SprW / ENEMY_ATLAS_PX_W;
            SprUV1.y := SprUV0.y + EnemyEntry.SprH / ENEMY_ATLAS_PX_H;

            DrawList^.AddImage(EnemyTexID, SprP1, SprP2, SprUV0, SprUV1, $FFFFFFFF);

            { Draw direction arrow for walking enemies (they always walk left initially) }
            if not (MarkerCh in [#$84, #$85, #$86,   { Piranha Plants }
                                 #$81,                 { Fish (vertical) }
                                 #$82,                 { Fireball (vertical) }
                                 #$B0, #$B1]) then     { Lifts/platforms }
            begin
              { Small left-pointing triangle at the left side of the sprite }
              ArrowTip.x := SprP1.x - 2 * ZoomLevel;
              ArrowTip.y := (SprP1.y + SprP2.y) * 0.5;
              ArrowTop.x := SprP1.x + 1 * ZoomLevel;
              ArrowTop.y := ArrowTip.y - 3 * ZoomLevel;
              ArrowBot.x := SprP1.x + 1 * ZoomLevel;
              ArrowBot.y := ArrowTip.y + 3 * ZoomLevel;
              DrawList^.AddTriangleFilled(ArrowTip, ArrowTop, ArrowBot, $CC00CCFF);
            end;

            Continue;  { Don't fall through to marker drawing }
          end;

          { Palette-dependent deco tiles: draw from tile atlas as overlay
            because Redraw uses wrong palette indices for these }
          if EdNeedsOverlay(Ord(MarkerCh)) then
          begin
            OverlayAtlasIdx := EdFindTileAtlasIndex(Ord(MarkerCh));
            if OverlayAtlasIdx >= 0 then
            begin
              OverlayEntry := EdGetTileAtlasEntry(OverlayAtlasIdx);
              SprP1.x := ImgMin.x + (tx * EdGetTileW - ScrollX) * ZoomLevel;
              SprP1.y := ImgMin.y + ty * EdGetTileH * ZoomLevel;
              SprP2.x := SprP1.x + EdGetTileW * ZoomLevel;
              SprP2.y := SprP1.y + EdGetTileH * ZoomLevel;

              if (SprP2.x >= ImgMin.x) and (SprP1.x <= ImgMax.x) then
              begin
                AtlasTexID := Pointer(PtrUInt(EdGetAtlasTexture));
                SprUV0.x := OverlayEntry.AtlasCol * EdGetTileW / ATLAS_PX_W;
                SprUV0.y := OverlayEntry.AtlasRow * EdGetTileH / ATLAS_PX_H;
                SprUV1.x := SprUV0.x + EdGetTileW / ATLAS_PX_W;
                SprUV1.y := SprUV0.y + EdGetTileH / ATLAS_PX_H;
                DrawList^.AddImage(AtlasTexID, SprP1, SprP2, SprUV0, SprUV1, $FFFFFFFF);
              end;
            end;
            Continue;
          end;

          { For non-enemy marker tiles (hidden blocks), use the original marker style }
          if GetMarkerInfo(MarkerCh, MarkerLab, MarkerCol, MarkerIsRect) then
          begin
            { Compute screen position of this tile's center }
            MarkerCenter.x := ImgMin.x + (tx * EdGetTileW - ScrollX + EdGetTileW div 2) * ZoomLevel;
            MarkerCenter.y := ImgMin.y + (ty * EdGetTileH + EdGetTileH div 2) * ZoomLevel;

            { Skip if outside viewport }
            if (MarkerCenter.x < ImgMin.x - TileW) or (MarkerCenter.x > ImgMax.x + TileW) then
              Continue;

            if MarkerIsRect then
            begin
              { Rectangle marker for hidden blocks }
              MarkerR1.x := MarkerCenter.x - TileW * 0.45;
              MarkerR1.y := MarkerCenter.y - TileH * 0.45;
              MarkerR2.x := MarkerCenter.x + TileW * 0.45;
              MarkerR2.y := MarkerCenter.y + TileH * 0.45;
              if MarkerCh = '$' then
                DrawList^.AddRect(MarkerR1, MarkerR2, MarkerCol, 0, ImDrawFlags_None, 2.0)
              else
                DrawList^.AddRectFilled(MarkerR1, MarkerR2, MarkerCol);
            end
            else
              DrawList^.AddCircleFilled(MarkerCenter, MarkerRadius, MarkerCol, 12);

            { Draw label letter centered on the marker }
            MarkerLabel[0] := MarkerLab;
            TextSize := ImGui.CalcTextSize(@MarkerLabel[0], nil, False, -1.0);
            TextPos.x := MarkerCenter.x - TextSize.x * 0.5;
            TextPos.y := MarkerCenter.y - TextSize.y * 0.5;
            DrawList^.AddText(TextPos, $FFFFFFFF, @MarkerLabel[0], nil);
          end;
        end;

      { --- Question/Hidden block content indicators --- }
      ContentLabel[1] := #0;
      if TileW < TileH then ContentR := TileW * 0.22
      else ContentR := TileH * 0.22;
      for tx := FirstTileX to LastTileX do
        for ty := 0 to EdGetNV - 1 do
        begin
          MarkerCh := EdGetTileAt(tx, ty);
          if MarkerCh in ['?', '$'] then
          begin
            BlockContent := GetBlockContent(tx, ty);
            if BlockContent = '' then
              Continue;  { default coin — no special indicator needed }

            { Determine indicator letter and color based on content }
            ContentLabel[0] := 'C';
            MarkerCol := $CC00CCFF;  { yellow default for coin }

            if BlockContent = 'Mushroom / Fire Flower' then
            begin ContentLabel[0] := 'M'; MarkerCol := $CC0000FF; end  { red }
            else if BlockContent = '1-Up Mushroom' then
            begin ContentLabel[0] := '1'; MarkerCol := $CC00CC00; end  { green }
            else if BlockContent = 'Star' then
            begin ContentLabel[0] := 'S'; MarkerCol := $CC00FFFF; end  { bright yellow }
            else if BlockContent = 'Poison Mushroom' then
            begin ContentLabel[0] := 'X'; MarkerCol := $CC0000AA; end  { dark red }
            else if (Pos('Coins', BlockContent) > 0) then
            begin ContentLabel[0] := '$'; MarkerCol := $CC00CCFF; end; { gold for multi-coin }

            { Draw small indicator circle at top-right corner of tile }
            ContentCenter.x := ImgMin.x + ((tx + 1) * EdGetTileW - ScrollX - EdGetTileW div 4) * ZoomLevel;
            ContentCenter.y := ImgMin.y + (ty * EdGetTileH + EdGetTileH div 4) * ZoomLevel;

            { Skip if outside viewport }
            if (ContentCenter.x < ImgMin.x) or (ContentCenter.x > ImgMax.x) then
              Continue;

            DrawList^.AddCircleFilled(ContentCenter, ContentR, MarkerCol, 10);
            { Draw label centered }
            TextSize := ImGui.CalcTextSize(@ContentLabel[0], nil, False, -1.0);
            TextPos.x := ContentCenter.x - TextSize.x * 0.5;
            TextPos.y := ContentCenter.y - TextSize.y * 0.5;
            DrawList^.AddText(TextPos, $FFFFFFFF, @ContentLabel[0], nil);
          end;
        end;

      { --- Pipe action markers (arrow + text on pipes with entry/exit/warp codes) --- }
      for tx := FirstTileX to LastTileX do
        for ty := 0 to EdGetNV - 1 do
        begin
          MarkerCh := EdGetTileAt(tx, ty);
          { Only process pipe top-left tiles }
          if MarkerCh <> '0' then Continue;
          { Check if the tile above has a pipe action code }
          if ty <= 0 then Continue;
          PipeAbove := EdGetTileAt(tx, ty - 1);
          if not (PipeAbove in [#$E0..#$E7]) then Continue;

          { Determine action label and color }
          case PipeAbove of
            #$E0: begin PipeActionLabel := 'WARP';  PipeActionCol := $CC00CC00; end;  { green }
            #$E1: begin PipeActionLabel := 'SWAP';  PipeActionCol := $CCFFCC00; end;  { cyan }
            #$E7: begin PipeActionLabel := 'EXIT';  PipeActionCol := $CC0055FF; end;  { red-orange }
          else
            begin PipeActionLabel := 'PIPE';  PipeActionCol := $CC888888; end;  { grey }
          end;

          { Calculate center of the pipe top (spans 2 tiles: '0' and '1') }
          MarkerCenter.x := ImgMin.x + (tx * EdGetTileW - ScrollX + EdGetTileW) * ZoomLevel;
          MarkerCenter.y := ImgMin.y + (ty * EdGetTileH + EdGetTileH div 2) * ZoomLevel;

          { Skip if outside viewport }
          if (MarkerCenter.x < ImgMin.x - TileW) or (MarkerCenter.x > ImgMax.x + TileW) then
            Continue;

          { Draw downward arrow (triangle) above the pipe center }
          PipeArrowTop.x := MarkerCenter.x;
          PipeArrowTop.y := MarkerCenter.y - TileH * 0.9;
          PipeArrowBL.x := MarkerCenter.x - TileW * 0.35;
          PipeArrowBL.y := MarkerCenter.y - TileH * 1.5;
          PipeArrowBR.x := MarkerCenter.x + TileW * 0.35;
          PipeArrowBR.y := MarkerCenter.y - TileH * 1.5;
          DrawList^.AddTriangleFilled(PipeArrowTop, PipeArrowBL, PipeArrowBR, PipeActionCol);

          { Draw text label background above the arrow }
          PipeLabelLen := Length(PipeActionLabel);
          if PipeLabelLen > 15 then PipeLabelLen := 15;
          Move(PipeActionLabel[1], PipeActionBuf[0], PipeLabelLen);
          PipeActionBuf[PipeLabelLen] := #0;

          TextSize := ImGui.CalcTextSize(@PipeActionBuf[0], nil, False, -1.0);
          PipeBgR1.x := MarkerCenter.x - TextSize.x * 0.5 - 3;
          PipeBgR1.y := PipeArrowBL.y - TextSize.y - 4;
          PipeBgR2.x := MarkerCenter.x + TextSize.x * 0.5 + 3;
          PipeBgR2.y := PipeArrowBL.y - 1;
          DrawList^.AddRectFilled(PipeBgR1, PipeBgR2, PipeActionCol);

          { Draw text label }
          TextPos.x := MarkerCenter.x - TextSize.x * 0.5;
          TextPos.y := PipeBgR1.y + 1;
          DrawList^.AddText(TextPos, $FFFFFFFF, @PipeActionBuf[0], nil);
        end;

      { --- Pipe warp connection lines (bezier curves between matched pipes) --- }
      PipeConnColors[0] := $CC00CC00;  { green }
      PipeConnColors[1] := $CCFF8800;  { blue }
      PipeConnColors[2] := $CC0088FF;  { orange }
      PipeConnColors[3] := $CCFF00FF;  { magenta }
      PipeConnColors[4] := $CC00FFFF;  { yellow }
      PipeConnColors[5] := $CCFFCC00;  { cyan }
      PipeConnColors[6] := $CC8800FF;  { purple }
      PipeConnColors[7] := $CC00FF88;  { lime }

      { Collect all warp/swap pipes across entire level (not just visible) }
      PipeCount := 0;
      for tx := 0 to EdGetLevelXSize - 1 do
        for ty := 1 to EdGetNV - 1 do
        begin
          if PipeCount >= 64 then Break;
          MarkerCh := EdGetTileAt(tx, ty);
          if MarkerCh <> '0' then Continue;
          PipeAbove := EdGetTileAt(tx, ty - 1);
          if not (PipeAbove in [#$E0..#$EF]) then Continue;
          { Match code is to the right of the action code }
          PipeInfoMatch[PipeCount] := EdGetTileAt(tx + 1, ty - 1);
          { Screen center }
          PipeInfoCX[PipeCount] := ImgMin.x + (tx * EdGetTileW - ScrollX + EdGetTileW) * ZoomLevel;
          PipeInfoCY[PipeCount] := ImgMin.y + (ty * EdGetTileH + EdGetTileH div 2) * ZoomLevel;
          Inc(PipeCount);
        end;

      { Draw bezier curves between matched pipe pairs }
      for PipeI := 0 to PipeCount - 2 do
        for PipeJ := PipeI + 1 to PipeCount - 1 do
        begin
          if (PipeInfoMatch[PipeI] = PipeInfoMatch[PipeJ]) and
             (PipeInfoMatch[PipeI] <> ' ') and (PipeInfoMatch[PipeI] <> #0) then
          begin
            BezP1.x := PipeInfoCX[PipeI];
            BezP1.y := PipeInfoCY[PipeI];
            BezP2.x := PipeInfoCX[PipeJ];
            BezP2.y := PipeInfoCY[PipeJ];

            { Arc upward — use a gentle fraction of distance, capped so
              the curve stays within the viewport bounds }
            BezDist := Abs(BezP2.x - BezP1.x) * 0.15;
            if BezDist < 30 then BezDist := 30;
            if BezDist > (ImgMax.y - ImgMin.y) * 0.4 then
              BezDist := (ImgMax.y - ImgMin.y) * 0.4;

            BezC1.x := BezP1.x;
            BezC1.y := BezP1.y - BezDist;
            BezC2.x := BezP2.x;
            BezC2.y := BezP2.y - BezDist;

            { Pick color based on match code }
            PipeColorIdx := Ord(PipeInfoMatch[PipeI]) mod 8;
            DrawList^.AddBezierCubic(BezP1, BezC1, BezC2, BezP2,
              PipeConnColors[PipeColorIdx], 2.0, 20);

            { Draw match code label at midpoint }
            BezMid.x := (BezP1.x + BezP2.x) * 0.5;
            BezMid.y := (BezC1.y + BezC2.y) * 0.5;
            PipeMatchLabel[0] := PipeInfoMatch[PipeI];
            PipeMatchLabel[1] := #0;
            TextSize := ImGui.CalcTextSize(@PipeMatchLabel[0], nil, False, -1.0);
            { Draw background rect }
            PipeBgR1.x := BezMid.x - TextSize.x * 0.5 - 2;
            PipeBgR1.y := BezMid.y - TextSize.y * 0.5 - 1;
            PipeBgR2.x := BezMid.x + TextSize.x * 0.5 + 2;
            PipeBgR2.y := BezMid.y + TextSize.y * 0.5 + 1;
            DrawList^.AddRectFilled(PipeBgR1, PipeBgR2, PipeConnColors[PipeColorIdx]);
            TextPos.x := BezMid.x - TextSize.x * 0.5;
            TextPos.y := BezMid.y - TextSize.y * 0.5;
            DrawList^.AddText(TextPos, $FFFFFFFF, @PipeMatchLabel[0], nil);
          end;
        end;

      { --- Player start marker (always shown when markers enabled) --- }
      PlayerTX := EdGetPlayerStartX;
      PlayerTY := EdGetPlayerStartY;

      { Position: bottom-align player sprite to tile bottom, center horizontally }
      SprDispW := PLAYER_SPR_W * ZoomLevel;
      SprDispH := PLAYER_SPR_H * ZoomLevel;
      SprP1.x := ImgMin.x + (PlayerTX * EdGetTileW - ScrollX) * ZoomLevel
                 + (EdGetTileW * ZoomLevel - SprDispW) * 0.5;
      SprP1.y := ImgMin.y + (PlayerTY + 1) * EdGetTileH * ZoomLevel - SprDispH;
      SprP2.x := SprP1.x + SprDispW;
      SprP2.y := SprP1.y + SprDispH;

      if (SprP2.x >= ImgMin.x) and (SprP1.x <= ImgMax.x) then
      begin
        if EdGetPlayerSpriteTexture <> 0 then
        begin
          SprUV0.x := 0; SprUV0.y := 0;
          SprUV1.x := 1; SprUV1.y := 1;
          DrawList^.AddImage(Pointer(PtrUInt(EdGetPlayerSpriteTexture)),
            SprP1, SprP2, SprUV0, SprUV1, $FFFFFFFF);
        end;
      end;

      { --- Camera lock markers (vertical lines with labels) --- }
      CamLockCount := EdGetCameraLocks(CamLocks, 32);
      for CamLockIdx := 0 to CamLockCount - 1 do
      begin
        { The lock is at this column in the hidden row.
          For RIGHT locks (#255), the game checks column (XView-1) div W + NH,
          so the visible right edge of the viewport hits this column.
          For LEFT locks (#254), the game checks column XView div W.
          Draw a vertical line at the tile column boundary. }
        if CamLocks[CamLockIdx].LockType = CAM_LOCK_RIGHT then
        begin
          { Right lock: draw line at the LEFT edge of this tile column }
          CamLockX := ImgMin.x + (CamLocks[CamLockIdx].Col * EdGetTileW - ScrollX) * ZoomLevel;
          CamLockCol := $CC00CCFF;  { yellow }
          CamLockLabel := 'CAM LOCK >';
        end
        else
        begin
          { Left lock: draw line at the RIGHT edge of this tile column }
          CamLockX := ImgMin.x + ((CamLocks[CamLockIdx].Col + 1) * EdGetTileW - ScrollX) * ZoomLevel;
          CamLockCol := $CC00CCFF;  { yellow }
          CamLockLabel := '< CAM LOCK';
        end;

        { Skip if outside viewport }
        if (CamLockX < ImgMin.x) or (CamLockX > ImgMax.x) then
          Continue;

        { Draw vertical dashed-style line spanning full viewport }
        CamLockLineTop.x := CamLockX;
        CamLockLineTop.y := ImgMin.y;
        CamLockLineBot.x := CamLockX;
        CamLockLineBot.y := ImgMax.y;
        DrawList^.AddLine(CamLockLineTop, CamLockLineBot, CamLockCol, 2.0);

        { Draw label background + text at top of line }
        PipeLabelLen := Length(CamLockLabel);
        if PipeLabelLen > 15 then PipeLabelLen := 15;
        Move(CamLockLabel[1], CamLockBuf[0], PipeLabelLen);
        CamLockBuf[PipeLabelLen] := #0;

        TextSize := ImGui.CalcTextSize(@CamLockBuf[0], nil, False, -1.0);
        CamLockBgR1.x := CamLockX - TextSize.x * 0.5 - 3;
        CamLockBgR1.y := ImgMin.y + 2;
        CamLockBgR2.x := CamLockX + TextSize.x * 0.5 + 3;
        CamLockBgR2.y := ImgMin.y + TextSize.y + 5;
        DrawList^.AddRectFilled(CamLockBgR1, CamLockBgR2, CamLockCol);

        TextPos.x := CamLockX - TextSize.x * 0.5;
        TextPos.y := ImgMin.y + 3;
        DrawList^.AddText(TextPos, $FF000000, @CamLockBuf[0], nil);
      end;

      { --- Selection Rectangle Overlay --- }
      if SelectionActive then
      begin
        SelP1.x := ImgMin.x + (SelMinX * EdGetTileW - ScrollX) * ZoomLevel;
        SelP1.y := ImgMin.y + SelMinY * TileH;
        SelP2.x := ImgMin.x + ((SelMaxX + 1) * EdGetTileW - ScrollX) * ZoomLevel;
        SelP2.y := ImgMin.y + (SelMaxY + 1) * TileH;
        DrawList^.AddRectFilled(SelP1, SelP2, $300080FF);
        DrawList^.AddRect(SelP1, SelP2, $FFFFFFFF, 0, ImDrawFlags_None, 2.0);
      end;

      { --- Paste Preview Overlay --- }
      if PastePreviewActive and (ClipWidth > 0) and (HoverTileX >= 0) then
      begin
        for PasteY := 0 to ClipHeight - 1 do
          for PasteX := 0 to ClipWidth - 1 do
          begin
            PasteCh := ClipBuf[(PasteY * ClipWidth) + PasteX + 1];
            if PasteCh <> ' ' then
            begin
              PasteTileIdx := EdFindTileAtlasIndex(Ord(PasteCh));
              if PasteTileIdx >= 0 then
              begin
                PasteEntry := EdGetTileAtlasEntry(PasteTileIdx);
                PasteP1.x := ImgMin.x + ((HoverTileX + PasteX) * EdGetTileW - ScrollX) * ZoomLevel;
                PasteP1.y := ImgMin.y + (HoverTileY + PasteY) * TileH;
                PasteP2.x := PasteP1.x + TileW;
                PasteP2.y := PasteP1.y + TileH;
                PasteUV0.x := PasteEntry.AtlasCol / ATLAS_COLS;
                PasteUV0.y := PasteEntry.AtlasRow / ATLAS_ROWS;
                PasteUV1.x := (PasteEntry.AtlasCol + 1) / ATLAS_COLS;
                PasteUV1.y := (PasteEntry.AtlasRow + 1) / ATLAS_ROWS;
                DrawList^.AddImage(Pointer(PtrUInt(EdGetAtlasTexture)),
                  PasteP1, PasteP2, PasteUV0, PasteUV1, $80FFFFFF);
              end;
            end;
          end;
        PasteP1.x := ImgMin.x + (HoverTileX * EdGetTileW - ScrollX) * ZoomLevel;
        PasteP1.y := ImgMin.y + HoverTileY * TileH;
        PasteP2.x := PasteP1.x + ClipWidth * TileW;
        PasteP2.y := PasteP1.y + ClipHeight * TileH;
        DrawList^.AddRect(PasteP1, PasteP2, $FF00FF00, 0, ImDrawFlags_None, 2.0);
      end;

      DrawList^.PopClipRect;
    end;
  end
  else
    ImGui.Text('No level loaded. Use File > Open Built-In.');

  ImGui.End_();

  { --- Level Settings Panel (right side) --- }
  PalAvail.x := 275; PalAvail.y := 260;
  ImGui.SetNextWindowSize(PalAvail, ImGuiCond_FirstUseEver);
  ImGui.Begin_('Level Settings', nil, ImGuiWindowFlags_None);
  ImGui.Text(AnsiString('Level: ' + LevelNames[CurrentLevel]));
  ImGui.Text(AnsiString('Sky:   ' + EdGetSkyTypeName(EdGetSkyType)
    + ' (' + IntToStr(EdGetSkyType) + ')'));
  ImGui.Text(AnsiString('BG:    ' + EdGetBackGrTypeName(EdGetBackGrType)
    + ' (' + IntToStr(EdGetBackGrType) + ')'));
  { Music track combo box }
  ImGui.Text('Music:');
  ImGui.SameLine(0, 4);
  ImGui.PushItemWidth(160);
  CurMusic := EdGetMusicTrack;
  if CurMusic = '' then
    MusicPreview := '(default)'
  else
    MusicPreview := CurMusic;
  MusicChanged := False;
  if ImGui.BeginCombo('##MusicTrack', MusicPreview, ImGuiComboFlags_None) then
  begin
    if ImGui.Selectable('(default)', CurMusic = '', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack(''); MusicChanged := True; end;
    if ImGui.Selectable('level1.ogg', CurMusic = 'level1.ogg', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack('level1.ogg'); MusicChanged := True; end;
    if ImGui.Selectable('level2.ogg', CurMusic = 'level2.ogg', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack('level2.ogg'); MusicChanged := True; end;
    if ImGui.Selectable('level3.ogg', CurMusic = 'level3.ogg', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack('level3.ogg'); MusicChanged := True; end;
    if ImGui.Selectable('level4.ogg', CurMusic = 'level4.ogg', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack('level4.ogg'); MusicChanged := True; end;
    if ImGui.Selectable('level5.ogg', CurMusic = 'level5.ogg', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack('level5.ogg'); MusicChanged := True; end;
    if ImGui.Selectable('level6.ogg', CurMusic = 'level6.ogg', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack('level6.ogg'); MusicChanged := True; end;
    if ImGui.Selectable('sublevel.ogg', CurMusic = 'sublevel.ogg', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack('sublevel.ogg'); MusicChanged := True; end;
    if ImGui.Selectable('menu.ogg', CurMusic = 'menu.ogg', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack('menu.ogg'); MusicChanged := True; end;
    if ImGui.Selectable('gameover.ogg', CurMusic = 'gameover.ogg', ImGuiSelectableFlags_None, ImVec2.New(0, 0)) then
    begin EdSetMusicTrack('gameover.ogg'); MusicChanged := True; end;
    ImGui.EndCombo();
  end;
  if MusicChanged then EditorDirty := True;
  ImGui.PopItemWidth();
  ImGui.Separator();
  { Level metadata fields }
  ImGui.Text('-- Level Metadata --');
  ImGui.PushItemWidth(-1);
  ImGui.Text('Name:');
  if ImGui.InputText('##MetaName', @MetaNameBuf[0], SizeOf(MetaNameBuf),
    ImGuiInputTextFlags_None, nil, nil) then
    EditorDirty := True;
  ImGui.Text('Creator:');
  if ImGui.InputText('##MetaCreator', @MetaCreatorBuf[0], SizeOf(MetaCreatorBuf),
    ImGuiInputTextFlags_None, nil, nil) then
    EditorDirty := True;
  ImGui.Text('Description:');
  if ImGui.InputText('##MetaDesc', @MetaDescBuf[0], SizeOf(MetaDescBuf),
    ImGuiInputTextFlags_None, nil, nil) then
    EditorDirty := True;
  ImGui.PopItemWidth();
  ImGui.Separator();
  ImGui.Text(AnsiString('Scroll: ' + IntToStr(ScrollX) + ' / ' + IntToStr(LevelW) + ' px'));
  ImGui.Text(AnsiString('Zoom: ' + IntToStr(ZoomLevel) + 'x'));
  ImGui.Separator();
  if HoverTileX >= 0 then
  begin
    TileName := GetTileName(HoverTileChar, HoverTileX, HoverTileY);
    ImGui.Text(AnsiString('Tile: (' + IntToStr(HoverTileX) + ', ' + IntToStr(HoverTileY) + ')'));
    if Ord(HoverTileChar) >= 32 then
      ImGui.Text(AnsiString('Char: ''' + HoverTileChar + ''' (#' + IntToStr(Ord(HoverTileChar)) + ')'))
    else
      ImGui.Text(AnsiString('Char: #' + IntToStr(Ord(HoverTileChar)) + ' ($' + IntToHex(Ord(HoverTileChar), 2) + ')'));
    if TileName <> '' then
      ImGui.Text(AnsiString('Type: ' + TileName));
    if HoverTileChar in ['?', '$'] then
    begin
      BlockContent := GetBlockContent(HoverTileX, HoverTileY);
      if BlockContent <> '' then
        ImGui.TextColored(ImVec4.New(1.0, 0.9, 0.3, 1.0), AnsiString('Contains: ' + BlockContent))
      else
        ImGui.TextColored(ImVec4.New(0.6, 0.6, 0.6, 1.0), 'Contains: Coin');
    end;
  end
  else
    ImGui.Text('Tile: -');
  ImGui.Separator();
  { Selected tile info }
  if SelectedCharCode > 0 then
  begin
    ImGui.TextColored(ImVec4.New(0.3, 1.0, 0.3, 1.0), AnsiString('Selected: ' + SelectedTileName));
    if SelectedCharCode >= 32 then
      ImGui.Text(AnsiString('Code: ''' + Chr(SelectedCharCode) + ''' (#' + IntToStr(SelectedCharCode) + ')'))
    else
      ImGui.Text(AnsiString('Code: #' + IntToStr(SelectedCharCode) + ' ($' + IntToHex(SelectedCharCode, 2) + ')'));
  end
  else
    ImGui.TextColored(ImVec4.New(0.6, 0.6, 0.6, 1.0), 'No tile selected');
  if EditorDirty then
    ImGui.TextColored(ImVec4.New(1.0, 0.4, 0.4, 1.0), '* Unsaved changes')
  else
    ImGui.TextColored(ImVec4.New(0.6, 0.6, 0.6, 1.0), 'No changes');
  {$IFDEF WINDOWS}
  if TestPlayActive then
    ImGui.TextColored(ImVec4.New(0.3, 1.0, 1.0, 1.0), 'Test Play running...');
  {$ENDIF}
  ImGui.End_();

  { --- Sky & Background Preview (right side, below Level Settings) --- }
  PalAvail.x := 346; PalAvail.y := 500;
  ImGui.SetNextWindowSize(PalAvail, ImGuiCond_FirstUseEver);
  ImGui.Begin_('Sky & Background', nil, ImGuiWindowFlags_None);
  if EdGetSkyTexture <> 0 then
  begin
    { Preview image }
    TexID := Pointer(PtrUInt(EdGetSkyTexture));
    TexSize.x := SKY_PV_W;
    TexSize.y := SKY_PV_H;
    UV0.x := 0; UV0.y := 0;
    UV1.x := 1; UV1.y := 1;
    Tint.x := 1; Tint.y := 1; Tint.z := 1; Tint.w := 1;
    Border.x := 0.3; Border.y := 0.3; Border.z := 0.3; Border.w := 1;
    ImGui.Image(TexID, TexSize, UV0, UV1, Tint, Border);
    ImGui.Separator();

    { Show current level's sky info }
    ImGui.Text(AnsiString('Level Sky: ' + IntToStr(EdGetSkyType) + ' - ' + EdGetSkyTypeName(EdGetSkyType)));
    ImGui.Text(AnsiString('Level BG: ' + IntToStr(EdGetBackGrType) + ' - ' + EdGetBackGrTypeName(EdGetBackGrType)));
    ImGui.Text(AnsiString('Clouds: ' + IntToStr(EdGetClouds) + '  Horizon: ' + IntToStr(EdGetHorizon)));
    ImGui.Separator();

    { Sky Type Browser }
    ImGui.Text('Sky Type Browser');
    if ImGui.Button('<<', ImVec2.New(30, 0)) then
    begin
      Dec(BrowseSkyType);
      if BrowseSkyType < 0 then BrowseSkyType := 12;
      SkyBrowserDirty := True;
    end;
    ImGui.SameLine(0, 8);
    ImGui.Text(AnsiString(IntToStr(BrowseSkyType) + ': ' + EdGetSkyTypeName(BrowseSkyType)));
    ImGui.SameLine(0, 8);
    if ImGui.Button('>>', ImVec2.New(30, 0)) then
    begin
      Inc(BrowseSkyType);
      if BrowseSkyType > 12 then BrowseSkyType := 0;
      SkyBrowserDirty := True;
    end;
    ImGui.SameLine(0, 12);
    if ImGui.Button('Reset##sky', ImVec2.New(0, 0)) then
    begin
      BrowseSkyType := EdGetSkyType;
      BrowseBgType := EdGetBackGrType;
      SkyBrowserDirty := True;
    end;

    { Background Type Browser }
    ImGui.Text('Background Browser');
    if ImGui.Button('<<##bg', ImVec2.New(30, 0)) then
    begin
      { Cycle through valid background types: 0-7, 9, 10 }
      Dec(BrowseBgType);
      if BrowseBgType = 8 then BrowseBgType := 7;
      if BrowseBgType < 0 then BrowseBgType := 10;
      SkyBrowserDirty := True;
    end;
    ImGui.SameLine(0, 8);
    ImGui.Text(AnsiString(IntToStr(BrowseBgType) + ': ' + EdGetBackGrTypeName(BrowseBgType)));
    ImGui.SameLine(0, 8);
    if ImGui.Button('>>##bg', ImVec2.New(30, 0)) then
    begin
      Inc(BrowseBgType);
      if BrowseBgType = 8 then BrowseBgType := 9;
      if BrowseBgType > 10 then BrowseBgType := 0;
      SkyBrowserDirty := True;
    end;

    { Apply button — commits browsed sky/bg to the level }
    if (BrowseSkyType <> EdGetSkyType) or (BrowseBgType <> EdGetBackGrType) then
    begin
      if ImGui.Button('Apply', ImVec2.New(80, 0)) then
      begin
        EdSetSkyType(BrowseSkyType);
        EdSetBackGrType(BrowseBgType);
        NeedRerender := True;
        EditorDirty := True;
      end;
      ImGui.SameLine(0, 8);
      ImGui.TextColored(ImVec4.New(1.0, 0.9, 0.3, 1.0), '(unsaved change)');
    end;

    { Re-render preview when browser selection changed }
    if SkyBrowserDirty then
    begin
      EdBuildSkyPreviewForType(BrowseSkyType, BrowseBgType, EdGetHorizon, 0);
      SkyBrowserDirty := False;
      NeedRerender := True;
    end;
  end
  else
    ImGui.Text('No level loaded.');
  ImGui.End_();

  { --- Enemy Palette Window (left column, below Tile Palette) --- }
  PalAvail.x := 280; PalAvail.y := 336;
  ImGui.SetNextWindowSize(PalAvail, ImGuiCond_FirstUseEver);
  ImGui.Begin_('Enemy Palette', nil, ImGuiWindowFlags_None);
  if EdGetEnemyAtlasTexture <> 0 then
  begin
    EnemyTexID := Pointer(PtrUInt(EdGetEnemyAtlasTexture));
    PalAvail := ImGui.GetContentRegionAvail();
    { Display sprites at 2× zoom (48×48 display per cell) }
    PalTileSize.x := ENEMY_CELL_W * 2;
    PalTileSize.y := ENEMY_CELL_H * 2;
    PalColCount := Trunc(PalAvail.x / (PalTileSize.x + 8));
    if PalColCount < 1 then PalColCount := 1;

    for i := 0 to EdGetEnemyAtlasCount - 1 do
    begin
      EnemyEntry := EdGetEnemyAtlasEntry(i);

      { Compute UV for the full cell (including centering padding) }
      PalUV0.x := EnemyEntry.AtlasCol * ENEMY_CELL_W / ENEMY_ATLAS_PX_W;
      PalUV0.y := EnemyEntry.AtlasRow * ENEMY_CELL_H / ENEMY_ATLAS_PX_H;
      PalUV1.x := PalUV0.x + ENEMY_CELL_W / ENEMY_ATLAS_PX_W;
      PalUV1.y := PalUV0.y + ENEMY_CELL_H / ENEMY_ATLAS_PX_H;

      ImGui.BeginGroup();
      PalTintCol := ImVec4.New(1, 1, 1, 1);

      { Highlight selected enemy with yellow border }
      IsSelected := SelectedIsEnemy and (SelectedEnemyIdx = i);
      if IsSelected then
        PalBgCol := ImVec4.New(1.0, 0.9, 0.0, 1.0)
      else
        PalBgCol := ImVec4.New(0.3, 0.3, 0.3, 0.5);

      PalBtnID := 'enemy_' + IntToStr(i);
      if ImGui.ImageButton(PAnsiChar(PalBtnID), EnemyTexID, PalTileSize,
        PalUV0, PalUV1, PalBgCol, PalTintCol) then
      begin
        SelectedEnemyIdx := i;
        SelectedTileIdx := -1;
        SelectedCharCode := EnemyEntry.CharCode;
        SelectedTileName := EnemyEntry.Name;
        SelectedIsEnemy := True;
      end;

      { Tooltip on hover }
      if ImGui.IsItemHovered(ImGuiHoveredFlags_None) then
      begin
        ImGui.BeginTooltip();
        ImGui.Text(EnemyEntry.Name);
        ImGui.Text(AnsiString('Code: #$' + IntToHex(EnemyEntry.CharCode, 2)
          + ' (' + IntToStr(EnemyEntry.SprW) + 'x' + IntToStr(EnemyEntry.SprH) + ')'));
        ImGui.EndTooltip();
      end;

      { Name label below sprite — constrain wrap to button width so
        long names don't widen the group and break grid flow }
      ImGui.PushTextWrapPos(ImGui.GetCursorPosX() + PalTileSize.x + 2);
      ImGui.TextWrapped(EnemyEntry.Name);
      ImGui.PopTextWrapPos();
      ImGui.EndGroup();

      { Grid flow: SameLine unless at end of row }
      if ((i + 1) mod PalColCount) <> 0 then
        ImGui.SameLine(0, 8);
    end;
  end
  else
    ImGui.Text('No level loaded.');
  ImGui.End_();

  { --- ImGui Demo Window (for development reference) --- }
  if ShowDemoWindow then
    ImGui.ShowDemoWindow(@ShowDemoWindow);

  { --- Render --- }
  ImGui.Render();
  SDL_GL_MakeCurrent(Window, GLContext);
  glViewport(0, 0, Trunc(IO^.DisplaySize.x), Trunc(IO^.DisplaySize.y));
  glClearColor(ClearColor.x, ClearColor.y, ClearColor.z, ClearColor.w);
  glClear(GL_COLOR_BUFFER_BIT);
  ImGui_OpenGL3_RenderDrawData(ImGui.GetDrawData());

  { Multi-viewport support }
  if (IO^.ConfigFlags and ImGuiConfigFlags_ViewportsEnable) <> 0 then
  begin
    BackupWindow := SDL_GL_GetCurrentWindow();
    BackupContext := SDL_GL_GetCurrentContext();
    ImGui.UpdatePlatformWindows();
    ImGui.RenderPlatformWindowsDefault(nil, nil);
    SDL_GL_MakeCurrent(BackupWindow, BackupContext);
  end;

  SDL_GL_SwapWindow(Window);
end;

{ Window resize callback }
function WindowRedrawOnResize(userdata: Pointer; e: PSDL_Event): Int32; cdecl;
begin
  if (e^.type_ = SDL_WINDOWEVENT) and (e^.window.event = SDL_WINDOWEVENT_RESIZED) then
  begin
    glViewport(0, 0, e^.window.data1, e^.window.data2);
    DrawGUI();
  end;
  Result := 1;
end;

var
  Flags: LongWord;
  DisplayMode: TSDL_DisplayMode;
  SavedWinX, SavedWinY, SavedWinW, SavedWinH: Integer;
  SavedMaximized: Boolean;
  MainKeyMods: Integer;

begin
  { Set Pascal allocators for ImGui }
  igSetAllocatorFunctions(@PasAllocMem, @PasFreeMem, nil);

  { Init SDL2 }
  SDL_SetHint(SDL_HINT_WINDOWS_DISABLE_THREAD_NAMING, '1');
  if SDL_Init(SDL_INIT_VIDEO or SDL_INIT_TIMER) < 0 then
  begin
    WriteLn('SDL_Init failed: ', SDL_GetError());
    Halt(1);
  end;

  { OpenGL context attributes }
  {$IFDEF DARWIN}
  GLSLVersion := '#version 150';
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
  {$ELSE}
  GLSLVersion := '#version 410';
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, 0);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
  {$ENDIF}

  SDL_SetHint(SDL_HINT_IME_SHOW_UI, '1');
  SDL_SetHint(SDL_HINT_RENDER_DRIVER, 'opengl');
  SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
  SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
  SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 0);   { No alpha channel — prevents OS compositor transparency }
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
  SDL_GetCurrentDisplayMode(0, @DisplayMode);

  { Load saved window state }
  LoadWindowState(SavedWinX, SavedWinY, SavedWinW, SavedWinH, SavedMaximized);

  { Create window }
  Flags := SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE or SDL_WINDOW_ALLOW_HIGHDPI;
  Window := SDL_CreateWindow('Leaper - Level Editor',
    SavedWinX, SavedWinY,
    SavedWinW, SavedWinH, Flags);
  if Window = nil then
  begin
    WriteLn('SDL_CreateWindow failed: ', SDL_GetError());
    Halt(1);
  end;

  if SavedMaximized then
    SDL_MaximizeWindow(Window);

  GLContext := SDL_GL_CreateContext(Window);
  SDL_GL_SetSwapInterval(1);

  { Init ImGui }
  ImGui.CreateContext(nil);
  IO := ImGui.GetIO();
  IO^.IniFilename := 'editor_layout.ini';
  IO^.ConfigFlags := IO^.ConfigFlags or ImGuiConfigFlags_DockingEnable;
  { Note: ViewportsEnable deliberately omitted — it causes OS-level per-pixel
    alpha on popup windows, making dropdown menus transparent. Docking still
    works within the main window. }

  { Init backends }
  ImGui_ImplSDL2_InitForOpenGL_Pas(Window, GLContext);
  ImGui_OpenGL3_Init(GLSLVersion);

  { Style }
  SetupImGuiStyle2();

  { Workaround: Writing a high-RGB-value color to the PopupBg style slot after
    SetupImGuiStyle2 prevents menus/popups from appearing transparent on Windows.
    The color itself doesn't visually affect popups (reason unknown — possibly a
    cimgui DLL vs Pascal bindings enum mismatch), but without this write, the
    DWM compositor renders popups as semi-transparent. }
  ImGui.GetStyle()^.Colors[ImGuiCol_PopupBg] := ImVec4.New(1.0, 0.0, 0.0, 1.0);

  { Load default font }
  IO^.Fonts^.AddFontDefault();

  { Background color }
  ClearColor.x := 0.20;
  ClearColor.y := 0.20;
  ClearColor.z := 0.25;
  ClearColor.w := 1.00;

  { Initialize the editor renderer }
  EdRenderInit;

  { Load default level (Level 1-A) }
  LoadSelectedLevel;

  { Main loop }
  Quit := False;
  SDL_SetEventFilter(@WindowRedrawOnResize, nil);

  while not Quit do
  begin
    StartingTick := SDL_GetPerformanceCounter();

    { Poll events }
    while SDL_PollEvent(@Event) <> 0 do
    begin
      ImGui_ImplSDL2_ProcessEvent_Pas(@Event);
      if Event.type_ = SDL_QUITEV then
        Quit := True;
      if (Event.type_ = SDL_WINDOWEVENT) and
         (Event.window.event = SDL_WINDOWEVENT_CLOSE) and
         (Event.window.windowID = SDL_GetWindowID(Window)) then
        Quit := True;

      { Middle mouse button for viewport panning }
      if (Event.type_ = SDL_MOUSEBUTTONDOWN) and
         (Event.button.button = SDL_BUTTON_MIDDLE) then
      begin
        IsDragging := True;
        DragLastX := Event.button.x;
      end;
      if (Event.type_ = SDL_MOUSEBUTTONUP) and
         (Event.button.button = SDL_BUTTON_MIDDLE) then
      begin
        IsDragging := False;
        DragLastX := -1;
      end;

      { Keyboard shortcuts }
      if (Event.type_ = SDL_KEYDOWN) then
      begin
        MainKeyMods := Integer(Event.key.keysym.mod_);

        { F5 — Test Play (works regardless of modifiers) }
        {$IFDEF WINDOWS}
        if (Event.key.keysym.sym = SDLK_F5) and EdIsLevelLoaded then
          LaunchTestPlay;
        {$ENDIF}

        { Ctrl+key shortcuts }
        if (MainKeyMods and Integer(KMOD_CTRL)) <> 0 then
        begin
          case Event.key.keysym.sym of
            SDLK_z: DoUndo;
            SDLK_y: DoRedo;
            SDLK_c: DoCopy;
            SDLK_x: DoCut;
            SDLK_v: DoPaste;
            SDLK_f: DoFill;
            SDLK_s: begin
              SyncMetaBuffersToEdRender;
              if (MainKeyMods and Integer(KMOD_SHIFT)) <> 0 then
                OpenFileDialog(True, 'Save Level As', '', ExtractFileName(CurrentFilePath))
              else if CurrentFilePath <> '' then begin
                if EdSaveLevelJSON(CurrentFilePath) then begin
                  EditorDirty := False; UpdateWindowTitle; end;
              end else
                OpenFileDialog(True, 'Save Level', '', 'level.json');
            end;
            SDLK_o: OpenFileDialog(False, 'Open Level', '', '');
          end;
        end
        else
        begin
          case Event.key.keysym.sym of
            SDLK_1: begin ZoomLevel := 1; NeedRerender := True; end;
            SDLK_2: begin ZoomLevel := 2; NeedRerender := True; end;
            SDLK_3: begin ZoomLevel := 3; NeedRerender := True; end;
            SDLK_g: begin ShowGrid := not ShowGrid; end;
            SDLK_m: begin ShowMarkers := not ShowMarkers; end;
            SDLK_DELETE: DoDeleteSelection;
            SDLK_ESCAPE: begin
              if PastePreviewActive then
                PastePreviewActive := False
              else if SelectionActive then
                ClearSelection
              else begin
                SelectedTileIdx := -1;
                SelectedEnemyIdx := -1;
                SelectedCharCode := 0;
                SelectedTileName := '';
                SelectedIsEnemy := False;
              end;
            end;
            SDLK_LEFT: begin
              ScrollX := ScrollX - 20;
              if ScrollX < 0 then ScrollX := 0;
              NeedRerender := True;
            end;
            SDLK_RIGHT: begin
              ScrollX := ScrollX + 20;
              if EdGetLevelWidth > EdGetViewWidth then
              begin
                if ScrollX > EdGetLevelWidth - EdGetViewWidth then
                  ScrollX := EdGetLevelWidth - EdGetViewWidth;
              end;
              NeedRerender := True;
            end;
          end;
        end;
      end;
    end;

    { Check if test play process has exited }
    {$IFDEF WINDOWS}
    CheckTestPlayProcess;
    {$ENDIF}

    DrawGUI();

    { Frame rate limiting }
    if FrameRate > 0 then
    begin
      ElapsedMS := (SDL_GetPerformanceCounter() - StartingTick) * 1000.0 /
                   SDL_GetPerformanceFrequency();
      SleepTime := Floor((1000.0 / FrameRate) - ElapsedMS);
      if SleepTime <= 0 then
        SleepTime := 0;
      SDL_Delay(SleepTime);
    end;
  end;

  { Save window state before cleanup }
  SaveWindowState(Window);

  { Cleanup }
  EdRenderShutdown;
  ImGui_OpenGL3_Shutdown();
  ImGui_ImplSDL2_Shutdown_Pas();
  ImGui.DestroyContext(nil);
  SDL_GL_DeleteContext(GLContext);
  if Window <> nil then
    SDL_DestroyWindow(Window);
  SDL_Quit();
end.
