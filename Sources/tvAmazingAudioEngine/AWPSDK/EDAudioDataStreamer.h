//
//  EDAudioDataStreamer.h
//  Eko Devices
//
//  Created by Tyler Crouch on 4/17/19.
//  Copyright © 2019 Eko Devices. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <EDBluetoothSDK/EDBluetoothSDK.h>

@protocol EDAudioDataStreamerDelegate <NSObject>

@optional
- (void) dataStreamerOutputtedAudioValue: (short) audioValue withAudioFilterChannel: (EDAudioFilterChannel) audioFilterChannel audioResolution: (int) audioResolution;
@end

@interface EDAudioDataStreamer : NSObject

@property (nonatomic, weak) id<EDAudioDataStreamerDelegate> delegate;

- (instancetype) initWithAudioFilterChannel: (EDAudioFilterChannel) audioFilterChannel audioResolution: (int) audioResolution;
- (void) setupWithAudioFilterChannel: (EDAudioFilterChannel) audioFilterChannel audioResolution: (int) audioResolution;

@end


