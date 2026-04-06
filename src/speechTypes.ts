export type SpeechClientStatus =
  | 'off'
  | 'loading-model'
  | 'generating'
  | 'idle'
  | 'terminating-generate';

export type LoadModelOnProgressEvent =
  | {
      status: 'downloading';
      progress: number;
    }
  | {
      status: 'loading';
    }
  | {
      status: 'completed';
    };

export type LoadModelOptions = {
  onProgressCallback?: (event: LoadModelOnProgressEvent) => void;
};
