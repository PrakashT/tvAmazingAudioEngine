//
//  EDWaveformAxesView.m
//  Eko Devices
//
//  Created by Eko Devices on 6/8/16.
//
//

#import "EDWaveformAxesView.h"

static int const maxNumberOfLines = 1000;
static int const minorToMajorPlotLineRatio = 5;
static int const lineThickness = 1;
static int const xAxisOneSecondLineThickness = 1;
static float const xAxisStartValue = 0;
static float const yAxisStartValue = 0;

static float const axisInterval = kWaveformXAxisInterval / minorToMajorPlotLineRatio; // .2 seconds per major line box

@interface EDWaveformAxesView () {
  
  // Line mode
  int numberOfMinorPlotLines;
  int numberOfMajorPlotLines;
  int numberOfOneSecondIntervalPlotLines;
  
  CGPoint *minorPlotPoints;
  CGPoint *majorPlotPoints;
  CGPoint *oneSecondIntervalPoints;
  
  float *minorPlotLineXCoordinates;
  float *minorPlotLineYCoordinates;
  
  float *majorPlotLineXCoordinates;
  float *majorPlotLineYCoordinates;
  
  float *oneSecondIntervalLineXCoordinates;
  float *oneSecondIntervalLineYCoordinates;
}

@property(nonatomic, assign, readwrite) CGSize majorGridLineSquareSize;

@end

@implementation EDWaveformAxesView

- (instancetype)initWithFrame:(CGRect)frame {
  
  self = [super initWithFrame:frame];
  if (self) {
    // Init code
    [self initialize];
  }
  return self;
}

- (void)dealloc {
  if (minorPlotLineXCoordinates) {
    free(minorPlotLineXCoordinates);
    minorPlotLineXCoordinates = nil;
  }
  if (minorPlotLineYCoordinates) {
    free(minorPlotLineYCoordinates);
    minorPlotLineYCoordinates = nil;
  }
  
  if (majorPlotLineXCoordinates) {
    free(majorPlotLineXCoordinates);
    majorPlotLineXCoordinates = nil;
  }
  if (majorPlotLineYCoordinates) {
    free(majorPlotLineYCoordinates);
    majorPlotLineYCoordinates = nil;
  }
  
  if (oneSecondIntervalLineXCoordinates) {
    free(oneSecondIntervalLineXCoordinates);
    oneSecondIntervalLineXCoordinates = nil;
  }
  if (oneSecondIntervalLineYCoordinates) {
    free(oneSecondIntervalLineYCoordinates);
    oneSecondIntervalLineYCoordinates = nil;
  }
  
  if (minorPlotPoints) {
    free(minorPlotPoints);
    minorPlotPoints = nil;
  }
  
  if (majorPlotPoints) {
    free(majorPlotPoints);
    majorPlotPoints = nil;
  }
  
  if (oneSecondIntervalPoints) {
    free(oneSecondIntervalPoints);
    oneSecondIntervalPoints = nil;
  }
}

- (void)layoutSubviews {
  [self setNeedsDisplay];
  [self setNeedsUpdateConstraints];
  [self layoutIfNeeded];
  
  [self setDuration:self.duration];
}

- (void)initialize {
  self.layer.borderWidth = 0;
  self.clipsToBounds = YES;

  self.backgroundColor = [UIColor colorWithRed:(252/255.0f) green:(252/255.0f) blue:(252/255.0f) alpha:1];
  [self setMajorPlotLineColor:[UIColor colorWithRed:(227.0f/255.0f) green:(232.0f/255.0f) blue:(234.0f/255.0f) alpha:1]];
  [self setMinorPlotLineColor:[UIColor colorWithRed:(246.0f/255.0f) green:(247.0f/255.0f) blue:(248.0f/255.0f) alpha:1]];
  
  _duration = 3.5f;
  
  [self setup];
}

- (BOOL)isSetup {
  return majorPlotPoints != nil;
}

