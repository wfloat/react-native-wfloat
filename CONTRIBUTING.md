# Contributing

Thanks for contributing to `@wfloat/react-native-wfloat`.

This repository is a React Native library package with a local example app used to exercise the library during development.

Before contributing, please read the [Code of Conduct](./CODE_OF_CONDUCT.md).

## Repository structure

- The package itself lives at the repository root.
- The example app lives in [`example/`](./example) and is used to run the package on iOS and Android during local development.

The root package is the main thing you are developing. The example app is a harness for validating package changes in a real React Native app.

## Getting started

Install dependencies from the repository root:

```sh
yarn
```

This repo uses Yarn workspaces. Use Yarn for development commands.

## Development model

Most code changes happen in the package at the repository root:

- JavaScript and TypeScript source lives in [`src/`](./src).
- iOS native code lives in [`ios/`](./ios).
- Android native code lives in [`android/`](./android).
- Generated package output is written to [`lib/`](./lib) by the build step.

The example app in [`example/`](./example) is how you run and verify the package while you work.

## Core commands

From the repository root:

```sh
yarn typecheck
yarn lint
yarn test
yarn prepare
```

What these do:

- `yarn typecheck` runs TypeScript checks.
- `yarn lint` runs ESLint.
- `yarn test` runs Jest tests.
- `yarn prepare` runs `bob build` and regenerates the package build output.

## When to run `yarn prepare`

Run `yarn prepare` from the repository root when you change package code that should be rebuilt into distributable output, especially:

- files in `src/`
- exported package APIs
- codegen-related package definitions
- package build output before publishing

Broadly, `yarn prepare` is the package build step for this repository.

## Working with the example app

You can run the example app either from the root with the workspace script or from inside `example/`.

From the repository root:

```sh
yarn example start
yarn example ios
yarn example android
```

Equivalent commands from `example/`:

```sh
yarn start
yarn ios
yarn android
```

## Typical development workflows

### JavaScript or TypeScript package changes

1. Edit package code in the repository root.
2. Start Metro for the example app.
3. Run the example app on iOS or Android.
4. Run `yarn prepare` if you need refreshed built package output.

Typical commands:

```sh
yarn example start
yarn example ios
```

or

```sh
yarn example start
yarn example android
```

### iOS native changes

If you change iOS native code or iOS dependency state:

1. Make the package change in the repository root.
2. Run `yarn prepare` if the package build or codegen output needs to be refreshed.
3. Install pods from `example/ios`.
4. Run the example app on iOS.

Typical commands:

```sh
yarn prepare
cd example/ios
bundle exec pod install
cd ../..
yarn example ios
```

Notes:

- Use Bundler for CocoaPods commands.
- Run React Native doctor for this repo from `example/`, not from the repository root.

Example:

```sh
cd example
npx react-native doctor
```

### Android native changes

If you change Android native code or Android build configuration:

1. Make the package change in the repository root.
2. Run `yarn prepare` if the package build or codegen output needs to be refreshed.
3. Run the example app on Android.

Typical commands:

```sh
yarn prepare
yarn example android
```

If you need Android codegen artifacts explicitly:

```sh
cd example/android
./gradlew generateCodegenArtifactsFromSchema
cd ../..
```

## Tooling notes

- CocoaPods and the iOS Ruby toolchain are configured from [`example/Gemfile`](./example/Gemfile).
- The example app links to the package in the repository root.
- Metro is configured so the example app can develop against the local package source.

## Quality checks

Before opening a pull request, run:

```sh
yarn typecheck
yarn lint
yarn test
```

If your change affects package build output or native integration, also run:

```sh
yarn prepare
```

If your change affects iOS, also verify:

```sh
cd example/ios
bundle exec pod install
cd ../..
yarn example ios
```

If your change affects Android, also verify:

```sh
yarn example android
```

## Commit messages

This repo follows [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

Examples:

- `feat: add playback status event`
- `fix: correct Android module initialization`
- `docs: update iOS setup instructions`
- `chore: refresh build configuration`

## Publishing

This repo uses `release-it` for releases:

```sh
yarn release
```

Before publishing, make sure the package has been rebuilt and the example app still validates the current changes.

## Pull requests

When opening a pull request:

- keep the change focused
- include tests when practical
- update docs when behavior or setup changes
- mention any iOS or Android manual verification you performed
