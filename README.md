# @wfloat/react-native-wfloat

`@wfloat/react-native-wfloat` adds Wfloat text-to-speech to React Native apps on iOS and Android. Use it to turn text into spoken audio in your app.

## Install

```bash
npm install @wfloat/react-native-wfloat
```

```bash
yarn add @wfloat/react-native-wfloat
```

## iOS setup

Install CocoaPods dependencies from your app's `ios/` directory:

```bash
cd ios
pod install
cd ..
```

React Native autolinking handles Android integration after the package is installed.

## Quick start

Your `modelId` is the **Model Credential** shown in your Wfloat account after purchase.

```tsx
import { SpeechClient } from "@wfloat/react-native-wfloat";

const modelId = "your-model-credential";

await SpeechClient.loadModel(modelId, {
  onProgressCallback(event) {
    if (event.status === "downloading") {
      console.log("Downloading", Math.round(event.progress * 100) + "%");
      return;
    }

    if (event.status === "loading") {
      console.log("Initializing native runtime");
      return;
    }

    console.log("Model ready");
  },
});

await SpeechClient.generate({
  text: "All systems are stable. You can begin the launch sequence.",
  voiceId: "narrator_woman",
  emotion: "neutral",
  intensity: 0.5,
  speed: 1,
  silencePaddingSec: 0.1,
  onProgressCallback(event) {
    console.log("progress", event.progress);
    console.log("isPlaying", event.isPlaying);
    console.log("highlight", event.textHighlightStart, event.textHighlightEnd);
    console.log("chunkText", event.text);
  },
  onFinishedPlayingCallback() {
    console.log("Playback finished");
  },
});
```

## API overview

- `SpeechClient.loadModel(modelId, { onProgressCallback })` loads the model for the current device. The first load downloads the model and native support assets for the platform.
- `SpeechClient.generate(options)` generates a single utterance and starts playback.
- `SpeechClient.generateDialogue(options)` generates multi-speaker dialogue from a list of segments.
- `SpeechClient.pause()` and `SpeechClient.play()` control playback for the active request.
- `SpeechClient.getStatus()` returns `"off" | "loading-model" | "generating" | "idle" | "terminating-generate"`.

## Progress callbacks

`loadModel(...)` emits:

```ts
{ status: "downloading", progress: number }
{ status: "loading" }
{ status: "completed" }
```

`generate(...)` and `generateDialogue(...)` emit:

```ts
{
  progress: number;
  isPlaying: boolean;
  textHighlightStart: number;
  textHighlightEnd: number;
  text: string;
}
```

## Dialogue example

```tsx
await SpeechClient.generateDialogue({
  silenceBetweenSegmentsSec: 0.2,
  onProgressCallback(event) {
    console.log(event.progress);
  },
  onFinishedPlayingCallback() {
    console.log("Dialogue finished");
  },
  segments: [
    {
      text: "We only get one pass at this.",
      voiceId: "narrator_man",
      emotion: "neutral",
    },
    {
      text: "Then let's make the first pass count.",
      voiceId: "strong_hero_woman",
      emotion: "joy",
      intensity: 0.65,
    },
  ],
});
```

## Useful exports

The package also exports `SPEAKER_IDS`, `VALID_EMOTIONS`, and `VALID_SIDS` for building voice pickers and validating user input.

## Contributing

Maintainer and local development notes live in [CONTRIBUTING.md](CONTRIBUTING.md).
