unit VGA256;

  {  SDL2 replacement for the Turbo Pascal VGA unit  }
  {  Original (C) Copyright 1994-2001, Mike Wiering   }
  {  SDL2 port preserves the identical interface       }

  {$R-}  { no range-checking }
  {$I-}  { no I/O-checking }

interface

  const
    VGA_SEGMENT           = $A000;  { kept for source compatibility }

    WINDOWHEIGHT        = 13 * 14;
    WINDOWWIDTH         = 16 * 20;

    SCREEN_WIDTH        = 320;
    SCREEN_HEIGHT       = 200;

    VIR_SCREEN_WIDTH    = SCREEN_WIDTH + 2 * 20;
    VIR_SCREEN_HEIGHT   = 182;
    BYTES_PER_LINE      = VIR_SCREEN_WIDTH div 4;  { kept for compatibility }

    { VGA register constants - kept for source compatibility but unused }
    MISC_OUTPUT         = $03C2;
    SC_INDEX            = $03C4;
    GC_INDEX            = $03CE;
    CRTC_INDEX          = $03D4;
    VERT_RESCAN         = $03DA;

    MAP_MASK            = 2;
    MEMORY_MODE         = 4;

    VERT_RETRACE_MASK   = 8;

    MAX_SCAN_LINE       = 9;
    START_ADDRESS_HIGH  = $C;
    START_ADDRESS_LOW   = $D;
    UNDERLINE           = $14;
    MODE_CONTROL        = $17;

    READ_MAP            = 4;
    GRAPHICS_MODE       = 5;
    MISCELLANEOUS       = 6;

    MAX_SCREENS         = 24;
    MAX_PAGE            = 1;
    PAGE_SIZE           = (VIR_SCREEN_HEIGHT + MAX_SCREENS) * BYTES_PER_LINE;
    PAGE_0              = 0;
    PAGE_1              = $8000;

    YBASE               = 9;

  function DetectVGA: Boolean;
  procedure InitVGA;
  procedure OldMode;
  function GetMode: Byte;
  procedure SetMode (NewMode: Byte);
  procedure ClearVGAMem;
  procedure WaitDisplay;
  procedure WaitRetrace;
  procedure SetView (X, Y: Integer);
  procedure SetViewport (X, Y: Integer; PageNr: Byte);
  procedure SwapPages;
  procedure ShowPage;
  procedure Border (Attr: Byte);
  procedure SetYStart (NewYStart: Integer);
  procedure SetYEnd (NewYEnd: Integer);
  procedure SetYOffset (NewYOffset: Integer);
  function GetYOffset: Integer;
  procedure PutPixel (X, Y: Integer; Attr: Byte);
  function GetPixel (X, Y: Integer): Byte;
  procedure DrawImage (XPos, YPos, Width, Height: Integer; var BitMap);
  procedure RecolorImage (XPos, YPos, Width, Height: Integer; var BitMap; Diff: Byte);
  procedure DrawPart (XPos, YPos, Width, Height, Y1, Y2: Integer; var BitMap);
  procedure UpSideDown (XPos, YPos, Width, Height: Integer; var BitMap);
  procedure PutImage (XPos, YPos, Width, Height: Integer; var BitMap);
  procedure GetImage (XPos, YPos, Width, Height: Integer; var BitMap);
  procedure Fill (X, Y, W, H: Integer; Attr: Integer);
  procedure SetPalette (Color, Red, Green, Blue: Byte);
  procedure ReadPalette (var NewPalette);
  procedure ClearPalette;
  function CurrentPage: Integer;
  function GetPageOffset: Word;
  procedure ResetStack;
  function PushBackGr (X, Y, W, H: Integer): Word;
  procedure PopBackGr (Address: Word);
  procedure DrawBitmap (X, Y: Integer; var BitMap; Attr: Byte);

  { New SDL-specific exports for other units }
  procedure PollEvents;
  procedure PresentFrame;
  function IsQuitRequested: Boolean;

  { Editor support: read/write palette entry as 6-bit VGA values }
  procedure GetPaletteEntry (Color: Byte; var R, G, B: Byte);
  procedure SetPaletteEntry (Color, R, G, B: Byte);

  const
    InGraphicsMode: Boolean = FALSE;

  const
    { Total framebuffer height: must be at least YBASE + SCREEN_HEIGHT = 209 }
    FB_HEIGHT = YBASE + SCREEN_HEIGHT;  { 9 + 200 = 209 rows }

  { Framebuffer exposed for direct access by Stars, BackGr, etc. }
  var
    FrameBuffer: array[0..MAX_PAGE] of
      array[0..VIR_SCREEN_WIDTH * FB_HEIGHT - 1] of Byte;

