import { Text, View, StyleSheet, Button } from 'react-native';
import { speech, playWav, loadModel, unloadModel } from '@wfloat/react-native-wfloat';


const playSound = async () => {
  try {
    const startTime = Date.now();
    const newSound = await speech("default_male", "Dubfloat. Realistic computer voice without subscriptions or usage based charges. It runs directly in your app and it's easy to set up.");
    const endTime = Date.now();
    console.log(`runtime is ${endTime - startTime}ms`);
    console.log(newSound);
    playWav(newSound)
  } catch (error) {
    console.error(error);
  }
};

const downloadVoice = async () => {
  try {
    // const modelPath = await loadModel('default_male');
    const modelPath = await loadModel("default_male");
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
      <Button title="Play Sound" onPress={playSound} />
      <Button title="Load model" onPress={downloadVoice} />
      <Button title="Unload model" onPress={removeVoice} />
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
