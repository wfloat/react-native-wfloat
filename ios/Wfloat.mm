#import "Wfloat.h"
#import <AVFoundation/AVFoundation.h>
#import <sherpa-onnx/c-api/c-api.h>
#import "WfloatAudioStreamer.h"
//#import "react_native_wfloat-Swift.h"

// --- Global static instance for C callback ---
static Wfloat *g_self = nil;

int StreamingCallback(const float *samples, int32_t n, float p) {
  printf("Progress: %.2f, Num Samples: %d\n", p, n);
    if (g_self && samples && n > 0) {
      [(Wfloat *)g_self enqueueAudioSamples:samples length:n];
    }
    return 1;
}

@interface Wfloat () <AVAudioPlayerDelegate>
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@property (strong, nonatomic) WfloatAudioStreamer *audioStreamer;
//@property (nonatomic) const SherpaOnnxOfflineTts *tts;
@property (nonatomic, assign) const SherpaOnnxOfflineTts *tts;
@property (nonatomic, copy) NSString *loadedModelPath;

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

- (void)dealloc {
    if (self.tts) {
        SherpaOnnxDestroyOfflineTts(self.tts);
        self.tts = nil;
    }
}

- (BOOL)loadModelIfNeeded:(NSString *)modelPath tokensPath:(NSString *)tokensPath dataDir:(NSString *)dataDir error:(NSError **)error {
//    if (self.tts && [self.loadedModelPath isEqualToString:modelPath]) {
  if (self.tts) {
        return YES; // Already loaded
    }

//    if (self.tts) {
//        SherpaOnnxDestroyOfflineTts(self.tts);
//        self.tts = nil;
//    }

    SherpaOnnxOfflineTtsConfig config;
    memset(&config, 0, sizeof(config));
    config.model.vits.model = [modelPath UTF8String];
    config.model.vits.tokens = [tokensPath UTF8String];
    config.model.vits.data_dir = [dataDir UTF8String];

    self.tts = SherpaOnnxCreateOfflineTts(&config);
    if (!self.tts) {
        if (error) {
            *error = [NSError errorWithDomain:@"WfloatErrorDomain" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to initialize TTS model"}];
        }
        return NO;
    }

    self.loadedModelPath = modelPath;
    return YES;
}

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
  NSString *tokensPath = getResourcePath(@"tokens.txt");
  NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  NSString *resolvedModelPath = [documentsPath stringByAppendingPathComponent:modelPath];

  if (![[NSFileManager defaultManager] fileExistsAtPath:resolvedModelPath]) {
      NSLog(@"Model file not found at path: %@", resolvedModelPath);
      return @"The file could not be found";
  }

  NSError *loadError = nil;
  if (![self loadModelIfNeeded:resolvedModelPath tokensPath:tokensPath dataDir:dataDir error:&loadError]) {
      return loadError.localizedDescription;
  }
  const SherpaOnnxGeneratedAudio *audio =
  SherpaOnnxOfflineTtsGenerate(self.tts, [inputText UTF8String], 0, 1.0);
  
  NSString *tempDirectoryPath = NSTemporaryDirectory();
  NSString *timestamp = [NSString stringWithFormat:@"%lld", (long long)[[NSDate date] timeIntervalSince1970]];
  NSString *filePath = [tempDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"audio_%@.wav", timestamp]];
  const char *filename = [filePath UTF8String];
  
  SherpaOnnxWriteWave(audio->samples, audio->n, audio->sample_rate, filename);

  SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
//  SherpaOnnxDestroyOfflineTts(tts);
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

- (NSString *)streamSpeech:(NSString *)modelPath inputText:(NSString *)inputText resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    g_self = self;

    NSString *espeakPath = @"espeak-ng-data";
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *dataDir = [bundle.resourceURL URLByAppendingPathComponent:espeakPath].path;
    NSString *tokensPath = getResourcePath(@"tokens.txt");
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *resolvedModelPath = [documentsPath stringByAppendingPathComponent:modelPath];

    if (![[NSFileManager defaultManager] fileExistsAtPath:resolvedModelPath]) {
        reject(@"file_not_found", @"Model file not found", nil);
        return @"Model not found";
    }

    NSError *loadError = nil;
    if (![self loadModelIfNeeded:resolvedModelPath tokensPath:tokensPath dataDir:dataDir error:&loadError]) {
        reject(@"load_failed", loadError.localizedDescription, nil);
      return @"Failed to load the tts model";
    }

    if (!self.audioStreamer) {
      // TODO: use SherpaOnnxOfflineTtsSampleRate
        self.audioStreamer = [[WfloatAudioStreamer alloc] initWithSampleRate:22050];
    }
    [self.audioStreamer start];

  const SherpaOnnxGeneratedAudio *audio = SherpaOnnxOfflineTtsGenerateWithProgressCallback(
        self.tts,
        [inputText UTF8String],
        0,      // speaker id
        1.0,    // speed
        StreamingCallback
    );
  
  NSString *tempDirectoryPath = NSTemporaryDirectory();
  NSString *timestamp = [NSString stringWithFormat:@"%lld", (long long)[[NSDate date] timeIntervalSince1970]];
  NSString *filePath = [tempDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"audio_%@.wav", timestamp]];
  const char *filename = [filePath UTF8String];
  
  SherpaOnnxWriteWave(audio->samples, audio->n, audio->sample_rate, filename);
  SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
  printf("hello there I am at the end of the stream function. File saved at: %s\n", filename);
  return filePath;
}


@end
