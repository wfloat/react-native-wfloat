import Wfloat from './NativeWfloat';
import ReactNativeBlobUtil, { type FetchBlobResponse } from 'react-native-blob-util'

type ModelName = "default_male"

async function downloadLargeFile(url: string): Promise<FetchBlobResponse> {
  const dirs = ReactNativeBlobUtil.fs.dirs
  const targetDir = `${dirs.DocumentDir}/react_native_wfloat`;

  const isDirExists = await ReactNativeBlobUtil.fs.exists(targetDir);
  if (!isDirExists) {
    await ReactNativeBlobUtil.fs.mkdir(targetDir);
  }

  return ReactNativeBlobUtil
    .config({
      path: `${targetDir}/default_male.onnx.json`,
      fileCache: true,  // enables file caching
    })
    .fetch('GET', url, {
      // some headers ..
    })
  // .then((res) => {
  //   return res;
  // })
}

export async function loadModel(modelName: ModelName): Promise<string> {
  const fileRegistryLocation = "https://registry.wfloat.com/repository/files/models/"
  if (modelName === "default_male") {
    const res = await downloadLargeFile(`${fileRegistryLocation}/default_male.onnx.json`)
    return res.path();
  } else if (!modelName) {
    throw new Error("Voice modelName is required.");
  } else {
    throw new Error(`Invalid voice modelName: ${modelName}.`);
  }
}

export function speech(inputText: string): string {
  const result = Wfloat.speech(inputText);
  return result;
}

export function playWav(filePath: string): string {
  return Wfloat.playWav(filePath);
}