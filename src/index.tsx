import Wfloat from './NativeWfloat';
import { enforceAudioOutputLimit, PushAudioOutput, readConfig } from './storage';

export type ModelName = "default_male" | "en_US-ryan-medium"

export async function speech(modelName: ModelName, inputText: string): Promise<string> {
  const config = await readConfig()
  const modelEntry = config.models[modelName];
  if (!modelEntry) {
    throw new Error(`Voice model "${modelName}" is not loaded on the device. To load the voice, add function call: loadModel("${modelName}")`);
  }
  const result = Wfloat.speech(modelEntry.modelPath, inputText);
  await PushAudioOutput(result);
  await enforceAudioOutputLimit();
  return result;
}

export async function streamSpeech(modelName: ModelName, inputText: string): Promise<string> {
  const config = await readConfig()
  const modelEntry = config.models[modelName];
  if (!modelEntry) {
    throw new Error(`Voice model "${modelName}" is not loaded on the device. To load the voice, add function call: loadModel("${modelName}")`);
  }
  const result = Wfloat.streamSpeech(modelEntry.modelPath, inputText);
  // return "fake success on stream";
  return result;
}

export function playWav(filePath: string): string {
  return Wfloat.playWav(filePath);
}

export { loadModel, unloadModel, testStorage } from "./storage"