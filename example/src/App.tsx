import { Text, View, StyleSheet, Button } from 'react-native';
import { speech, playWav } from 'react-native-wfloat';

const result = speech();
playWav(result);

const playSound = async () => {
  playWav(result);
};

export default function App() {
  
  return (
    <View style={styles.container}>
      <Text>Result: {result}</Text>
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
