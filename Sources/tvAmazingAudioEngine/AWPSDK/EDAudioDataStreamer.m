//
//  EDAudioDataStreamer.m
//  Eko Devices
//
//  Created by Tyler Crouch on 4/17/19.
//  Copyright © 2019 Eko Devices. All rights reserved.
//

#import "EDAudioDataStreamer.h"

#import <EDBluetoothSDK/EDBluetooth.h>

@interface EDAudioDataStreamer () <EDPeripheralAuscultationDataDelegate>

@end

@implementation EDAudioDataStreamer

# pragma mark - Initialization

- (instancetype)init {
    return [self initWithAudioFilterChannel:EDAudioFilterChannelFilteredData audioResolution:1];
}

- (instancetype) initWithAudioFilterChannel: (EDAudioFilterChannel) audioFilterChannel audioResolution: (int) audioResolution{
    self = [super init];
    
    if (self) {
        [self setupWithAudioFilterChannel:audioFilterChannel audioResolution:audioResolution];
    }
    
    return self;
}

- (void) setupWithAudioFilterChannel: (EDAudioFilterChannel) audioFilterChannel audioResolution: (int) resolution {
    [[EDBluetooth sharedInstance] removePeripheralAuscultationDataDelegate:self];
    [[EDBluetooth sharedInstance] addPeripheralAuscultationDataDelegate:self audioFilterChannel:audioFilterChannel audioResolution:resolution];
}

# pragma mark - Bluetooth delegate

- (void) ekoPeripheralOutputtedAudioValue:(short)audioValue audioFilterChannel:(EDAudioFilterChannel)audioFilterChannel audioResolution:(short)audioResolution {
    [self outputAudioValue:audioValue audioFilterChannel:audioFilterChannel audioResolution:audioResolution];
}

- (void) ekoPeripheralOutputtedECGValue:(short)ECGValue audioValue:(short)audioValue audioFilterChannel:(EDAudioFilterChannel)audioFilterChannel audioResolution:(short)audioResolution {
    [self outputAudioValue:audioValue audioFilterChannel:audioFilterChannel audioResolution:audioResolution];
}

# pragma mark - Data output to delegates

- (void) outputAudioValue:(short)audioValue audioFilterChannel:(EDAudioFilterChannel)audioFilterChannel audioResolution:(short)audioResolution {
    if(self.delegate && [self.delegate respondsToSelector:@selector(dataStreamerOutputtedAudioValue:withAudioFilterChannel:audioResolution:)]){
        [self.delegate dataStreamerOutputtedAudioValue:audioValue withAudioFilterChannel:audioFilterChannel audioResolution:audioResolution];
    }
}

@end
