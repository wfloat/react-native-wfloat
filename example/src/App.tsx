import { Text, View, StyleSheet, Button } from 'react-native';
import { speech, playWav, loadModel } from 'react-native-wfloat';


const playSound = () => {
  try {
    const startTime = Date.now();
    const newSound = speech("Dubfloat. Realistic computer voice without subscriptions or usage based charges. It runs directly in your app and it's easy to set up.");
    const endTime = Date.now();
    console.log(`runtime is ${endTime - startTime}ms`);
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

export default function App() {
  
  return (
    <View style={styles.container}>
      {/* <Text>Result: {result}</Text> */}
      <Button title="Play Sound" onPress={playSound} />
      <Button title="Download model" onPress={downloadVoice} />
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
