import type { TurboModule } from 'react-native';
import type { EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';
import { TurboModuleRegistry } from 'react-native';

export type LoadModelNativeOptions = {
  modelId: string;
  modelUrl: string;
  tokensUrl: string;
  espeakDataUrl: string;
  espeakChecksum: string;
};

export type GenerateNativeOptions = {
  requestId: number;
  text: string;
  sid: number;
  emotion: string;
  intensity: number;
  speed: number;
  silencePaddingSec: number;
};

export type NativeLoadModelProgressEvent = {
  status: string;
  progress?: number;
};

export type NativeSpeechProgressEvent = {
  requestId: number;
  progress: number;
  isPlaying: boolean;
  textHighlightStart: number;
  textHighlightEnd: number;
  text: string;
};

export type NativeSpeechPlaybackFinishedEvent = {
  requestId: number;
};

export interface Spec extends TurboModule {
  loadModel(options: LoadModelNativeOptions): Promise<void>;
  generate(options: GenerateNativeOptions): Promise<void>;
  play(): Promise<void>;
  pause(): Promise<void>;
  readonly onLoadModelProgress: EventEmitter<NativeLoadModelProgressEvent>;
  readonly onSpeechProgress: EventEmitter<NativeSpeechProgressEvent>;
  readonly onSpeechPlaybackFinished: EventEmitter<NativeSpeechPlaybackFinishedEvent>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('Wfloat');
