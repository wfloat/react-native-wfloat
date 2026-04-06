#import "Wfloat.h"
#import <AVFoundation/AVFoundation.h>
#import <sherpa-onnx/c-api/c-api.h>
#import "WfloatAudioStreamer.h"

typedef NS_ENUM(NSInteger, WfloatLoadModelDownloadPhase) {
  WfloatLoadModelDownloadPhaseNone = 0,
  WfloatLoadModelDownloadPhaseModel = 1,
  WfloatLoadModelDownloadPhaseTokens = 2,
};

static NSString *const WfloatErrorDomain = @"WfloatErrorDomain";
static Wfloat *g_self = nil;

int StreamingCallback(const float *samples, int32_t n, float p) {
  printf("Progress: %.2f, Num Samples: %d\n", p, n);
  if (g_self && samples && n > 0) {
    [(Wfloat *)g_self enqueueAudioSamples:samples length:n];
  }
  return 1;
}

static NSString *WfloatPathForBundledResource(NSString *resourceName) {
  NSArray<NSBundle *> *candidateBundles = @[
    [NSBundle bundleForClass:[Wfloat class]],
    [NSBundle mainBundle],
  ];

  for (NSBundle *bundle in candidateBundles) {
    NSString *path = [bundle pathForResource:resourceName ofType:nil];
    if (path.length > 0) {
      return path;
    }
  }

  return nil;
}

static NSString *WfloatCacheRootDirectory(void) {
  NSArray<NSString *> *paths =
      NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *cacheDirectory = paths.firstObject ?: NSTemporaryDirectory();
  return [cacheDirectory stringByAppendingPathComponent:@"wfloat/models"];
}

static NSString *WfloatSanitizePathComponent(NSString *value) {
  return [[value stringByReplacingOccurrencesOfString:@"/" withString:@"_"]
      stringByReplacingOccurrencesOfString:@":" withString:@"_"];
}

@interface Wfloat () <AVAudioPlayerDelegate, NSURLSessionDownloadDelegate>
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@property (strong, nonatomic) WfloatAudioStreamer *audioStreamer;
@property (nonatomic, assign) const SherpaOnnxOfflineTts *tts;
@property (nonatomic, copy) NSString *loadedModelPath;
@property (nonatomic, copy) NSString *loadedTokensPath;
@property (nonatomic, copy) NSString *loadedModelId;
@property (strong, nonatomic) NSURLSession *loadModelSession;
@property (nonatomic, copy) RCTPromiseResolveBlock loadModelResolve;
@property (nonatomic, copy) RCTPromiseRejectBlock loadModelReject;
@property (nonatomic, copy) NSString *pendingModelId;
@property (nonatomic, copy) NSString *pendingModelURLString;
@property (nonatomic, copy) NSString *pendingTokensURLString;
@property (nonatomic, copy) NSString *pendingModelPath;
@property (nonatomic, copy) NSString *pendingTokensPath;
@property (nonatomic, copy) NSString *currentDownloadDestinationPath;
@property (nonatomic, assign) WfloatLoadModelDownloadPhase currentDownloadPhase;
@property (nonatomic, assign) BOOL pendingNeedsModelDownload;
@property (nonatomic, assign) BOOL pendingNeedsTokensDownload;
@property (nonatomic, assign) BOOL plannedModelDownload;
@property (nonatomic, assign) BOOL plannedTokensDownload;
@property (nonatomic, assign) float lastEmittedDownloadProgress;

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

  [self.loadModelSession invalidateAndCancel];
}

- (BOOL)ensureDirectoryExistsAtPath:(NSString *)path error:(NSError **)error {
  return [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:error];
}

- (NSString *)cacheDirectoryForModelId:(NSString *)modelId {
  NSString *sanitizedModelId = WfloatSanitizePathComponent(modelId);
  return [WfloatCacheRootDirectory() stringByAppendingPathComponent:sanitizedModelId];
}

- (void)emitLoadModelProgressWithStatus:(NSString *)status progress:(NSNumber *)progress {
#ifdef RCT_NEW_ARCH_ENABLED
  NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObject:status forKey:@"status"];
  if (progress != nil) {
    event[@"progress"] = progress;
  }
  [self emitOnLoadModelProgress:event];
#else
  (void)status;
  (void)progress;
#endif
}

- (void)clearPendingLoadModelState {
  [self.loadModelSession invalidateAndCancel];
  self.loadModelSession = nil;
  self.loadModelResolve = nil;
  self.loadModelReject = nil;
  self.pendingModelId = nil;
  self.pendingModelURLString = nil;
  self.pendingTokensURLString = nil;
  self.pendingModelPath = nil;
  self.pendingTokensPath = nil;
  self.currentDownloadDestinationPath = nil;
  self.currentDownloadPhase = WfloatLoadModelDownloadPhaseNone;
  self.pendingNeedsModelDownload = NO;
  self.pendingNeedsTokensDownload = NO;
  self.plannedModelDownload = NO;
  self.plannedTokensDownload = NO;
  self.lastEmittedDownloadProgress = -1;
}

