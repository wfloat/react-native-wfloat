#import "Wfloat.h"
#import <AVFoundation/AVFoundation.h>
#import "sherpa-onnx.xcframework/Headers/sherpa-onnx/c-api/c-api.h"
#import "WfloatAudioStreamer.h"
//#import "react_native_wfloat-Swift.h"

// --- Global static instance for C callback ---
static Wfloat *g_self = nil;

int StreamingCallback(const float *samples, int32_t n, float /*progress*/) {
    if (g_self && samples && n > 0) {
      [(Wfloat *)g_self enqueueAudioSamples:samples length:n];
    }
    return 0;
}

@interface Wfloat () <AVAudioPlayerDelegate>
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@property (strong, nonatomic) WfloatAudioStreamer *audioStreamer;

- (void)enqueueAudioSamples:(const float *)samples length:(int32_t)n;
@end

@implementation Wfloat
RCT_EXPORT_MODULE()


#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeWfloatSpecJSI>(params);
}
#endif

- (void)enqueueAudioSamples:(const float *)samples length:(int32_t)n {
    NSData *pcmData = [NSData dataWithBytes:samples length:n * sizeof(float)];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.audioStreamer enqueuePCMData:pcmData];
    });
}

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

- (void)streamSpeech:(NSString *)modelPath inputText:(NSString *)inputText resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    g_self = self;
  
  NSString *espeakPath = @"espeak-ng-data";
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *dataDir = [bundle.resourceURL URLByAppendingPathComponent:espeakPath].path;
  
//  NSString *modelPathTest = getResourcePath(@"en_US-ryan-high.onnx");
  NSString *tokensPath = getResourcePath(@"tokens.txt");
  
  NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  NSString *resolvedModelPath = [documentsPath stringByAppendingPathComponent:modelPath];
  
      if (![[NSFileManager defaultManager] fileExistsAtPath:resolvedModelPath]) {
          reject(@"file_not_found", @"Model file not found", nil);
      }
  
  SherpaOnnxOfflineTtsConfig config;
  memset(&config, 0, sizeof(config));
  config.model.vits.model = [resolvedModelPath UTF8String];
  config.model.vits.tokens = [tokensPath UTF8String];
  config.model.vits.data_dir = [dataDir UTF8String];
  
  SherpaOnnxOfflineTts *tts = SherpaOnnxCreateOfflineTts(&config);
  
      // Prepare and start audio streamer
      if (!self.audioStreamer) {
          self.audioStreamer = [[WfloatAudioStreamer alloc] initWithSampleRate:22050];
      }
      [self.audioStreamer start];
  
      // Start TTS with chunk callback
      SherpaOnnxOfflineTtsGenerateWithProgressCallback(
          tts,
          [inputText UTF8String],
          0,      // speaker id
          1.0,    // speed
          StreamingCallback
      );
  
  // Use dispatch_after to delay the promise resolution
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      resolve(@"Speech synthesis completed.");
  });
  
  SherpaOnnxDestroyOfflineTts(tts);

//    resolve(@"junk string placeholder");
  
}


//- (void)streamSpeech:(NSString *)modelPath
//          inputText:(NSString *)inputText
//           resolver:(RCTPromiseResolveBlock)resolve
//           rejecter:(RCTPromiseRejectBlock)reject
//{
//    g_self = self;
//
//    NSString *espeakPath = @"espeak-ng-data";
//    NSBundle *bundle = [NSBundle mainBundle];
//    NSString *dataDir = [bundle.resourceURL URLByAppendingPathComponent:espeakPath].path;
//    NSString *tokensPath = getResourcePath(@"tokens.txt");
//
//    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
//    NSString *resolvedModelPath = [documentsPath stringByAppendingPathComponent:modelPath];
//
////    if (![[NSFileManager defaultManager] fileExistsAtPath:resolvedModelPath]) {
////        reject(@"file_not_found", @"Model file not found", nil);
////        return;
////    }
//
//    SherpaOnnxOfflineTtsConfig config;
//    memset(&config, 0, sizeof(config));
//    config.model.vits.model = [resolvedModelPath UTF8String];
//    config.model.vits.tokens = [tokensPath UTF8String];
//    config.model.vits.data_dir = [dataDir UTF8String];
//
//    SherpaOnnxOfflineTts *tts = SherpaOnnxCreateOfflineTts(&config);
//
//    // Prepare and start audio streamer
//    if (!self.audioStreamer) {
//        self.audioStreamer = [[WfloatAudioStreamer alloc] initWithSampleRate:16000];
//    }
//    [self.audioStreamer start];
//
//    // Start TTS with chunk callback
//    SherpaOnnxOfflineTtsGenerateWithProgressCallback(
//        tts,
//        [inputText UTF8String],
//        0,      // speaker id
//        1.0,    // speed
//        StreamingCallback
//    );
//
//    SherpaOnnxDestroyOfflineTts(tts);
//    resolve(@"streaming_started");
//}

@end
