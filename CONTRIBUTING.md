
Before running the example app, create a local config file for untracked developer-specific values:

```ts
// example/src/localConfig.ts
export const LOCAL_CONFIG = {
  modelId: 'your-model-id',
} as const;
```

This file is gitignored. Use it for values you need locally in the example app but do not want to commit, such as a model id.

## Repository structure

- The package itself lives at the repository root.
- The example app lives in [`example/`](./example) and is used to run the package on iOS and Android during local development.

## Getting started

Install dependencies from the repository root:

```sh
yarn
```


### iOS native changes

Typical commands:

```sh
yarn prepare
cd example/ios
bundle exec pod install
cd ../..
yarn example ios
```
