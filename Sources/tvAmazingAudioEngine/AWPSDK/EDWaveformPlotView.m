//
//  EDWaveformPlotView.m

#import "EDWaveformPlotView.h"

//------------------------------------------------------------------------------
#pragma mark - Constants
//------------------------------------------------------------------------------

UInt32 const EDWaveformPlotMaximumBufferLength = 8192;

//------------------------------------------------------------------------------
#pragma mark - Data Structures
//------------------------------------------------------------------------------

typedef struct {
  EDWaveformPlotGLPoint *points;
  EDWaveformPlotGLColor *colors;
  
  UInt32 plotPointCount;
  GLuint plotVertexBufferObject; //  First Plot Vertex buffer object
  GLuint plotColorBufferObject;  //  First Plot Color buffer object
} EZAudioPlotGLInfo;

//------------------------------------------------------------------------------
#pragma mark - EZAudioPlotGL (Interface Extension)
//------------------------------------------------------------------------------

@interface EDWaveformPlotView ()
@property(nonatomic, strong) GLKBaseEffect *baseEffect;
@property(nonatomic, strong) CADisplayLink *displayLink;
@property(nonatomic, assign) EZAudioPlotGLInfo *firstPlotInfo;
@property(nonatomic, assign) EZAudioPlotGLInfo *secondPlotInfo;

@end

//------------------------------------------------------------------------------
#pragma mark - EZAudioPlotGL (Implementation)
//------------------------------------------------------------------------------

@implementation EDWaveformPlotView

//------------------------------------------------------------------------------
#pragma mark - Dealloc
//------------------------------------------------------------------------------

- (void)tearDown {
  [self pauseDrawing]; // Stop / destroy displayLink
}

- (void)dealloc {
  if (self.firstPlotInfo) {
    [self deallocatePlotInfo:self.firstPlotInfo];
    self.firstPlotInfo = nil;
  }
  
  if (self.secondPlotInfo) {
    [self deallocatePlotInfo:self.secondPlotInfo];
    self.secondPlotInfo = nil;
  }
}

- (void)deallocatePlotInfo:(EZAudioPlotGLInfo *)info {
  if (info) {
    glDeleteBuffers(1, &info->plotVertexBufferObject);
    glDeleteBuffers(1, &info->plotColorBufferObject);
    
    free(info->colors);
    free(info->points);
    free(info);
  }
}

//------------------------------------------------------------------------------
#pragma mark - Initialization
//------------------------------------------------------------------------------

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self initialize];
  }
  return self;
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (void)initialize {
  //
  // Setup view properties
  //
  [self setup];
}

- (void)setup {
  if (self.firstPlotInfo != nil && self.secondPlotInfo != nil) {
    return;
  }
  
  [self setBackgroundColor:[UIColor clearColor]];
  
  //
  // Setup info data structure
  //
  self.firstPlotInfo = [self initializePlotInfo];
  self.secondPlotInfo = [self initializePlotInfo];
  
  //
  // Setup OpenGL specific stuff
  //
  [self setupOpenGL];
  
  //[self outputCurrentLineWidthAndPotentialLineWidthRange];
}

- (EZAudioPlotGLInfo *)initializePlotInfo {
  
  //
  // Setup info data structure
  //
  EZAudioPlotGLInfo *info =
  (EZAudioPlotGLInfo *)malloc(sizeof(EZAudioPlotGLInfo));
  memset(info, 0, sizeof(EZAudioPlotGLInfo));
  
  //
  // Create points array
  //
  info->points = (EDWaveformPlotGLPoint *)calloc(
                                                 sizeof(EDWaveformPlotGLPoint), EDWaveformPlotMaximumBufferLength);
  info->plotPointCount = EDWaveformPlotMaximumBufferLength;
  
  //
  // Create colors array
  //
  info->colors = (EDWaveformPlotGLColor *)calloc(
                                                 sizeof(EDWaveformPlotGLColor), EDWaveformPlotMaximumBufferLength);
  
  return info;
}

//------------------------------------------------------------------------------