- (void)rejectPendingLoadModelWithCode:(NSString *)code
                               message:(NSString *)message
                                 error:(NSError *)error {
  RCTPromiseRejectBlock reject = self.loadModelReject;
  [self clearPendingLoadModelState];
  if (reject) {
    reject(code, message, error);
  }
}

- (void)resolvePendingLoadModel {
  RCTPromiseResolveBlock resolve = self.loadModelResolve;
  [self clearPendingLoadModelState];
  if (resolve) {
    resolve(nil);
  }
}

- (NSString *)fileNameFromURLString:(NSString *)urlString error:(NSError **)error {
  NSURL *url = [NSURL URLWithString:urlString];
  NSString *fileName = url.lastPathComponent;
  if (fileName.length > 0) {
    return fileName;
  }

  if (error) {
    *error = [NSError errorWithDomain:WfloatErrorDomain
                                 code:100
                             userInfo:@{NSLocalizedDescriptionKey : @"Invalid model asset URL"}];
  }
  return nil;
}

- (BOOL)loadTtsWithModelPath:(NSString *)modelPath
                  tokensPath:(NSString *)tokensPath
                     dataDir:(NSString *)dataDir
                     modelId:(NSString *)modelId
                       error:(NSError **)error {
  if (self.tts && [self.loadedModelPath isEqualToString:modelPath] &&
      [self.loadedTokensPath isEqualToString:tokensPath]) {
    return YES;
  }

  SherpaOnnxOfflineTtsConfig config;
  memset(&config, 0, sizeof(config));
  config.model.wfloat.model = [modelPath UTF8String];
  config.model.wfloat.tokens = [tokensPath UTF8String];
  config.model.wfloat.data_dir = [dataDir UTF8String];
  config.model.wfloat.noise_scale = 0.667f;
  config.model.wfloat.noise_scale_w = 0.8f;
  config.model.wfloat.length_scale = 1.0f;
  config.model.num_threads = 1;
  config.model.debug = 0;
  config.model.provider = "cpu";
  config.max_num_sentences = 1;
  config.silence_scale = 0.2f;

  const SherpaOnnxOfflineTts *newTts = SherpaOnnxCreateOfflineTts(&config);
  if (!newTts) {
    if (error) {
      *error = [NSError errorWithDomain:WfloatErrorDomain
                                   code:101
                               userInfo:@{
                                NSLocalizedDescriptionKey : @"Failed to initialize TTS model",
                               }];
    }
    return NO;
  }

  if (self.tts) {
    SherpaOnnxDestroyOfflineTts(self.tts);
  }

  self.tts = newTts;
  self.loadedModelId = modelId;
  self.loadedModelPath = modelPath;
  self.loadedTokensPath = tokensPath;
  return YES;
}

- (void)cleanupStaleFilesInDirectory:(NSString *)directoryPath
                    activeFileNames:(NSSet<NSString *> *)activeFileNames {
  NSError *contentsError = nil;
  NSArray<NSString *> *fileNames =
      [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:&contentsError];
  if (contentsError || fileNames.count == 0) {
    return;
  }

  for (NSString *fileName in fileNames) {
    if ([activeFileNames containsObject:fileName]) {
      continue;
    }

    if (![fileName hasSuffix:@".onnx"] && ![fileName hasSuffix:@"_tokens.txt"]) {
      continue;
    }

    NSString *path = [directoryPath stringByAppendingPathComponent:fileName];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
  }
}

- (double)overallProgressForPhaseProgress:(double)phaseProgress {
  double clampedPhaseProgress = MIN(MAX(phaseProgress, 0), 1);
  if (self.plannedModelDownload && self.plannedTokensDownload) {
    if (self.currentDownloadPhase == WfloatLoadModelDownloadPhaseModel) {
      return clampedPhaseProgress * 0.95;
    }

    if (self.currentDownloadPhase == WfloatLoadModelDownloadPhaseTokens) {
      return 0.95 + (clampedPhaseProgress * 0.05);
    }
  }

  return clampedPhaseProgress;
}

- (void)emitDownloadProgress:(double)phaseProgress {
  double overallProgress = [self overallProgressForPhaseProgress:phaseProgress];
  if (fabsf(self.lastEmittedDownloadProgress - overallProgress) < 0.01f &&
      overallProgress < 1.0f) {
    return;
  }

  self.lastEmittedDownloadProgress = overallProgress;
  [self emitLoadModelProgressWithStatus:@"downloading" progress:@(overallProgress)];
}

