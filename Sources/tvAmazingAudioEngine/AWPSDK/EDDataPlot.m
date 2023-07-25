//
//  EDDataPlot.m
//  Eko Devices
//
//  Created by Tyler Crouch on 7/7/17.
//
//

//@import tvDeviceLibETMP
#import "EDDataPlot.h"
//#import "tvDeviceLibETest.h"

// Bluetooth (get constant)
#import <EDBluetoothSDK/EDBluetooth.h>

// Data formatter
#import <EDBluetoothSDK/EDDataFormatter.h>

// UI objects
#import "EDWaveformAxesView.h"
#import "EDWaveformPlotView.h"

// Constants
#define shortConstant (1/32767.0f) //https://stackoverflow.com/questions/11153156/define-vs-const-in-objective-c
static const float graphPlotMillimetersPerSecond = 25.0f;

typedef struct
{
    unsigned int rollingIndex; // Current index of rolling plot
    
    EDWaveformPlotGLPoint *points; // Current plot points
    EDWaveformPlotGLColor *colors; // Current plot colors
    
    unsigned int length; // Current plot length (length of points and colors)

    float gain; // Gain for plot
} PlotInfo;

@interface EDDataPlot () {
    
    EDWaveformAxesView *waveformAxesView;
    EDWaveformPlotView *waveformPlotView;
    
    // Graphed data
    PlotInfo *audioPlotInfo;
    PlotInfo *ECGPlotInfo;
    
    // Graph properties
    float alphaIncrement;

    // Colors
    EDWaveformPlotGLColor waveformColor;

    // Rendering display link
    CADisplayLink *renderingDisplayLink;
}

@end

@implementation EDDataPlot

# pragma mark - View lifecycle

- (instancetype) initWithFrame: (CGRect) frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        // Init code
        [self initialize];
    }
    return self;
}

- (void) cleanUp {
  // Prepare to dealloc
  [self clear];
  
  // Tear down
  [waveformPlotView tearDown];
}

- (void) dealloc {
    
    if(renderingDisplayLink){
        [renderingDisplayLink invalidate];
        renderingDisplayLink = nil;
    }

    [waveformPlotView clear];
    
    _color = nil; // do not do self.color = nil
    
  [self deallocatePlotInfo:self->audioPlotInfo];
  self->audioPlotInfo = nil;
  
  [self deallocatePlotInfo:self->ECGPlotInfo];
  self->ECGPlotInfo = nil;
}

- (void) deallocatePlotInfo: (PlotInfo*) plotInfo {
    @autoreleasepool {
        if(plotInfo){
            if(plotInfo->points){
                free(plotInfo->points);
                plotInfo->points = nil;
            }
            if(plotInfo->colors){
                free(plotInfo->colors);
                plotInfo->colors = nil;
            }
            
            free(plotInfo);
        }
    }
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(320, 275);
}

- (void) layoutSubviews {
    // Make sure to call super or else the graph plot line view won't initially render correctly
    [super layoutSubviews];
    
    // Update autolayout constraints whenever view is resized
    [self setNeedsUpdateConstraints];
    [self layoutIfNeeded];
    [self setNeedsDisplay];
    
    // Update objects that change based on superview
    [self updateObjects];
}

# pragma mark - Public Methods

- (void) setAudioSampleRate:(unsigned int)audioSampleRate {
    if(audioSampleRate < 0){
        // Must be at least 1
        audioSampleRate = 1;
    }
    
    BOOL newValue = self.audioSampleRate != audioSampleRate;
    
    _audioSampleRate = audioSampleRate;
    
    if(newValue){
        [self updatePlot];
    }
}

- (void) setECGSampleRate:(unsigned int)ECGSampleRate {
    if(ECGSampleRate < 0){
        // Must be at least 1
        ECGSampleRate = 1;
    }
    
    BOOL newValue = self.ECGSampleRate != ECGSampleRate;
    
    _ECGSampleRate = ECGSampleRate;
    
    if(newValue){
        [self updatePlot];
    }
}

