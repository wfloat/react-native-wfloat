import { Text, View, StyleSheet, Button } from 'react-native';
import { speech, playWav } from 'react-native-wfloat';


const playSound = () => {
  try {
    const startTime = Date.now();
    const newSound = speech();
    const endTime = Date.now();
    console.log(`runtime is ${endTime - startTime}ms`);
    playWav(newSound)
  } catch (error) {
    console.error(error);
  }
};

export default function App() {
  
  return (
    <View style={styles.container}>
      {/* <Text>Result: {result}</Text> */}
      <Button title="Play Sound" onPress={playSound} />
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
