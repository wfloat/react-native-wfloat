import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  speech(modelPath: string, inputText: string): string;
  //   - (void)streamSpeech:(NSString *)modelPath
  //           inputText:(NSString *)inputText
  //            resolver:(RCTPromiseResolveBlock)resolve
  //            rejecter:(RCTPromiseRejectBlock)reject
  // {
  streamSpeech(modelPath: string, inputText: string): Promise<string>;
  playWav(filePath: string): string;
  // multiply(a: number, b: number): number;
  // subtract(a: number, b: number): number;
  // createTtsModelConfigWithModel(
  //   model: string,
  //   lexicon: string,
  //   tokens: string,
  //   dataDir: string,
  //   noiseScale: number,
  //   noiseScaleW: number,
  //   lengthScale: number,
  //   dictDir: string
  // ): number;
  // checkIfClassExists(): boolean;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Wfloat');
