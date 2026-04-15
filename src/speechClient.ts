import type { EventSubscription } from 'react-native';
import Wfloat, {
  type NativeLoadModelProgressEvent,
  type NativeSpeechPlaybackFinishedEvent,
  type NativeSpeechProgressEvent,
} from './NativeWfloat';
import { getModelAssets } from './modelAssets';
import type {
  LoadModelOnProgressEvent,
  LoadModelOptions,
  SpeechClientStatus,
  SpeechEmotion,
  SpeechGenerateDialogueOptions,
  SpeechGenerateOptions,
  SpeechOnProgressEvent,
  SpeechSegment,
} from './speechTypes';
import { SPEAKER_IDS, VALID_EMOTIONS, VALID_SIDS } from './speechTypes';

const DEFAULT_EMOTION: SpeechEmotion = 'neutral';
const DEFAULT_INTENSITY = 0.5;
const DEFAULT_SPEED = 1;
const DEFAULT_SILENCE_PADDING_SEC = 0.1;
const DEFAULT_SILENCE_BETWEEN_SEGMENTS_SEC = 0.2;
const INPUT_PREVIEW_MAX_LENGTH = 100;

type ActiveSpeechRequest = {
  requestId: number;
  onProgressCallback: ((event: SpeechOnProgressEvent) => void) | null;
  onFinishedPlayingCallback: (() => void) | null;
};

type NormalizedGenerateOptions = {
  text: string;
  sid: number;
  emotion: SpeechEmotion;
  intensity: number;
  speed: number;
  silencePaddingSec: number;
};

type NormalizedGenerateDialogueOptions = {
  segments: NormalizedGenerateDialogueSegment[];
  silenceBetweenSegmentsSec: number;
};

type NormalizedGenerateDialogueSegment = {
  text: string;
  sid: number;
  emotion: SpeechEmotion;
  intensity: number;
  speed: number;
  sentenceSilencePaddingSec: number;
};

export class SpeechClient {
  private static status: SpeechClientStatus = 'off';
  private static isModelLoaded = false;
  private static nextRequestId = 1;
  private static loadModelProgressSubscription: EventSubscription | null = null;
  private static speechProgressSubscription: EventSubscription | null = null;
  private static speechPlaybackFinishedSubscription: EventSubscription | null =
    null;
  private static loadModelOnProgressCallback:
    | ((event: LoadModelOnProgressEvent) => void)
    | null = null;
  private static activeSpeechRequest: ActiveSpeechRequest | null = null;
  private static activeGenerateRequestId: number | null = null;

  static async loadModel(
    modelId: string,
    options: LoadModelOptions = {}
  ): Promise<void> {
    if (this.status === 'loading-model') {
      console.warn(
        `Received multiple SpeechClient.loadModel(...) calls in rapid succession. Ignoring most recent loadModel call with modelId "${modelId}".`
      );
      return;
    }

    this.status = 'loading-model';
    this.isModelLoaded = false;
    this.loadModelOnProgressCallback = options.onProgressCallback ?? null;
    this.subscribeToLoadModelProgress();

    try {
      const assets = await getModelAssets(modelId);
      await Wfloat.loadModel({
        modelId,
        modelUrl: assets.model_onnx,
        tokensUrl: assets.model_tokens,
        espeakDataUrl: assets.espeak_data,
        espeakChecksum: assets.espeak_checksum,
      });
      this.isModelLoaded = true;
      this.status = 'idle';
    } catch (error) {
      this.status = 'off';
      this.isModelLoaded = false;
      throw error;
    } finally {
      this.loadModelOnProgressCallback = null;
      this.loadModelProgressSubscription?.remove();
      this.loadModelProgressSubscription = null;
    }
  }

  static getStatus(): SpeechClientStatus {
    return this.status;
  }

  static async generate(options: SpeechGenerateOptions): Promise<void> {
    if (!this.isModelLoaded) {
      throw new Error(
        'SpeechClient is not created. Call SpeechClient.loadModel(...) first.'
      );
    }

    const normalizedOptions = this.normalizeGenerateOptions(options);
    const requestId = this.nextRequestId;
    this.nextRequestId += 1;

    const hadActiveSession = this.activeSpeechRequest !== null;
    if (hadActiveSession) {
      this.status = 'terminating-generate';
    }

    this.subscribeToSpeechEvents();
    this.activeGenerateRequestId = requestId;
    this.activeSpeechRequest = {
      requestId,
      onProgressCallback: options.onProgressCallback ?? null,
      onFinishedPlayingCallback: options.onFinishedPlayingCallback ?? null,
    };
    this.status = 'generating';

    try {
      await Wfloat.generate({
        requestId,
        text: normalizedOptions.text,
        sid: normalizedOptions.sid,
        emotion: normalizedOptions.emotion,
        intensity: normalizedOptions.intensity,
        speed: normalizedOptions.speed,
        silencePaddingSec: normalizedOptions.silencePaddingSec,
      });

      if (this.activeGenerateRequestId === requestId) {
        this.activeGenerateRequestId = null;
        this.status = 'idle';
      }
    } catch (error) {
      if (this.activeGenerateRequestId === requestId) {
        this.activeGenerateRequestId = null;
      }

      if (this.activeSpeechRequest?.requestId === requestId) {
        this.activeSpeechRequest = null;
        this.status = this.isModelLoaded ? 'idle' : 'off';
      }

      throw error;
    }
  }

