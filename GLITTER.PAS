unit Glitter;

interface

  uses
    VGA256,
    Buffers;

  procedure ClearGlitter;
  procedure NewGlitter (X, Y: Integer; NewAttr, Duration: Byte);
  procedure NewStar (X, Y: Integer; NewAttr, Duration: Byte);
  procedure ShowGlitter;
  procedure HideGlitter;
  procedure CoinGlitter (X, Y: Integer);
  procedure StartGlitter (X, Y, W, H: Integer);

implementation

  const
    MaxGlitter = 75;

  type
    GlitterRec = record
      Attr: Byte;
      Pos: Word;
      BackGr: Array [0 .. MAX_PAGE] of Byte;
      Dummy1, Dummy2, Dummy3: Byte;  { Size: 8 bytes }
    end;

  var
    Count: String [MaxGlitter];
    NumGlitter: Byte absolute Count;
    GlitterList: array [1 .. MaxGlitter] of GlitterRec;

  procedure ClearGlitter;
  begin
    FillChar (Count, SizeOf (Count), #0);
  end;

  procedure NewGlitter (X, Y: Integer; NewAttr, Duration: Byte);
  var
    i: Integer;
  begin
    if (X < XView) or (X >= XView + NH * W) then
      Exit;
    i := 1;
    while (Count [i] > #0) and (i < MaxGlitter) do
      Inc (i);
    if (i < MaxGlitter) then
    begin
      if (Y < 0) or (Y > NV * H) then
        Exit;
      Count [i] := Chr (Duration);
      Inc (NumGlitter);
      with GlitterList [i] do
      begin
        Pos := Y * VIR_SCREEN_WIDTH + X;
        FillChar (BackGr, SizeOf (BackGr), #0);
        Attr := NewAttr;
      end;
    end;
  end;

  procedure NewStar (X, Y: Integer; NewAttr, Duration: Byte);
  begin
    NewGlitter (X, Y, NewAttr, Duration + 4);
    NewGlitter (X + 1, Y, NewAttr, Duration);
    NewGlitter (X, Y + 1, NewAttr, Duration);
    NewGlitter (X - 1, Y, NewAttr, Duration);
    NewGlitter (X, Y - 1, NewAttr, Duration);
  end;

  procedure ShowGlitter;
  var
    i: Integer;
    Pg: Integer;
    GX, GY: Integer;
  begin
    Pg := CurrentPage;
    if NumGlitter > 0 then
      for i := 1 to MaxGlitter do
        if Count [i] > Chr (MAX_PAGE + 1) then
        begin
          with GlitterList [i] do
          begin
            GY := Pos div VIR_SCREEN_WIDTH;
            GX := Pos mod VIR_SCREEN_WIDTH;
            BackGr [Pg] := GetPixel (GX, GY);
            PutPixel (GX, GY, Attr);
          end;
        end
        else
          if Count [i] > #0 then
            with GlitterList [i] do
              BackGr [CurrentPage] := 0;
  end;

  procedure HideGlitter;
  var
    i: Integer;
    Pg: Integer;
    GX, GY: Integer;
  begin
    if NumGlitter = 0 then
      Exit;
    Pg := CurrentPage;
    for i := MaxGlitter downto 1 do
      if Count [i] > #0 then
      begin
        with GlitterList [i] do
        begin
          if BackGr [Pg] <> 0 then
          begin
            GY := Pos div VIR_SCREEN_WIDTH;
            GX := Pos mod VIR_SCREEN_WIDTH;
            PutPixel (GX, GY, BackGr [Pg]);
          end;
        end;
        Dec (Count [i]);
        if Count [i] = #0 then
          Dec (NumGlitter);
      end;
  end;

  procedure CoinGlitter (X, Y: Integer);
  begin
    NewStar (X + 5, Y + 2, $1F, 20);
    NewStar (X + W - 6, Y + 6, $1F, 18);
    NewStar (X + 10, Y + H - 3, $1F, 16);
    NewGlitter (X + W - 9, Y + 2, $1F, 15);
    NewGlitter (X + 6, Y + 7, $1F, 17);
    NewGlitter (X + 3, Y + 9, $1F, 15);
  end;

  procedure StartGlitter (X, Y, W, H: Integer);
  var
    i: Integer;
  begin
    NewStar (X + Random (W), Y + Random (H), $1F, 10 + Random (10));
    for i := 1 to 4 do
      NewGlitter (X + Random (W), Y + Random (H), $1F, 5 + Random (10));
  end;

end.
