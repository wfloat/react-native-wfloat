import type { TurboModule } from 'react-native';
import type { EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';
import { TurboModuleRegistry } from 'react-native';

export type LoadModelNativeOptions = {
  modelId: string;
  modelUrl: string;
  tokensUrl: string;
};

export type NativeLoadModelProgressEvent = {
  status: string;
  progress?: number;
};

export interface Spec extends TurboModule {
  loadModel(options: LoadModelNativeOptions): Promise<void>;
  readonly onLoadModelProgress: EventEmitter<NativeLoadModelProgressEvent>;
  speech(modelPath: string, inputText: string): string;
  streamSpeech(modelPath: string, inputText: string): Promise<string>;
  playWav(filePath: string): string;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Wfloat');