- (void)setup {
  if ([self isSetup]) {
    return;
  }
  
  minorPlotPoints = (CGPoint *)malloc(sizeof(CGPoint) * maxNumberOfLines);
  majorPlotPoints = (CGPoint *)malloc(sizeof(CGPoint) * maxNumberOfLines);
  oneSecondIntervalPoints =
  (CGPoint *)malloc(sizeof(CGPoint) * maxNumberOfLines);
  
  // Set default graph duration
  [self setDuration:_duration];
}

//- (void) lineRenderTest {
//    [self setXAxisStartValue:0 xAxisEndValue:3 xAxisInterval:.04f
//    yAxisStartValue:0 yAxisEndValue:3 yAxisInterval:.04f];
//
//    CADisplayLink *theLink = [CADisplayLink displayLinkWithTarget:self
//    selector:@selector(moveGraph)]; theLink.frameInterval = 1; [theLink
//    addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
//
//}
//
//- (void) moveGraph {
//    [self setXAxisStartValue:_xAxisStartValue-(1/60.0f)
//    xAxisEndValue:_xAxisEndValue-(1/60.0f) xAxisInterval:_xAxisInterval
//    yAxisStartValue:_yAxisStartValue yAxisEndValue:_yAxisEndValue
//    yAxisInterval:_yAxisInterval];
//}

#pragma mark - Parameter setting

