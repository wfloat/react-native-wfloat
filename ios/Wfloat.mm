#import "Wfloat.h"
#import <AVFoundation/AVFoundation.h>
#import "sherpa-onnx.xcframework/Headers/sherpa-onnx/c-api/c-api.h"
//#import "react_native_wfloat-Swift.h"


@interface Wfloat () <AVAudioPlayerDelegate>
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@end

@implementation Wfloat

RCT_EXPORT_MODULE()

// - (NSNumber *)multiply:(double)a b:(double)b {
//     NSNumber *result = @(a * b);

//     return result;
// }

// - (NSNumber *)subtract:(double)a b:(double)b {
//     NSNumber *result = @(a - b);

//     return result;
// }

// // Expose the Swift testSpeech method to React Native
// RCT_EXPORT_METHOD(testSpeech:(NSInteger)a b:(NSInteger)b resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
//     @try {
//         // Call the Swift static method
//         NSInteger result = [Wfloat testSpeechWithA:a b:b];
//         resolve(@(result)); // Resolve the promise with the result
//     } @catch (NSException *exception) {
//         reject(@"testSpeech_error", exception.reason, nil); // Reject the promise with an error
//     }
// }

//RCT_REMAP_METHOD(add, addA:(NSInteger)a
//                        andB:(NSInteger)b
//                withResolver:(RCTPromiseResolveBlock) resolve
//                withRejecter:(RCTPromiseRejectBlock) reject)
//{
//  return [self add:a b:b resolve:resolve reject:reject];
//}

#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeWfloatSpecJSI>(params);
}
#endif

//- (void)add:(double)a b:(double)b resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
//  // NSNumber *result = @([Wfloat addWithA:a b:b]);
//  double sum = a + b;
//  NSNumber *result = [NSNumber numberWithDouble:sum];
//  resolve(result);
//}

NSString *getResourcePath(NSString *filename) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *fullPath = [bundle pathForResource:filename ofType:nil];
    return fullPath;
}

- (NSString *)speech:(NSString *)modelPath inputText:(NSString *)inputText {
  NSString *espeakPath = @"espeak-ng-data";
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *dataDir = [bundle.resourceURL URLByAppendingPathComponent:espeakPath].path;
  
//  NSString *modelPathTest = getResourcePath(@"en_US-ryan-high.onnx");
  NSString *tokensPath = getResourcePath(@"tokens.txt");
  
  NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  NSString *resolvedModelPath = [documentsPath stringByAppendingPathComponent:modelPath];

  if (![[NSFileManager defaultManager] fileExistsAtPath:resolvedModelPath]) {
      NSLog(@"Model file not found at path: %@", resolvedModelPath);
      return @"The file could not be found";
  }
  
//  return modelPathTest;
  
  SherpaOnnxOfflineTtsConfig config;
  memset(&config, 0, sizeof(config));
  config.model.vits.model = [resolvedModelPath UTF8String];
  config.model.vits.tokens = [tokensPath UTF8String];
  config.model.vits.data_dir = [dataDir UTF8String];
  
  SherpaOnnxOfflineTts *tts = SherpaOnnxCreateOfflineTts(&config);
  const SherpaOnnxGeneratedAudio *audio =
  SherpaOnnxOfflineTtsGenerate(tts, [inputText UTF8String], 0, 1.0);
  
  NSString *tempDirectoryPath = NSTemporaryDirectory();
  NSString *timestamp = [NSString stringWithFormat:@"%lld", (long long)[[NSDate date] timeIntervalSince1970]];
  NSString *filePath = [tempDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"audio_%@.wav", timestamp]];
  const char *filename = [filePath UTF8String];
  
  SherpaOnnxWriteWave(audio->samples, audio->n, audio->sample_rate, filename);

  SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
  SherpaOnnxDestroyOfflineTts(tts);
//  free((void *)filename);

  return filePath;
}

- (NSString *)playWav:(NSString *)filePath {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSError *error = nil;

    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
    
    if (error) {
        return [error localizedDescription];
    }

    [self.audioPlayer play];
    return @"success";
}

// - (NSString *)speech {
//     NSString *espeakPath = @"espeak-ng-data";
//     NSBundle *bundle = [NSBundle mainBundle];
//     NSURL *dataDirURL = [bundle.resourceURL URLByAppendingPathComponent:espeakPath];
//     NSString *afDictPath = [dataDirURL.path stringByAppendingPathComponent:@"af_dic"];

//     NSFileManager *fileManager = [NSFileManager defaultManager];
//     if ([fileManager fileExistsAtPath:afDictPath]) {
//         return @"yes";
//     } else {
//         return @"no";
//     }
// }

@end
