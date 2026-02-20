Program Editor;
{
  Mario & Luigi Level Editor
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
  {$R editor.res}
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

  LevelNames: array[0..11] of PAnsiChar = (
    'Level 1-A', 'Level 1-B',
    'Level 2-A', 'Level 2-B',
    'Level 3-A', 'Level 3-B',
    'Level 4-A', 'Level 4-B',
    'Level 5-A', 'Level 5-B',
    'Level 6-A', 'Level 6-B'
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
  CurrentLevel: Integer = 0;  { 0..11: index into LevelNames }
  ScrollX: Integer = 0;
  ZoomLevel: Integer = 2;     { 1x, 2x, 3x }
  NeedRerender: Boolean = True;
  ShowGrid: Boolean = False;
  ShowMarkers: Boolean = True;  { Show enemy/item/player start markers }
  IsDragging: Boolean = False; { True while middle-click dragging viewport }
  DragLastX: Integer = -1;    { Last mouse X during drag (SDL screen coords) }
  DragLastY: Integer = -1;    { Last mouse Y during drag }
  DragCurX: Integer = 0;      { Current mouse X (temp) }
  DragCurY: Integer = 0;      { Current mouse Y (temp) }
  DragDeltaX: Integer = 0;    { Delta X per frame (temp) }
  ShowAbout: Boolean = False;   { Show About dialog }
  { Sky browser state }
  BrowseSkyType: Integer = 0;   { Currently browsed sky type (0-12) }
  BrowseBgType: Integer = 0;    { Currently browsed background type }
  SkyBrowserDirty: Boolean = False; { True when browser selection changed }

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

procedure LoadSelectedLevel;
var
  WorldIdx: Integer;
  Sub: Char;
begin
  WorldIdx := CurrentLevel div 2;
  if (CurrentLevel mod 2) = 0 then
    Sub := 'A'
  else
    Sub := 'B';
  EdLoadLevel(WorldIdx, Sub);
  ScrollX := 0;
  NeedRerender := True;
  { Sync sky browser to the loaded level's settings }
  BrowseSkyType := EdGetSkyType;
  BrowseBgType := EdGetBackGrType;
  SkyBrowserDirty := False;
end;

var
  { Hover info updated each frame }
  HoverTileX: Integer = -1;
  HoverTileY: Integer = -1;
  HoverTileChar: Char = ' ';

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
        for i := 0 to 11 do
        begin
          if ImGui.MenuItem(LevelNames[i], nil, i = CurrentLevel, True) then
          begin
            CurrentLevel := i;
            LoadSelectedLevel;
          end;
        end;
        ImGui.EndMenu();
      end;
      ImGui.Separator();
      if ImGui.MenuItem('Quit', 'Alt+F4', False, True) then
        Quit := True;
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
    ImGui.Text('Mario & Luigi Level Editor');
    ImGui.Separator();
    ImGui.Text(AnsiString('Build: ' + BUILD_DATE + '-' + BUILD_TIME));
    ImGui.Text('Engine: SDL2 + OpenGL3 + Dear ImGui');
    ImGui.Separator();
    if ImGui.Button('OK', ImVec2.New(120, 0)) then
      ImGui.CloseCurrentPopup();
    ImGui.EndPopup();
  end;

  { --- Tile Palette Panel (left column, top) --- }
  PalAvail.x := 280; PalAvail.y := 360;
  ImGui.SetNextWindowSize(PalAvail, ImGuiCond_FirstUseEver);
  ImGui.Begin_('Tile Palette', nil, ImGuiWindowFlags_None);
  if EdGetAtlasTexture <> 0 then
  begin
    { Calculate how many tiles fit per row at 2x zoom (40px + 4px gap) }
    PalAvail := ImGui.GetContentRegionAvail();
    PalTilesPerRow := Trunc(PalAvail.x / 44);
    if PalTilesPerRow < 1 then PalTilesPerRow := 1;

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
            Tint.x := 1; Tint.y := 1; Tint.z := 1; Tint.w := 1;
            Border.x := 0.3; Border.y := 0.3; Border.z := 0.3; Border.w := 1;

            ImGui.Image(TexID, PalTileSize, PalUV0, PalUV1, Tint, Border);

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

    ImGui.Image(TexID, TexSize, UV0, UV1, Tint, Border);

    { Get the actual screen rect of the image AFTER drawing it }
    ImgMin := ImGui.GetItemRectMin();
    ImgMax := ImGui.GetItemRectMax();

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
      DragLastY := DragCurY;
    end;

    { Tile size in screen pixels }
    TileW := EdGetTileW * ZoomLevel;
    TileH := EdGetTileH * ZoomLevel;

    { Sub-tile offset for grid alignment when scrolled mid-tile }
    SubTileOff := (ScrollX mod EdGetTileW) * ZoomLevel;

    { Use the window draw list instead of the foreground draw list.
      Window draw list draws within the window's Z-order (behind popups),
      and since we add commands after ImGui.Image(), they appear on top of the image. }
    DrawList := ImGui.GetWindowDrawList();

    { Compute hovered tile from mouse position }
    HoverTileX := -1;
    HoverTileY := -1;
    HoverTileChar := ' ';

    { Get mouse position from ImGui IO (in window-local coords) }
    MousePos := IO^.MousePos;
    RelX := MousePos.x - ImgMin.x;
    RelY := MousePos.y - ImgMin.y;

    { Bounds check: is the mouse within the image rect? }
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
        HoverTileChar := EdGetTileAt(HoverTileX, HoverTileY);

        { Highlight hovered tile }
        HighlightCol := $8000FFFF;  { semi-transparent yellow (ABGR) }
        HighRect1.x := ImgMin.x + (HoverTileX * EdGetTileW - ScrollX) * ZoomLevel;
        HighRect1.y := ImgMin.y + HoverTileY * TileH;
        HighRect2.x := HighRect1.x + TileW;
        HighRect2.y := HighRect1.y + TileH;
        DrawList^.AddRectFilled(HighRect1, HighRect2, HighlightCol);

        { Tooltip with tile info }
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
        ImGui.EndTooltip();
    end;

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

      MarkerRadius := Min(TileW, TileH) * 0.35;
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
            Continue;  { Don't fall through to marker drawing }
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
      ContentR := Min(TileW, TileH) * 0.22;
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

      { --- Player start marker (always shown when markers enabled) --- }
      PlayerTX := EdGetPlayerStartX;
      PlayerTY := EdGetPlayerStartY;

      { Position: bottom-align Mario sprite to tile bottom, center horizontally }
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
  if (CurrentLevel mod 2) = 1 then
    ImGui.Text('Music: sublevel.ogg')
  else
    ImGui.Text(AnsiString('Music: level' + IntToStr(CurrentLevel div 2 + 1) + '.ogg'));
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

    { Apply the browsed sky type if changed }
    if SkyBrowserDirty then
    begin
      EdBuildSkyPreviewForType(BrowseSkyType, BrowseBgType, EdGetHorizon, 0);
      SkyBrowserDirty := False;
      NeedRerender := True;  { Re-render level viewport after palette restore }
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
    { Display sprites at 3× zoom (72×72 display per cell) }
    PalTileSize.x := ENEMY_CELL_W * 3;
    PalTileSize.y := ENEMY_CELL_H * 3;
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
      Tint.x := 1; Tint.y := 1; Tint.z := 1; Tint.w := 1;
      Border.x := 0.3; Border.y := 0.3; Border.z := 0.3; Border.w := 0.5;
      ImGui.Image(EnemyTexID, PalTileSize, PalUV0, PalUV1, Tint, Border);

      { Tooltip on hover }
      if ImGui.IsItemHovered(ImGuiHoveredFlags_None) then
      begin
        ImGui.BeginTooltip();
        ImGui.Text(EnemyEntry.Name);
        ImGui.Text(AnsiString('Code: #$' + IntToHex(EnemyEntry.CharCode, 2)
          + ' (' + IntToStr(EnemyEntry.SprW) + 'x' + IntToStr(EnemyEntry.SprH) + ')'));
        ImGui.EndTooltip();
      end;

      { Name label below sprite }
      ImGui.TextWrapped(EnemyEntry.Name);
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
  Window := SDL_CreateWindow('Mario & Luigi - Level Editor',
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
        DragLastY := Event.button.y;
      end;
      if (Event.type_ = SDL_MOUSEBUTTONUP) and
         (Event.button.button = SDL_BUTTON_MIDDLE) then
      begin
        IsDragging := False;
        DragLastX := -1;
        DragLastY := -1;
      end;

      { Keyboard shortcuts }
      if (Event.type_ = SDL_KEYDOWN) then
      begin
        case Event.key.keysym.sym of
          SDLK_1: begin ZoomLevel := 1; NeedRerender := True; end;
          SDLK_2: begin ZoomLevel := 2; NeedRerender := True; end;
          SDLK_3: begin ZoomLevel := 3; NeedRerender := True; end;
          SDLK_g: begin ShowGrid := not ShowGrid; end;
          SDLK_m: begin ShowMarkers := not ShowMarkers; end;
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
