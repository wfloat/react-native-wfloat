# react-native-wfloat

Wfloat package for react native

## Installation

```sh
npm install react-native-wfloat
```

## Usage


```js
import { multiply } from 'react-native-wfloat';

// ...

const result = multiply(3, 7);
```


## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)

cd ~/dev/react-native-wfloat && yarn clean && yarn prepare && cd example/ios && bundle exec pod install && cd ../..
npm publish

cd ~/dev/wfloat/packages/react-native-wfloat && yarn clean && yarn prepare && cd example/android && ./gradlew generateCodegenArtifactsFromSchema && cd ../..