  static async generateDialogue(
    options: SpeechGenerateDialogueOptions
  ): Promise<void> {
    if (!this.isModelLoaded) {
      throw new Error(
        'SpeechClient is not created. Call SpeechClient.loadModel(...) first.'
      );
    }

    const normalizedOptions = this.normalizeGenerateDialogueOptions(options);
    const requestId = this.nextRequestId;
    this.nextRequestId += 1;

    const hadActiveSession = this.activeSpeechRequest !== null;
    if (hadActiveSession) {
      this.status = 'terminating-generate';
    }

    this.subscribeToSpeechEvents();
    this.activeGenerateRequestId = requestId;
    this.activeSpeechRequest = {
      requestId,
      onProgressCallback: options.onProgressCallback ?? null,
      onFinishedPlayingCallback: options.onFinishedPlayingCallback ?? null,
    };
    this.status = 'generating';

    try {
      await Wfloat.generateDialogue({
        requestId,
        segments: normalizedOptions.segments,
        silenceBetweenSegmentsSec: normalizedOptions.silenceBetweenSegmentsSec,
      });

      if (this.activeGenerateRequestId === requestId) {
        this.activeGenerateRequestId = null;
        this.status = 'idle';
      }
    } catch (error) {
      if (this.activeGenerateRequestId === requestId) {
        this.activeGenerateRequestId = null;
      }

      if (this.activeSpeechRequest?.requestId === requestId) {
        this.activeSpeechRequest = null;
        this.status = this.isModelLoaded ? 'idle' : 'off';
      }

      throw error;
    }
  }

  static async play(): Promise<void> {
    if (!this.activeSpeechRequest) {
      console.warn(
        'SpeechClient.play() ignored because the audio player is not initialized.'
      );
      return;
    }

    await Wfloat.play();
  }

  static async pause(): Promise<void> {
    if (!this.activeSpeechRequest) {
      console.warn(
        'SpeechClient.pause() ignored because the audio player is not initialized.'
      );
      return;
    }

    await Wfloat.pause();
  }

  private static subscribeToLoadModelProgress(): void {
    this.loadModelProgressSubscription?.remove();
    this.loadModelProgressSubscription = Wfloat.onLoadModelProgress(
      (event: NativeLoadModelProgressEvent) => {
        const normalizedEvent = this.normalizeLoadModelProgressEvent(event);
        if (!normalizedEvent) {
          return;
        }

        this.loadModelOnProgressCallback?.(normalizedEvent);
      }
    );
  }

  private static normalizeLoadModelProgressEvent(
    event: NativeLoadModelProgressEvent
  ): LoadModelOnProgressEvent | null {
    if (event.status === 'downloading') {
      return {
        status: 'downloading',
        progress:
          typeof event.progress === 'number' && Number.isFinite(event.progress)
            ? Math.min(Math.max(event.progress, 0), 1)
            : 0,
      };
    }

    if (event.status === 'loading') {
      return { status: 'loading' };
    }

    if (event.status === 'completed') {
      return { status: 'completed' };
    }

    console.warn(
      `Ignoring unknown loadModel progress event status "${event.status}".`
    );
    return null;
  }

  private static subscribeToSpeechEvents(): void {
    if (!this.speechProgressSubscription) {
      this.speechProgressSubscription = Wfloat.onSpeechProgress(
        (event: NativeSpeechProgressEvent) => {
          this.handleSpeechProgressEvent(event);
        }
      );
    }

    if (!this.speechPlaybackFinishedSubscription) {
      this.speechPlaybackFinishedSubscription = Wfloat.onSpeechPlaybackFinished(
        (event: NativeSpeechPlaybackFinishedEvent) => {
          this.handleSpeechPlaybackFinishedEvent(event);
        }
      );
    }
  }

  private static handleSpeechProgressEvent(
    event: NativeSpeechProgressEvent
  ): void {
    const activeRequest = this.activeSpeechRequest;
    if (!activeRequest || activeRequest.requestId !== event.requestId) {
      return;
    }

    activeRequest.onProgressCallback?.({
      progress:
        typeof event.progress === 'number' && Number.isFinite(event.progress)
          ? Math.min(Math.max(event.progress, 0), 1)
          : 0,
      isPlaying: Boolean(event.isPlaying),
      textHighlightStart:
        typeof event.textHighlightStart === 'number' &&
        Number.isFinite(event.textHighlightStart)
          ? Math.max(0, Math.trunc(event.textHighlightStart))
          : 0,
      textHighlightEnd:
        typeof event.textHighlightEnd === 'number' &&
        Number.isFinite(event.textHighlightEnd)
          ? Math.max(0, Math.trunc(event.textHighlightEnd))
          : 0,
      text: typeof event.text === 'string' ? event.text : '',
    });
  }

