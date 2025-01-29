import Wfloat from './NativeWfloat';
// import ReactNativeBlobUtil from 'react-native-blob-util';

// export function multiply(a: number, b: number): number {
//   return Wfloat.multiply(a, b);
// }

// export function subtract(a: number, b: number): number {
//   return Wfloat.subtract(a, b);
// }

// export function testSherpaOnnx() {
//   return Wfloat.checkIfClassExists();
// }

export async function loadModel(modelName: string): Promise<string> {
  console.log(modelName);
  return Promise.resolve("foobar poop");
  // return ReactNativeBlobUtil
  //   .config({
  //     fileCache: true,  // enables file caching
  //   })
  //   .fetch('GET', 'https://registry.wfloat.com/repository/files/models/tempfile.txt', {
  //     // some headers ..
  //   })
  //   .then((res) => {
  //     console.log('The file saved to ', res.path());
  //     return res.path();  // returns the file path
  //   });
}


export function speech(inputText: string): string {
  const result = Wfloat.speech(inputText);
  return result;
}

export function playWav(filePath: string): string {
  return Wfloat.playWav(filePath);
}