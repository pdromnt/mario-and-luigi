unit Stars;

interface

  uses
    Buffers,
    VGA256;

  procedure ClearStars;
  procedure InitStars;
  procedure ShowStars;
  procedure HideStars;

implementation

  const
    STAR_SPEED = 10;
    Max = (MaxWorldSize div STAR_SPEED) * W;

  var
    StarMap: array [0 .. 319] of Word;
    LastX: array [0 .. 3] of Integer;
    BlinkCounter: Integer;
    C1, C2: Byte;

  procedure ClearStars;
  begin
    FillChar (StarBackGr^, SizeOf (StarBackGr^), #0);
    FillChar (LastX, SizeOf (LastX), #0);
  end;

  procedure InitStars;
  var
    i: Integer;
  begin
    ClearStars;
    RandSeed := 0;
    for i := 0 to 319 do
      StarMap [i] := ((Random (Options.Horizon) {+ WindowY}) * VIR_SCREEN_WIDTH + i);
    if Options.Stars in [1, 2] then
      for i := 0 to 319 do
        if Random (10) > 2 then StarMap [i] := 0;
    case Options.Stars of
      1: begin
           C1 := 29;
           C2 := 31;
         end;
      2: begin
           C1 := 90;
           C2 := 92;
         end;
    end;
  end;

  procedure ShowStars;
  var
    i, X: Integer;
    Pg: Integer;
    StarY, StarX: Integer;
    WX: Integer;
    Addr: LongInt;
    Pixel: Byte;
    StarColor: Byte;
  begin
    Pg := CurrentPage;
    LastX [Pg] := XView;
    X := (8 * XView) div STAR_SPEED;
    BlinkCounter := Random (320);

    for i := 0 to 319 do
    begin
      if StarMap[i] = 0 then Continue;

      { Decompose StarMap address into row and column, add scroll offset,
        then wrap X coordinate to handle VGA CRTC circular buffer }
      StarY := StarMap[i] div VIR_SCREEN_WIDTH;
      StarX := StarMap[i] mod VIR_SCREEN_WIDTH;
      WX := (StarX + X) mod VIR_SCREEN_WIDTH;
      if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
      Addr := LongInt(StarY) * VIR_SCREEN_WIDTH + WX;

      { Read pixel from current page's framebuffer }
      if (StarY >= 0) and (StarY < FB_HEIGHT) then
      begin
        Pixel := FrameBuffer[Pg, Addr];

        { Only draw star if pixel is sky color ($A0+) or $F0, otherwise skip }
        if Pixel = 0 then
        begin
          StarBackGr^[Pg, i] := 0;
          Continue;
        end;

        if (Pixel = $F0) or (Pixel >= $A0) then
        begin
          { Skip $F0 exactly - treat as non-star pixel }
          if Pixel = $F0 then
          begin
            StarBackGr^[Pg, i] := 0;
            Continue;
          end;

          { Pick star color - one random star blinks brighter }
          Dec(BlinkCounter);
          if BlinkCounter = 0 then
            StarColor := C2
          else
            StarColor := C1;

          { Save background and draw star }
          StarBackGr^[Pg, i] := Pixel;
          FrameBuffer[Pg, Addr] := StarColor;
        end
        else
          StarBackGr^[Pg, i] := 0;
      end
      else
        StarBackGr^[Pg, i] := 0;
    end;
  end;

  procedure HideStars;
  var
    i, X: Integer;
    Pg: Integer;
    StarY, StarX: Integer;
    WX: Integer;
    Addr: LongInt;
    Saved: Byte;
  begin
    Pg := CurrentPage;
    X := (8 * LastX [Pg]) div STAR_SPEED;

    for i := 0 to 319 do
    begin
      if StarMap[i] = 0 then Continue;

      Saved := StarBackGr^[Pg, i];
      if Saved = 0 then Continue;

      { Decompose and wrap X coordinate }
      StarY := StarMap[i] div VIR_SCREEN_WIDTH;
      StarX := StarMap[i] mod VIR_SCREEN_WIDTH;
      WX := (StarX + X) mod VIR_SCREEN_WIDTH;
      if WX < 0 then Inc(WX, VIR_SCREEN_WIDTH);
      Addr := LongInt(StarY) * VIR_SCREEN_WIDTH + WX;

      if (StarY >= 0) and (StarY < FB_HEIGHT) then
        FrameBuffer[Pg, Addr] := Saved;
    end;
  end;

end.
