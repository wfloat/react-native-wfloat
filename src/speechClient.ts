import type { EventSubscription } from 'react-native';
import Wfloat, { type NativeLoadModelProgressEvent } from './NativeWfloat';
import { getModelAssets } from './modelAssets';
import type {
  LoadModelOnProgressEvent,
  LoadModelOptions,
  SpeechClientStatus,
} from './speechTypes';

export class SpeechClient {
  private static status: SpeechClientStatus = 'off';
  private static loadModelProgressSubscription: EventSubscription | null = null;
  private static loadModelOnProgressCallback:
    | LoadModelOptions['onProgressCallback']
    | null = null;

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
      this.status = 'idle';
    } catch (error) {
      this.status = 'off';
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
}
