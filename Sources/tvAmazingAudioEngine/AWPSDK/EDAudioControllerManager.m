//
//  AudioControllerManager.m
//  Eko Devices
//
//  Created by Eko Devices on 9/8/16.
//
//

#import "EDAudioControllerManager.h"
#import "EDAudioDataStreamer.h"

// Audio
#import <TheAmazingAudioEngine/Modules/TPCircularBuffer/TPCircularBuffer.h>
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>
#import <AVFoundation/AVFoundation.h>

typedef struct
{
    int               maximumBufferSize;
    TPCircularBuffer  circularBuffer;
} DataHistoryInfo;

@interface EDAudioControllerManager () <EDAudioDataStreamerDelegate> {
    AEAudioController *audioController;
    DataHistoryInfo  *audioDataHistoryInfo;
    EDAudioDataStreamer *audioDataStreamer;
}

@property (nonatomic, strong) dispatch_queue_t timerQueue;

@end

@implementation EDAudioControllerManager

#pragma mark - Init
+ (EDAudioControllerManager*) sharedInstance {
    static id sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance =  [[self alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype) init {
    
    self = [super init];

    if (self) {
        _timerQueue = dispatch_queue_create("com.Eko.liveAudioQueue", DISPATCH_QUEUE_SERIAL);
        //dispatch_set_target_queue(_timerQueue, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
        [self initializeAudioControllerObjects];
    }
    
    return self;
}

# pragma mark - Buffer management

- (DataHistoryInfo *) dataHistoryInfoWithLength: (UInt32)maximumLength
{
    // defaultLength => Default history buffer length determines how many points are available in the buffer - the bufferSize.
    // maximumLength => Maximum length will allocate extra room in the circular buffer to allow you to go and dynamic change the bufferSize up to the specified upper limit.
    
    //
    // Setup buffers
    //
    DataHistoryInfo *historyInfo = (DataHistoryInfo *)malloc(sizeof(DataHistoryInfo));
    historyInfo-> maximumBufferSize = maximumLength;
    TPCircularBufferInit(&historyInfo->circularBuffer, maximumLength);
    
    //
    // Zero out circular buffer
    //
    short emptyBuffer[maximumLength];
    memset(emptyBuffer, 0, sizeof(short));
    TPCircularBufferProduceBytes(&historyInfo->circularBuffer,
                                 emptyBuffer,
                                 (int32_t)sizeof(emptyBuffer));
    
    return historyInfo;
}

- (void) clearHistoryInfo: (DataHistoryInfo *)historyInfo {
    TPCircularBufferClear(&historyInfo->circularBuffer);
}

# pragma mark - AAE Test

- (void) initializeAudioControllerObjects {
    // When just using static audio values (not real data) this functions nominally on iPhone 5 / iOS 8.4.1, iPhone 6s / iOS 9.3.1
    // Seems to build up latency a significant amount when user seperates iPhone from Eko Core (iPhone 6 / iOS 10.1)

    if(audioController || audioController.running){
        return;
    }
    
    __weak __typeof(self) weakSelf = self;

    // Initialize circular buffer
    dispatch_sync(_timerQueue, ^{
        if (weakSelf) {
            EDAudioControllerManager *strongSelf = weakSelf;
            strongSelf->audioDataHistoryInfo = [weakSelf dataHistoryInfoWithLength: 8192];
        }
    });
    
    // Initialize audio contoller
    AudioStreamBasicDescription audioDescription = [AEAudioController nonInterleaved16BitStereoAudioDescription];
    audioDescription.mSampleRate    = 8000;
    audioDescription.mBytesPerFrame  = 2;
    audioDescription.mBytesPerPacket = 2;
    audioDescription.mBitsPerChannel = 16;
    audioDescription.mFramesPerPacket = 1;
    //audioDescription.mChannelsPerFrame = 1;
    
    audioDataStreamer = [[EDAudioDataStreamer alloc] initWithAudioFilterChannel:EDAudioFilterChannelUpsampled8kHzAudioPlayerData audioResolution:1];
    audioDataStreamer.delegate = self;
    audioController = [[AEAudioController alloc] initWithAudioDescription:audioDescription];
    
    // Allow other apps to play audio when engine is online. Important if you want
    // app to play nice with other streaming apps like Zoom.
    audioController.allowMixingWithOtherApps = YES;
    audioController.enableBluetoothInput = NO;
    
    //_audioController.voiceProcessingEnabled = YES;
    //_audioController.useMeasurementMode = YES;// Automatically boosts gain
    audioController.preferredBufferDuration = 1/60.0f;

    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{
    AEBlockChannel * outputChannel = [AEBlockChannel channelWithBlock:^(const AudioTimeStamp *time,
                                                                        UInt32 frames,
                                                                        AudioBufferList *audio) {
        
        dispatch_sync(_timerQueue, ^{
            if (weakSelf) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                @autoreleasepool {
                    int32_t availableBytes;
                    short * audioBuffer = TPCircularBufferTail(&strongSelf->audioDataHistoryInfo->circularBuffer, &availableBytes);
                    int availableShorts = availableBytes / 2;
                    
                    BOOL cutBuffer = NO;
                    if(availableShorts > 1500){
                        cutBuffer = YES;
                        //NSLog(@"cut buffer");
                    }
                    
                    signed short value;
                    unsigned short numberOfPointsToOutput = !cutBuffer && frames > availableShorts ? availableShorts : frames;
                    
                    // test off sounds marginally better
                    for (int i = 0; i != numberOfPointsToOutput; i++ ) {
                        value = cutBuffer ? 0 : audioBuffer[i];
                        
                        // Max audio value ~4000, rustling or tapping on head of stethoscope is roughly double that
                        ((SInt16*)audio->mBuffers[0].mData)[i] = value;
                        ((SInt16*)audio->mBuffers[1].mData)[i] = value;
                    }
                    
                    if(cutBuffer){
                        TPCircularBufferConsume(&strongSelf->audioDataHistoryInfo->circularBuffer, (availableShorts * sizeof(short)));
                    }else{
                        TPCircularBufferConsume(&strongSelf->audioDataHistoryInfo->circularBuffer, (numberOfPointsToOutput * sizeof(short)));
                    }
                }
            }
        });
    }];
    outputChannel.audioDescription = audioDescription;
    
    if(!audioController.channels || ![audioController.channels containsObject:outputChannel]){
        [audioController addChannels:[NSArray arrayWithObject:outputChannel]];
    }
    
    outputChannel = nil;
    
    [self resetBuffer];
}

# pragma mark - Audio

- (void) startStreamingAudioToSpeaker {
    [self resetBuffer];
    
    if(!audioController){
        [self initializeAudioControllerObjects];
    }
    
    if(!audioController.running){
        NSError *error = NULL;
        BOOL result = [audioController start:&error];
    }
}

- (void) stopStreamingAudioToSpeaker {
    if(audioController && audioController.running){
        [audioController stop];
    }
}

- (void) resetBuffer {
    __weak __typeof(self) weakSelf = self;
    dispatch_sync(_timerQueue, ^{
        if (weakSelf) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf clearHistoryInfo:strongSelf->audioDataHistoryInfo];
        }
    });
}

- (void) addBufferValue: (short) value {
    if(![self isStreamingAudioToSpeaker]) {
        return; // Ignore inputs when not streaming to speaker.
    }
    
    __weak __typeof(self) weakSelf = self;
    dispatch_sync(_timerQueue, ^{
        if (weakSelf) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            TPCircularBufferProduceBytes(&strongSelf->audioDataHistoryInfo->circularBuffer, &value, 1 * sizeof(short));
        }
    });
}

- (BOOL) isStreamingAudioToSpeaker {
    return audioController && audioController.running;
}

- (void)dataStreamerOutputtedAudioValue:(short)audioValue withAudioFilterChannel:(EDAudioFilterChannel)audioFilterChannel audioResolution:(int)audioResolution {
    if(![self isStreamingAudioToSpeaker]) {
        return; // Ignore inputs when not streaming to speaker.
    }
    
    __weak __typeof(self) weakSelf = self;
    dispatch_sync(_timerQueue, ^{
        if (weakSelf) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            TPCircularBufferProduceBytes(&strongSelf->audioDataHistoryInfo->circularBuffer, &audioValue, 1 * sizeof(short));
        }
    });
}

@end