- (void)setupOpenGL {
  self.baseEffect = [[GLKBaseEffect alloc] init];
  self.baseEffect.useConstantColor =
  GL_FALSE; // If NO then code is expected to enable / use
  // GLKVertexAttribColor (as this code does).
  // self.baseEffect.useConstantColor = GL_FALSE;
  // self.baseEffect.colorMaterialEnabled = YES;
  self.baseEffect.constantColor =
  GLKVector4Make(0.0f, 0.0f, 0.0f, 0.0f); // Remove base effect color
  
  if (!self.context) {
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    // kEAGLRenderingAPIOpenGLES3 also an option but would drop support for
    // iPhones 4s / 5 / 5c
  }
  [EAGLContext setCurrentContext:self.context];
  self.drawableColorFormat =
  GLKViewDrawableColorFormatRGBA8888; // Full range of needed color
  self.drawableDepthFormat =
  GLKViewDrawableDepthFormatNone; // Stock = GLKViewDrawableDepthFormat24;
  self.drawableStencilFormat =
  GLKViewDrawableStencilFormatNone; // Stock =
  // GLKViewDrawableStencilFormat8;
  self.drawableMultisample = GLKViewDrawableMultisample4X;
  self.opaque = NO; // Changed from NO to increase performance
  self.enableSetNeedsDisplay =
  NO; // Allow redraw to be manually controlled with displaylink
  
  glGenBuffers(
               1,
               &self.firstPlotInfo
               ->plotColorBufferObject); // Generate color buffer address in memory
  glBindBuffer(
               GL_ARRAY_BUFFER,
               self.firstPlotInfo->plotColorBufferObject); // Bind buffer to address
  glBufferData(GL_ARRAY_BUFFER,
               self.firstPlotInfo->plotPointCount *
               sizeof(EDWaveformPlotGLColor),
               self.firstPlotInfo->colors,
               GL_STREAM_DRAW); // Reserve space for buffer
  
  glGenBuffers(
               1, &self.firstPlotInfo->plotVertexBufferObject); // Generate point buffer
  // address in memeory
  glBindBuffer(
               GL_ARRAY_BUFFER,
               self.firstPlotInfo->plotVertexBufferObject); // Bind buffer to address
  glBufferData(GL_ARRAY_BUFFER,
               self.firstPlotInfo->plotPointCount *
               sizeof(EDWaveformPlotGLPoint),
               self.firstPlotInfo->points,
               GL_STREAM_DRAW); // Reserve space for buffer
  
  glGenBuffers(
               1,
               &self.secondPlotInfo
               ->plotColorBufferObject); // Generate color buffer address in memory
  glBindBuffer(
               GL_ARRAY_BUFFER,
               self.secondPlotInfo->plotColorBufferObject); // Bind buffer to address
  glBufferData(GL_ARRAY_BUFFER,
               self.secondPlotInfo->plotPointCount *
               sizeof(EDWaveformPlotGLColor),
               self.secondPlotInfo->colors,
               GL_STREAM_DRAW); // Reserve space for buffer
  
  glGenBuffers(
               1, &self.secondPlotInfo->plotVertexBufferObject); // Generate point buffer
  // address in memeory
  glBindBuffer(
               GL_ARRAY_BUFFER,
               self.secondPlotInfo->plotVertexBufferObject); // Bind buffer to address
  glBufferData(GL_ARRAY_BUFFER,
               self.secondPlotInfo->plotPointCount *
               sizeof(EDWaveformPlotGLPoint),
               self.secondPlotInfo->points,
               GL_STREAM_DRAW); // Reserve space for buffer
  
  glLineWidth(2.5f); // Set width of lines drawn
  
  self.frame = self.frame;
}


//------------------------------------------------------------------------------
#pragma mark - Updating The Plot
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