- (void) setAudioGraphHidden: (BOOL) audioGraphHidden {
    if(self.audioGraphHidden != audioGraphHidden){
        _audioGraphHidden = audioGraphHidden;
        [self updatePlot];
    }
}

- (void) setECGGraphHidden: (BOOL) ECGGraphHidden {
    if(self.ECGGraphHidden != ECGGraphHidden){
        _ECGGraphHidden = ECGGraphHidden;
        [self updatePlot];
    }
}

- (void) setDuration: (float) duration {
    if(duration <= 0){
        return;
    }else if(duration > [self maximumPlotDuration]){
        NSLog(@"EDWaveformPlot: setDuration: Inputted duration (%f seconds) is greater than maximum graph duration %f. Will set graph to maximum duration.", duration, [self maximumPlotDuration]);
        duration = [self maximumPlotDuration];
    }

    BOOL durationChanged = self.duration != duration;
    
    // Set new plot duration
    _duration = duration;
    
    // Update the graph axis grid as needed
    // Make sure plot updates its frame to whatever new value it may have been set to before setting duration
    [waveformAxesView layoutSubviews];
    [waveformAxesView setDuration:duration];
    [self updateECGGain];
  
    // Set buffer plot properties
    if(durationChanged){
        // Rerender graph if necessary
        [self updatePlot];
    }
}

- (void) setColor: (UIColor*) color {
    if(!color){
        color = [UIColor clearColor];
    }
    
    _color = color;
    
  CGFloat red; CGFloat green; CGFloat blue; CGFloat alpha;
  [color getRed:&red green:&green blue:&blue alpha:&alpha];
  
  self->waveformColor.red = red;
  self->waveformColor.green = green;
  self->waveformColor.blue = blue;
  self->waveformColor.alpha = alpha;
  
  for(int x = 0; x < EDWaveformPlotMaximumBufferLength; x++){
    // Set amplitude to zero
    self->audioPlotInfo->colors[x].red = self->waveformColor.red;
    self->audioPlotInfo->colors[x].green = self->waveformColor.green;
    self->audioPlotInfo->colors[x].blue = self->waveformColor.blue;
    self->audioPlotInfo->colors[x].alpha = self->waveformColor.alpha;
    
    self->ECGPlotInfo->colors[x].red = self->waveformColor.red;
    self->ECGPlotInfo->colors[x].green = self->waveformColor.green;
    self->ECGPlotInfo->colors[x].blue = self->waveformColor.blue;
    self->ECGPlotInfo->colors[x].alpha = self->waveformColor.alpha;
  }
}

- (void) setAudioGraphGain:(float)audioGraphGain {
  if(self->audioPlotInfo){
    self->audioPlotInfo->gain = audioGraphGain;
  }
}

- (float) audioGraphGain {
  return self->audioPlotInfo ? self->audioPlotInfo->gain : 1;
}

- (void) updateRollingPlotAudioPointBuffer: (short) audioAmplitude {
    float audioFloatAmplitude = [self convertShortToFloat:audioAmplitude];
    [self addRollingPlotAmplitudeBuffer:&audioFloatAmplitude withBufferLength:1 toPlotInfo:audioPlotInfo];
    
    [self startDrawingPlot];
}

- (void) updateRollingPlotECGPointBuffer: (short) ECGAmplitude {
    float ECGFloatAmplitude = [self convertShortToFloat:ECGAmplitude];
    [self addRollingPlotAmplitudeBuffer:&ECGFloatAmplitude withBufferLength:1 toPlotInfo:ECGPlotInfo];
    [self startDrawingPlot];
}

- (void) updateRollingPlotAudioPointBuffer: (short) audioAmplitude
                            ECGPointBuffer: (short) ECGAmplitude {
    
    [self updateRollingPlotAudioPointBuffer:audioAmplitude];
    [self updateRollingPlotECGPointBuffer:ECGAmplitude];
}