- (void)setDuration:(float)duration {
  if ([self isSetup] == false) {
    assert(0);
    return;
  }
  
  if (duration <= 0) {
    return;
  }
  
  _duration = duration;
  
  if (self.frame.size.height == 0 || self.frame.size.width == 0) {
    return; // Don't try to render if view covers no place to render.
  }
  
  // Initialize all the graphing variables
  int numberOfMinorLines = 0;
  int numberOfMajorLines = 0;
  int numberOfOneSecondIntervalLines = 0;
  
  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= X axis
  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  
  // Calculate the size of a major grid line square (used when determining
  // spacing of y axis grid lines)
  float boxDimension =
  self.frame.size.width / ((duration - xAxisStartValue) /
                           (axisInterval * minorToMajorPlotLineRatio));
  self.majorGridLineSquareSize = CGSizeMake(boxDimension, boxDimension);
  
  // Change the inputs to integers to avoid rounding errors and to simplify the
  // math.
  int xS = xAxisStartValue * 10000;
  int xE = (xAxisStartValue + duration) * 10000;
  int xI = axisInterval * 10000;
  
  int totalXTime = xE - xS;
  
  //    floorf(xS / (xI*minorToMajorPlotLineRatio)) * xI *
  //    minorToMajorPlotLineRatio; while(closestMajorXValue < xS){
  //        closestMajorXValue += xI * minorToMajorPlotLineRatio;
  //    }
  
  int majorXCounter = minorToMajorPlotLineRatio - 1;
  float majorXTimeCounter = 0;
  
  for (int x = 0; x <= xE; x += xI) {
    majorXCounter++;
    
    if (majorXCounter == minorToMajorPlotLineRatio) {
      majorXCounter = 0;
      majorXTimeCounter += kWaveformXAxisInterval;
      
      if (majorXTimeCounter >= 1) {
        majorXTimeCounter = 0;
        
        oneSecondIntervalPoints[numberOfOneSecondIntervalLines] =
        CGPointMake(((float)(x) / totalXTime) * self.frame.size.width, 0);
        oneSecondIntervalPoints[numberOfOneSecondIntervalLines + 1] =
        CGPointMake(
                    oneSecondIntervalPoints[numberOfOneSecondIntervalLines].x,
                    self.frame.size.height);
        
        numberOfOneSecondIntervalLines += 2;
      } else {
        majorPlotPoints[numberOfMajorLines] =
        CGPointMake(((float)(x) / totalXTime) * self.frame.size.width, 0);
        majorPlotPoints[numberOfMajorLines + 1] = CGPointMake(
                                                              majorPlotPoints[numberOfMajorLines].x, self.frame.size.height);
        
        //                majorPlotLineXCoordinates[numberOfMajorLines] =
        //                ((float)(xE - x)/totalXTime)*self.frame.size.width;
        //                majorPlotLineYCoordinates[numberOfMajorLines] = 0;
        //
        //                majorPlotLineXCoordinates[numberOfMajorLines+1] =
        //                majorPlotLineXCoordinates[numberOfMajorLines];
        //                majorPlotLineYCoordinates[numberOfMajorLines+1] =
        //                self.frame.size.height;
        
        numberOfMajorLines += 2;
      }
      
    } else {
      
      minorPlotPoints[numberOfMinorLines] =
      CGPointMake(((float)(x) / totalXTime) * self.frame.size.width, 0);
      minorPlotPoints[numberOfMinorLines + 1] = CGPointMake(
                                                            minorPlotPoints[numberOfMinorLines].x, self.frame.size.height);
      
      //                minorPlotLineXCoordinates[numberOfMinorLines] =
      //                ((float)(xE - x)/totalXTime)*self.frame.size.width;
      //                minorPlotLineYCoordinates[numberOfMinorLines] = 0;
      //
      //                minorPlotLineXCoordinates[numberOfMinorLines+1] =
      //                minorPlotLineXCoordinates[numberOfMinorLines];
      //                minorPlotLineYCoordinates[numberOfMinorLines+1] =
      //                self.frame.size.height;
      
      numberOfMinorLines += 2;
    }
  }
  
  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= Y axis
  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
  
  float numberOfYAxisMajorBoxes =
  self.frame.size.height / self.majorGridLineSquareSize.height;
  float numberOfYAxisMinorLines =
  numberOfYAxisMajorBoxes * minorToMajorPlotLineRatio;
  
  // Change the inputs to integers to avoid rounding errors and to simplify the
  // math.
  int yS = yAxisStartValue * 10000;
  int yE = (yAxisStartValue + numberOfYAxisMinorLines * axisInterval) * 10000;
  int yI = axisInterval * 10000;
  int totalYTime = yE - yS;
  
  int closestMinorYValue = floor(yS / yI) * yI;
  while (closestMinorYValue < yS) {
    closestMinorYValue += yI;
  }
  
  int closestMajorYValue = floor(yS / (yI * minorToMajorPlotLineRatio)) * yI *
  minorToMajorPlotLineRatio;
  while (closestMajorYValue < yS) {
    closestMajorYValue += yI * minorToMajorPlotLineRatio;
  }
  
  int majorYCounter =
  (closestMajorYValue == closestMinorYValue
   ? minorToMajorPlotLineRatio - 1
   : minorToMajorPlotLineRatio - 1 -
   ((closestMajorYValue - closestMinorYValue) / yI));
  
  for (int y = closestMinorYValue; y <= yE; y += yI) {
    
    majorYCounter++;
    
    if (majorYCounter == minorToMajorPlotLineRatio) {
      majorYCounter = 0;
      
      majorPlotPoints[numberOfMajorLines] =
      CGPointMake(0, ((float)(y) / totalYTime) * self.frame.size.height);
      majorPlotPoints[numberOfMajorLines + 1] = CGPointMake(
                                                            self.frame.size.width, majorPlotPoints[numberOfMajorLines].y);
      
      //                majorPlotLineXCoordinates[numberOfMajorLines] = 0;
      //                majorPlotLineYCoordinates[numberOfMajorLines] =
      //                ((float)(yE - y)/totalYTime)*self.frame.size.height;
      //
      //                majorPlotLineXCoordinates[numberOfMajorLines+1] =
      //                self.frame.size.width;
      //                majorPlotLineYCoordinates[numberOfMajorLines+1] =
      //                majorPlotLineYCoordinates[numberOfMajorLines];
      
      numberOfMajorLines += 2;
      
    } else {
      minorPlotPoints[numberOfMinorLines] =
      CGPointMake(0, ((float)(y) / totalYTime) * self.frame.size.height);
      minorPlotPoints[numberOfMinorLines + 1] = CGPointMake(
                                                            self.frame.size.width, minorPlotPoints[numberOfMinorLines].y);
      
      //                minorPlotLineXCoordinates[numberOfMinorLines] = 0;
      //                minorPlotLineYCoordinates[numberOfMinorLines] =
      //                ((float)(yE - y)/totalYTime)*self.frame.size.height;
      //
      //                minorPlotLineXCoordinates[numberOfMinorLines+1] =
      //                self.frame.size.width;
      //                minorPlotLineYCoordinates[numberOfMinorLines+1] =
      //                minorPlotLineYCoordinates[numberOfMinorLines];
      
      numberOfMinorLines += 2;
    }
  }
  
  numberOfMinorPlotLines = numberOfMinorLines;
  numberOfMajorPlotLines = numberOfMajorLines;
  numberOfOneSecondIntervalPlotLines = numberOfOneSecondIntervalLines;
  
  [self setNeedsDisplay];
}