- (void)renderFirstPlotPoints:(EDWaveformPlotGLPoint *)firstPlotPoints
                       colors:(EDWaveformPlotGLColor *)firstPlotColors
                       length:(int)firstPlotLength
             secondPlotPoints:(EDWaveformPlotGLPoint *)secondPlotPoints
                       colors:(EDWaveformPlotGLColor *)secondPlotColors
                       length:(int)secondPlotLength {
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self setPoints:firstPlotPoints
             colors:firstPlotColors
             length:firstPlotLength
        forPlotInfo:self.firstPlotInfo];
    [self setPoints:secondPlotPoints
             colors:secondPlotColors
             length:secondPlotLength
        forPlotInfo:self.secondPlotInfo];
    
    if (self.window == nil || self.superview.window == nil) {
      // If you don't check self.window != nil then log will get a lot of spam
      // messages as the code can't render to a nonexistent drawing space
      return;
    }
    
    if (!self.displayLink || self.displayLink.paused) {
      [self resumeDrawing];
    }
  });
}

- (void)setPoints:(EDWaveformPlotGLPoint *)points
           colors:(EDWaveformPlotGLColor *)colors
           length:(int)length
      forPlotInfo:(EZAudioPlotGLInfo *)plotInfo {
  if (!plotInfo) {
    return;
  } else if (!points || !colors || length == 0) {
    plotInfo->plotPointCount = 0;
    return;
  }
  
  memcpy(plotInfo->points, points, length * sizeof(EDWaveformPlotGLPoint));
  memcpy(plotInfo->colors, colors, length * sizeof(EDWaveformPlotGLColor));
  
  plotInfo->plotPointCount = length;
  
  // Bind data to the buffers that are actually graphed when the screen
  // rerenders
  glBindBuffer(GL_ARRAY_BUFFER, plotInfo->plotVertexBufferObject);
  glBufferSubData(GL_ARRAY_BUFFER, 0,
                  plotInfo->plotPointCount * sizeof(EDWaveformPlotGLPoint),
                  plotInfo->points);
  
  glBindBuffer(GL_ARRAY_BUFFER, plotInfo->plotColorBufferObject);
  glBufferSubData(GL_ARRAY_BUFFER, 0,
                  plotInfo->plotPointCount * sizeof(EDWaveformPlotGLColor),
                  plotInfo->colors);
}

//------------------------------------------------------------------------------
#pragma mark - Clearing The Plot
//------------------------------------------------------------------------------

- (void)clear {
  [self clearPlotInfo:self.firstPlotInfo];
  [self clearPlotInfo:self.secondPlotInfo];
  
  [self setPoints:self.firstPlotInfo->points
           colors:self.firstPlotInfo->colors
           length:self.firstPlotInfo->plotPointCount
      forPlotInfo:self.firstPlotInfo];
  [self setPoints:self.secondPlotInfo->points
           colors:self.secondPlotInfo->colors
           length:self.secondPlotInfo->plotPointCount
      forPlotInfo:self.secondPlotInfo];
  
  [self render];
}

- (void)clearPlotInfo:(EZAudioPlotGLInfo *)plotInfo {
  if (plotInfo == nil) {
    return;
  }
  
  plotInfo->plotPointCount = EDWaveformPlotMaximumBufferLength;
  
  for (int x = 0; x < plotInfo->plotPointCount; x++) {
    plotInfo->points[x].x = 0;
    plotInfo->points[x].y = 0;
    plotInfo->colors[x].alpha = 0;
    plotInfo->colors[x].red = 0;
    plotInfo->colors[x].blue = 0;
    plotInfo->colors[x].green = 0;
  }
}

//------------------------------------------------------------------------------
#pragma mark - CADisplayLink: Plot rendering
//------------------------------------------------------------------------------

- (void)pauseDrawing {
  
  // Pause drawing when deallocated or told to do so by super class.
  if (self.displayLink) {
    [self.displayLink invalidate];
    self.displayLink = nil;
  }
}

//------------------------------------------------------------------------------

- (void)resumeDrawing {
  // Resumes drawing when a point is fed to graph (updateBuffer is called)
  if (!self.displayLink) {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                   selector:@selector(render)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                           forMode:NSDefaultRunLoopMode];
  }
  self.displayLink.paused = NO;
}

- (void)render {
  dispatch_async(dispatch_get_main_queue(),
                 ^{ // [[UIApplication sharedApplication] applicationState]
    // needs to be called on main thread
    if (self.window != nil && self.superview.window != nil &&
        ([[UIApplication sharedApplication] applicationState] ==
         UIApplicationStateActive ||
         [[UIApplication sharedApplication] applicationState] ==
         UIApplicationStateInactive)) {
      [self display];
    }
  });
}

