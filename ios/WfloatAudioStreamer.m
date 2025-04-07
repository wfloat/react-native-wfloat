#import "WfloatAudioStreamer.h"

@interface WfloatAudioStreamer ()
@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) AVAudioPlayerNode *playerNode;
@property (nonatomic, strong) AVAudioFormat *audioFormat;
@property (nonatomic, assign) BOOL isStarted;
@end

@implementation WfloatAudioStreamer

- (instancetype)initWithSampleRate:(int)sampleRate {
    self = [super init];
    if (self) {
        _engine = [[AVAudioEngine alloc] init];
        _playerNode = [[AVAudioPlayerNode alloc] init];
        _audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                         sampleRate:sampleRate
                                                           channels:1
                                                        interleaved:YES];

        [_engine attachNode:_playerNode];
        [_engine connect:_playerNode to:_engine.mainMixerNode format:_audioFormat];
        _isStarted = NO;
    }
    return self;
}

- (void)start {
    if (!_isStarted) {
        NSError *error = nil;
        [_engine startAndReturnError:&error];
        if (!error) {
            [_playerNode play];
            _isStarted = YES;
        } else {
            NSLog(@"Audio engine failed: %@", error);
        }
    }
}

- (void)stop {
    [_playerNode stop];
    [_engine stop];
    _isStarted = NO;
}

- (void)enqueuePCMData:(NSData *)pcmData {
    if (!_isStarted) [self start];
    
    UInt32 frameCount = (UInt32)(pcmData.length / sizeof(float));
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_audioFormat frameCapacity:frameCount];
    buffer.frameLength = frameCount;

    memcpy(buffer.floatChannelData[0], pcmData.bytes, pcmData.length);
    [_playerNode scheduleBuffer:buffer completionHandler:nil];
}

@end
