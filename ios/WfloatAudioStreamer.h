#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface WfloatAudioStreamer : NSObject

- (instancetype)initWithSampleRate:(int)sampleRate;
- (void)start;
- (void)stop;
- (void)enqueuePCMData:(NSData *)pcmData;

@end