//------------------------------------------------------------------------------
#pragma mark - Color Setters & Getters
//------------------------------------------------------------------------------

- (void)setBackgroundColor:(id)backgroundColor {
  _backgroundColor = backgroundColor;
  
  if ([backgroundColor isKindOfClass:[UIColor class]] &&
      ![backgroundColor isEqual:[UIColor clearColor]]) {
    CGColorRef colorRef = [backgroundColor CGColor];
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    [self getColorComponentsFromCGColor:colorRef
                                    red:&red
                                  green:&green
                                   blue:&blue
                                  alpha:&alpha];
    //
    // Note! If you set the alpha to be 0 on mac for a transparent view
    // the EZAudioPlotGL will make the superview layer-backed to make
    // sure there is a surface to display itself on (or else you will get
    // some pretty weird drawing glitches
    //
    
    glClearColor(red, green, blue,
                 alpha); // .569, .82, .478, 1.... .988, .988, .988, 1
  } else {
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
  }
}

//------------------------------------------------------------------------------
#pragma mark - Drawing
//------------------------------------------------------------------------------

- (void)drawRect:(CGRect)rect {
  [self redraw];
}

//------------------------------------------------------------------------------

- (void)redraw {
  // Draw graph plots
  
  // If you ever wanted to make two seperate graph objects this is the call that
  // would make it all possible. This call clears graph so that all points go
  // clear. -> https://github.com/beelsebob/Cocoa-GL-Tutorial. So... with a
  // double grapher you would need to be careful when this is called to avoid
  // wiping things that are already drawn.
  glClear(GL_COLOR_BUFFER_BIT);
  
  if (self.firstPlotInfo->plotPointCount != 0) {
    [self redrawWithBaseEffect:self.baseEffect
            vertexBufferObject:self.firstPlotInfo->plotVertexBufferObject
             colorBufferObject:self.firstPlotInfo->plotColorBufferObject
                    pointCount:self.firstPlotInfo->plotPointCount];
  }
  
  if (self.secondPlotInfo->plotPointCount != 0) {
    [self redrawWithBaseEffect:self.baseEffect
            vertexBufferObject:self.secondPlotInfo->plotVertexBufferObject
             colorBufferObject:self.secondPlotInfo->plotColorBufferObject
                    pointCount:self.secondPlotInfo->plotPointCount];
  }
}

//------------------------------------------------------------------------------

- (void)redrawWithBaseEffect:(GLKBaseEffect *)baseEffect
          vertexBufferObject:(GLuint)vbo
           colorBufferObject:(GLuint)cbo
                  pointCount:(UInt32)pointCount {
  GLenum mode = GL_LINE_STRIP;
  float xscale = 2.0f / ((float)pointCount);
  float yscale = 1.0f;
  GLKMatrix4 transform = GLKMatrix4MakeTranslation(-1.0f, 0.0f, 0.0f);
  transform = GLKMatrix4Scale(transform, xscale, yscale, 1.0f);
  baseEffect.transform.modelviewMatrix = transform;
  
  [baseEffect prepareToDraw];
  
  glBindBuffer(GL_ARRAY_BUFFER, cbo);
  glEnableVertexAttribArray(GLKVertexAttribColor);
  glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE,
                        sizeof(EDWaveformPlotGLColor), NULL);
  
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glEnableVertexAttribArray(GLKVertexAttribPosition);
  glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE,
                        sizeof(EDWaveformPlotGLPoint), NULL);
  
  glDrawArrays(mode, 0, pointCount);
}

//------------------------------------------------------------------------------

#pragma mark - Utility

- (void)getColorComponentsFromCGColor:(CGColorRef)color
                                  red:(CGFloat *)red
                                green:(CGFloat *)green
                                 blue:(CGFloat *)blue
                                alpha:(CGFloat *)alpha {
  size_t componentCount = CGColorGetNumberOfComponents(color);
  if (componentCount == 4) {
    const CGFloat *components = CGColorGetComponents(color);
    *red = components[0];
    *green = components[1];
    *blue = components[2];
    *alpha = components[3];
  }
}

@end
