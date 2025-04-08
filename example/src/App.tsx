import { Text, View, StyleSheet, Button } from 'react-native';
import { speech, playWav, loadModel, unloadModel, testStorage, streamSpeech } from '@wfloat/react-native-wfloat';

const playSound = async () => {
  try {
    // const text = "Implementing a super epic duper VITS with streaming capabilities on iOS is feasible but requires custom development. VITS, originally a non-streaming text-to-speech model, has been adapted for streaming in projects like VITS Server, which supports fast inference and streaming capabilities. However, integrating such a server-based solution into an iOS app would involve setting up a backend server to handle the TTS processing and streaming the generated audio to the iOS device." // hellooooo hi world this is going to be a looong sentence let's see if it fails. Is a realistic text and i am messing with it";
    const text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    // const words = text.split(" ");
    // const randomLength = Math.floor(Math.random() * words.length) + 1;
    // const randomText = words.slice(0, randomLength).join(" ");

    // console.log("random text", randomText);

    const startTime = Date.now();
    const newSound = await speech("en_US-ryan-medium", text);
    const endTime = Date.now();

    console.log(`runtime is ${endTime - startTime}ms`);
    console.log(newSound);
    playWav(newSound);
  } catch (error) {
    console.error(error);
  }
};

const streamAudio = async () => {
  try {
    // const text = "Hello there Dubfloat. Wfloat is a realistic text. Anyway now you know. Auuuh, Peace out!";
    const text = "Implementing a super duper VITS with streaming capabilities on iOS is feasible but requires custom development. VITS, originally a non-streaming text-to-speech model, has been adapted for streaming in projects like VITS Server, which supports fast inference and streaming capabilities. However, integrating such a server-based solution into an iOS app would involve setting up a backend server to handle the TTS processing and streaming the generated audio to the iOS device."
    // const words = text.split(" ");
    // const randomLength = Math.floor(Math.random() * words.length) + 1;
    // const randomText = words.slice(0, randomLength).join(" ");

    // console.log("random text", randomText);

    const startTime = Date.now();
    const newSound = await streamSpeech("en_US-ryan-medium", text);
    console.log("newSound", newSound);
    const endTime = Date.now();
    playWav(newSound);

    console.log(`runtime is ${endTime - startTime}ms`);
    console.log(newSound);
    // playWav(newSound);
  } catch (error) {
    console.error(error);
  }
};


const downloadVoice = async () => {
  try {
    // const modelPath = await loadModel('default_male');
    console.log("loading model");
    const modelPath = await loadModel("en_US-ryan-medium");
    console.log("model loaded");
    console.log(modelPath);
  } catch (error) {
    console.error(error);
  }
};

const removeVoice = async () => {
  await unloadModel("en_US-ryan-medium")
}

export default function App() {

  return (
    <View style={styles.container}>
      {/* <Text>Result: {result}</Text> */}
      <Button title="Stream speech" onPress={streamAudio} />
      <Button title="Play Sound" onPress={playSound} />
      <Button title="Load model" onPress={downloadVoice} />
      <Button title="Unload model" onPress={removeVoice} />
      <Button title="Test Storage" onPress={testStorage} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
