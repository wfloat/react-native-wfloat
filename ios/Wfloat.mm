#import "Wfloat.h"
#import "sherpa-onnx.xcframework/Headers/sherpa-onnx/c-api/c-api.h"


/* Argument types ch``eatsheet
 * | Objective C                                   | JavaScript         |
 * |-----------------------------------------------|--------------------|
 * | NSString                                      | string, ?string    |
 * | BOOL                                          | boolean            |
 * | NSNumber                                      | ?boolean           |
 * | double                                        | number             |
 * | NSNumber                                      | ?number            |
 * | NSArray                                       | Array, ?Array      |
 * | NSDictionary                                  | Object, ?Object    |
 * | RCTResponseSenderBlock                        | Function (success) |
 * | RCTResponseSenderBlock, RCTResponseErrorBlock | Function (failure) |
 * | RCTPromiseResolveBlock, RCTPromiseRejectBlock | Promise            |
 */

@implementation Wfloat
RCT_EXPORT_MODULE()

- (NSNumber *)multiply:(double)a b:(double)b {
    NSNumber *result = @(a * b);

    return result;
}

- (NSNumber *)subtract:(double)a b:(double)b {
    NSNumber *result = @(a - b);

    return result;
}

- (SherpaOnnxOfflineTtsVitsModelConfig *)createTtsModelConfigWithModel:(NSString *)model
                                                               lexicon:(NSString *)lexicon
                                                               tokens:(NSString *)tokens
                                                              dataDir:(NSString *)dataDir
                                                           noiseScale:(float)noiseScale
                                                         noiseScaleW:(float)noiseScaleW
                                                         lengthScale:(float)lengthScale
                                                              dictDir:(NSString *)dictDir {
    SherpaOnnxOfflineTtsVitsModelConfig *config = new SherpaOnnxOfflineTtsVitsModelConfig();
    config->model = [self toCPointer:model];
    config->lexicon = [self toCPointer:lexicon];
    config->tokens = [self toCPointer:tokens];
    config->data_dir = [self toCPointer:(dataDir.length > 0 ? dataDir : @"")];
    config->noise_scale = noiseScale;
    config->noise_scale_w = noiseScaleW;
    config->length_scale = lengthScale;
    config->dict_dir = [self toCPointer:(dictDir.length > 0 ? dictDir : @"")];
    
    return config;
}

// Helper method to convert NSString to C strings
- (const char *)toCPointer:(NSString *)string {
    return [string UTF8String];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeWfloatSpecJSI>(params);
}

@end
