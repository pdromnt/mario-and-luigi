unit BackGr;

{ SDL2 port of background rendering unit }
{ Original (C) Copyright 1994-2001, Mike Wiering }
{ All VGA planar/Mode13h assembly replaced with linear FrameBuffer access }

{$R-} { no range-checking }

interface

  uses
    Buffers,
    VGA256,
    Palettes;

  const
    Left = 0;
    Right = 1;
    Shift = 16;

  var
    BackGround: Byte;

  procedure InitBackGr (NewBackGr, bClouds: Byte);
  procedure DrawBackGr (FirstTime: Boolean);
  procedure DrawBackGrMap (Y1, Y2, Shift: Integer; C: Byte);
  procedure StartClouds;
  procedure DrawPalBackGr;
  procedure ReadColorMap;
  procedure DrawBricks (X, Y, W, H: Integer);
  procedure LargeBricks (X, Y, W, H: Integer);
  procedure Pillar (X, Y, W, H: Integer);
  procedure Windows (X, Y, W, H: Integer);
  procedure DrawBackGrBlock (X, Y, W, H: Integer);
  procedure SmoothFill (X, Y, W, H: Integer);

implementation

  {$I data\palbrick.inc}
  {$I data\palpill.inc}

  {$I data\backgrounds.inc}

  const
    Speed = 3;
    BrickSpeed = 2;
    Max = (MaxWorldSize div Speed) * W;
    Height = 26;  { 7, 15, 20, 21, 23, 24, 26 }
    CloudSpeed = 4;
    MaxClouds = 7;
    MinCloudSize = 30;
    MaxCloudSize = 70;
    CloudHeight = 19;

  var
    BackGrMap: array [0 .. Max] of Byte;
    ColorMap: array [0 .. NV * H - 1] of Word;
    CloudMap: array [1 .. 2 * MaxClouds, 0 .. 1] of Integer;
    Clouds: Byte;


  procedure InitClouds;
  begin
    CloudMap [1, 0] :=   50; CloudMap [1, 1] :=  58; CloudMap [MaxClouds + 1, 0] :=   92;
    CloudMap [2, 0] :=  180; CloudMap [2, 1] :=  20; CloudMap [MaxClouds + 2, 0] :=  228;
    CloudMap [3, 0] :=  430; CloudMap [3, 1] :=  40; CloudMap [MaxClouds + 3, 0] :=  484;
    CloudMap [4, 0] :=  570; CloudMap [4, 1] :=  15; CloudMap [MaxClouds + 4, 0] :=  600;
    CloudMap [5, 0] :=  840; CloudMap [5, 1] :=  30; CloudMap [MaxClouds + 5, 0] :=  900;
    CloudMap [6, 0] :=  980; CloudMap [6, 1] :=  60; CloudMap [MaxClouds + 6, 0] := 1040;
    CloudMap [7, 0] := 1200; CloudMap [7, 1] :=  20; CloudMap [MaxClouds + 7, 0] := 1240;
  end;


  procedure TraceCloud (X, Y, N: Integer; Dir, Attr, Ovr: Byte);
  { Original used Mode 13h linear (320-byte rows) writing to segment $A000.
    Converted to FrameBuffer[CurrentPage] with VIR_SCREEN_WIDTH row pitch.

    Draws a cloud edge shape. The shape is defined by 19 rows of horizontal
    delta offsets. For each of the 19 rows, N pixels are drawn horizontally.
    The delta offsets are cumulative, shifting the drawing position left/right
    to create the curved cloud edge.

    A pixel is only overwritten if its current value matches Ovr, and it must
    be within the horizontal clipping range [MinX..MaxX] which tracks XView
    on the current scanline. Drawing stops early on a row if a non-matching
    pixel is found after at least one successful match (creating clean edges). }
  const
    LeftDeltas: array[0..18] of Integer =
      (9, -3, -2, -1, -1, -1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 2, 3);
    RightDeltas: array[0..18] of Integer =
      (0, 3, 2, 1, 1, 1, 0, 1, 0, 0, 0, 0, -1, 0, -1, -1, -1, -2, -3);
  var
    Row, Col: Integer;
    MinX, MaxX: Integer;
    CurX: Integer;
    Pg: Integer;
    Offs: LongInt;
    WX: Integer;
    Pix: Byte;
    Ok: Boolean;
  begin
    if N = 0 then Exit;
    Pg := CurrentPage;

    { The deltas are cumulative, starting from X }
    CurX := X;

    for Row := 0 to 18 do
    begin
      { Apply cumulative horizontal delta }
      if Dir = Left then
        CurX := CurX + LeftDeltas[Row]
      else
        CurX := CurX + RightDeltas[Row];

      { Clipping: Min/Max advance by one row each iteration (in the original
        they advanced by 320 bytes = one scanline). Here we just track the
        Y coordinate and use XView for horizontal clipping. }
      MinX := XView;
      MaxX := XView + SCREEN_WIDTH - 1;

      Ok := False;
      if (Y + Row >= 0) and (Y + Row < FB_HEIGHT) then
      begin
        for Col := 0 to N - 1 do
        begin
          WX := (CurX + Col) mod VIR_SCREEN_WIDTH;
          if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
          Offs := LongInt(Y + Row) * VIR_SCREEN_WIDTH + WX;
          Pix := FrameBuffer[Pg, Offs];
          if Pix = Ovr then
          begin
            if (CurX + Col >= MinX) and (CurX + Col <= MaxX) then
            begin
              FrameBuffer[Pg, Offs] := Attr;
              Ok := True;
            end
            else
            begin
              { Outside clipping range after having drawn: stop this row }
              if Ok then Break;
            end;
          end;
        end;
      end;
    end;
  end;


  procedure PutClouds (Offset, N: Integer);
  var
    i, X1, X2, Y: Integer;
    Attr, Ovr, Size, XSize: Byte;
  begin
    if Clouds = 0 then Exit;
    i := 1;
    repeat
      Attr := Clouds;
      Ovr := $E0;
      X1 := XView - Offset + CloudMap [i, 0];
      X2 := XView - Offset + CloudMap [i + MaxClouds, 0];
      XSize := X2 - X1 + 1;
      Y := CloudMap [i, 1];

      if N > 0 then
      begin
        Size := 0;
        if X2 + 10 >= XView + NH * W then Size := 10;
        if (X2 + 10 > XView) and (X2 < XView + NH * W + 10) then
          TraceCloud (X2 - N - Size, Y, N + Size, Right, Attr, Ovr);
        if (X1 + 10 > XView) and (X1 < XView + NH * W) then
        begin
          TraceCloud (X1 - N, Y, N, Left, Ovr, Attr);
          if not (X2 < XView + NH * W) then
            TraceCloud (X1, Y, XSize, Left, Attr, Ovr);
        end;
      end;
      if N < 0 then
      begin
        if (X2 + 10 > XView) and (X2 < XView + NH * W + 10) then
        begin
          TraceCloud (X2, Y, - N, Right, Ovr, Attr);
          if not (X1 > XView - 10) then
            TraceCloud (X2 - XSize, Y, XSize, Right, Attr, Ovr);
        end;
        Size := 0;
        if X1 < XView + 10 then Size := 10;
        if (X1 + 10 > XView) and (X1 < XView + NH * W + 10) then
          TraceCloud (X1, Y, - N + Size, Left, Attr, Ovr);
      end;

      Inc (i);
    until (i > MaxClouds);
  end;


  procedure StartClouds;
  var
    i: Integer;
  begin
    if Clouds = 0 then Exit;
    for i := XView + MaxCloudSize downto XView do
    begin
      XView := i;
      PutClouds (i div CloudSpeed, -CloudSpeed);
    end;
  end;


  procedure InitBackGr (NewBackGr, bClouds: Byte);
  var
    i: Integer;
  begin
    BackGround := NewBackGr;
    case BackGround of
      1, 2:
         begin
           Move (BogenData, BackGrMap, SizeOf (BackGrMap));
         end;
      3: begin
           Move (MountData, BackGrMap, SizeOf (BackGrMap));
         end;
      9: Move (Bogen7Data, BackGrMap, SizeOf (BackGrMap));
     10: Move (Bogen26Data, BackGrMap, SizeOf (BackGrMap));
    end;
    if BackGround in [1, 9, 10] then
      for i := 0 to Max do
        BackGrMap [i] := Height - BackGrMap [i] + 1;

    Clouds := bClouds;
    if Clouds <> 0 then
      InitClouds;
  end;


  procedure PutBackGr (var Map; Fill: Boolean);
  { Original uses planar VGA addressing (BYTES_PER_LINE=90, 4 planes).
    Converted to linear FrameBuffer access with VIR_SCREEN_WIDTH row pitch.

    The background map contains height values indexed by pixel column.
    For each visible column, we compare the new height (from current scroll
    position) with the old height (from previous scroll position) and update
    the framebuffer accordingly:
    - Pixels below the arch line: should be $E0 (background/fill color)
    - Pixels above the arch line: should be $F0 (sky color)
    Only pixels that need to change are modified (conditional on current value).

    In Fill mode (first-time draw), every column gets full treatment.
    In delta mode, only the difference between old and new heights is drawn,
    plus any newly exposed columns from scrolling.

    The original code iterates 4 times (once per VGA plane), processing
    every 4th pixel column each time. In our linear framebuffer, we simply
    iterate over every pixel column once. }
  var
    MapData: PByte;
    Col, Row: Integer;
    DX: Integer;
    OldXView_: Integer;
    X1Pos, X2Pos: Integer;
    NewMapIdx, OldMapIdx: Integer;
    NewH, OldH: Integer;
    BaseY: Integer;
    Pg: Integer;
    Offs: LongInt;
    WX: Integer;
    Pix: Byte;
    DoFill: Boolean;
  begin
    Pg := CurrentPage;
    MapData := @Map;
    OldXView_ := LastXView[Pg];
    BaseY := Options.Horizon - Height;
    DX := XView - OldXView_;

    { X1Pos..X2Pos defines the range where delta mode is used.
      Columns outside this range get full fill treatment. }
    X1Pos := XView;
    X2Pos := OldXView_ + NH * W - 1;
    if DX < 0 then
    begin
      X1Pos := OldXView_;
      X2Pos := XView + NH * W - 1;
    end;

    { Process every visible column }
    for Col := XView to XView + NH * W - 1 do
    begin
      { Wrap X coordinate for framebuffer access }
      WX := Col mod VIR_SCREEN_WIDTH;
      if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);

      { Map index for current position: XView div Speed + (Col - XView)
        This gives each pixel column its own map entry. }
      NewMapIdx := (XView div Speed) + (Col - XView);

      { Map index for old position: OldXView div Speed + (Col - XView)
        Note: the original uses OldXStart = OldXView div Speed + DX, and
        increments by 1 per column, so for column offset k from XView:
        OldMapIdx = OldXView div Speed + DX + k = OldXView div Speed + (XView - OldXView) + k }
      OldMapIdx := (OldXView_ div Speed) + DX + (Col - XView);

      { Bounds check map indices }
      if (NewMapIdx < 0) or (NewMapIdx > Max) then Continue;
      if (OldMapIdx < 0) or (OldMapIdx > Max) then
        OldMapIdx := NewMapIdx;

      NewH := MapData[NewMapIdx];
      OldH := MapData[OldMapIdx];

      { Determine if this column gets full fill or delta treatment }
      DoFill := Fill or (Col < X1Pos) or (Col > X2Pos);

      if DoFill then
      begin
        { Full column fill: iterate from row 0 to HEIGHT.
          Below NewH: if pixel is $F0, write $E0 (add background)
          At/above NewH: if pixel is $E0, write $F0 (restore sky) }
        for Row := 0 to Height do
        begin
          if (BaseY + Row >= 0) and (BaseY + Row < FB_HEIGHT) then
          begin
            Offs := LongInt(BaseY + Row) * VIR_SCREEN_WIDTH + WX;
            Pix := FrameBuffer[Pg, Offs];
            if Row < NewH then
            begin
              { Below arch: background color }
              if Pix = $F0 then
                FrameBuffer[Pg, Offs] := $E0;
            end
            else
            begin
              { Above arch: sky color }
              if Pix = $E0 then
                FrameBuffer[Pg, Offs] := $F0;
            end;
          end;
        end;
      end
      else
      begin
        { Delta mode: only update rows that changed between old and new height }
        if NewH = OldH then
          { No change }
        else if NewH > OldH then
        begin
          { Arch grew taller: fill from OldH to NewH-1 with background.
            These rows were sky ($F0) and should become background ($E0). }
          for Row := OldH to NewH - 1 do
          begin
            if (BaseY + Row >= 0) and (BaseY + Row < FB_HEIGHT) then
            begin
              Offs := LongInt(BaseY + Row) * VIR_SCREEN_WIDTH + WX;
              if FrameBuffer[Pg, Offs] = $F0 then
                FrameBuffer[Pg, Offs] := $E0;
            end;
          end;
        end
        else
        begin
          { Arch shrunk: erase from NewH to OldH-1 with sky.
            These rows were background ($E0) and should become sky ($F0). }
          for Row := NewH to OldH - 1 do
          begin
            if (BaseY + Row >= 0) and (BaseY + Row < FB_HEIGHT) then
            begin
              Offs := LongInt(BaseY + Row) * VIR_SCREEN_WIDTH + WX;
              if FrameBuffer[Pg, Offs] = $E0 then
                FrameBuffer[Pg, Offs] := $F0;
            end;
          end;
        end;
      end;
    end;
  end;


  procedure BrickPalette (i: Integer);
  var
    j: Integer;
  begin
    i := i mod 20;
    for j := 0 to 19 do
      if (i = j) then
        CopyPalette ($FE, $E0 + j)
      else
        if (((i + 2) mod 20) = j) then
          CopyPalette ($FF, $E0 + j)
        else
          CopyPalette ($FD, $E0 + j);
  end;

  procedure LargeBrickPalette (i: Integer);
  var
    j: Integer;
  begin
    i := i mod 32;
    for j := 0 to 31 do
      if (i = j) or (((i + 1) mod 32) = j) then
        CopyPalette ($D6, $E0 + j)
      else
        if (((i + 3) mod 32) = j) or (((i + 4) mod 32) = j) then
          CopyPalette ($D4, $E0 + j)
        else
          CopyPalette ($D1, $E0 + j);
  end;

  procedure PillarPalette (i: Integer);
  const
    ShadowPos = 28;
    ShadowEnd = 36;
  var
    j, k, l: Integer;
    c1, c2, c3,
    Base: Byte;
  begin
    Base := Options.BackGrColor1;
    C1 := Palette [Base, 0] div 4;
    C2 := Palette [Base, 1] div 4;
    C3 := Palette [Base, 2] div 4;
    i := i mod 60;
    j := 0;
    k := 1;
    repeat
      for l := j to k do
      begin
        OutPalette ($C0 + ((l + i) mod 60), C1 + k, C2 + k, C3 + k);
        OutPalette ($C0 + ((ShadowPos + i - l) mod 60), C1 + k, C2 + k, C3 + k);
      end;
      j := k;
      k := k + 1;
    until k >= 15;
    for j := ShadowPos to ShadowEnd do
    begin
      if C1 > 0 then Dec (C1);
      if C2 > 0 then Dec (C2);
      if C3 > 0 then Dec (C3);
      OutPalette ($C0 + ((j + i) mod 60), C1, C2, C3);
    end;
    Base := Options.BackGrColor2;
    C1 := Palette [Base, 0] div 4;
    C2 := Palette [Base, 1] div 4;
    C3 := Palette [Base, 2] div 4;
    for j := ShadowEnd + 1 to 59 do
      OutPalette ($C0 + ((i + j) mod 60), C1, C2, C3);
  end;

  procedure WindowPalette (i: Integer);
  var
    j: Integer;
  begin
    i := i mod 32;
    for j := 0 to 5 do
      CopyPalette (1, $E0 + ((i + j) mod 32));
    for j := 6 to 31 do
      CopyPalette (16, $E0 + ((i + j) mod 32));
  end;

  procedure DrawBackGr (FirstTime: Boolean);
  var
    i: Integer;
  begin
    case BackGround of
      1 .. 3,
      9..11: PutBackGr (BackGrMap, FirstTime);
    end;

    if Clouds <> 0 then
    begin
      i := XView div CloudSpeed;
      PutClouds (i, XView - LastXView [CurrentPage]);
    end;
  end;

  procedure DrawBackGrMap (Y1, Y2, Shift: Integer; C: Byte);
    var
      i, j: Integer;
  begin
    for i := 0 to 320 - 1 do
    begin
      for j := Y1 - BackGrMap[i + Shift] to Y2 do
        if GetPixel (i, j) >= $C0 then
          PutPixel (i, j, C);
    end;
  end;

  procedure DrawPalBackGr;
  var
    i: Integer;
  begin
    i := Round (XView / BrickSpeed);
    case BackGround of
      4: BrickPalette (i);
      5: LargeBrickPalette (i);
      6: PillarPalette (i);
      7: WindowPalette (i);
    end;
  end;

  procedure ReadColorMap;
  var
    i: Integer;
  begin
    for i := 0 to NV * H - 1 do
      ColorMap [i] := GetPixel (XView + Shift, i) * 256 +
        GetPixel (XView + Shift + 1, i);
  end;

  procedure DrawBricks (X, Y, W, H: Integer);
  begin
    PutImage (X, Y, W, H, Palbrick000Data);
  end;

  procedure LargeBricks (X, Y, W, H: Integer);
  { Original used Mode 13h linear (320-byte rows) writing to segment $A000.
    Converted to FrameBuffer[CurrentPage] with VIR_SCREEN_WIDTH row pitch.

    Draws tiled large brick patterns with 3-row mortar lines every 16 rows.
    Brick body uses cycling palette colors $E0..$FF (32-entry cycle).
    The brick offset alternates by 16 pixels at every mortar line to create
    the staggered brick-laying pattern.

    Row within 16-row cycle:
      0: mortar color $D6 (brightest), toggles brick shift
      1: mortar color $D1 (darkest)
      2: mortar color $D4 (medium)
      3-15: brick body with cycling colors }
  var
    Row, Col: Integer;
    BaseColor: Byte;
    RowMod16: Integer;
    Pg: Integer;
    Offs: LongInt;
    WX: Integer;
    C, BrickCol: Byte;
  begin
    if (W <= 0) or (H <= 0) then Exit;
    Pg := CurrentPage;

    BaseColor := (X and $1F);

    if ((Y + 14) and $10) <> 0 then
      BaseColor := BaseColor xor 16;

    for Row := 0 to H - 1 do
    begin
      if (Y + Row >= 0) and (Y + Row < FB_HEIGHT) then
      begin
        RowMod16 := (Y + Row) and $0F;

        if RowMod16 = 0 then
        begin
          { Mortar line at row%16==0: color $D6, toggle brick shift }
          C := $D6;
          BaseColor := BaseColor xor 16;
          for Col := 0 to W - 1 do
          begin
            WX := (X + Col) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(Y + Row) * VIR_SCREEN_WIDTH + WX;
            FrameBuffer[Pg, Offs] := C;
          end;
        end
        else if RowMod16 = 1 then
        begin
          { Mortar line at row%16==1: color $D1 }
          C := $D1;
          for Col := 0 to W - 1 do
          begin
            WX := (X + Col) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(Y + Row) * VIR_SCREEN_WIDTH + WX;
            FrameBuffer[Pg, Offs] := C;
          end;
        end
        else if RowMod16 = 2 then
        begin
          { Mortar line at row%16==2: color $D4 }
          C := $D4;
          for Col := 0 to W - 1 do
          begin
            WX := (X + Col) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(Y + Row) * VIR_SCREEN_WIDTH + WX;
            FrameBuffer[Pg, Offs] := C;
          end;
        end
        else
        begin
          { Brick body: cycling colors }
          BrickCol := BaseColor;
          for Col := 0 to W - 1 do
          begin
            WX := (X + Col) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(Y + Row) * VIR_SCREEN_WIDTH + WX;
            C := $E0 + (BrickCol and $1F);
            FrameBuffer[Pg, Offs] := C;
            Inc(BrickCol);
          end;
        end;
      end
      else
      begin
        { Row is off-screen but we still need to track mortar toggles }
        RowMod16 := (Y + Row) and $0F;
        if RowMod16 = 0 then
          BaseColor := BaseColor xor 16;
      end;
    end;
  end;


  procedure Pillar (X, Y, W, H: Integer);
  begin
    case (X div W) mod 3 of
      0: PutImage (X, Y, W, H, Palpill000Data);
      1: PutImage (X, Y, W, H, Palpill001Data);
      2: PutImage (X, Y, W, H, Palpill002Data);
    end;
  end;


  procedure Windows (X, Y, W, H: Integer);
  { Original used Mode 13h linear (320-byte rows) writing to segment $A000.
    Converted to FrameBuffer[CurrentPage] with VIR_SCREEN_WIDTH row pitch.

    Draws building window patterns. Within each 32-row cycle, rows where
    (Y+22) AND $1F < 3 are "glass" rows (solid color 1 = white/light),
    and the remaining rows are "wall" with cycling palette colors. }
  var
    Row, Col: Integer;
    BaseColor: Byte;
    RowInWindow: Integer;
    Pg: Integer;
    Offs: LongInt;
    WX: Integer;
    C, WallCol: Byte;
  begin
    if (W <= 0) or (H <= 0) then Exit;
    Pg := CurrentPage;

    { Base color from X position, same as LargeBricks }
    BaseColor := X and $1F;

    for Row := 0 to H - 1 do
    begin
      if (Y + Row >= 0) and (Y + Row < FB_HEIGHT) then
      begin
        RowInWindow := (Y + Row + 22) and $1F;

        if RowInWindow < 3 then
        begin
          { Glass/light rows: fill with color 1 }
          for Col := 0 to W - 1 do
          begin
            WX := (X + Col) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(Y + Row) * VIR_SCREEN_WIDTH + WX;
            FrameBuffer[Pg, Offs] := 1;
          end;
        end
        else
        begin
          { Wall rows: cycling colors $E0 + ((BaseColor + Col) AND $1F) }
          WallCol := BaseColor;
          for Col := 0 to W - 1 do
          begin
            WX := (X + Col) mod VIR_SCREEN_WIDTH;
            if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
            Offs := LongInt(Y + Row) * VIR_SCREEN_WIDTH + WX;
            C := $E0 or (WallCol and $1F);
            FrameBuffer[Pg, Offs] := C;
            Inc(WallCol);
          end;
        end;
      end;
    end;
  end;


  procedure DrawBackGrBlock (X, Y, W, H: Integer);
  var
    i: Integer;
  begin
    if Options.SkyType in [2, 5, 9, 10, 11] then
      SmoothFill (X, Y, W, H)
    else
      case BackGround of

        4: DrawBricks (X, Y, W, H);
        5: LargeBricks (X, Y, W, H);
        6: Pillar (X, Y, W, H);
        7: Windows (X, Y, W, H);
        else
          for i := 0 to H - 1 do
            Fill (X, Y + i, W, 1, ColorMap [Y + i]);
      end;
  end;


  procedure SmoothFill (X, Y, W, H: Integer);
  { Original used planar VGA (VIR_SCREEN_WIDTH/4 bytes per row, plane masking).
    Converted to linear FrameBuffer access with VIR_SCREEN_WIDTH row pitch.
    Constraint from original: X mod 4 = 0, W mod 4 = 0.

    Draws a vertical gradient using colors $E0..$EF..$F0.
    The color decreases by 1 every 6 rows (getting lighter toward the horizon).
    At Y >= Horizon, the color is fixed at $F0 (ground/sky boundary).

    Dithering: on sub-rows 3, 4, 5 within each 6-row band, a secondary color
    (one step darker, i.e. color-1) is drawn on specific pixel columns:
      - Sub-row 3 (dh=3, dh AND 1 = 1): plane 1 -> pixels where col mod 4 == 1
      - Sub-row 4 (dh=4, dh AND 1 = 0): plane 0 -> pixels where col mod 4 == 0
      - Sub-row 5 (dh=5, dh AND 1 = 1): plane 1 -> pixels where col mod 4 == 1
    This creates a smooth gradient transition between color bands.

    When the base color is $E0 or $F0, no dithering is applied. }
  var
    Row, Col: Integer;
    Pg: Integer;
    Offs: LongInt;
    WX: Integer;
    BaseColor: Byte;       { dl in original: the main fill color }
    SubRow: Byte;           { dh in original: 0..5 position within 6-row band }
    Horizon: Integer;
    CurY: Integer;
    DitherColor: Byte;
    DitherPlane: Integer;   { which plane (mod 4 value) gets the dither }
  begin
    if (W <= 0) or (H <= 0) then Exit;
    Pg := CurrentPage;
    Horizon := Options.Horizon - 4;  { -4 for BumpBlock }

    { Calculate initial color and sub-row position from Y.
      Original: ax = Y; div 6 -> al = Y/6, ah = Y mod 6
      dl = $EF - al; if dl < $E0 then dl = $E0; dh = ah }
    if Y >= Horizon then
    begin
      BaseColor := $F0;
      SubRow := Y mod 6;
    end
    else
    begin
      BaseColor := $EF - (Y div 6);
      if BaseColor < $E0 then
        BaseColor := $E0;
      SubRow := Y mod 6;
    end;

    for Row := 0 to H - 1 do
    begin
      CurY := Y + Row;
      if (CurY >= 0) and (CurY < FB_HEIGHT) then
      begin
        { First pass: fill entire row with BaseColor, with X wrapping }
        for Col := 0 to W - 1 do
        begin
          WX := (X + Col) mod VIR_SCREEN_WIDTH;
          if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
          Offs := LongInt(CurY) * VIR_SCREEN_WIDTH + WX;
          FrameBuffer[Pg, Offs] := BaseColor;
        end;

        { Second pass: dithering on sub-rows >= 3 }
        if SubRow >= 3 then
        begin
          { Compute dither color: BaseColor - 1, unless at $E0 or $F0 }
          if (BaseColor <> $E0) and (BaseColor <> $F0) then
            DitherColor := BaseColor - 1
          else
            DitherColor := BaseColor;

          { Determine which pixel columns get the dither:
            dh AND 1 selects the VGA plane.
            SubRow=3: plane 1 (col mod 4 == 1)
            SubRow=4: plane 0 (col mod 4 == 0)
            SubRow=5: plane 1 (col mod 4 == 1) }
          DitherPlane := SubRow and 1;  { 0 for even subrow, 1 for odd }

          { Only overwrite if dither color differs from base }
          if DitherColor <> BaseColor then
          begin
            Col := DitherPlane;
            while Col < W do
            begin
              WX := (X + Col) mod VIR_SCREEN_WIDTH;
              if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
              Offs := LongInt(CurY) * VIR_SCREEN_WIDTH + WX;
              FrameBuffer[Pg, Offs] := DitherColor;
              Inc(Col, 4);
            end;
          end;
        end;
      end;

      { Advance sub-row and color for next row.
        Original: inc Y; if Y >= Horizon then dl = $F0;
                  inc dh; if dh = 6 then dh = 0 and dec dl (unless $E0/$F0) }
      if (CurY + 1) >= Horizon then
        BaseColor := $F0;
      Inc(SubRow);
      if SubRow >= 6 then
      begin
        SubRow := 0;
        if (BaseColor <> $E0) and (BaseColor <> $F0) then
          Dec(BaseColor);
      end;
    end;
  end;

end.
