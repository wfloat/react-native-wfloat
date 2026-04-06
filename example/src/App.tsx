import { View, StyleSheet, Button } from 'react-native';
import { SpeechClient } from '@wfloat/react-native-wfloat';
import { LOCAL_CONFIG } from './localConfig';

const downloadVoice = async () => {
  try {
    console.log('loading model');
    await SpeechClient.loadModel(LOCAL_CONFIG.modelId, {
      onProgressCallback: (event) => {
        console.log('loadModel progress', event);
      },
    });
    console.log('model loaded');
  } catch (error) {
    console.error(error);
  }
};

export default function App() {
  return (
    <View style={styles.container}>
      <Button title="Load model" onPress={downloadVoice} />
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
