unit Figures;

{  SDL2 port of Figures unit                      }
{  Original (C) Copyright 1994-2001, Mike Wiering  }
{  All VGA planar assembler replaced with pure     }
{  Pascal operating on linear byte framebuffer     }

{$R-}  { no range-checking }

interface

  uses
    Buffers,
    Palettes,
    VGA256,
    BackGr;

  const
    N1 = 3;
    N2 = 13;

  var
    FigList: Array [1 .. N1, 1 .. N2] of ImageBuffer;

    Bricks: Array [0 .. 3] of ImageBuffer;

  var
    Sky: Byte;

  procedure ReColor (P1, P2: Pointer; C: Byte);
  procedure ReColor2 (P1, P2: Pointer; C1, C2: Byte);
  procedure Replace (P1, P2: Pointer; N1, N2: Byte);
  procedure Mirror (P1, P2: Pointer);
  procedure Rotate (P1, P2: Pointer);
  procedure InitSky (NewSky: Byte);
  procedure InitPipes (NewColor: Byte);
  procedure InitWalls (W1, W2, W3: Byte);
  procedure DrawSky (X, Y, W, H: Integer);
  procedure SetSkyPalette;
  procedure Redraw (X, Y: Integer);
  procedure BuildWorld;

implementation

  { -- Sprite data includes (linear byte-per-pixel format) -- }

  {$I sprites\GREEN000.inc} {$I sprites\GREEN001.inc} {$I sprites\GREEN002.inc}
  {$I sprites\GREEN003.inc} {$I sprites\GREEN004.inc}

  {$I sprites\GROUND000.inc} {$I sprites\GROUND001.inc} {$I sprites\GROUND002.inc}
  {$I sprites\GROUND003.inc} {$I sprites\GROUND004.inc}

  {$I sprites\SAND000.inc} {$I sprites\SAND001.inc} {$I sprites\SAND002.inc}
  {$I sprites\SAND003.inc} {$I sprites\SAND004.inc}

  {$I sprites\BROWN000.inc} {$I sprites\BROWN001.inc} {$I sprites\BROWN002.inc}
  {$I sprites\BROWN003.inc} {$I sprites\BROWN004.inc}

  {$I sprites\GRASS000.inc} {$I sprites\GRASS001.inc} {$I sprites\GRASS002.inc}
  {$I sprites\GRASS003.inc} {$I sprites\GRASS004.inc}

  {$I sprites\DES000.inc} {$I sprites\DES001.inc} {$I sprites\DES002.inc}
  {$I sprites\DES003.inc} {$I sprites\DES004.inc}

  {$I sprites\GRASS1000.inc} {$I sprites\GRASS2000.inc} {$I sprites\GRASS3000.inc}
  {$I sprites\GRASS1001.inc} {$I sprites\GRASS2001.inc} {$I sprites\GRASS3001.inc}
  {$I sprites\GRASS1002.inc} {$I sprites\GRASS2002.inc} {$I sprites\GRASS3002.inc}

  {$I sprites\PIPE000.inc} {$I sprites\PIPE001.inc} {$I sprites\PIPE002.inc} {$I sprites\PIPE003.inc}

  {$I sprites\BLOCK000.inc} {$I sprites\BLOCK001.inc}

  {$I sprites\QUEST000.inc} {$I sprites\QUEST001.inc}

  {$I sprites\WPALM000.inc}

  {$I sprites\PALM0000.inc} {$I sprites\PALM1000.inc} {$I sprites\PALM2000.inc} {$I sprites\PALM3000.inc}
  {$I sprites\PALM0001.inc} {$I sprites\PALM1001.inc} {$I sprites\PALM2001.inc} {$I sprites\PALM3001.inc}
  {$I sprites\PALM0002.inc} {$I sprites\PALM1002.inc} {$I sprites\PALM2002.inc} {$I sprites\PALM3002.inc}

  {$I sprites\FENCE000.inc} {$I sprites\FENCE001.inc}
  {$I sprites\PIN000.inc}

  {$I sprites\FALL000.inc} {$I sprites\FALL001.inc}
  {$I sprites\LAVA000.inc} {$I sprites\LAVA001.inc}

  {$I sprites\LAVA2001.inc} {$I sprites\LAVA2002.inc} {$I sprites\LAVA2003.inc}
  {$I sprites\LAVA2004.inc} {$I sprites\LAVA2005.inc}

  {$I sprites\TREE000.inc} {$I sprites\TREE001.inc} {$I sprites\TREE002.inc} {$I sprites\TREE003.inc}

  {$I sprites\BRICK0000.inc} {$I sprites\BRICK0001.inc} {$I sprites\BRICK0002.inc}
  {$I sprites\BRICK1000.inc} {$I sprites\BRICK1001.inc} {$I sprites\BRICK1002.inc}
  {$I sprites\BRICK2000.inc} {$I sprites\BRICK2001.inc} {$I sprites\BRICK2002.inc}

  {$I sprites\EXIT000.inc} {$I sprites\EXIT001.inc}
  {$I sprites\WOOD000.inc}

  {$I sprites\COIN000.inc}

  {$I sprites\NOTE000.inc}

  {$I sprites\WINDOW000.inc} {$I sprites\WINDOW001.inc}

  {$I sprites\SMTREE000.inc} {$I sprites\SMTREE001.inc}

  {$I sprites\XBLOCK000.inc}


  { -- Helper: copy sprite constant data into an ImageBuffer -- }

  procedure CopySpriteToBuffer (var Dest: ImageBuffer; const Src; SrcSize: Integer);
  { Copies a linear byte array into an ImageBuffer [1..H, 1..W] of Char.
    Both are W*H = 280 contiguous bytes in row-major order. }
  begin
    Move(Src, Dest, SrcSize);
  end;


  procedure ConvertGrass (P0, P1, P2: ImageBufferPtr);
  var
    i, j: Integer;
    C0, C1, C2: Byte;

  procedure Convert;
  begin
    C0 := C1;
    if C1 = C2 then Exit;
    if C1 = 2 then
    begin
      C0 := 153;
      if C2 = 0 then Exit;
      C0 := 155;
    end
    else
    if C1 = 3 then
    begin
      C0 := 154;
      if C2 = 0 then Exit;
      C0 := 156;
    end
    else  { C1 = 0 }
      if C2 = 2 then
        C0 := 157
      else
        C0 := 155;
  end;

  begin
    for i := 1 to H do
      for j := 1 to W do
      begin
        C1 := Ord (P1^ [i, j]);
        C2 := Ord (P2^ [i, j]);
        Convert;
        P0^ [i, j] := Chr (C0);
      end;
  end;


  { ReColor: For each pixel in source, if value > $10,
    mask to lower 3 bits and add color offset C. Copy to dest. }
  procedure ReColor (P1, P2: Pointer; C: Byte);
  var
    Src, Dst: PByte;
    i: Integer;
    B: Byte;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    for i := 0 to W * H - 1 do
    begin
      B := Src[i];
      if B > $10 then
        B := (B and $07) + C;
      Dst[i] := B;
    end;
  end;


  { ReColor2: For each pixel in source, if value > $10,
    mask to lower 4 bits; if >= 8, mask to lower 3 bits and add C2,
    otherwise add C1. Copy to dest. }
  procedure ReColor2 (P1, P2: Pointer; C1, C2: Byte);
  var
    Src, Dst: PByte;
    i: Integer;
    B: Byte;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    for i := 0 to W * H - 1 do
    begin
      B := Src[i];
      if B > $10 then
      begin
        B := B and $0F;
        if B >= 8 then
          B := (B and $07) + C2
        else
          B := B + C1;
      end;
      Dst[i] := B;
    end;
  end;


  { Replace: Copy source to dest, replacing any byte equal to N1 with N2 }
  procedure Replace (P1, P2: Pointer; N1, N2: Byte);
  var
    Src, Dst: PByte;
    i: Integer;
    B: Byte;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    for i := 0 to W * H - 1 do
    begin
      B := Src[i];
      if B = N1 then
        B := N2;
      Dst[i] := B;
    end;
  end;


  { Mirror: Flip tile data horizontally (linear byte format).
    Each row of W pixels is reversed left-to-right. }
  procedure Mirror (P1, P2: Pointer);
  var
    Src, Dst: PByte;
    j, i: Integer;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    for j := 0 to H - 1 do
      for i := 0 to W - 1 do
        Dst[j * W + i] := Src[j * W + (W - 1 - i)];
  end;


  { Rotate: Reverse the entire linear buffer (180-degree rotation).
    Reads source from end to start, writes to dest from start to end. }
  procedure Rotate (P1, P2: Pointer);
  var
    Src, Dst: PByte;
    i, Total: Integer;
  begin
    Src := PByte(P1);
    Dst := PByte(P2);
    Total := W * H;
    for i := 0 to Total - 1 do
      Dst[i] := Src[Total - 1 - i];
  end;


  procedure InitSky (NewSky: Byte);
  begin
    Sky := NewSky;
  end;

  procedure InitPipes (NewColor: Byte);
  begin
    ReColor (@Pipe000, @Pipe000, NewColor);
    ReColor (@Pipe001, @Pipe001, NewColor);
    ReColor (@Pipe002, @Pipe002, NewColor);
    ReColor (@Pipe003, @Pipe003, NewColor);
  end;

  procedure InitWalls (W1, W2, W3: Byte);

  procedure InitWall (N, WallType: Byte);
  var
    i, j: Integer;
  begin
    case WallType of
      0: begin
           CopySpriteToBuffer (FigList [N,  1], Green000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Green001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Green002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Green003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Green004, SizeOf(ImageBuffer));
         end;
      1: begin
           CopySpriteToBuffer (FigList [N,  1], Sand000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Sand001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Sand002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Sand003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Sand004, SizeOf(ImageBuffer));
         end;
      2: begin
           i := Options. GroundColor1;
           j := Options. GroundColor2;
           Recolor2 (@Green000, @FigList [N,  1], i, j);
           Recolor2 (@Green001, @FigList [N,  2], i, j);
           Recolor2 (@Green002, @FigList [N,  4], i, j);
           Recolor2 (@Green003, @FigList [N,  5], i, j);
           Recolor2 (@Green004, @FigList [N, 10], i, j);
         end;
      3: begin
           CopySpriteToBuffer (FigList [N,  1], Brown000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Brown001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Brown002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Brown003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Brown004, SizeOf(ImageBuffer));
         end;
      4: begin
           CopySpriteToBuffer (FigList [N,  1], Grass000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Grass001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Grass002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Grass003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Grass004, SizeOf(ImageBuffer));
         end;
      5: begin
           CopySpriteToBuffer (FigList [N,  1], Des000, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  2], Des001, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  4], Des002, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N,  5], Des003, SizeOf(ImageBuffer));
           CopySpriteToBuffer (FigList [N, 10], Des004, SizeOf(ImageBuffer));
         end;

    end;

    Mirror (@FigList [N,  1], @FigList [N,  3]);
    Rotate (@FigList [N,  4], @FigList [N,  6]);
    Rotate (@FigList [N,  1], @FigList [N,  9]);
    Rotate (@FigList [N,  2], @FigList [N,  8]);
    Rotate (@FigList [N,  3], @FigList [N,  7]);
    Mirror (@FigList [N, 10], @FigList [N, 11]);
    Rotate (@FigList [N, 11], @FigList [N, 12]);
    Mirror (@FigList [N, 12], @FigList [N, 13]);

  end;

  begin  { InitWalls }
    InitWall (1, W1);
    InitWall (2, W2);
    InitWall (3, W3);
  end;

  procedure SetSkyPalette;
  var
    i, j: Integer;
  begin
    case Sky of
      0:
        begin
           ChangePalette ($E0, 35, 45, 63);
           ChangePalette ($F0, 20, 38, 48);
           ChangePalette ($FF, 54, 57, 60);
         end;
      1:
         begin
           ChangePalette ($E0, 52, 55, 55);
           ChangePalette ($F0, 42, 48, 45);
           ChangePalette ($FF, 61, 61, 61);
         end;
      2:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 48 - 2 * j, 58 - j, 58);
          end;
          ChangePalette ($F0, 35, 48, 46);
        end;
      3:
         begin
           ChangePalette ($E0,  0,  5,  3);
           ChangePalette ($F0,  8, 12, 10);
           ChangePalette ($FF,  8, 13, 13);
         end;
      4:
         begin
           ChangePalette ($E0, 35, 45, 53);
           ChangePalette ($F0, 23, 39, 43);
           ChangePalette ($FF, 58, 60, 60);
         end;
      5:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 58 - j div 2, 56 - j, 38 - j);
          end;
          ChangePalette ($F0, 52, 49, 32);
        end;
      6: { Brown bricks }
        if Options.BackGrType = 4 then
        begin
          for i := $E0 to $EF do
            ChangePalette (i, 22, 15, 11);
          ChangePalette ($FD, 22, 15, 11);
          ChangePalette ($FE, 19, 12,  8);
          ChangePalette ($FF, 25, 18, 14);
        end
        else
        begin
          for i := $E0 to $FF do
            ChangePalette (i, 19,  9,  8);
          ChangePalette ($D1, 19,  9,  8);
          ChangePalette ($D6, 21, 11, 10);
          ChangePalette ($D4, 17,  7,  6);
        end;
      7: { Gray bricks }
        if Options.BackGrType = 4 then
        begin
          for i := $E0 to $EF do
            ChangePalette (i, 18, 18, 22);
          ChangePalette ($FD, 18, 18, 22);
          ChangePalette ($FF, 23, 23, 27);
          ChangePalette ($FE, 13, 13, 17);
        end
        else
        begin
          for i := $E0 to $FF do
            ChangePalette (i, 15, 15, 18);
          ChangePalette ($D1, 15, 15, 18);
          ChangePalette ($D4, 18, 18, 21);
          ChangePalette ($D6, 12, 12, 15);
        end;
      8: { Dark brown bricks }
        if Options.BackGrType = 4 then
        begin
          for i := $E0 to $EF do
            ChangePalette (i, 17, 10, 10);
          ChangePalette ($FD, 17, 10, 10);
          ChangePalette ($FE, 11,  5,  5);
          ChangePalette ($FF, 20, 14, 14);
        end
        else
        begin
          for i := $E0 to $FF do
            ChangePalette (i, 15,  5,  5);
          ChangePalette ($D1, 15,  5,  5);
          ChangePalette ($D4, 20, 10, 10);
          ChangePalette ($D6, 10,  0,  0);
        end;
      9:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 63 - j div 3, 50 - j, 25 - j);
          end;
          ChangePalette ($F0, 48, 35, 18);
        end;
      10:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 27 - j, 43 - j, 63 - j);
          end;
          ChangePalette ($F0, 58, 58, 63);
        end;
      11:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 60 - j, 63 - j, 63 - j);
          end;
          ChangePalette ($F0, 42, 48, 45);
        end;
      12:
        begin
          for i := $E0 to $EF do
          begin
            j := i - $E0;
            ChangePalette (i, 55 - j, 63 - j, 63);
          end;
          ChangePalette ($F0, 30, 50, 58);
          ChangePalette ($F0, 36, 45, 41);
        end;
    end;
  end;

  procedure DrawSky (X, Y, W, H: Integer);
  const
    Y1 = 0;
    Y2 = Y1 + 96;
    YStep = (Y2 - Y1) div 16;  { = 6 }
  var
    i, j, k: Integer;
    Mix: Word;
  begin
    if Options.BackGrType = 0 then
      Fill (X, Y, W, H, $E0)
    else
    case Sky of
      0, 1, 3, 4:
        begin
          i := Options.Horizon;
          j := i - Y;
          if (i < Y) then
            Fill (X, Y, W, H, $F0)
          else
            if (i > Y + H - 1) then
              Fill (X, Y, W, H, $E0)
            else
            begin
              Fill (X, Y, W, j, $E0);
              Fill (X, i, W, H - j, $F0);
            end;
        end;
      2, 5, 9, 10, 11, 12:
        SmoothFill (X, Y, W, H);
      6, 7, 8:
        case Options.BackGrType of
          4: DrawBricks (X, Y, W, H);
          5: LargeBricks (X, Y, W, H);
          6: Pillar (X, Y, W, H);
          7: Windows (X, Y, W, H);
        end;
    end;
  end;

  procedure Redraw (X, Y: Integer);
  var
    Ch: Char;
    Fig: Pointer;
    L, R, LS, RS: Boolean;
    XPos, YPos: Integer;
  begin
    XPos := X * W;
    YPos := Y * H;
    Ch := WorldMap^ [X, Y];
    if (X >= 0) and (Y >= 0) and (Y < NV) then
    begin
      if (not (Ch in [#0])) then
        if (Ch = '%') and (Options.Design = 4) then
          DrawSky (XPos, YPos, W, H div 2)
        else
          DrawSky (XPos, YPos, W, H);
      if Ch = ' ' then Exit;
      if WorldMap^ [X, Y - 1] = #18 then
      begin
        Fig := @FigList [1, 5];
        PutImage (XPos, YPos, W, H, Fig^);
      end;
      Fig := Nil;
      case Ch of

        #1 .. #26:
          begin
            if Ch > #13 then
              Ch := Chr (Ord (Ch) - 13)
            else
              if WorldMap^ [X - 1, Y] in [#14..#26] then
              begin
                if Ch in [#1, #4, #7] then
                begin
                  Fig := @FigList [1, Ord (WorldMap^ [X - 1, Y]) - 13];
                  PutImage (XPos, YPos, W, H, Fig^);
                end;
              end
              else
                if WorldMap^ [X + 1, Y] in [#14..#26] then
                  if Ch in [#3, #6, #9] then
                  begin
                    Fig := @FigList [1, Ord (WorldMap^ [X + 1, Y]) - 13];
                    PutImage (XPos, YPos, W, H, Fig^);
                  end;

            Fig := @FigList [1, Ord (Ch)];
            if not (Ch in [#1, #3, #4, #6, #7, #9]) then
            begin
              PutImage (XPos, YPos, W, H, Fig^);
              Fig := Nil;
            end;
          end;

        '?': Fig := @Quest000;
        '@': Fig := @Quest001;

        'A': begin
               L := WorldMap^ [X - 1, Y] = 'A';
               R := WorldMap^ [X + 1, Y] = 'A';
               if Odd (X + Y) then
               begin
                 RS := True;
                 LS := False;
               end
               else
               begin
                 LS := True;
                 RS := False;
               end;
               if (LS and R) then
                 Fig := @Bricks [1]
               else
                 if (RS and L) then
                   Fig := @Bricks [2]
                 else
                   Fig := @Bricks [0]
             end;


        'I': Fig := @Block000;
        'J': Fig := @Block001;
        'K': Fig := @Note000;

        'X': Fig := @XBlock000;

        'W': Fig := @Wood000;
        '=': begin
               Fig := @Pin000;
               if WorldMap^ [X, Y + 1] in CanHoldYou then
                 DrawImage (XPos, YPos, W, H, Fig^)
               else
                 UpSideDown (XPos, YPos, W, H, Fig^);
               Fig := NIL;
             end;

        '0': Fig := @Pipe000;
        '1': Fig := @Pipe001;
        '2': Fig := @Pipe002;
        '3': Fig := @Pipe003;

        '*': Fig := @Coin000;

        #254: if WorldMap^ [X, Y - 1] = #254 then
               Fig := @Exit001
             else
               Fig := @Exit000;

        #247: begin
               if (WorldMap^ [X, Y - 1] = #240) and (Options.Design = 2) then
               begin
                 Fig := @SmTree001;
                 DrawImage (XPos, YPos, W, H, Fig^);
               end;
               if WorldMap^ [X, Y - 1] = #246 then
                 if Options.Design in [1] then
                 begin
                   Fig := @WPalm000;
                   DrawImage (XPos, YPos, W, H, Fig^);
                 end;
               if (X = 0) or (WorldMap^ [X - 1, Y] = Ch) then
               begin
                 if WorldMap^ [X + 1, Y] = Ch then
                   Fig := @Grass2000
                 else
                   Fig := @Grass3000;
               end
               else
                 if WorldMap^ [X + 1, Y] = Ch then
                   Fig := @Grass1000
                 else
                   Fig := @Grass3000;
             end;

        #240: case Options.Design of
               1: if WorldMap^ [X, Y - 1] <> Ch then
                    Fig := @Fence001
                  else
                    Fig := @Fence000;
               2: if WorldMap^ [X, Y - 1] <> Ch then
                    Fig := @SmTree000
                  else
                    Fig := @SmTree001;
             end;

        #246: case Options.Design of
               1: Fig := @WPalm000;
             end;
        #250: case Options.Design of
               1: begin
                    if WorldMap^ [X - 1, Y] = #249 then
                    begin
                      Fig := @Palm3000;
                      DrawImage (XPos, YPos, W, H, Fig^);
                    end
                    else
                    if WorldMap^ [X + 1, Y] = #249 then
                    begin
                      Fig := @Palm1000;
                      DrawImage (XPos, YPos, W, H, Fig^);
                    end;
                    Fig := @Palm0000;
                 end;
             end;
        #244: case Options.Design of
               1: begin
                    if WorldMap^ [X, Y + 1] = #246 then
                    begin
                      Fig := @WPalm000;
                      DrawImage (XPos, YPos, W, H, Fig^);
                    end;
                    Fig := @Palm1000;
                  end;
             end;
        #249: case Options.Design of
               1: Fig := @Palm2000;
             end;
        #245: case Options.Design of
               1: begin
                    if WorldMap^ [X, Y + 1] = #246 then
                    begin
                      Fig := @WPalm000;
                      DrawImage (XPos, YPos, W, H, Fig^);
                    end;
                    Fig := @Palm3000;
                  end;
             end;


        '#': case Options.Design of
               1: Fig := @Fall000;
               2: case WorldMap^ [X, Y - 1] of
                    '#': PutImage (XPos, YPos, W, H, Tree001);
                    '%': begin
                           Fig := @Tree000;
                           PutImage (XPos, YPos, W, H, Fig^);
                           Fig := @Tree003;
                         end;
                    else Fig := @Tree003;
                  end;
               3: Fig := @Window001;
               4: Fig := @Lava000;
               5: Fill (XPos, YPos, W, H, 5);
             end;
        '%': case Options.Design of
               1: Fig := @Fall001;
               2: case WorldMap^ [X, Y - 1] of
                    '%': PutImage (XPos, YPos, W, H, Tree000);
                    '#': begin
                           Fig := @Tree001;
                           PutImage (XPos, YPos, W, H, Fig^);
                           Fig := @Tree002;
                         end;
                    else
                         Fig := @Tree002;
                  end;
               3: Fig := @Window000;
               4: Fig := @Lava001;
               5: begin
                    case (X + LavaCounter div 8) mod 5 of
                      0: Fig := @Lava2001;
                      1: Fig := @Lava2002;
                      2: Fig := @Lava2003;
                      3: Fig := @Lava2004;
                      4: Fig := @Lava2005;
                    end;
                  end;
             end;

      end;
      if Fig <> Nil then
        DrawImage (XPos, YPos, W, H, Fig^);
    end;
  end;

  procedure BuildWorld;
  var
    AB,
    CD,
    EF,
    LastAB,
    LastCD,
    LastEF: Char;

  procedure BuildWall (X, Y: Integer);
  const
    IgnoreAbove = [#247];
  var
    A, B, L, R: Byte;
    N: Byte;
    C: Char;
    Ch, ChLeft: Set of Char;
  begin
    C := WorldMap^ [X, Y];
    case C of
      'A', 'B': begin
                  AB := C;
                  Ch := [C] + [#1 .. #13];
                  if LastAB <> C then
                    ChLeft := Ch - [#3, #6, #9]
                  else
                    ChLeft := Ch;
                  N := 0;
                end;
      'C', 'D': begin
                  CD := C;
                  Ch := [C] + [#1..#26] + ['A', 'B'] + IgnoreAbove;
                  ChLeft := Ch;
                  N := 13;
                end;
      else Exit;
    end;
    A := 1 - Byte ((WorldMap^ [X, Y - 1] in (Ch - IgnoreAbove)) or (Y = 0));
    B := 2 * Byte (Not ((Y = NV - 1) or (WorldMap^ [X, Y + 1] in Ch)));
    L := 4 * Byte (Not ((X = 0) or (WorldMap^ [X - 1, Y] in ChLeft)));
    R := 8 * Byte (Not ((X = Options.XSize - 1) or (WorldMap^ [X + 1, Y] in Ch)));
    case A + B + L + R of
      0: begin
           if (X > 0) and (Y > 0) then
             if (not (WorldMap^ [X - 1, Y - 1] in Ch)) then
               begin WorldMap^ [X, Y] := Chr (10 + N); Exit end;
           if (X < Options.XSize - 1) and (Y > 0) then
             if not (WorldMap^ [X + 1, Y - 1] in Ch) then
               begin WorldMap^ [X, Y] := Chr (11 + N); Exit end;
           if (X > 0) and (Y < NV - 1) then
             if not (WorldMap^ [X - 1, Y + 1] in Ch) then
               begin WorldMap^ [X, Y] := Chr (12 + N); Exit end;
           if (X < Options.XSize - 1) and (Y < NV - 1) then
             if not (WorldMap^ [X + 1, Y + 1] in Ch) then
               begin WorldMap^ [X, Y] := Chr (13 + N); Exit end;
           WorldMap^ [X, Y] := Chr (5 + N);
         end;
      1: WorldMap^ [X, Y] := Chr (2 + N);
      2: WorldMap^ [X, Y] := Chr (8 + N);
      4: WorldMap^ [X, Y] := Chr (4 + N);
      8: WorldMap^ [X, Y] := Chr (6 + N);

      5: WorldMap^ [X, Y] := Chr (1 + N);
      6: WorldMap^ [X, Y] := Chr (7 + N);
      9: WorldMap^ [X, Y] := Chr (3 + N);
     10: WorldMap^ [X, Y] := Chr (9 + N);

      else WorldMap^ [X, Y] := Chr (5 + N);
    end;

  end;

  var
    i, j, k, l: Integer;

  begin  { BuildWorld }
    for i := 0 to Options.XSize - 1 do
      for j := 0 to NV - 1 do
        case WorldMap^ [i, j] of
          #253: begin
                 WorldMap^ [i, j - 5] := '?';
                 WorldMap^ [i, j - 6] := #225;
                 WorldMap^ [i, j] := ' ';
               end;
          #252: begin
                 WorldMap^ [i, j - 2] := '*';
                 WorldMap^ [i, j] := ' ';
               end;
          #173: begin
                 k := j + 1;
                 for l := j downto -1 do
                   WorldMap^ [i, l] := WorldMap^ [i, k];
               end;
          #174: begin
                 WorldMap^ [i, j] := WorldMap^ [i, j - 1];
                 WorldMap^ [i, NV] := #254;
               end;
          #175: begin
                 WorldMap^ [i, j] := WorldMap^ [i, j - 1];
                 WorldMap^ [i, NV] := #255;
               end;
        end;

    LastAB := ' ';
    LastCD := ' ';
    LastEF := ' ';

    with Options do
      BuildWall := (WallType1 < 100);

    if Options.BuildWall then
    begin
      for i := 0 to Options.XSize - 1 do
      begin
        for j := 0 to NV - 1 do
          BuildWall (i, j);

        LastAB := AB;
        LastAB := CD;   { Note: matches original bug - should be LastCD }
        LastAB := EF;   { Note: matches original bug - should be LastEF }
      end;
    end
    else
      with Options do
      begin
        case WallType1 of
          100:
            begin
              Recolor (@Brick0000, @Bricks [0], GroundColor1);
              Recolor (@Brick0001, @Bricks [1], GroundColor1);
              Recolor (@Brick0002, @Bricks [2], GroundColor1);
            end;
          101:
            begin
              Recolor (@Brick1000, @Bricks [0], GroundColor1);
              Recolor (@Brick1001, @Bricks [1], GroundColor1);
              Recolor (@Brick1002, @Bricks [2], GroundColor1);
            end;
          102:
            begin
              Recolor (@Brick2000, @Bricks [0], GroundColor1);
              Recolor (@Brick2001, @Bricks [1], GroundColor1);
              Recolor (@Brick2002, @Bricks [2], GroundColor1);
            end;

        end;
      end;

    { Convert grass overlays }
    ConvertGrass (@Grass1000, @Grass1001, @Grass1002);
    ConvertGrass (@Grass2000, @Grass2001, @Grass2002);
    ConvertGrass (@Grass3000, @Grass3002, @Grass3001);

    ConvertGrass (@Palm0000, @Palm0001, @Palm0002);
    ConvertGrass (@Palm1000, @Palm1001, @Palm1002);
    ConvertGrass (@Palm2000, @Palm2001, @Palm2002);
    ConvertGrass (@Palm3000, @Palm3001, @Palm3002);

    Recolor (@Block001, @Block001, Options.BrickColor);
    Recolor (@Wood000, @Wood000, Options.WoodColor);
    Recolor (@XBlock000, @XBlock000, Options.XBlockColor);

  end;

end.
