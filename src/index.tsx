import Wfloat from './NativeWfloat';
import ReactNativeBlobUtil, { type FetchBlobResponse } from 'react-native-blob-util'
import { CONFIG_FILE_PATH, isModelLoaded, updateLoadedModelEntry } from './storage';

export type ModelName = "default_male"

export function speech(inputText: string): string {
  const result = Wfloat.speech(inputText);
  return result;
}

export function playWav(filePath: string): string {
  return Wfloat.playWav(filePath);
}