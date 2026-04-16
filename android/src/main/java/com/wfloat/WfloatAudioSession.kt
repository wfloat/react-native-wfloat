package com.wfloat

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.roundToInt

private const val PROGRESS_TICK_INTERVAL_MS = 50L

internal class WfloatAudioSession(
  val requestId: Int,
  sampleRate: Int,
  private val progressHandler: (
    requestId: Int,
    progress: Double,
    isPlaying: Boolean,
    textHighlightStart: Int,
    textHighlightEnd: Int,
    text: String,
  ) -> Unit,
  private val playbackFinishedHandler: (requestId: Int) -> Unit,
) {
  private data class AudioWriteItem(
    val samples: FloatArray,
  )

  private data class ProgressChunk(
    val startFrame: Long,
    val progress: Double,
    val textHighlightStart: Int,
    val textHighlightEnd: Int,
    val text: String,
  )

  private val stateLock = Any()
  private val pauseLock = Object()
  private val cancelled = AtomicBoolean(false)
  private val queue = LinkedBlockingQueue<AudioWriteItem>()
  private val progressChunks = mutableListOf<ProgressChunk>()
  private val scheduler: ScheduledExecutorService =
    Executors.newSingleThreadScheduledExecutor()

  private val track: AudioTrack
  private val playbackThread: Thread

  @Volatile
  private var generationComplete = false

  @Volatile
  private var writesComplete = false

  @Volatile
  private var userPaused = false

  @Volatile
  private var playbackFinishedEmitted = false

  @Volatile
  private var lastEmittedChunkIndex = -1

  @Volatile
  private var totalFramesScheduled = 0L

  init {
    val minBufferSize = AudioTrack.getMinBufferSize(
      sampleRate,
      AudioFormat.CHANNEL_OUT_MONO,
      AudioFormat.ENCODING_PCM_FLOAT
    )
    val bufferSize = max(minBufferSize, sampleRate / 2)

    val attributes = AudioAttributes.Builder()
      .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
      .setUsage(AudioAttributes.USAGE_MEDIA)
      .build()

    val format = AudioFormat.Builder()
      .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
      .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
      .setSampleRate(sampleRate)
      .build()

    track = AudioTrack(
      attributes,
      format,
      bufferSize,
      AudioTrack.MODE_STREAM,
      AudioManager.AUDIO_SESSION_ID_GENERATE
    )
    track.play()

    playbackThread = Thread(
      {
        playbackLoop()
      },
      "WfloatAudioSession-$requestId"
    ).apply {
      isDaemon = true
      start()
    }

    scheduler.scheduleAtFixedRate(
      { tickProgress() },
      PROGRESS_TICK_INTERVAL_MS,
      PROGRESS_TICK_INTERVAL_MS,
      TimeUnit.MILLISECONDS
    )
  }

  fun isCancelled(): Boolean {
    return cancelled.get()
  }

  fun enqueueSpeech(
    samples: FloatArray,
    progress: Double,
    text: String,
    textHighlightStart: Int,
    textHighlightEnd: Int,
    silencePaddingSec: Float,
    sampleRate: Int,
  ) {
    if (cancelled.get() || samples.isEmpty()) {
      return
    }

    synchronized(stateLock) {
      progressChunks.add(
        ProgressChunk(
          startFrame = totalFramesScheduled,
          progress = progress,
          textHighlightStart = textHighlightStart,
          textHighlightEnd = textHighlightEnd,
          text = text
        )
      )
      totalFramesScheduled += samples.size.toLong()
    }
    queue.put(AudioWriteItem(samples))

    val silenceFrameCount =
      if (silencePaddingSec > 0f) (silencePaddingSec * sampleRate).roundToInt()
      else 0
    if (silenceFrameCount > 0) {
      synchronized(stateLock) {
        totalFramesScheduled += silenceFrameCount.toLong()
      }
      queue.put(AudioWriteItem(FloatArray(silenceFrameCount)))
    }
  }

  fun markGenerationComplete() {
    generationComplete = true
    if (queue.isEmpty()) {
      writesComplete = true
    }
    tickProgress()
  }

  fun play() {
    if (cancelled.get()) {
      return
    }

    userPaused = false
    track.play()
    synchronized(pauseLock) {
      pauseLock.notifyAll()
    }
    emitActiveChunkStateChanged()
  }

  fun pause() {
    if (cancelled.get()) {
      return
    }

    userPaused = true
    track.pause()
    emitActiveChunkStateChanged()
  }

  fun cancel() {
    if (!cancelled.compareAndSet(false, true)) {
      return
    }

    synchronized(pauseLock) {
      pauseLock.notifyAll()
    }
    playbackThread.interrupt()
    teardownAudioTrack()
  }

  private fun playbackLoop() {
    try {
      while (!cancelled.get()) {
        if (userPaused) {
          synchronized(pauseLock) {
            while (userPaused && !cancelled.get()) {
              pauseLock.wait()
            }
          }
        }

        if (cancelled.get()) {
          return
        }

        val item = queue.poll(100, TimeUnit.MILLISECONDS)
        if (item == null) {
          if (generationComplete && queue.isEmpty()) {
            writesComplete = true
            return
          }
          continue
        }

        var offset = 0
        while (offset < item.samples.size && !cancelled.get()) {
          if (userPaused) {
            synchronized(pauseLock) {
              while (userPaused && !cancelled.get()) {
                pauseLock.wait()
              }
            }
          }

          val written = track.write(
            item.samples,
            offset,
            item.samples.size - offset,
            AudioTrack.WRITE_BLOCKING
          )
          if (written <= 0) {
            break
          }
          offset += written
        }
      }
    } catch (_: InterruptedException) {
      // Session teardown interrupts the playback thread.
    } finally {
      writesComplete = writesComplete || (generationComplete && queue.isEmpty())
    }
  }

  private fun tickProgress() {
    if (cancelled.get()) {
      return
    }

    val playedFrames = try {
      currentPlaybackHeadPosition()
    } catch (_: IllegalStateException) {
      return
    }
    val chunksToEmit = mutableListOf<ProgressChunk>()
    var shouldEmitFinished = false

    synchronized(stateLock) {
      while (lastEmittedChunkIndex + 1 < progressChunks.size &&
        playedFrames >= progressChunks[lastEmittedChunkIndex + 1].startFrame
      ) {
        lastEmittedChunkIndex += 1
        chunksToEmit.add(progressChunks[lastEmittedChunkIndex])
      }

      if (!playbackFinishedEmitted &&
        generationComplete &&
        writesComplete &&
        playedFrames >= totalFramesScheduled
      ) {
        playbackFinishedEmitted = true
        shouldEmitFinished = true
      }
    }

    chunksToEmit.forEach(::emitProgressForChunk)

    if (shouldEmitFinished) {
      teardownAudioTrack()
      playbackFinishedHandler(requestId)
    }
  }

  private fun emitActiveChunkStateChanged() {
    val chunk = synchronized(stateLock) {
      if (lastEmittedChunkIndex < 0 || lastEmittedChunkIndex >= progressChunks.size) {
        null
      } else {
        progressChunks[lastEmittedChunkIndex]
      }
    } ?: return

    emitProgressForChunk(chunk)
  }

  private fun emitProgressForChunk(chunk: ProgressChunk) {
    if (cancelled.get()) {
      return
    }

    progressHandler(
      requestId,
      chunk.progress,
      isPlaying(),
      chunk.textHighlightStart,
      chunk.textHighlightEnd,
      chunk.text
    )
  }

  private fun isPlaying(): Boolean {
    return try {
      !cancelled.get() &&
        !userPaused &&
        track.playState == AudioTrack.PLAYSTATE_PLAYING
    } catch (_: IllegalStateException) {
      false
    }
  }

  private fun currentPlaybackHeadPosition(): Long {
    return track.playbackHeadPosition.toLong() and 0xffffffffL
  }

  private fun teardownAudioTrack() {
    scheduler.shutdownNow()
    try {
      track.pause()
    } catch (_: IllegalStateException) {
    }
    try {
      track.flush()
    } catch (_: IllegalStateException) {
    }
    try {
      track.stop()
    } catch (_: IllegalStateException) {
    }
    try {
      track.release()
    } catch (_: IllegalStateException) {
    }
  }
}
