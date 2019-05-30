(*
  OsMap components for offline rendering and routing functionalities
  based on OpenStreetMap data

  Copyright (C) 2019  Sergey Bodrov

  This source is ported from libosmscout-map library
  Copyright (C) 2017 Lukas Karas

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
*)
(*
  OsMap labels path layouter
LabelPath:
  Segment
  LabelPath

LabelLayouter:
  Rectangle
  PathLabelData
  LabelData
  Glyph  -> TMapGlyph
  Label  -> TMapLabel
  LabelInstance
  ContourLabel
  Mask   -> TMapMask
  LabelLayouter  -> TLabelLayouter (not used)
*)
unit OsMapLabels;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl, OsMapTypes, OsMapGeometry, OsMapStyles,
  OsMapParameters, OsMapProjection;


type
  TQWordArray = array of QWord;

  { TSegment }

  TSegment = object
    Start: TVertex2D;
    Offset: Double;
    Length: Double;
    Angle: Double;

    procedure Init(const AStart: TVertex2D; AOffset, ALength, AAngle: Double); inline;
  end;

  TSegmentArray = array of TSegment;

  { TLabelPath }

  TLabelPath = object
  private
    FLength: Double;
    FSegments: TSegmentArray;
    FOffsetIndexArr: array of Integer;  // segment offset by length 100
    FMinSegmentLength: Double;
    FEnd: TVertex2D;
    FEndDistance: Double;

    function SegmentBefore(AOffset: Double): TSegment;
  public
    procedure Init(AMinSegmentLength: Double = 5); inline;
    procedure AddPoint(X, Y: Double);
    function GetLength(): Double;
    function PointAtLength(AOffset: Double): TVertex2D;
    function AngleAtLength(AOffset: Double): Double;
    function AngleAtLengthDeg(AOffset: Double): Double;

    { Test how squiggly is path in given offsets. It return true
      if angle between first path segment (on startOffset) and any
      following (until endOffset) is lesser than required maximum. }
    function TestAngleVariance(AStartOffset, AEndOffset, AMaximumAngle: Double): Boolean;
  end;

  { TDoubleRectangle }

  TDoubleRectangle = object
    X: Double;
    Y: Double;
    Width: Double;
    Height: Double;

    procedure Init(AX, AY, AW, AH: Double); inline;
    { Test if this Rectangle intersects with another.
      It is using open interval, so if two rectangles are just touching
      each other, these don't intersects. }
    function Intersects(AOther: TDoubleRectangle): Boolean;
  end;

  { TIntRectangle }

  TIntRectangle = object
    X: Integer;
    Y: Integer;
    Width: Integer;
    Height: Integer;

    procedure Init(AX, AY, AW, AH: Integer); inline;
    { Test if this Rectangle intersects with another.
      It is using open interval, so if two rectangles are just touching
      each other, these don't intersects. }
    function Intersects(AOther: TIntRectangle): Boolean;
  end;

  { TPathLabelData }

  TPathLabelData = object
  public
    Priority: Integer;        // Priority of the entry
    Text: string;             // The label text (type==Text|PathText)
    //FontSize: Double;         // Font size to be used, in pixels
    Style: TPathTextStyle;
    ContourLabelOffset: Double;
    ContourLabelSpace: Double;
    procedure Init(AStyle: TPathTextStyle);
  end;

  TLabelDataType = (ldtIcon, ldtSymbol, ldtText);

  { TLabelData }
  { Properties for label of any type - text, icon  }
  TLabelData = object
  public
    DataType: TLabelDataType;  // ldtIcon, ldtSymbol, ldtText
    Priority: Integer;       // Priority of the entry
    Position: Integer;       // Relative vertical position of the label

    Alpha: Double;           // Alpha value of the label; 0.0 = fully transparent, 1.0 = solid
    FontSize: Double;        // Font size to be used, in pixels
    Style: TLabelStyle;      // Style for drawing
    Text: string;            // The label text (type==Text|PathText)

    IconStyle: TIconStyle;   // Icon or symbol style
    IconWidth: Double;
    IconHeight: Double;

    procedure Init();
  end;

  { TLabelDataList }

  TLabelDataList = object
  private
    function GetCount: Integer;
  public
    Items: array of TLabelData;
    procedure Clear();
    function Add(const AItem: TLabelData): Integer;

    property Count: Integer read GetCount;
  end;

type
  { TMapGlyph }
  TMapGlyph = object
  public
    TextChar: Char;
    NativeGlyph: Pointer; // TNativeGlyph;
    Position: TVertex2D;  // glyph baseline position
    Width: Double;        // width before rotation
    Height: Double;       // height before rotation
    Angle: Double;        // clock-wise rotation in radian

    TrPosition: TVertex2D; // top-left position after rotation
    TrWidth: Double;   // width after rotation
    TrHeight: Double;  // height after rotation
  end;

  TMapGlyphArray = array of TMapGlyph;

  { TMapLabel }

  TMapLabel = object
  public
    pLabel: Pointer;   // TNativeLabel
    Width: Double;
    Height: Double;
    FontSize: Double;  // Resulting font size
    Text: string;      // The label text
    Glyphs: TMapGlyphArray;

    procedure Init();
    { Implementation have to be provided by backend.
      Glyph positions should be relative to label baseline. }
    //function ToGlyphs(): TMapGlyphArray;
  end;

  { TLabelInstanceElement }
  { Represent row for multi-line label }
  TLabelInstanceElement = class
  public
    LabelData: TLabelData;
    X: Double;             // Coordinate of the left, top edge of the text / icon / symbol
    Y: Double;             // Coordinate of the left, top edge of the text / icon / symbol
    MapLabel: TMapLabel;   // std::shared_ptr<Label<NativeGlyph, NativeLabel>>

    procedure Assign(AOther: TLabelInstanceElement);
  end;

  TLabelInstanceElementList = specialize TFPGObjectList<TLabelInstanceElement>;

  { TLabelInstance }
  {  }
  TLabelInstance = class
  private
    FElements: TLabelInstanceElementList;
  public
    Priority: Integer;

    constructor Create();
    destructor Destroy; override;
    property Elements: TLabelInstanceElementList read FElements;
  end;

  TLabelInstanceList = specialize TFPGObjectList<TLabelInstance>;

  TContourLabel = class
  public
    {$ifdef DEBUG_LABEL_LAYOUTER}
    Text: string;
    {$endif}
    Priority: Integer;
    Glyphs: TMapGlyphArray;
    Style: TPathTextStyle;
  end;

  TContourLabelList = specialize TFPGObjectList<TContourLabel>;

  { TMapMask }

  TMapMask = object
  public
    CellFrom: Integer;
    CellTo: Integer;
    RowFrom: Integer;
    RowTo: Integer;
    D: array of QWord;

    procedure Init(ARowSize: Integer);
    procedure Assign(const AOther: TMapMask);
    procedure Prepare(const ARect: TIntRectangle);
    function Size(): Integer;
  end;

  { for low level text layouting }

  { glyph bounding box relative to its base point }
  //TOnGlyphBoundingBox = procedure(const AGlyph: TMapGlyph; out ARect: TDoubleRectangle) of object;

  { Adjust text label layout for area object
    AFontSize - font size (height) in pixels
    AObjectWidth - width in pixels of drawable object (area)
    AEnableWrapping - wrap text to multiple lines if it not fit to AObjectWidth
    AContourLabel - if True then fill position and size for every glyph (character of text) }
  TOnTextLayout = procedure(out ALabel: TMapLabel; AProjection: TProjection;
      AParameter: TMapParameter;
      const AText: string;
      AFontSize, AObjectWidth: Double;
      AEnableWrapping: Boolean = False;
      AContourLabel: Boolean = False) of object;

  { Draw the Symbol as defined by the SymbolStyle at the given pixel coordinate (symbol center). }
  TOnDrawSymbol = procedure(AProjection: TProjection;
      AParameter: TMapParameter;
      ASymbol: TMapSymbol;
      X, Y: Double) of object;

  { Draw the Icon as defined by the IconStyle at the given pixel coordinate (icon center). }
  TOnDrawIcon = procedure(AStyle: TIconStyle;
      ACenterX, ACenterY: Double;
      AWidth, AHeight: Double) of object;

  TOnDrawLabel = procedure(AProjection: TProjection;
      AParameter: TMapParameter;
      X, Y: Double;
      const AMapLabel: TMapLabel;
      const ALabel: TLabelData) of object;

  TOnDrawGlyphs = procedure(AProjection: TProjection;
      AParameter: TMapParameter;
      AStyle: TPathTextStyle;
      AGlyphs: TMapGlyphArray) of object;

  { TLabelLayouter }
  { TextLayouter is built-in, and must be overriden in decent classes }
  TLabelLayouter = class
  private
    FContourLabelInstances: TContourLabelList;
    FLabelInstances: TLabelInstanceList;
    FTextElements: TLabelInstanceElementList;
    FOverlayElements: TLabelInstanceElementList;

    FVisibleViewport: TDoubleRectangle;
    FLayoutViewport: TDoubleRectangle;
    FLayoutOverlap: Double;  // overlap ratio used for label layouting

    //FOnGlyphBoundingBox: TOnGlyphBoundingBox;
    FOnTextLayout: TOnTextLayout;
    FOnDrawSymbol: TOnDrawSymbol;
    FOnDrawIcon: TOnDrawIcon;
    FOnDrawLabel: TOnDrawLabel;
    FOnDrawGlyphs: TOnDrawGlyphs;

  public
    constructor Create();
    destructor Destroy; override;

    procedure SetViewport(const V: TDoubleRectangle);

    procedure SetLayoutOverlap(AOverlap: Double);

    procedure Reset();

    function CheckLabelCollision(const ACanvas: TQWordArray;
      const AMask: TMapMask;
      AViewportHeight: Integer): Boolean;

    procedure MarkLabelPlace(const ACanvas: TQWordArray;
      const AMask: TMapMask;
      AViewportHeight: Integer);

    // Something is an overlay, if its alpha is <0.8
    function IsOverlay(const ALabelData: TLabelData): Boolean;

    procedure Layout(AProjection: TProjection; AParameter: TMapParameter);

    { APainter - TMapPainter }
    procedure DrawLabels(AProjection: TProjection; AParameter: TMapParameter);

    procedure RegisterLabel(AProjection: TProjection; AParameter: TMapParameter;
      const APoint: TVertex2D;
      const ADataList: TLabelDataList;
      AObjectWidth: Double = 10.0);

    procedure RegisterContourLabel(AProjection: TProjection; AParameter: TMapParameter;
      const ALabelData: TPathLabelData;
      const ALabelPath: TLabelPath);

    property Labels: TLabelInstanceList read FLabelInstances;
    property ContourLabels: TContourLabelList read FContourLabelInstances;

    //property OnGlyphBoundingBox: TOnGlyphBoundingBox read FOnGlyphBoundingBox write FOnGlyphBoundingBox;
    property OnTextLayout: TOnTextLayout read FOnTextLayout write FOnTextLayout;
    property OnDrawSymbol: TOnDrawSymbol read FOnDrawSymbol write FOnDrawSymbol;
    property OnDrawIcon: TOnDrawIcon read FOnDrawIcon write FOnDrawIcon;
    property OnDrawLabel: TOnDrawLabel read FOnDrawLabel write FOnDrawLabel;
    property OnDrawGlyphs: TOnDrawGlyphs read FOnDrawGlyphs write FOnDrawGlyphs;
  end;


  function LabelInstanceSorter(const A, B: TLabelInstance): Integer;

  function ContourLabelSorter(const A, B: TContourLabel): Integer;


implementation

uses Math, OsMapPainter;

const
  M_PI   = 3.14159265358979323846;
  M_PI_4 = 0.785398163397448309616;

function LabelInstanceSorter(const A, B: TLabelInstance): Integer;
begin
  Result := -1;
  if (A.Priority = B.Priority)  then
  begin
    Assert(A.Elements.Count <> 0);
    Assert(B.Elements.Count <> 0);
    if A.Elements[0].X < B.Elements[0].X then
      Result := 1;
  end
  else if (A.Priority < B.Priority) then
    Result := 1;
end;

function ContourLabelSorter(const A, B: TContourLabel): Integer;
begin
  Result := -1;
  if (A.Priority = B.Priority)  then
  begin
    Assert(Length(A.Glyphs) <> 0);
    Assert(Length(B.Glyphs) <> 0);
    if A.Glyphs[0].TrPosition.X < B.Glyphs[0].TrPosition.X then
      Result := 1;
  end
  else if (A.Priority < B.Priority) then
    Result := 1;
end;

{ TSegment }

procedure TSegment.Init(const AStart: TVertex2D; AOffset, ALength,
  AAngle: Double);
begin
  Start.Assign(AStart);
  Offset := AOffset;
  Length := ALength;
  Angle := AAngle;
end;

{ TLabelPath }

function TLabelPath.SegmentBefore(AOffset: Double): TSegment;
var
  i, iHundred: Integer;
begin
  iHundred := Trunc(AOffset / 100);
  if (iHundred >= Length(FOffsetIndexArr)) then
  begin
    Result := FSegments[High(FSegments)];
    Exit;
  end;
  i := FOffsetIndexArr[iHundred];
  while i < Length(FSegments) do
  begin
    if (AOffset < (FSegments[i].Offset + FSegments[i].Length)) then
    begin
      Result := FSegments[i];
      Exit;
    end;
    Inc(i);
  end;
  Result := FSegments[High(FSegments)];
end;

procedure TLabelPath.Init(AMinSegmentLength: Double);
begin
  FLength := 0.0;
  FMinSegmentLength := AMinSegmentLength;
  FEndDistance := 0.0;
  Setlength(FOffsetIndexArr, 1);
  FOffsetIndexArr[0] := 0;
end;

procedure TLabelPath.AddPoint(X, Y: Double);
var
  n, i: Integer;
  LastSeg: TSegment;
  endDistance: Double;
begin
  if Length(FSegments) = 0 then
  begin
    FEnd.SetValue(X, Y);
    n := Length(FSegments);
    SetLength(FSegments, n+1);
    FSegments[n].Init(FEnd, 0, 0, 0);
  end
  else
  begin
    FEnd.SetValue(X, Y);
    LastSeg := FSegments[High(FSegments)];
    endDistance := LastSeg.Start.DistanceTo(Vertex2D(X, Y)); //  QVector2D(last.start).distanceToPoint(QVector2D(x,y));
    if (endDistance > FMinSegmentLength) then
    begin
      FLength := FLength + endDistance;
      LastSeg.Length := endDistance;
      LastSeg.Angle := arctan2(LastSeg.Start.Y - Y, X - LastSeg.Start.X);
      FSegments[High(FSegments)] := LastSeg;

      // fill offsetIndex
      for i := High(FOffsetIndexArr) to Trunc(FLength / 100) do
      begin
        n := Length(FOffsetIndexArr);
        SetLength(FOffsetIndexArr, n+1);
        FOffsetIndexArr[n] := High(FSegments);
      end;

      n := Length(FSegments);
      SetLength(FSegments, n+1);
      FSegments[n].Init(FEnd, FLength, 0, 0);
    end;
  end;
end;

function TLabelPath.GetLength(): Double;
begin
  Result := FLength + FEndDistance;
end;

function TLabelPath.PointAtLength(AOffset: Double): TVertex2D;
var
  RelSeg: TSegment;
  p, VtAdd: TVertex2D;
  mul: Double;
begin
  if Length(FSegments) = 0 then
    Exit;

  RelSeg := SegmentBefore(AOffset);
  p.Assign(RelSeg.Start);
  mul := (AOffset - RelSeg.Offset);
  VtAdd.SetValue(cos(RelSeg.Angle) * mul, -sin(RelSeg.Angle) * mul);

  Result.SetValue(p.X + VtAdd.X, p.Y + VtAdd.Y);
end;

function TLabelPath.AngleAtLength(AOffset: Double): Double;
begin
  Result := SegmentBefore(AOffset).Angle;
end;

function TLabelPath.AngleAtLengthDeg(AOffset: Double): Double;
begin
  Result := (AngleAtLength(AOffset) * 180) / M_PI;
end;

function TLabelPath.TestAngleVariance(AStartOffset, AEndOffset,
  AMaximumAngle: Double): Boolean;
var
  initialAngle: Double;
  IsInited: Boolean;
  i: Integer;
begin
  initialAngle := 0;
  IsInited := False;
  for i := Low(FSegments) to High(FSegments) do
  begin
    if (FSegments[i].Offset > AEndOffset) then
    begin
      Result := True;
      Exit;
    end;
    if (FSegments[i].Offset + FSegments[i].Length > AStartOffset) then
    begin
      if (not IsInited) then
      begin
        initialAngle := FSegments[i].Angle;
        IsInited := True;
      end
      else
      begin
        if (AngleDiff(initialAngle, FSegments[i].Angle) > AMaximumAngle) then
        begin
          Result := False;
          Exit;
        end;
      end;
    end;
  end;
  Result := True;
end;

{ TDoubleRectangle }

procedure TDoubleRectangle.Init(AX, AY, AW, AH: Double);
begin
  X := AX;
  Y := AY;
  Width := AW;
  Height := AH;
end;

function TDoubleRectangle.Intersects(AOther: TDoubleRectangle): Boolean;
begin
  Result := not (((X + Width) < AOther.X)
               or (X > (AOther.X + AOther.Width))
               or ((Y + Height) < AOther.Y)
               or (Y > (AOther.Y + AOther.Height)));
end;

{ TIntRectangle }

procedure TIntRectangle.Init(AX, AY, AW, AH: Integer);
begin
  X := AX;
  Y := AY;
  Width := AW;
  Height := AH;
end;

function TIntRectangle.Intersects(AOther: TIntRectangle): Boolean;
begin
  Result := not (((X + Width) < AOther.X)
               or (X > (AOther.X + AOther.Width))
               or ((Y + Height) < AOther.Y)
               or (Y > (AOther.Y + AOther.Height)));
end;

{ TLabelData }

procedure TLabelData.Init();
begin
  DataType := ldtText;
  Priority := 0;
  Position := 0;
  Alpha := 1.0;
  FontSize := 0.0;
  Style := nil;
  Text := '';
  IconStyle := nil;
  IconWidth := 0;
  IconHeight := 0;
end;

{ TMapLabel }

procedure TMapLabel.Init();
begin
  pLabel := nil;
  Width := -1;
  Height := -1;
  FontSize := 1;
  Text := '';
end;

{function TMapLabel.ToGlyphs(): TMapGlyphArray;
begin
  SetLength(Result, 0);
end;}

{ TMapMask }

procedure TMapMask.Init(ARowSize: Integer);
begin
  CellFrom := 0;
  CellTo := 0;
  RowFrom := 0;
  RowTo := 0;
  SetLength(D, ARowSize);
end;

procedure TMapMask.Assign(const AOther: TMapMask);
var
  i: Integer;
begin
  CellFrom := AOther.CellFrom;
  CellTo := AOther.CellTo;
  RowFrom := AOther.RowFrom;
  RowTo := AOther.RowTo;
  SetLength(D, Length(AOther.D));
  for i := Low(D) to High(D) do
    D[i] := AOther.D[i];
end;

procedure TMapMask.Prepare(const ARect: TIntRectangle);
var
  c, iTo: Integer;
  CellFromBit, CellToBit: Word;
  BitMask: QWord;
begin
  // clear
  for c := max(Low(D), CellFrom) to min(High(D), CellTo) do
    D[c] := 0;

  // setup
  CellFrom := ARect.X div 64;
  if ARect.X < 0 then
    CellFromBit := 0
  else
    CellFromBit := ARect.X mod 64;

  iTo := (ARect.X + ARect.Width);
  if (iTo < 0) or (CellFrom >= size()) then
    Exit; // mask is outside viewport, keep it blank
  CellTo := iTo div 64;
  CellToBit := (ARect.X + ARect.Width) mod 64;
  if (CellToBit = 0) then
    Dec(CellTo);

  RowFrom := ARect.Y;
  RowTo := ARect.Y + ARect.Height;

  BitMask := High(BitMask);
  for c := max(Low(D), CellFrom) to min(High(D), CellTo) do
    D[c] := BitMask;
  if (CellFrom >= 0) and (CellFrom < size()) and (CellFromBit > 0) then
    D[CellFrom] := BitMask shl CellFromBit;

  if (CellTo >= 0) and (CellTo < size()) and (CellToBit > 0) then
    D[CellTo] := D[CellTo] and (BitMask shr (64 - CellToBit));

end;

function TMapMask.Size(): Integer;
begin
  Result := Length(D);
end;

{ TLabelLayouter }

constructor TLabelLayouter.Create();
begin
  inherited Create();
  FContourLabelInstances := TContourLabelList.Create();
  FLabelInstances := TLabelInstanceList.Create();
  FTextElements := TLabelInstanceElementList.Create(False);
  FOverlayElements := TLabelInstanceElementList.Create(False);

  FVisibleViewport.Init(0, 0, 0, 0);
  FLayoutViewport.Init(0, 0, 0, 0);
  FLayoutOverlap := 0;
end;

destructor TLabelLayouter.Destroy;
begin
  FreeAndNil(FLabelInstances);
  FreeAndNil(FContourLabelInstances);
  inherited Destroy;
end;

procedure TLabelLayouter.SetViewport(const V: TDoubleRectangle);
begin
  FVisibleViewport := V;
  SetLayoutOverlap(FLayoutOverlap);
end;

procedure TLabelLayouter.SetLayoutOverlap(AOverlap: Double);
begin
  if AOverlap < 0 then
    AOverlap := 0;

  FLayoutOverlap := AOverlap;
  FLayoutViewport.Width := FVisibleViewport.Width * (AOverlap + 1);
  FLayoutViewport.Height := FVisibleViewport.Height * (AOverlap + 1);
  FLayoutViewport.X := FVisibleViewport.X - (FVisibleViewport.Width * AOverlap) / 2;
  FLayoutViewport.Y := FVisibleViewport.Y - (FVisibleViewport.Height * AOverlap) / 2;
end;

procedure TLabelLayouter.Reset();
begin
  FContourLabelInstances.Clear();
  FLabelInstances.Clear();
end;

function TLabelLayouter.CheckLabelCollision(const ACanvas: TQWordArray;
  const AMask: TMapMask; AViewportHeight: Integer): Boolean;
var
  r, rMax, c, cMax: Integer;
begin
  Result := False;
  rMax := min(AViewportHeight-1, AMask.RowTo);
  cMax := min(AMask.Size()-1, AMask.CellTo);

  r := max(0, AMask.RowFrom);
  while (not Result) and (r <= rMax) do
  begin
    c := max(0, AMask.CellFrom);
    while (not Result) and (c <= cMax) do
    begin
      Result := ((AMask.D[c] and ACanvas[r * AMask.Size() + c]) <> 0);
      Inc(c);
    end;
    Inc(r);
  end;
end;

procedure TLabelLayouter.MarkLabelPlace(const ACanvas: TQWordArray;
  const AMask: TMapMask; AViewportHeight: Integer);
var
  r, rMax, c, cMax: Integer;
begin
  rMax := min(AViewportHeight-1, AMask.RowTo);
  cMax := min(AMask.Size()-1, AMask.CellTo);

  r := max(0, AMask.RowFrom);
  while (r <= rMax) do
  begin
    c := max(0, AMask.CellFrom);
    while (c <= cMax) do
    begin
      ACanvas[r * AMask.Size() + c] := AMask.D[c] or ACanvas[r * AMask.Size() + c];
      Inc(c);
    end;
    Inc(r);
  end;
end;

function TLabelLayouter.IsOverlay(const ALabelData: TLabelData): Boolean;
begin
  Result := (ALabelData.Alpha < 0.8);
end;

procedure TLabelLayouter.Layout(AProjection: TProjection;
  AParameter: TMapParameter);
var
  AllSortedContourLabels: TContourLabelList;
  AllSortedLabels: TLabelInstanceList;
  iconPadding, labelPadding, shieldLabelPadding: Double;
  contourLabelPadding, overlayLabelPadding: Double;
  i, iLabel, iContour: Integer;
  rowSize: Int64;
  iconCanvas: TQWordArray;
  labelCanvas: TQWordArray;
  overlayCanvas: TQWordArray;
  currentLabel: TLabelInstance;
  currentContourLabel: TContourLabel;
  //m: TMapMask;
  masks: array of TMapMask;
  canvases: array of ^TQWordArray;
  visibleElements: TLabelInstanceElementList;
  eli, glyphCnt, gi: Integer;
  element, elementCopy: TLabelInstanceElement;
  pRow: ^TMapMask;
  padding: Double;
  rectangle: TIntRectangle;
  pCanvas: ^TQWordArray;
  IsCollision: Boolean;
  instanceCopy: TLabelInstance;
  pGlyph: ^TMapGlyph;
begin
  iconPadding := AProjection.ConvertWidthToPixel(AParameter.IconPadding);
  labelPadding := AProjection.ConvertWidthToPixel(AParameter.LabelPadding);
  shieldLabelPadding := AProjection.ConvertWidthToPixel(AParameter.PlateLabelPadding);
  contourLabelPadding := AProjection.ConvertWidthToPixel(AParameter.ContourLabelPadding);
  overlayLabelPadding := AProjection.ConvertWidthToPixel(AParameter.OverlayLabelPadding);


  AllSortedLabels := FLabelInstances;
  AllSortedContourLabels := FContourLabelInstances;
  // sort labels by priority and position (to be deterministic)
  { TODO : sorting }
  //AllSortedLabels.Sort(@LabelInstanceSorter);
  //AllSortedContourLabels.Sort(@ContourLabelSorter);

  // compute collisions, hide some labels
  rowSize := Trunc((FLayoutViewport.Width / 64)+1);
  SetLength(iconCanvas, Trunc(rowSize * FLayoutViewport.Height));
  SetLength(labelCanvas, Trunc(rowSize * FLayoutViewport.Height));
  SetLength(overlayCanvas, Trunc(rowSize * FLayoutViewport.Height));

  iLabel := 0;
  iContour := 0;
  while (iLabel < AllSortedLabels.Count) or (iContour < AllSortedContourLabels.Count) do
  begin
    currentLabel := nil;
    currentContourLabel := nil;
    if (iLabel < AllSortedLabels.Count) and (iContour < AllSortedContourLabels.Count) then
    begin
      currentLabel := AllSortedLabels[iLabel];
      currentContourLabel := AllSortedContourLabels[iContour];
      if (currentLabel.Priority <> currentContourLabel.Priority) then
      begin
        if (currentLabel.Priority < currentContourLabel.Priority) then
          currentContourLabel := nil
        else
          currentLabel := nil;
      end;
    end
    else
      Break;

    if Assigned(currentLabel) then
    begin
      SetLength(masks, currentLabel.Elements.Count);
      for i := 0 to Length(masks)-1 do
        masks[i].Init(rowSize);

      SetLength(canvases, currentLabel.Elements.Count);
      for i := 0 to Length(canvases)-1 do
        canvases[i] := nil;

      visibleElements := TLabelInstanceElementList.Create(False);
      try
        for eli := 0 to currentLabel.Elements.Count-1 do
        begin
          element := currentLabel.Elements[eli];
          pRow := Addr(masks[eli]);

          if element.LabelData.DataType in [ldtIcon, ldtSymbol] then
            padding := iconPadding
          else if IsOverlay(element.LabelData) then
            padding := overlayLabelPadding
          else if Assigned(element.LabelData.Style) then
            padding := shieldLabelPadding
          else
            padding := labelPadding;

          rectangle.Init(floor(element.X - FLayoutViewport.X - padding),
                         floor(element.Y - FLayoutViewport.Y - padding),
                         0, 0);

          pCanvas := Addr(labelCanvas);
          if (element.labelData.DataType in [ldtIcon, ldtSymbol]) then
          begin
            rectangle.width := ceil(element.LabelData.IconWidth + 2*padding);
            rectangle.height := ceil(element.LabelData.IconHeight + 2*padding);
            pCanvas := Addr(iconCanvas);
            {$ifdef DEBUG_LABEL_LAYOUTER}
            if (element.labelData.DataType = ldtIcon) then
              Writeln('Test icon ', element.LabelData.IconStyle.IconName)
            else
              WriteLn('Test symbol ', element.labelData.IconStyle.Symbol.Name);
            {$endif}
          end
          else
          begin
            {$ifdef DEBUG_LABEL_LAYOUTER}
            if IsOverlay(element.LabelData) then
              WriteLn('Test overlay label prio ', currentLabel.Priority, ': ', element.LabelData.Text)
            else
              WriteLn('Test label prio ', currentLabel.Priority, ': ', element.LabelData.Text);
            {$endif}

            rectangle.Width := ceil(element.MapLabel.Width + 2*padding);
            rectangle.Height := ceil(element.MapLabel.Height + 2*padding);

            if (IsOverlay(element.labelData)) then
              pCanvas := Addr(overlayCanvas);
          end;
          pRow^.Prepare(rectangle);
          IsCollision := CheckLabelCollision(pCanvas^, pRow^, Trunc(FLayoutViewport.Height));
          if (not IsCollision) then
          begin
            visibleElements.Add(element);
            canvases[eli] := pCanvas;
          end;
          {$ifdef DEBUG_LABEL_LAYOUTER}
          if IsCollision then
            WriteLn(' -> skipped')
          else
            WriteLn(' -> added');
          {$endif}
        end;

        if (visibleElements.Count <> 0) then
        begin
          instanceCopy := TLabelInstance.Create();
          instanceCopy.Priority := currentLabel.Priority;
          //instanceCopy.Elements.Assign(visibleElements);
          for element in visibleElements do
          begin
            elementCopy := TLabelInstanceElement.Create();
            elementCopy.Assign(element);
            instanceCopy.Elements.Add(elementCopy);
          end;
          FLabelInstances.Add(instanceCopy);

          // mark all labels at once
          for eli := 0 to currentLabel.Elements.Count-1 do
          begin
            if Assigned(canvases[eli]) then
              MarkLabelPlace(canvases[eli]^, masks[eli], Trunc(FLayoutViewport.Height));
          end;
        end;

        Inc(iLabel);
      finally
        visibleElements.Free();
      end;
    end;

    if Assigned(currentContourLabel) then
    begin
      glyphCnt := Length(currentContourLabel.Glyphs);

      {$ifdef DEBUG_LABEL_LAYOUTER}
      WriteLn('Test contour label prio ', currentContourLabel.Priority, ': ', currentContourLabel.Text);
      {$endif}

      SetLength(masks, glyphCnt);
      for i := 0 to glyphCnt-1 do
        masks[i].Init(rowSize);

      IsCollision := False;
      gi := 0;
      while (not IsCollision) and (gi < glyphCnt) do
      begin
        pGlyph := Addr(currentContourLabel.Glyphs[gi]);
        rectangle.Init(Trunc(pGlyph^.TrPosition.X - FLayoutViewport.X - contourLabelPadding),
                       Trunc(pGlyph^.TrPosition.Y - FLayoutViewport.Y - contourLabelPadding),
                       Trunc(pGlyph^.TrWidth + 2 * contourLabelPadding),
                       Trunc(pGlyph^.TrHeight + 2 * contourLabelPadding));
        masks[gi].Prepare(rectangle);
        IsCollision := IsCollision or CheckLabelCollision(labelCanvas, masks[gi], Trunc(FLayoutViewport.Height));
        Inc(gi);
      end;
      if (not IsCollision) then
      begin
        for gi :=0 to glyphCnt-1 do
          MarkLabelPlace(labelCanvas, masks[gi], Trunc(FLayoutViewport.Height));

        FContourLabelInstances.Add(currentContourLabel);
      end;
      {$ifdef DEBUG_LABEL_LAYOUTER}
      if IsCollision then
        WriteLn(' -> skipped')
      else
        WriteLn(' -> added');
      {$endif}
      Inc(iContour);
    end;
  end;
end;

procedure TLabelLayouter.DrawLabels(AProjection: TProjection;
  AParameter: TMapParameter);
var
  inst: TLabelInstance;
  el: TLabelInstanceElement;
  elementRectangle: TDoubleRectangle;
  ConLabel: TContourLabel;
begin
  FOverlayElements.Clear();
  FTextElements.Clear();
  // draw symbols and icons first, then standard labels and then overlays

  for inst in Labels do
  begin
    for el in inst.Elements do
    begin
      if (el.LabelData.DataType = ldtText) then
        elementRectangle.Init(el.x, el.y, el.MapLabel.Width, el.MapLabel.Height)
      else
        elementRectangle.Init(el.x, el.y, el.LabelData.IconWidth, el.LabelData.IconHeight);

      if (not FVisibleViewport.Intersects(elementRectangle)) then
        Continue;

      if (el.LabelData.DataType = ldtSymbol) and Assigned(OnDrawSymbol) then
      begin
        OnDrawSymbol(AProjection, AParameter,
          el.LabelData.IconStyle.Symbol,
          el.X + el.LabelData.IconWidth / 2,
          el.Y + el.LabelData.IconHeight / 2);
      end
      else if (el.LabelData.DataType = ldtIcon) and Assigned(OnDrawIcon) then
      begin
        OnDrawIcon(el.LabelData.IconStyle,
          el.X + el.LabelData.IconWidth / 2,
          el.Y + el.LabelData.IconHeight / 2,
          el.LabelData.IconWidth, el.LabelData.IconHeight);
      end
      else
      begin
        // postpone text elements
        if (IsOverlay(el.LabelData)) then
          FOverlayElements.Add(el)
        else
          FTextElements.Add(el);
      end;
    end;
  end;

  if not Assigned(OnDrawLabel) then Exit;

  // draw postponed text elements
  for el in FTextElements do
  begin
    OnDrawLabel(AProjection, AParameter,
                el.X, el.Y,
                el.MapLabel, el.LabelData);
  end;

  for el in FOverlayElements do
  begin
    OnDrawLabel(AProjection, AParameter,
                el.X, el.Y,
                el.MapLabel, el.LabelData);
  end;

  for ConLabel in ContourLabels do
  begin
    OnDrawGlyphs(AProjection, AParameter,
                 ConLabel.Style, ConLabel.Glyphs);
  end;
end;

procedure TLabelLayouter.RegisterLabel(AProjection: TProjection;
  AParameter: TMapParameter; const APoint: TVertex2D;
  const ADataList: TLabelDataList; AObjectWidth: Double);
var
  instance: TLabelInstance;
  offset: Double;
  i: Integer;
  d: TLabelData;
  element: TLabelInstanceElement;
begin
  instance := TLabelInstance.Create();
  instance.Priority := MaxInt;

  offset := -1;
  for i := 0 to ADataList.Count-1 do
  begin
    d := ADataList.Items[i];
    element := TLabelInstanceElement.Create();
    element.LabelData := d;
    if (d.DataType in [ldtIcon, ldtSymbol]) then
    begin
      // TODO: icons and symbols don't support priority now
      element.X := APoint.X - d.IconWidth / 2;
      if (offset < 0) then
      begin
        element.Y := APoint.Y - d.IconHeight / 2;
        offset := APoint.Y + d.IconHeight / 2;
      end
      else
      begin
        element.Y := offset;
        offset := offset + d.IconHeight;
      end;
    end
    else
    begin
      instance.Priority := min(instance.Priority, d.Priority);
      // TODO: should we take style into account?
      // Qt allows to split text layout and style setup
      if Assigned(OnTextLayout) then
      begin
        OnTextLayout(element.MapLabel,
          AProjection, AParameter,
          d.Text, d.FontSize,
          AObjectWidth,
          {enable wrapping} True,
          {contour label} False);
      end;
      element.X := APoint.X - (element.MapLabel.Width / 2);
      if (offset < 0) then
      begin
        element.Y := APoint.Y - (element.MapLabel.Height / 2);
        offset := APoint.Y + (element.MapLabel.Height / 2);
      end
      else
      begin
        element.Y := offset;
        offset := offset + element.MapLabel.Height;
      end;
    end;
    instance.elements.Add(element);
  end;

  FLabelInstances.Add(instance);
end;

procedure TLabelLayouter.RegisterContourLabel(AProjection: TProjection;
  AParameter: TMapParameter; const ALabelData: TPathLabelData;
  const ALabelPath: TLabelPath);
var
  TmpLabel: TMapLabel;
  textBaselineOffset, PathLength, offset, initialAngle: Double;
  glyph, glyphCopy: TMapGlyph;
  ContLabel: TContourLabel;
  IsUpwards: Boolean;
  glyphOffset, w, h: Double;
  point: TVertex2D;  // glyph point
  GlyphRect: TDoubleRectangle;
  tl: TVertex2D; // glyph top left
  angle: Double; // glyph angle in radians
  diagonal, FontHeight: Double;
  sinA, cosA, ox, oy: Double;
  XArr, YArr: array [0..3] of Double;
  i, GlyphIndex: Integer;
  minX, maxX, minY, maxY: Double;
begin
  // TODO: cache label for string and font parameters
  FontHeight := AProjection.ConvertWidthToPixel(ALabelData.Style.Size);
  TmpLabel.Init();
  OnTextLayout(TmpLabel, AProjection, AParameter,
      ALabelData.Text,
      FontHeight,
      { object width } 0.0,
      { enable wrapping } False,
      { contour label } True);

  // text should be rendered with 0x0 coordinate as left baseline
  // we want to move label little bit bottom, near to line center
  textBaselineOffset := TmpLabel.Height * 0.25;

  PathLength := ALabelPath.GetLength();
  offset := ALabelData.ContourLabelOffset;
  while ((offset + TmpLabel.Width) < PathLength) do
  begin
    // skip string rendering when path is too much squiggly at this offset
    if (not ALabelPath.TestAngleVariance(offset, offset + TmpLabel.Width, M_PI_4)) then
    begin
      // skip drawing current label and let offset point to the next instance
      offset := offset + TmpLabel.Width + ALabelData.ContourLabelSpace;
      Continue;
    end;

    ContLabel := TContourLabel.Create();
    ContLabel.Priority := ALabelData.Priority;
    ContLabel.Style := ALabelData.Style;

    {$ifdef DEBUG_LABEL_LAYOUTER}
    ContLabel.Text = ALabelData.Text;
    {$endif}

    // do the magic to make sure that we don't render label upside-down

    // direction of path at the label drawing starting point
    initialAngle := abs(ALabelPath.AngleAtLengthDeg(offset));
    IsUpwards := (initialAngle > 90) and (initialAngle < 270);

    SetLength(ContLabel.Glyphs, Length(TmpLabel.Glyphs));
    GlyphIndex := -1;

    for glyph in TmpLabel.Glyphs do
    begin
      if IsUpwards then
        glyphOffset := offset - glyph.Position.X + TmpLabel.Width
      else
        glyphOffset := offset + glyph.Position.X;

      point := ALabelPath.PointAtLength(glyphOffset);

      //OnGlyphBoundingBox(glyph, textBoundingBox);
      w := glyph.Width;
      h := glyph.Height;
      tl.Assign(glyph.Position);

      // glyph angle in radians
      if IsUpwards then
        angle := ALabelPath.AngleAtLength(glyphOffset - w/2) * -1
      else
        angle := ALabelPath.AngleAtLength(glyphOffset + w/2) * -1;

      // it is not real diagonal, but maximum distance from glyph
      // point that can be covered after treansformantions
      diagonal := w + h + abs(textBaselineOffset);

      // fast check if current glyph can be visible
      GlyphRect.Init(point.X-diagonal, point.Y-diagonal, 2*diagonal, 2*diagonal);
      if (not FLayoutViewport.Intersects(GlyphRect)) then
        Continue;

      if IsUpwards then
        angle := angle - M_PI;

      sinA := sin(angle);
      cosA := cos(angle);

      glyphCopy := glyph;
      glyphCopy.Position.X := point.X - textBaselineOffset * sinA;
      glyphCopy.Position.Y := point.Y + textBaselineOffset * cosA;
      glyphCopy.Angle := angle;

      // four coordinates of glyph bounding box; x,y of top-left, top-right, bottom-right, bottom-left
      XArr[0] := tl.X;
      XArr[1] := tl.X + w;
      XArr[2] := tl.X + w;
      XArr[3] := tl.X;

      YArr[0] := tl.Y;
      YArr[1] := tl.Y;
      YArr[2] := tl.Y + h;
      YArr[3] := tl.Y + h;

      // rotate
      for i := 0 to 3 do
      begin
        ox := XArr[i];
        oy := YArr[i];
        XArr[i] := (ox * cosA) - (oy * sinA);
        YArr[i] := (ox * sinA) + (oy * cosA);
      end;

      // bounding box after rotation
      minX := XArr[0];
      maxX := XArr[0];
      minY := YArr[0];
      maxY := YArr[0];
      for i := 1 to 3 do
      begin
        minX := min(minX, XArr[i]);
        maxX := max(maxX, XArr[i]);
        minY := min(minY, YArr[i]);
        maxY := max(maxY, YArr[i]);
      end;
      // setup glyph top-left position and dimension after rotation
      glyphCopy.trPosition.SetValue(minX + glyphCopy.Position.X, minY + glyphCopy.Position.Y);
      glyphCopy.trWidth  := maxX - minX;
      glyphCopy.trHeight := maxY - minY;

      Inc(GlyphIndex);
      ContLabel.Glyphs[GlyphIndex] := glyphCopy;
    end;

    if GlyphIndex <> -1 then // is some glyph visible?
    begin
      SetLength(ContLabel.Glyphs, GlyphIndex+1);
      FContourLabelInstances.Add(ContLabel);
    end;
    offset := offset + TmpLabel.Width + ALabelData.ContourLabelSpace;
  end;
end;

{ TLabelInstance }

constructor TLabelInstance.Create();
begin
  FElements := TLabelInstanceElementList.Create();
  Priority := 0;
end;

destructor TLabelInstance.Destroy;
begin
  FreeAndNil(FElements);
  inherited Destroy;
end;

{ TLabelDataList }

function TLabelDataList.GetCount: Integer;
begin
  Result := Length(Items);
end;

procedure TLabelDataList.Clear();
begin
  SetLength(Items, 0);
end;

function TLabelDataList.Add(const AItem: TLabelData): Integer;
begin
  Result := Length(Items);
  SetLength(Items, Result+1);
  Items[Result] := AItem;
end;

{ TPathLabelData }

procedure TPathLabelData.Init(AStyle: TPathTextStyle);
begin
  Priority := AStyle.Priority;
  Text := '';
  Style := AStyle;
  ContourLabelOffset := 0.0;
  ContourLabelSpace := 0.0;
end;

{ TLabelInstanceElement }

procedure TLabelInstanceElement.Assign(AOther: TLabelInstanceElement);
begin
  LabelData := AOther.LabelData;
  MapLabel := AOther.MapLabel;
  X := AOther.X;
  Y := AOther.Y;
end;


end.

