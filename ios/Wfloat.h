#import <Foundation/Foundation.h>

#ifdef RCT_NEW_ARCH_ENABLED

#import "generated/RNWfloatSpec/RNWfloatSpec.h"
@interface Wfloat : NSObject <NativeWfloatSpec>

#else

#import <React/RCTBridgeModule.h>
@interface Wfloat : NSObject <RCTBridgeModule>

#endif

- (void)enqueueAudioSamples:(const float *)samples length:(int32_t)n;

@end
