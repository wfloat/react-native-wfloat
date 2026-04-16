# react-native-wfloat

Wfloat package for react native

## Installation

```sh
npm install react-native-wfloat
```

### Android JNI libraries

This package expects the sherpa Android native libraries to live under
`android/src/main/jniLibs/<abi>`.

Install or refresh them with:

```sh
./install-android-jni-libs.sh
```

You can also pass an explicit version:

```sh
./install-android-jni-libs.sh 1.13.1
```

The installer downloads the combined Android archive from the Wfloat registry
and copies the `.so` files into the matching ABI directories.

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

## TODO: Fix the react-native-blob-util dependency according to this FAQ: https://callstack.github.io/react-native-builder-bob/faq#how-do-i-add-a-react-native-library-containing-native-code-as-a-dependency-in-my-library 

cd ~/dev/react-native-wfloat && yarn clean && yarn prepare && cd example/ios && bundle exec pod install && cd ../..
npm publish

cd ~/dev/wfloat/packages/react-native-wfloat && yarn clean && yarn prepare && cd example/android && ./gradlew generateCodegenArtifactsFromSchema && cd ../..