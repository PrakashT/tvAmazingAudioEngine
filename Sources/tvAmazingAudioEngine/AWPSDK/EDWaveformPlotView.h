//
//  EDWaveformPlotView.h

#import <GLKit/GLKit.h>

//------------------------------------------------------------------------------
#pragma mark - Constants
//------------------------------------------------------------------------------
/**
 The default value used for the maximum rolling history buffer length of any EDWaveformPlotView.
 */
FOUNDATION_EXPORT UInt32 const EDWaveformPlotMaximumBufferLength;

//------------------------------------------------------------------------------
#pragma mark - Data Structures
//------------------------------------------------------------------------------

typedef struct
{
  GLfloat x; // 4 bit value
  GLfloat y;
} EDWaveformPlotGLPoint;

typedef struct
{
  GLfloat red; // 8 bit value
  GLfloat green;
  GLfloat blue;
  GLfloat alpha;
} EDWaveformPlotGLColor;

//------------------------------------------------------------------------------
#pragma mark - EZAudioPlotGL
//------------------------------------------------------------------------------

@interface EDWaveformPlotView : GLKView

//------------------------------------------------------------------------------
#pragma mark - Properties
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Customizing The Plot's Appearance
///-----------------------------------------------------------

/**
 The default background color of the plot. For iOS the color is specified as a UIColor.
 */
@property (nonatomic, strong) IBInspectable UIColor *backgroundColor;

//------------------------------------------------------------------------------
#pragma mark - Clearing The Plot
//------------------------------------------------------------------------------

/**
 Render inputted points and color buffers with given length
 */

- (void) renderFirstPlotPoints: (EDWaveformPlotGLPoint*) firstPlotPoints
                        colors: (EDWaveformPlotGLColor*) firstPlotColors
                        length: (int) firstPlotLength
              secondPlotPoints: (EDWaveformPlotGLPoint*) secondPlotPoints
                        colors: (EDWaveformPlotGLColor*) secondPlotColors
                        length: (int) secondPlotLength;

//------------------------------------------------------------------------------
#pragma mark - Clearing The Plot
//------------------------------------------------------------------------------

/**
 Clears all data from the audio plot (includes both EZPlotTypeBuffer and EZPlotTypeRolling)
 */
-(void)clear;

//------------------------------------------------------------------------------
#pragma mark - Start/Stop Display Link
//------------------------------------------------------------------------------

/**
 Call this method to tell the EZAudioDisplayLink to stop drawing temporarily.
 */
- (void)pauseDrawing;

//------------------------------------------------------------------------------

/**
 Call this method to manually tell the EZAudioDisplayLink to start drawing again.
 */
- (void)resumeDrawing;

//------------------------------------------------------------------------------
#pragma mark - Subclass
//------------------------------------------------------------------------------

/**
 Called during the OpenGL run loop to constantly update the drawing 60 fps. Callers can use this force update the screen while subclasses can override this for complete control over their rendering. However, subclasses are more encouraged to use the `redrawWithPoints:pointCount:baseEffect:vertexBufferObject:vertexArrayBuffer:interpolated:mirrored:gain:`
 */
- (void)redraw;

- (void) setup;
- (void) tearDown;

@end