- (void)finishPendingLoadModel {
  NSString *dataDir = WfloatPathForBundledResource(@"espeak-ng-data");
  if (dataDir.length == 0) {
    [self rejectPendingLoadModelWithCode:@"missing_resources"
                                 message:@"espeak-ng-data resource bundle is missing."
                                   error:nil];
    return;
  }

  [self emitLoadModelProgressWithStatus:@"loading" progress:nil];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *loadError = nil;
    BOOL didLoad = [self loadTtsWithModelPath:self.pendingModelPath
                                   tokensPath:self.pendingTokensPath
                                      dataDir:dataDir
                                      modelId:self.pendingModelId
                                        error:&loadError];

    dispatch_async(dispatch_get_main_queue(), ^{
      if (!didLoad) {
        [self rejectPendingLoadModelWithCode:@"load_failed"
                                     message:loadError.localizedDescription ?: @"Failed to load model."
                                       error:loadError];
        return;
      }

      NSString *directoryPath = [self.pendingModelPath stringByDeletingLastPathComponent];
      NSSet<NSString *> *activeFileNames = [NSSet setWithObjects:
                                                           self.pendingModelPath.lastPathComponent,
                                                           self.pendingTokensPath.lastPathComponent,
                                                           nil];
      [self cleanupStaleFilesInDirectory:directoryPath activeFileNames:activeFileNames];
      [self emitLoadModelProgressWithStatus:@"completed" progress:nil];
      [self resolvePendingLoadModel];
    });
  });
}

- (void)startDownloadFromURLString:(NSString *)urlString
                   destinationPath:(NSString *)destinationPath
                             phase:(WfloatLoadModelDownloadPhase)phase {
  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) {
    [self rejectPendingLoadModelWithCode:@"invalid_url" message:@"Invalid model asset URL." error:nil];
    return;
  }

  if (!self.loadModelSession) {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSOperationQueue *delegateQueue = [[NSOperationQueue alloc] init];
    delegateQueue.maxConcurrentOperationCount = 1;
    self.loadModelSession = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:self
                                                     delegateQueue:delegateQueue];
  }

  self.currentDownloadPhase = phase;
  self.currentDownloadDestinationPath = destinationPath;
  self.lastEmittedDownloadProgress = -1;
  [self emitDownloadProgress:0];

  NSURLSessionDownloadTask *task = [self.loadModelSession downloadTaskWithURL:url];
  [task resume];
}

- (void)startNextPendingDownloadStep {
  if (self.pendingNeedsModelDownload) {
    [self startDownloadFromURLString:self.pendingModelURLString
                     destinationPath:self.pendingModelPath
                               phase:WfloatLoadModelDownloadPhaseModel];
    return;
  }

  if (self.pendingNeedsTokensDownload) {
    [self startDownloadFromURLString:self.pendingTokensURLString
                     destinationPath:self.pendingTokensPath
                               phase:WfloatLoadModelDownloadPhaseTokens];
    return;
  }

  [self finishPendingLoadModel];
}

- (void)loadModel:(JS::NativeWfloat::LoadModelNativeOptions &)options
          resolve:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject {
  if (self.loadModelResolve != nil || self.loadModelReject != nil) {
    reject(@"load_in_progress", @"A loadModel operation is already in progress.", nil);
    return;
  }

  NSString *modelId = options.modelId();
  NSString *modelURLString = options.modelUrl();
  NSString *tokensURLString = options.tokensUrl();
  if (modelId.length == 0 || modelURLString.length == 0 || tokensURLString.length == 0) {
    reject(@"invalid_arguments", @"modelId, modelUrl, and tokensUrl are required.", nil);
    return;
  }

  NSError *pathError = nil;
  NSString *modelFileName = [self fileNameFromURLString:modelURLString error:&pathError];
  NSString *tokensFileName = [self fileNameFromURLString:tokensURLString error:&pathError];
  if (pathError) {
    reject(@"invalid_url", pathError.localizedDescription, pathError);
    return;
  }

  NSString *directoryPath = [self cacheDirectoryForModelId:modelId];
  if (![self ensureDirectoryExistsAtPath:directoryPath error:&pathError]) {
    reject(@"filesystem_error", pathError.localizedDescription, pathError);
    return;
  }

  NSString *modelPath = [directoryPath stringByAppendingPathComponent:modelFileName];
  NSString *tokensPath = [directoryPath stringByAppendingPathComponent:tokensFileName];

  self.loadModelResolve = resolve;
  self.loadModelReject = reject;
  self.pendingModelId = modelId;
  self.pendingModelURLString = modelURLString;
  self.pendingTokensURLString = tokensURLString;
  self.pendingModelPath = modelPath;
  self.pendingTokensPath = tokensPath;
  self.pendingNeedsModelDownload = ![[NSFileManager defaultManager] fileExistsAtPath:modelPath];
  self.pendingNeedsTokensDownload = ![[NSFileManager defaultManager] fileExistsAtPath:tokensPath];
  self.plannedModelDownload = self.pendingNeedsModelDownload;
  self.plannedTokensDownload = self.pendingNeedsTokensDownload;
  self.currentDownloadPhase = WfloatLoadModelDownloadPhaseNone;
  self.lastEmittedDownloadProgress = -1;

  [self startNextPendingDownloadStep];
}

