//
//  EDWaveformAxesView.h
//  Eko Devices
//
//  Created by Eko Devices on 6/8/16.
//
//

#import <UIKit/UIKit.h>

static const float kWaveformXAxisInterval = .2f;

@interface EDWaveformAxesView : UIView

@property (nonatomic, assign) float duration;
@property (nonatomic, strong) UIColor* minorPlotLineColor;
@property (nonatomic, strong) UIColor* majorPlotLineColor;

@property (nonatomic, assign, readonly) CGSize majorGridLineSquareSize;

- (void) setup;

@end
