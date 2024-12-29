# react-native
cd wfloat-react-native
yarn

node ./node_modules/react-native/scripts/generate-codegen-artifacts.js --targetPlatform ios --path ./example --outputPath ./generated

cd example/ios
rm -rf build
bundle exec pod install

Using yarn because https://github.com/facebook/react-native/issues/29977