- (void) clear {
    [self stopDrawingPlot];
    
  [self->waveformPlotView clear];
  
  self->audioPlotInfo->rollingIndex = 0;
  self->ECGPlotInfo->rollingIndex = 0;
  
  for(int x = 0; x < EDWaveformPlotMaximumBufferLength; x++){
    // Set amplitude to zero
    self->audioPlotInfo->points[x].x = x;
    self->audioPlotInfo->points[x].y = 0;
    
    self->ECGPlotInfo->points[x].x = x;
    self->ECGPlotInfo->points[x].y = 0;
  }
  
    waveformPlotView.alpha = 0;
    
    [self renderPlot];
}

# pragma mark - Object initialization

- (void)initialize {
  // Initialize UI objects
  self.backgroundColor = [UIColor clearColor];

  // Initialize variables
  _audioSampleRate = 4000;
  _ECGSampleRate = 500;
  _audioGraphHidden = NO;
  _ECGGraphHidden = YES;
  self.backgroundColor = [UIColor clearColor];

  alphaIncrement = 5 / 60.0f; // Avoid problem where waveform will stick around after being cleared and then flash when it begins rendering again.
  
  // Setup
  [self setup];
  
}

- (void)setup {
  if ([self isSetup]) {
    return;
  }
  
  if(!self->audioPlotInfo){
    self->audioPlotInfo = [self initializePlotInfo];
  }
  if(!self->ECGPlotInfo){
    self->ECGPlotInfo = [self initializePlotInfo];
  }
  
  self.color = [UIColor colorWithRed:(72/255.0f) green:(82/255.0f) blue:(91/255.0f) alpha:1];
    
  if (!waveformAxesView) {
    waveformAxesView = [[EDWaveformAxesView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    
    [self addSubview:waveformAxesView];
  } else {
    [waveformAxesView setup];
  }
  
  if (!waveformPlotView) {
    // Make sure to allocate this with some frame. This avoids irritating error
    // messages from filling up the log. The performance isn't effected, but it
    // is nice to clean the log up by initializing this properly.
    waveformPlotView = [[EDWaveformPlotView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    
    [self addSubview:waveformPlotView];

  } else {
    [waveformPlotView setup];
  }

  [self clear];
  
  // Update objects to reflect properties
  [self updateObjects];
  [self updatePlot];
}

- (BOOL)isSetup {
  return audioPlotInfo != nil && ECGPlotInfo != nil;
}

- (PlotInfo*) initializePlotInfo {
    PlotInfo * plotInfo = (PlotInfo *)malloc(sizeof(PlotInfo));
    
    // Initialize points
    plotInfo->points = (EDWaveformPlotGLPoint *)calloc(sizeof(EDWaveformPlotGLPoint), EDWaveformPlotMaximumBufferLength);
    
    // Initialize colors
    plotInfo->colors = (EDWaveformPlotGLColor *)calloc(sizeof(EDWaveformPlotGLColor), EDWaveformPlotMaximumBufferLength);
    
    // Set initial values for points
    for(int x = 0; x < EDWaveformPlotMaximumBufferLength; x++){
        plotInfo->points[x].x = x; // These x values should never need to be adjusted.
    }
    
    // Initialize other properties
    plotInfo->length = 0;
    plotInfo->rollingIndex = 0;
    plotInfo->gain = 1;
    
    return plotInfo;
}

# pragma mark - Object updating based on context

- (void) updateObjects {
    waveformAxesView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    waveformPlotView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
  
    waveformAxesView.backgroundColor = self.backgroundColor;
  
    [self setDuration:[self maximumPlotDuration]]; //[self getDefaultPlotDuration]
    [self updateECGGain];
}

- (void) updateECGGain {
  
  // Calibrate ECG gain
  // NOTE: The scale (height/width) of an ECG signal is medically relevant. The graph here is verified to display ECG signal to the correct scale.
  // Audio gain is arbitrary - adjust as you see fit.
  // See this image to learn more about ECG scale: https://en.wikipedia.org/wiki/Electrocardiography#/media/File:ECG_Paper_v2.svg
  // y axis: Every two large boxes equates to 1 mV of ECG signal amplitude
  // x axis: Every single large box is .2 seconds in time. 5 boxes = 1 second.
  float gridRatio = (waveformAxesView.majorGridLineSquareSize.height * 2) / waveformAxesView.frame.size.height;
  float graphRatio = [EDDataFormatter convertShortToFloat:EDOneMillivoltECGSignalAmplitude];
  ECGPlotInfo->gain = 2 * gridRatio / graphRatio;
}

# pragma mark - Waveform buffer management

- (void) addRollingPlotAmplitudeBuffer: (float*) amplitudeBuffer withBufferLength: (unsigned short) bufferLength toPlotInfo: (PlotInfo *) plotInfo {
    if(bufferLength == 0 || !amplitudeBuffer){
        return;
    }
    
  float plotValue;
  
  for(short y = 0; y < bufferLength; y++){
    // Set value of new plot point
    // X values are precalculated
    plotValue = amplitudeBuffer[y]*plotInfo->gain;
    plotInfo->points[plotInfo->rollingIndex].y = [self windowAmplitude:plotValue forPlotInfo:plotInfo]; // Set Y value
    
    // Increment plot index
    plotInfo->rollingIndex++;
    if(plotInfo->rollingIndex == plotInfo->length){
      plotInfo->rollingIndex = 0;
    }
  }
}

- (float) windowAmplitude: (float) amplitude forPlotInfo: (PlotInfo*) plotInfo{
    float topBound;
    float bottomBound;
    
    if(plotInfo == audioPlotInfo){
        topBound = self.ECGGraphHidden ? 1 : 0;
        bottomBound = -1;
        amplitude += self.ECGGraphHidden ? 0 : -.5f;
    }else{
        topBound = 1;
        bottomBound = self.audioGraphHidden ? -1 : 0;
        amplitude += self.audioGraphHidden ? 0 : .5f;
        //amplitude = .8702902436; // Approx 1 big box down on a graph that has height 253
    }
    
    return amplitude > topBound ? topBound : amplitude < bottomBound ? bottomBound : amplitude;
}

# pragma mark - Waveform plot scaling

- (void) updatePlot {
    // Rerender plot
    if(self.duration <= 0){
        return;
    }else if(self.duration > [self maximumPlotDuration]){
        // Change plot duration if it exceeds maximum duration. This usually triggers if ECG or audio graph hides / reveals dynamically during use session.
        [self setDuration:[self maximumPlotDuration]];
    }
    
    [self clear];
    
  int audioPointsToPlot = [self getNumberOfAudioPointsToPlot];
  int ECGPointsToPlot = [self getNumberOfECGPointsToPlot];
  BOOL plotLengthChange = self->audioPlotInfo->length != audioPointsToPlot || self->ECGPlotInfo->length != ECGPointsToPlot;
  
  // Set plot length (Range [128, 8192]) based on duration.
  //NSLog(@"updatePlot: plot %d audio points and %d ECG points (duration %f, audio sample rate %d, audio resolution %d)", audioPointsToPlot, ECGPointsToPlot, self.duration, self.audioSampleRate , self.audioRollingPlotResolution);
  self->audioPlotInfo->length = audioPointsToPlot;
  self->ECGPlotInfo->length = ECGPointsToPlot;
  
  // Set x point values for plot
  if(plotLengthChange){
    dispatch_async(dispatch_get_main_queue(), ^{
      [self clear];
    });
    
    // Number of points graphed has changed.
    if(self->audioPlotInfo->rollingIndex > self->audioPlotInfo->length - 1 || self->ECGPlotInfo->rollingIndex > self->ECGPlotInfo->length - 1){
      self->audioPlotInfo->rollingIndex = self->audioPlotInfo->length - 1;
      self->ECGPlotInfo->rollingIndex = self->ECGPlotInfo->length - 1;
    }
  }
}

# pragma mark - Rendering

- (void) stopDrawingPlot {
    if(renderingDisplayLink){
        [renderingDisplayLink invalidate];
        renderingDisplayLink = nil;
    }
}

- (void) startDrawingPlot {
    if(!renderingDisplayLink){
        renderingDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderPlot)];
        renderingDisplayLink.frameInterval = 1;
        [renderingDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void) renderPlot {
    if(self.superview.window == nil || self.window == nil ){
        return;
    }
    
    if(waveformPlotView.alpha != 1){
        // Avoid problem where waveform will stick around after being cleared and then flash when it begins rendering again.
        waveformPlotView.alpha += alphaIncrement;
        if(waveformPlotView.alpha > 1){
            waveformPlotView.alpha = 1;
        }
    }
    
  if(!self.audioGraphHidden && !self.ECGGraphHidden){
    [self->waveformPlotView renderFirstPlotPoints:self->audioPlotInfo->points colors:self->audioPlotInfo->colors length:self->audioPlotInfo->length secondPlotPoints:self->ECGPlotInfo->points colors:self->ECGPlotInfo->colors length:self->ECGPlotInfo->length];
    
  }else if(!self.audioGraphHidden && self.ECGGraphHidden){
    [self->waveformPlotView renderFirstPlotPoints:self->audioPlotInfo->points colors:self->audioPlotInfo->colors length:self->audioPlotInfo->length secondPlotPoints:nil colors:nil length:0];
    
  }else if(self.audioGraphHidden && !self.ECGGraphHidden){
    [self->waveformPlotView renderFirstPlotPoints:self->ECGPlotInfo->points colors:self->ECGPlotInfo->colors length:self->ECGPlotInfo->length secondPlotPoints:nil colors:nil length:0];
    
  }
}

# pragma mark - Utility

- (int) getMaximumRollingPlotAudioPointCount {
    if(self.audioGraphHidden){
        return 0;
    }else if(self.ECGGraphHidden){
        return EDWaveformPlotMaximumBufferLength;
    }

    return floor([self maximumPlotDuration] * self.audioSampleRate);
}

- (int) getMaximumRollingPlotECGPointCount {
    if(self.ECGGraphHidden){
        return 0;
    }else if(self.audioGraphHidden){
        return EDWaveformPlotMaximumBufferLength;
    }

    return floor([self maximumPlotDuration] * self.ECGSampleRate);
}

- (float) maximumPlotDuration {
    // Graph has a current limitation of 8192 points (audio + ECG point count must be less than 8192 points)
    return floor(EDWaveformPlotMaximumBufferLength / ((float)(self.audioSampleRate + self.ECGSampleRate)));
}

- (int) getNumberOfAudioPointsToPlot {
    return self.audioGraphHidden ? 0 : self.duration * self.audioSampleRate;
}

- (int) getNumberOfECGPointsToPlot {
    return self.ECGGraphHidden ? 0 : self.duration * self.ECGSampleRate;
}

- (void) printPlotDataForPlotInfo: (PlotInfo*) plotInfo {
    NSLog(@"---------------------------------------------------- PRINT PLOT DATA ----------------------------------------------------");
    NSLog(@"Current rolling index = %d", plotInfo->rollingIndex);
    
  for (int x = 0; x < plotInfo->length; x++){
    NSLog(@"(%f, %f) - R: %f, G: %f, B: %f, A: %f", plotInfo->points[x].x, plotInfo->points[x].y, plotInfo->colors[x].red, plotInfo->colors[x].green, plotInfo->colors[x].blue, plotInfo->colors[x].alpha);
  }
}

- (float) convertShortToFloat: (short) value {
    // [-32768, -1] --> [-32767, 0] --> [-1, 0] or [0, 32767] --> [0, 1]
    
    return (float)(value < 0 ? (value+1) * shortConstant : value * shortConstant);
}

@end
