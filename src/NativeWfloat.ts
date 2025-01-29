import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  speech(inputText: string): string;
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
