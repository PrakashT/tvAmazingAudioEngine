//
//  EDDataPlot.h
//  Eko Devices
//
//  Created by Tyler Crouch on 7/7/17.
//
//

#import <UIKit/UIKit.h>

// NOTE: The scale (height/width) of an ECG signal is medically relevant. The graph here is verified to display ECG signal to the correct scale.
// Audio gain is arbitrary - adjust as you see fit.
// See this image to learn more about ECG scale: https://en.wikipedia.org/wiki/Electrocardiography#/media/File:ECG_Paper_v2.svg
// y axis: Every two large boxes equates to 1 mV of ECG signal amplitude
// x axis: Every single large box is .2 seconds in time. 5 boxes = 1 second.

@interface EDDataPlot : UIView

@property (nonatomic, assign) float duration;
@property (nonatomic, strong) UIColor* color;

@property (nonatomic, assign) unsigned int audioSampleRate;
@property (nonatomic, assign) unsigned int ECGSampleRate;

@property (nonatomic, assign) float audioGraphGain;

@property (nonatomic, assign) BOOL audioGraphHidden;
@property (nonatomic, assign) BOOL ECGGraphHidden;

// Update buffer
- (void) updateRollingPlotAudioPointBuffer: (short) audioAmplitude;

- (void) updateRollingPlotECGPointBuffer: (short) ECGAmplitude;

- (void) updateRollingPlotAudioPointBuffer: (short) audioAmplitude
                            ECGPointBuffer: (short) ECGAmplitude;

- (void) clear;

// Prepare to dealloc.
- (void) cleanUp;
- (void) setup;

@end