#pragma mark - Rendering

- (void)initializeContext {
  //    CGContextRef context = UIGraphicsGetCurrentContext();
  //    CGContextClearRect(context, self.bounds);
  //
  //    CGContextSetLineCap(context, kCGLineCapSquare);
  //    CGContextSetLineWidth(context, lineThickness);
  // CGContextSetLineJoin(context, kCGLineJoinMiter);
  // CGContextSetMiterLimit(context, 1);
  // CGContextSetFlatness(context, 1);
}

- (void)drawRect:(CGRect)rect {
  // Drawing code
  [super drawRect:rect];
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextClearRect(context, self.bounds);
  
  CGContextSetLineCap(context, kCGLineCapSquare);
  CGContextSetLineWidth(context, lineThickness);
  
  CGContextSetFillColorWithColor(context, self.backgroundColor.CGColor);
  CGContextFillRect(context, self.bounds);
  
  // ~81% cpu
  
  CGContextSetStrokeColorWithColor(context, [_minorPlotLineColor CGColor]);
  CGContextStrokeLineSegments(context, minorPlotPoints, numberOfMinorPlotLines);
  
  CGContextSetStrokeColorWithColor(context, [_majorPlotLineColor CGColor]);
  CGContextStrokeLineSegments(context, majorPlotPoints, numberOfMajorPlotLines);
  
  CGContextSetStrokeColorWithColor(context, [_majorPlotLineColor CGColor]);
  CGContextSetLineWidth(context, xAxisOneSecondLineThickness);
  CGContextStrokeLineSegments(context, oneSecondIntervalPoints,
                              numberOfOneSecondIntervalPlotLines);
  //    //85% cpu!
  
  //    for(int x = 0; x < numberOfMinorPlotLines*2; x += 2){
  //        CGContextMoveToPoint(context, minorPlotLineXCoordinates[x],
  //        minorPlotLineYCoordinates[x]); CGContextAddLineToPoint(context,
  //        minorPlotLineXCoordinates[x+1], minorPlotLineYCoordinates[x+1]);
  //    }
  //
  //    CGContextStrokePath(context);
  //
  //    CGContextSetStrokeColorWithColor(context, [_majorPlotLineColor
  //    CGColor]);
  //
  //    for(int x = 0; x < numberOfMajorPlotLines*2; x += 2){
  //        CGContextMoveToPoint(context, majorPlotLineXCoordinates[x],
  //        majorPlotLineYCoordinates[x]); CGContextAddLineToPoint(context,
  //        majorPlotLineXCoordinates[x+1], majorPlotLineYCoordinates[x+1]);
  //    }
  //
  //    CGContextStrokePath(context);
}

@end