  private static handleSpeechPlaybackFinishedEvent(
    event: NativeSpeechPlaybackFinishedEvent
  ): void {
    const activeRequest = this.activeSpeechRequest;
    if (!activeRequest || activeRequest.requestId !== event.requestId) {
      return;
    }

    const callback = activeRequest.onFinishedPlayingCallback;
    this.activeSpeechRequest = null;
    callback?.();
  }

  private static normalizeGenerateOptions(
    options: SpeechGenerateOptions
  ): NormalizedGenerateOptions {
    if (!options.text) {
      throw new Error('text is required.');
    }

    return {
      text: options.text,
      sid: this.normalizeVoiceId(options.voiceId),
      emotion: this.normalizeEmotion(options.emotion),
      intensity: this.normalizeIntensity(options.intensity),
      speed: this.normalizeSpeed(options.speed),
      silencePaddingSec: this.normalizeSilencePaddingSec(
        options.silencePaddingSec
      ),
    };
  }

  private static normalizeGenerateDialogueOptions(
    options: SpeechGenerateDialogueOptions
  ): NormalizedGenerateDialogueOptions {
    if (!options.segments?.length) {
      throw new Error('segments is required.');
    }

    const defaultSpeed = this.normalizeSpeed(options.speed);

    return {
      segments: options.segments.map((segment, index) =>
        this.normalizeGenerateDialogueSegment(segment, index, defaultSpeed)
      ),
      silenceBetweenSegmentsSec: this.normalizeNonNegativeNumber(
        options.silenceBetweenSegmentsSec,
        DEFAULT_SILENCE_BETWEEN_SEGMENTS_SEC
      ),
    };
  }

  private static normalizeGenerateDialogueSegment(
    segment: SpeechSegment,
    index: number,
    defaultSpeed: number
  ): NormalizedGenerateDialogueSegment {
    if (!segment.text) {
      throw new Error(`segments[${index}].text is required.`);
    }

    return {
      text: segment.text,
      sid: this.normalizeVoiceId(segment.voiceId),
      emotion: this.normalizeEmotion(segment.emotion),
      intensity: this.normalizeIntensity(segment.intensity),
      speed:
        typeof segment.speed === 'number' && Number.isFinite(segment.speed)
          ? this.normalizeSpeed(segment.speed)
          : defaultSpeed,
      sentenceSilencePaddingSec: this.normalizeNonNegativeNumber(
        segment.sentenceSilencePaddingSec,
        DEFAULT_SILENCE_PADDING_SEC
      ),
    };
  }

  private static normalizeVoiceId(
    voiceId: string | number | undefined
  ): number {
    if (typeof voiceId === 'number') {
      if (!Number.isInteger(voiceId) || !VALID_SIDS.includes(voiceId)) {
        throw new Error(`Invalid numeric voiceId: ${voiceId}`);
      }

      return voiceId;
    }

    if (typeof voiceId === 'string') {
      const trimmedVoiceId = voiceId.trim();
      if (!trimmedVoiceId) {
        return 0;
      }

      const mappedSid = SPEAKER_IDS[trimmedVoiceId];
      if (mappedSid === undefined) {
        throw new Error(`Invalid string voiceId: ${trimmedVoiceId}`);
      }

      return mappedSid;
    }

    return 0;
  }

  private static normalizeEmotion(
    emotion: SpeechGenerateOptions['emotion']
  ): SpeechEmotion {
    if (VALID_EMOTIONS.includes(emotion as SpeechEmotion)) {
      return emotion as SpeechEmotion;
    }

    return DEFAULT_EMOTION;
  }

  private static normalizeIntensity(intensity: number | undefined): number {
    if (typeof intensity !== 'number' || !Number.isFinite(intensity)) {
      return DEFAULT_INTENSITY;
    }

    return Math.min(Math.max(intensity, 0), 1);
  }

  private static normalizeSpeed(speed: number | undefined): number {
    if (typeof speed !== 'number' || !Number.isFinite(speed) || speed <= 0) {
      return DEFAULT_SPEED;
    }

    return speed;
  }

  private static normalizeSilencePaddingSec(
    silencePaddingSec: number | undefined
  ): number {
    return this.normalizeNonNegativeNumber(
      silencePaddingSec,
      DEFAULT_SILENCE_PADDING_SEC
    );
  }

  private static normalizeNonNegativeNumber(
    value: number | undefined,
    defaultValue: number
  ): number {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      return defaultValue;
    }

    return Math.max(value, 0);
  }

  static getOnProgressCallback():
    | ((event: SpeechOnProgressEvent) => void)
    | null {
    return this.activeSpeechRequest?.onProgressCallback ?? null;
  }

  static getLoadModelOnProgressCallback():
    | ((event: LoadModelOnProgressEvent) => void)
    | null {
    return this.loadModelOnProgressCallback;
  }

  static getActiveSpeechRequestId(): number | null {
    return this.activeSpeechRequest?.requestId ?? null;
  }

  static previewInputText(text: string): string {
    if (text.length <= INPUT_PREVIEW_MAX_LENGTH) {
      return text;
    }

    return `${text.slice(0, INPUT_PREVIEW_MAX_LENGTH)}...`;
  }
}
