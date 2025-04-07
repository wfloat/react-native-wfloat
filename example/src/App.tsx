import { Text, View, StyleSheet, Button } from 'react-native';
import { speech, playWav, loadModel, unloadModel, testStorage, streamSpeech } from '@wfloat/react-native-wfloat';

const playSound = async () => {
  try {
    const text = "Dubfloat. Realistic computer voice without subscriptions or usage based charges.";
    const words = text.split(" ");
    const randomLength = Math.floor(Math.random() * words.length) + 1;
    const randomText = words.slice(0, randomLength).join(" ");

    console.log("random text", randomText);

    const startTime = Date.now();
    const newSound = await speech("default_male", randomText);
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
    const text = "Dubfloat is a realistic text-to-speech that is a really long sentence and i want to know how it will be split up and i guess we shall see this is probably going to take a really long time which is sad. There once upon a time was a story with words in it where stuff happened. Anyway know you.";
    // const words = text.split(" ");
    // const randomLength = Math.floor(Math.random() * words.length) + 1;
    // const randomText = words.slice(0, randomLength).join(" ");

    // console.log("random text", randomText);

    const startTime = Date.now();
    const newSound = await streamSpeech("default_male", text);
    const endTime = Date.now();

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
    const modelPath = await loadModel("default_male");
    console.log("model loaded");
    console.log(modelPath);
  } catch (error) {
    console.error(error);
  }
};

const removeVoice = async () => {
  await unloadModel("default_male")
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
