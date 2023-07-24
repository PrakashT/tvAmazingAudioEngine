//
//  AudioControllerManager.h
//  Eko Devices
//
//  Created by Eko Devices on 9/8/16.
//
//

#import <Foundation/Foundation.h>

@interface EDAudioControllerManager : NSObject

+ (EDAudioControllerManager*) sharedInstance;

- (void) startStreamingAudioToSpeaker;
- (void) stopStreamingAudioToSpeaker;
- (void) resetBuffer;

- (BOOL) isStreamingAudioToSpeaker;

@end