implementation

  uses
    sdl2, Keyboard;

  const
    SCALE_FACTOR = 3;  { Window is 960x546 (320x3 x 182x3) }
    FRAME_TIME   = 14; { ~71 fps in ms — matches original DOS speed }

  var
    SDLWindow: PSDL_Window;
    SDLRenderer: PSDL_Renderer;
    RenderTexture: PSDL_Texture;
    PixelBuffer: array[0..SCREEN_WIDTH * VIR_SCREEN_HEIGHT - 1] of UInt32;
    QuitRequested: Boolean;
    LastFrameTime: UInt32;

  { SDL palette: stored as VGA 6-bit values (0-63) }
  var
    PaletteR: array[0..255] of Byte;
    PaletteG: array[0..255] of Byte;
    PaletteB: array[0..255] of Byte;

  const
    XView: Integer = 0;
    YView: Integer = 0;

    Page: Integer = 0;
    PageOffset: Word = 0;  { kept for GetPageOffset compatibility }

    YOffset: Integer = 0;
    YStart: Integer = 0;
    YEnd: Integer = SCREEN_HEIGHT;

  { Background save/restore stack }
  const
    MAX_BACKGR_STACK = 256;

  type
    PBackGrData = ^TBackGrData;
    TBackGrData = array[0..65519] of Byte;

    TBackGrEntry = record
      X, Y, W, H: Integer;
      Data: PBackGrData;
      DataSize: Word;
      Valid: Boolean;
    end;

  var
    BackGrStacks: array[0..MAX_PAGE] of array[0..MAX_BACKGR_STACK - 1] of TBackGrEntry;
    StackTops: array[0..MAX_PAGE] of Integer;


  { ===== SDL Initialization ===== }

  function DetectVGA: Boolean;
  begin
    DetectVGA := True;  { Always available with SDL }
  end;

  function GetMode: Byte;
  begin
    if InGraphicsMode then
      GetMode := $13
    else
      GetMode := $03;
  end;

  procedure SetMode (NewMode: Byte);
  begin
    { No-op in SDL - mode is always 320x200 }
  end;

  procedure InitVGA;
  var
    i: Integer;
  begin
    if InGraphicsMode then
      Exit;

    if SDL_Init(SDL_INIT_VIDEO or SDL_INIT_AUDIO or SDL_INIT_JOYSTICK or SDL_INIT_TIMER) < 0 then
    begin
      WriteLn('SDL_Init failed: ', SDL_GetError);
      Halt(1);
    end;

    SDLWindow := SDL_CreateWindow('Mario & Luigi',
      SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
      SCREEN_WIDTH * SCALE_FACTOR, VIR_SCREEN_HEIGHT * SCALE_FACTOR,
      SDL_WINDOW_SHOWN);
    if SDLWindow = nil then
    begin
      WriteLn('SDL_CreateWindow failed: ', SDL_GetError);
      Halt(1);
    end;

    SDLRenderer := SDL_CreateRenderer(SDLWindow, -1,
      SDL_RENDERER_ACCELERATED or SDL_RENDERER_PRESENTVSYNC);
    if SDLRenderer = nil then
      SDLRenderer := SDL_CreateRenderer(SDLWindow, -1, SDL_RENDERER_SOFTWARE);
    if SDLRenderer = nil then
    begin
      WriteLn('SDL_CreateRenderer failed: ', SDL_GetError);
      Halt(1);
    end;

    SDL_RenderSetLogicalSize(SDLRenderer, SCREEN_WIDTH, VIR_SCREEN_HEIGHT);
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, '0');  { nearest-neighbor }

    RenderTexture := SDL_CreateTexture(SDLRenderer,
      SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING,
      SCREEN_WIDTH, VIR_SCREEN_HEIGHT);
    if RenderTexture = nil then
    begin
      WriteLn('SDL_CreateTexture failed: ', SDL_GetError);
      Halt(1);
    end;

    { Clear everything }
    ClearPalette;
    ClearVGAMem;
    ResetStack;

    Page := 0;
    PageOffset := PAGE_0;
    XView := 0;
    YView := 0;
    YOffset := 0;
    YStart := 0;
    YEnd := SCREEN_HEIGHT;
    QuitRequested := False;
    LastFrameTime := SDL_GetTicks;

    InGraphicsMode := True;
  end;

  procedure OldMode;
  begin
    if not InGraphicsMode then
      Exit;

    InGraphicsMode := False;

    if RenderTexture <> nil then
    begin
      SDL_DestroyTexture(RenderTexture);
      RenderTexture := nil;
    end;
    if SDLRenderer <> nil then
    begin
      SDL_DestroyRenderer(SDLRenderer);
      SDLRenderer := nil;
    end;
    if SDLWindow <> nil then
    begin
      SDL_DestroyWindow(SDLWindow);
      SDLWindow := nil;
    end;

    SDL_Quit;
  end;


  { ===== Frame Buffer Operations ===== }

  procedure ClearVGAMem;
  begin
    FillChar(FrameBuffer, SizeOf(FrameBuffer), 0);
  end;

  procedure WaitDisplay;
  begin
    { No-op - retrace sync handled by PresentFrame }
  end;

  procedure WaitRetrace;
  var
    Now, Elapsed: UInt32;
  begin
    { Frame timing to approximate 60 Hz }
    Now := SDL_GetTicks;
    Elapsed := Now - LastFrameTime;
    if Elapsed < FRAME_TIME then
      SDL_Delay(FRAME_TIME - Elapsed);
    LastFrameTime := SDL_GetTicks;
  end;

  procedure SetView (X, Y: Integer);
  begin
    XView := X;
    YView := Y;
  end;

  procedure PresentFrame;
  var
    SrcX, SrcY: Integer;
    DispPage: Integer;
    i, j, Idx, FBIdx: Integer;
    WrapX: Integer;
    c: Byte;
    r, g, b: UInt32;
  begin
    if not InGraphicsMode then Exit;
    if RenderTexture = nil then Exit;

    { ShowPage calls PresentFrame BEFORE SwapPages, so Page is still
      the page that was just drawn to. Display that page. }
    DispPage := Page;

    SrcX := XView;
    SrcY := YView;  { Do NOT add YOffset; game content is drawn at YOffset rows down,
                       creating natural top border like VGA CRTC blanking did }

    { Bounds checking }
    if SrcX < 0 then SrcX := 0;
    if SrcY < 0 then SrcY := 0;

    { Convert indexed framebuffer to ARGB8888.
      Only render VIR_SCREEN_HEIGHT (182) rows — window is sized to match. }
    for j := 0 to VIR_SCREEN_HEIGHT - 1 do
    begin
      for i := 0 to SCREEN_WIDTH - 1 do
      begin
        Idx := j * SCREEN_WIDTH + i;

        { Wrap X coordinate like VGA CRTC does }
        WrapX := (SrcX + i) mod VIR_SCREEN_WIDTH;
        FBIdx := (SrcY + j) * VIR_SCREEN_WIDTH + WrapX;

        { Bounds check framebuffer access }
        if (SrcY + j >= 0) and (SrcY + j < FB_HEIGHT) then
          c := FrameBuffer[DispPage, FBIdx]
        else
          c := 0;

        { Convert VGA 6-bit palette to 8-bit and pack as ARGB }
        r := UInt32(PaletteR[c]) shl 2;
        g := UInt32(PaletteG[c]) shl 2;
        b := UInt32(PaletteB[c]) shl 2;
        if r > 255 then r := 255;
        if g > 255 then g := 255;
        if b > 255 then b := 255;
        PixelBuffer[Idx] := $FF000000 or (r shl 16) or (g shl 8) or b;
      end;
    end;

    SDL_UpdateTexture(RenderTexture, nil, @PixelBuffer[0], SCREEN_WIDTH * 4);
    SDL_RenderClear(SDLRenderer);
    SDL_RenderCopy(SDLRenderer, RenderTexture, nil, nil);
    SDL_RenderPresent(SDLRenderer);
  end;

  procedure SetViewport (X, Y: Integer; PageNr: Byte);
  begin
    XView := X;
    YView := Y;
    { In the original this programmed CRTC registers. }
    { In SDL we just store the values and use them in PresentFrame. }
  end;

  procedure SwapPages;
  begin
    case Page of
      0: begin
           Page := 1;
           PageOffset := PAGE_1 + YOffset * BYTES_PER_LINE;
         end;
      1: begin
           Page := 0;
           PageOffset := PAGE_0 + YOffset * BYTES_PER_LINE;
         end;
    end;
  end;

  procedure ShowPage;
  var
    Now, Elapsed: UInt32;
  begin
    SetViewport(XView, YView, Page);
    PresentFrame;
    PollKeyboard;  { Process SDL events -> update key states }

    { Enforce frame timing: the original game ran at ~60fps on DOSBox
      at 9000 cycles. Without this delay, the SDL port runs far too fast
      because modern CPUs blaze through the game logic in microseconds. }
    Now := SDL_GetTicks;
    Elapsed := Now - LastFrameTime;
    if Elapsed < FRAME_TIME then
      SDL_Delay(FRAME_TIME - Elapsed);
    LastFrameTime := SDL_GetTicks;

    SwapPages;
  end;

  procedure Border (Attr: Byte);
  begin
    { Set the renderer clear color to the border/overscan color }
    if SDLRenderer <> nil then
      SDL_SetRenderDrawColor(SDLRenderer,
        PaletteR[Attr] shl 2,
        PaletteG[Attr] shl 2,
        PaletteB[Attr] shl 2, 255);
  end;

  procedure SetYStart (NewYStart: Integer);
  begin
    YStart := NewYStart;
  end;

  procedure SetYEnd (NewYEnd: Integer);
  begin
    YEnd := NewYEnd;
  end;

  procedure SetYOffset (NewYOffset: Integer);
  begin
    YOffset := NewYOffset;
  end;

  function GetYOffset: Integer;
  begin
    GetYOffset := YOffset;
  end;


  { ===== Pixel Operations ===== }

  procedure PutPixel (X, Y: Integer; Attr: Byte);
  var
    Offs: LongInt;
    WX: Integer;
  begin
    if (Y >= 0) and (Y < FB_HEIGHT) then
    begin
      WX := X mod VIR_SCREEN_WIDTH;
      if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
      Offs := LongInt(Y) * VIR_SCREEN_WIDTH + WX;
      FrameBuffer[Page, Offs] := Attr;
    end;
  end;

  function GetPixel (X, Y: Integer): Byte;
  var
    Offs: LongInt;
    WX: Integer;
  begin
    if (Y >= 0) and (Y < FB_HEIGHT) then
    begin
      WX := X mod VIR_SCREEN_WIDTH;
      if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
      Offs := LongInt(Y) * VIR_SCREEN_WIDTH + WX;
      GetPixel := FrameBuffer[Page, Offs];
    end
    else
      GetPixel := 0;
  end;


  { ===== Image Drawing Operations ===== }

  procedure DrawImage (XPos, YPos, Width, Height: Integer; var BitMap);
    { Draw an image - zero bytes (transparent) are skipped }
  var
    Src: PByte;
    i, j: Integer;
    c: Byte;
    WX: Integer;
    Offs: LongInt;
  begin
    if Height <= 0 then Exit;
    if Width <= 0 then Exit;
    if YPos >= FB_HEIGHT then Exit;
    if (YPos < 0) and (YPos + Height <= 0) then Exit;

    Src := @BitMap;
    for j := 0 to Height - 1 do
    begin
      if (YPos + j >= 0) and (YPos + j < FB_HEIGHT) then
      begin
        for i := 0 to Width - 1 do
        begin
          c := Src[j * Width + i];
          if c <> 0 then
          begin
            WX := (XPos + i) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(YPos + j) * VIR_SCREEN_WIDTH + WX;
            FrameBuffer[Page, Offs] := c;
          end;
        end;
      end;
    end;
  end;

  procedure RecolorImage (XPos, YPos, Width, Height: Integer; var BitMap; Diff: Byte);
    { Draw an image with color offset - zero bytes (transparent) are skipped }
  var
    Src: PByte;
    i, j: Integer;
    c: Byte;
    WX: Integer;
    Offs: LongInt;
  begin
    if Height <= 0 then Exit;
    if Width <= 0 then Exit;
    if YPos >= FB_HEIGHT then Exit;
    if (YPos < 0) and (YPos + Height <= 0) then Exit;

    Src := @BitMap;
    for j := 0 to Height - 1 do
    begin
      if (YPos + j >= 0) and (YPos + j < FB_HEIGHT) then
      begin
        for i := 0 to Width - 1 do
        begin
          c := Src[j * Width + i];
          if c <> 0 then
          begin
            WX := (XPos + i) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(YPos + j) * VIR_SCREEN_WIDTH + WX;
            FrameBuffer[Page, Offs] := c + Diff;
          end;
        end;
      end;
    end;
  end;

  procedure DrawPart (XPos, YPos, Width, Height, Y1, Y2: Integer; var BitMap);
    { Draw an image clipped to rows Y1..Y2 }
  var
    Src: PByte;
    i, j: Integer;
    c: Byte;
    WX: Integer;
    Offs: LongInt;
  begin
    if Height <= 0 then Exit;
    if Width <= 0 then Exit;
    if YPos >= FB_HEIGHT then Exit;
    if (YPos < 0) and (YPos + Height <= 0) then Exit;

    Src := @BitMap;
    for j := 0 to Height - 1 do
    begin
      if (j < Y1) or (j > Y2) then Continue;
      if (YPos + j >= 0) and (YPos + j < FB_HEIGHT) then
      begin
        for i := 0 to Width - 1 do
        begin
          c := Src[j * Width + i];
          if c <> 0 then
          begin
            WX := (XPos + i) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(YPos + j) * VIR_SCREEN_WIDTH + WX;
            FrameBuffer[Page, Offs] := c;
          end;
        end;
      end;
    end;
  end;

  procedure UpSideDown (XPos, YPos, Width, Height: Integer; var BitMap);
    { Draw an image upside-down - zero bytes (transparent) are skipped }
  var
    Src: PByte;
    i, j: Integer;
    c: Byte;
    DestY: Integer;
    WX: Integer;
    Offs: LongInt;
  begin
    if Height <= 0 then Exit;
    if Width <= 0 then Exit;
    if YPos >= FB_HEIGHT then Exit;
    if (YPos < 0) and (YPos + Height <= 0) then Exit;

    Src := @BitMap;
    for j := 0 to Height - 1 do
    begin
      DestY := YPos + Height - 1 - j;
      if (DestY >= 0) and (DestY < FB_HEIGHT) then
      begin
        for i := 0 to Width - 1 do
        begin
          c := Src[j * Width + i];
          if c <> 0 then
          begin
            WX := (XPos + i) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(DestY) * VIR_SCREEN_WIDTH + WX;
            FrameBuffer[Page, Offs] := c;
          end;
        end;
      end;
    end;
  end;

  procedure PutImage (XPos, YPos, Width, Height: Integer; var BitMap);
    { Draw an image - ALL bytes are drawn (opaque) }
  var
    Src: PByte;
    i, j: Integer;
    WX: Integer;
    Offs: LongInt;
  begin
    if Height <= 0 then Exit;
    if Width <= 0 then Exit;

    Src := @BitMap;
    for j := 0 to Height - 1 do
    begin
      if (YPos + j >= 0) and (YPos + j < FB_HEIGHT) then
      begin
        for i := 0 to Width - 1 do
        begin
          WX := (XPos + i) mod VIR_SCREEN_WIDTH;
          if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
          Offs := LongInt(YPos + j) * VIR_SCREEN_WIDTH + WX;
          FrameBuffer[Page, Offs] := Src[j * Width + i];
        end;
      end;
    end;
  end;

  procedure GetImage (XPos, YPos, Width, Height: Integer; var BitMap);
    { Read an image from the framebuffer }
  var
    Dst: PByte;
    i, j: Integer;
    WX: Integer;
    Offs: LongInt;
  begin
    if Height <= 0 then Exit;
    if Width <= 0 then Exit;

    Dst := @BitMap;
    for j := 0 to Height - 1 do
    begin
      if (YPos + j >= 0) and (YPos + j < FB_HEIGHT) then
      begin
        for i := 0 to Width - 1 do
        begin
          WX := (XPos + i) mod VIR_SCREEN_WIDTH;
          if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
          Offs := LongInt(YPos + j) * VIR_SCREEN_WIDTH + WX;
          Dst[j * Width + i] := FrameBuffer[Page, Offs];
        end;
      end
      else
        FillChar(Dst[j * Width], Width, 0);
    end;
  end;

  procedure Fill (X, Y, W, H: Integer; Attr: Integer);
    { Fill an area with a color - with X wrapping }
  var
    i, j: Integer;
    WX: Integer;
    Offs: LongInt;
    FillByte: Byte;
  begin
    if (W <= 0) or (H <= 0) then Exit;
    FillByte := Byte(Attr);

    for j := 0 to H - 1 do
    begin
      if (Y + j >= 0) and (Y + j < FB_HEIGHT) then
      begin
        for i := 0 to W - 1 do
        begin
          WX := (X + i) mod VIR_SCREEN_WIDTH;
          if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
          Offs := LongInt(Y + j) * VIR_SCREEN_WIDTH + WX;
          FrameBuffer[Page, Offs] := FillByte;
        end;
      end;
    end;
  end;


  { ===== Palette Operations ===== }

  procedure SetPalette (Color, Red, Green, Blue: Byte);
  begin
    PaletteR[Color] := Red;
    PaletteG[Color] := Green;
    PaletteB[Color] := Blue;
  end;

  procedure ReadPalette (var NewPalette);
    { Apply a palette to the display (confusing name from original -
      it actually WRITES the palette to the VGA DAC) }
  var
    P: PByte;
    i: Integer;
  begin
    P := @NewPalette;
    for i := 0 to 255 do
    begin
      PaletteR[i] := P[i * 3 + 0];
      PaletteG[i] := P[i * 3 + 1];
      PaletteB[i] := P[i * 3 + 2];
    end;
  end;

  procedure ClearPalette;
  begin
    FillChar(PaletteR, SizeOf(PaletteR), 0);
    FillChar(PaletteG, SizeOf(PaletteG), 0);
    FillChar(PaletteB, SizeOf(PaletteB), 0);
  end;


  { ===== Page Management ===== }

  function CurrentPage: Integer;
  begin
    CurrentPage := Page;
  end;

  function GetPageOffset: Word;
  begin
    GetPageOffset := PageOffset;
  end;


  procedure GetPaletteEntry (Color: Byte; var R, G, B: Byte);
  begin
    R := PaletteR[Color];
    G := PaletteG[Color];
    B := PaletteB[Color];
  end;

  procedure SetPaletteEntry (Color, R, G, B: Byte);
  begin
    PaletteR[Color] := R;
    PaletteG[Color] := G;
    PaletteB[Color] := B;
  end;


  { ===== Background Save/Restore Stack ===== }

  procedure ResetStack;
  var
    pg: Integer;
  begin
    { Only reset the stack counters - do NOT free or invalidate saved data.
      In the original VGA, ResetStack just reset the stack pointer so new
      PushBackGr calls reuse memory. PopBackGr can still access old entries
      via their handles (addresses). We must preserve old entries so PopBackGr
      can restore backgrounds from previous frames. }
    for pg := 0 to MAX_PAGE do
      StackTops[pg] := 0;
  end;

  function PushBackGr (X, Y, W, H: Integer): Word;
    { Save background - returns handle encoding page+index (0 = failed).
      Handle format: (Page * MAX_BACKGR_STACK + Idx + 1) so PopBackGr
      can recover the correct page even if called when a different page
      is current (e.g. menu code uses a cached Page variable). }
  var
    Idx: Integer;
    DataSize: Word;
    i, j: Integer;
    WX: Integer;
    Offs: LongInt;
    DstOffs: Integer;
  begin
    PushBackGr := 0;

    if not ((Y + H >= 0) and (Y < 200)) then
      Exit;

    Idx := StackTops[Page];
    if Idx >= MAX_BACKGR_STACK then
      Exit;

    DataSize := W * H;
    if DataSize = 0 then Exit;

    { NOTE: Do NOT use "with BackGrStacks[Page, Idx] do" here!
      The record has fields named X, Y, W, H which would shadow the
      function parameters of the same name, causing silent data corruption. }

    { Free old data if this slot was previously used }
    if BackGrStacks[Page, Idx].Valid and (BackGrStacks[Page, Idx].Data <> nil) then
      FreeMem(BackGrStacks[Page, Idx].Data, BackGrStacks[Page, Idx].DataSize);
    GetMem(BackGrStacks[Page, Idx].Data, DataSize);
    if BackGrStacks[Page, Idx].Data = nil then
    begin
      BackGrStacks[Page, Idx].Valid := False;
      Exit;
    end;

    { Store metadata FIRST so the copy loop uses correct values }
    BackGrStacks[Page, Idx].X := X;
    BackGrStacks[Page, Idx].Y := Y;
    BackGrStacks[Page, Idx].W := W;
    BackGrStacks[Page, Idx].H := H;
    BackGrStacks[Page, Idx].DataSize := DataSize;
    BackGrStacks[Page, Idx].Valid := True;

    { Copy rectangle from framebuffer with X wrapping }
    DstOffs := 0;
    for j := 0 to H - 1 do
    begin
      if (Y + j >= 0) and (Y + j < FB_HEIGHT) then
      begin
        for i := 0 to W - 1 do
        begin
          WX := (X + i) mod VIR_SCREEN_WIDTH;
          if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
          Offs := LongInt(Y + j) * VIR_SCREEN_WIDTH + WX;
          BackGrStacks[Page, Idx].Data^[DstOffs + i] := FrameBuffer[Page, Offs];
        end;
      end
      else
        FillChar(BackGrStacks[Page, Idx].Data^[DstOffs], W, #0);
      Inc(DstOffs, W);
    end;

    Inc(StackTops[Page]);
    { Encode page into handle so PopBackGr can find the right stack }
    PushBackGr := Word(Page * MAX_BACKGR_STACK + Idx + 1);
  end;

  procedure PopBackGr (Address: Word);
    { Restore background from handle. Handle encodes source page+index
      so we find the right data. But restore always goes to the CURRENT
      page (Page variable), matching original VGA behavior where PopBackGr
      writes via PageOffset to the current display page. }
  var
    Pg: Integer;
    Idx: Integer;
    i, j: Integer;
    WX: Integer;
    Offs: LongInt;
    SrcOffs: Integer;
  begin
    if Address = 0 then
      Exit;

    { Decode source page and index from handle }
    Dec(Address);
    Pg := Integer(Address) div MAX_BACKGR_STACK;
    Idx := Integer(Address) mod MAX_BACKGR_STACK;

    if (Pg < 0) or (Pg > MAX_PAGE) then Exit;
    if (Idx < 0) or (Idx >= MAX_BACKGR_STACK) then Exit;

    with BackGrStacks[Pg, Idx] do
    begin
      if not Valid then Exit;
      if Data = nil then Exit;

      { Restore rectangle to the CURRENT page (not the source page).
        In the original VGA, PopBackGr reads saved data from the stack
        area (which is per-page) but writes to PageOffset (current page).
        The menu uses a cached Page variable for BG array indexing, but
        the actual restore must go to whichever page is current now. }
      SrcOffs := 0;
      for j := 0 to H - 1 do
      begin
        if (Y + j >= 0) and (Y + j < FB_HEIGHT) then
        begin
          for i := 0 to W - 1 do
          begin
            WX := (X + i) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(Y + j) * VIR_SCREEN_WIDTH + WX;
            FrameBuffer[Page, Offs] := Data^[SrcOffs + i];
          end;
        end;
        Inc(SrcOffs, W);
      end;
    end;
  end;


  { ===== Bitmap Drawing (for text) ===== }

  procedure DrawBitmap (X, Y: Integer; var BitMap; Attr: Byte);
    { Draw a 1-bit bitmap. Bitmap starts with width byte, height byte,
      then packed bit data (LSB first, matching original x86 SHR/JNC). }
  var
    Src: PByte;
    BmW, BmH: Integer;
    i, j: Integer;
    CurByte: Byte;
    BitsLeft: Integer;
    SrcIdx: Integer;
  begin
    Src := @BitMap;
    BmW := Src[0];
    BmH := Src[1];
    SrcIdx := 2;
    BitsLeft := 0;
    CurByte := 0;

    for j := 0 to BmH - 1 do
    begin
      for i := 0 to BmW - 1 do
      begin
        if BitsLeft = 0 then
        begin
          CurByte := Src[SrcIdx];
          Inc(SrcIdx);
          BitsLeft := 8;
        end;
        Dec(BitsLeft);
        if (CurByte and 1) <> 0 then
          PutPixel(X + i, Y + j, Attr);
        CurByte := CurByte shr 1;
      end;
    end;
  end;


  { ===== SDL Event Processing ===== }

  procedure PollEvents;
  var
    Event: TSDL_Event;
  begin
    { Process SDL events - keyboard handling is done by the Keyboard unit }
    { Here we just check for quit }
    while SDL_PeepEvents(@Event, 1, SDL_GETEVENT, SDL_QUITEV, SDL_QUITEV) > 0 do
    begin
      QuitRequested := True;
      Halt(0);
    end;
  end;

  function IsQuitRequested: Boolean;
  begin
    IsQuitRequested := QuitRequested;
  end;

  { ===== Unit Initialization ===== }

var
  i: Integer;

begin
  QuitRequested := False;
  Page := 0;
  PageOffset := PAGE_0;
  XView := 0;
  YView := 0;
  YOffset := 0;
  SDLWindow := nil;
  SDLRenderer := nil;
  RenderTexture := nil;
  FillChar(FrameBuffer, SizeOf(FrameBuffer), 0);
  FillChar(PaletteR, SizeOf(PaletteR), 0);
  FillChar(PaletteG, SizeOf(PaletteG), 0);
  FillChar(PaletteB, SizeOf(PaletteB), 0);
  FillChar(BackGrStacks, SizeOf(BackGrStacks), 0);
  FillChar(StackTops, SizeOf(StackTops), 0);
end.