- (void)enqueueAudioSamples:(const float *)samples length:(int32_t)n {
  NSData *pcmData = [NSData dataWithBytes:samples length:n * sizeof(float)];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.audioStreamer enqueuePCMData:pcmData];
  });
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didWriteData:(int64_t)bytesWritten
totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  (void)session;
  (void)downloadTask;
  if (totalBytesExpectedToWrite <= 0) {
    return;
  }

  double phaseProgress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
  [self emitDownloadProgress:phaseProgress];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
  (void)session;
  (void)downloadTask;

  NSError *fileError = nil;
  NSString *destinationPath = self.currentDownloadDestinationPath;
  if (destinationPath.length == 0) {
    [self rejectPendingLoadModelWithCode:@"filesystem_error"
                                 message:@"Missing download destination path."
                                   error:nil];
    return;
  }

  [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
  if (![[NSFileManager defaultManager] moveItemAtURL:location
                                               toURL:[NSURL fileURLWithPath:destinationPath]
                                               error:&fileError]) {
    [self rejectPendingLoadModelWithCode:@"filesystem_error"
                                 message:fileError.localizedDescription ?: @"Failed to save download."
                                   error:fileError];
    return;
  }

  if (self.currentDownloadPhase == WfloatLoadModelDownloadPhaseModel) {
    self.pendingNeedsModelDownload = NO;
  } else if (self.currentDownloadPhase == WfloatLoadModelDownloadPhaseTokens) {
    self.pendingNeedsTokensDownload = NO;
  }

  self.currentDownloadDestinationPath = nil;
  [self startNextPendingDownloadStep];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
  (void)session;
  (void)task;
  if (!error) {
    return;
  }

  [self rejectPendingLoadModelWithCode:@"download_failed"
                               message:error.localizedDescription ?: @"Failed to download model assets."
                                 error:error];
}

- (NSString *)speech:(NSString *)modelPath inputText:(NSString *)inputText {
  (void)modelPath;
  if (!self.tts) {
    return @"SpeechClient.loadModel(...) must be called before speech().";
  }

  const SherpaOnnxGeneratedAudio *audio =
      SherpaOnnxOfflineTtsGenerate(self.tts, [inputText UTF8String], 0, 1.0);

  NSString *tempDirectoryPath = NSTemporaryDirectory();
  NSString *timestamp =
      [NSString stringWithFormat:@"%lld", (long long)[[NSDate date] timeIntervalSince1970]];
  NSString *filePath = [tempDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"audio_%@.wav", timestamp]];
  const char *filename = [filePath UTF8String];

  SherpaOnnxWriteWave(audio->samples, audio->n, audio->sample_rate, filename);
  SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
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

- (void)streamSpeech:(NSString *)modelPath
           inputText:(NSString *)inputText
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject {
  (void)modelPath;
  if (!self.tts) {
    reject(@"model_not_loaded", @"SpeechClient.loadModel(...) must be called before streamSpeech().", nil);
    return;
  }

  g_self = self;
  if (!self.audioStreamer) {
    self.audioStreamer =
        [[WfloatAudioStreamer alloc] initWithSampleRate:SherpaOnnxOfflineTtsSampleRate(self.tts)];
  } else {
    [self.audioStreamer stop];
    self.audioStreamer =
        [[WfloatAudioStreamer alloc] initWithSampleRate:SherpaOnnxOfflineTtsSampleRate(self.tts)];
  }

  [self.audioStreamer start];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    const SherpaOnnxGeneratedAudio *audio = SherpaOnnxOfflineTtsGenerateWithProgressCallback(
        self.tts,
        [inputText UTF8String],
        0,
        1.0,
        StreamingCallback);

    NSString *tempDirectoryPath = NSTemporaryDirectory();
    NSString *timestamp =
        [NSString stringWithFormat:@"%lld", (long long)[[NSDate date] timeIntervalSince1970]];
    NSString *filePath = [tempDirectoryPath
        stringByAppendingPathComponent:[NSString stringWithFormat:@"audio_%@.wav", timestamp]];
    const char *filename = [filePath UTF8String];

    SherpaOnnxWriteWave(audio->samples, audio->n, audio->sample_rate, filename);
    SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);

    dispatch_async(dispatch_get_main_queue(), ^{
      resolve(filePath);
    });
  });
}

@end
