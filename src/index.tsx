import Wfloat from './NativeWfloat';
import { readConfig } from './storage';

export type ModelName = "default_male"

export async function speech(modelName: ModelName, inputText: string): Promise<string> {
  const config = await readConfig()
  const modelEntry = config[modelName];
  if (!modelEntry) {
    throw new Error(`Voice model "${modelName}" is not loaded on the device. To load the voice, add function call: loadModel("${modelName}")`);
  }
  const result = Wfloat.speech(modelEntry.modelPath, inputText);
  return result;
}

export function playWav(filePath: string): string {
  return Wfloat.playWav(filePath);
}

export { loadModel, unloadModel, testStorage } from "./storage"