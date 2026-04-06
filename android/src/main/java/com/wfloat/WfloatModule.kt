package com.wfloat

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReadableMap
import android.content.res.AssetManager
import com.k2fsa.sherpa.onnx.OfflineTts
import com.k2fsa.sherpa.onnx.OfflineTtsConfig
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig
import com.k2fsa.sherpa.onnx.getOfflineTtsConfig
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig
import android.util.Log
import java.io.File
import java.io.IOException
import android.content.Context
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import android.media.MediaPlayer
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.LinkedBlockingQueue

@ReactModule(name = WfloatModule.NAME)
class WfloatModule(reactContext: ReactApplicationContext) :
  NativeWfloatSpec(reactContext) {

  override fun getName(): String {
    return NAME
  }

  override fun loadModel(options: ReadableMap, promise: Promise) {
    promise.reject(
      "UNIMPLEMENTED",
      "loadModel is only implemented on iOS right now."
    )
  }

  private fun copyDir(assetManager: AssetManager, assetDir: String, targetDir: File) {
    val assets = assetManager.list(assetDir) ?: return
    targetDir.mkdirs()
    for (asset in assets) {
      val path = "$assetDir/$asset"
      val file = File(targetDir, asset)
      if (assetManager.list(path)?.isNotEmpty() == true) {
        copyDir(assetManager, path, file)
      } else {
        assetManager.open(path).use { input: InputStream ->
          FileOutputStream(file).use { output: OutputStream ->
            input.copyTo(output)
          }
        }
      }
    }
  }

  private fun copyAssetsToFilesDir(context: Context): Map<String, String> {
    val assetManager = context.assets
    val filesDir = context.filesDir

    val espeakTarget = File(filesDir, "espeak-ng-data")
    copyDir(assetManager, "espeak-ng-data", espeakTarget)

    val tokensTarget = File(filesDir, "tokens.txt")
    assetManager.open("tokens.txt").use { input: InputStream ->
      FileOutputStream(tokensTarget).use { output: OutputStream ->
        input.copyTo(output)
      }
    }

    return mapOf(
      "espeakDirPath" to espeakTarget.absolutePath,
      "tokensFilePath" to tokensTarget.absolutePath
    )
  }

  override fun speech(modelPath: String, inputText: String): String {

    val paths = copyAssetsToFilesDir(reactApplicationContext)
    val espeakDirPath = paths["espeakDirPath"]!!
    val tokensFilePath = paths["tokensFilePath"]!!

    val fullModelPath = File(reactApplicationContext.filesDir, modelPath).absolutePath
    val fullModelFile = File(fullModelPath)
    val modelDirPath = fullModelFile.parent
    val modelName = fullModelFile.name

    // Minimal dummy config — values can be empty since we just want to load JNI
    // val config = OfflineTtsVitsModelConfig(
    //       model = fullModelPath,
    //       tokens = tokensFilePath!!,
    //       dataDir = espeakDirPath!!,
    //   )

//     val config = getOfflineTtsConfig(
//           modelDir = modelDirPath!!,
//           modelName = modelName,
//           acousticModelName = "",
//           vocoder = "",
//           voices = "",
//           lexicon = "",
//           dataDir = espeakDirPath!!,
//           dictDir = "",
//           ruleFsts = "",
//           ruleFars = "",
//       )

    var assets = reactApplicationContext.assets

//    val modelDir = File(modelDirPath)
//    val dataDir = File(espeakDirPath)
//    // val modelNameFile = File(modelName)
//
//    val existenceReport = """
//    modelDir: ${modelDir.exists()}
//    fullModelFile: ${fullModelFile.exists()}
//    espeakDirPath: ${File(espeakDirPath).isDirectory()}
//
//""".trimIndent()

    // return existenceReport

//     val tts =
//       val tts = OfflineTts(config = config)

    // val config = OfflineTtsConfig(
    //   model = OfflineTtsVitsModelConfig(
    //     model = fullModelPath,  // should be the asset file name, e.g., "model.onnx"
    //     tokens = tokensFilePath!!,
    //     dataDir = espeakDirPath!!
    //   )
    // )

    val config = OfflineTtsConfig(
      model = OfflineTtsModelConfig(
        vits = OfflineTtsVitsModelConfig(
          model = fullModelPath,
          tokens = tokensFilePath,
          dataDir = espeakDirPath
        )
      )
    )
    val tts = OfflineTts(config = config)

    val audio = tts.generate(
      text = inputText,
      sid = 0,
      speed = 1.0f
    )

    val tempDirPath = reactApplicationContext.cacheDir.absolutePath
    val timestamp = (System.currentTimeMillis() / 1000).toString()
    val filePath = "$tempDirPath/audio_$timestamp.wav"

//    val filename = "audio.wav"
    val result = audio.save(filename = filePath)
    tts.free()

    return filePath
    // return "${espeakDirPath};${tokensFilePath};${modelName};${modelDirPath}" // This will crash if JNI isn't properly loaded
  }

  override fun streamSpeech(modelPath: String, inputText: String, promise: Promise) {
    try {
      val paths = copyAssetsToFilesDir(reactApplicationContext)
      val espeakDirPath = paths["espeakDirPath"]!!
      val tokensFilePath = paths["tokensFilePath"]!!

      val fullModelPath = File(reactApplicationContext.filesDir, modelPath).absolutePath
      val fullModelFile = File(fullModelPath)

      val config = OfflineTtsConfig(
        model = OfflineTtsModelConfig(
          vits = OfflineTtsVitsModelConfig(
            model = fullModelPath,
            tokens = tokensFilePath,
            dataDir = espeakDirPath
          )
        )
      )

      val tts = OfflineTts(config = config)

      val sampleRate = tts.sampleRate()
      val bufferSize = AudioTrack.getMinBufferSize(
        sampleRate,
        AudioFormat.CHANNEL_OUT_MONO,
        AudioFormat.ENCODING_PCM_FLOAT
      )

      val audioTrack = AudioTrack.Builder()
        .setAudioAttributes(
          AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        )
        .setAudioFormat(
          AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .build()
        )
        .setBufferSizeInBytes(bufferSize)
        .setTransferMode(AudioTrack.MODE_STREAM)
        .build()

      val audioQueue = LinkedBlockingQueue<FloatArray>()

      val writerThread = Thread {
        audioTrack.play()
        while (true) {
          val samples = audioQueue.take() // blocks until data is available
          if (samples.isEmpty()) break // poison pill to stop
          audioTrack.write(samples, 0, samples.size, AudioTrack.WRITE_BLOCKING)
        }
      }
      writerThread.start()

      val audio = tts.generateWithCallback(
        text = inputText,
        sid = 0,
        speed = 1.0f,
        callback = { samples: FloatArray ->
          audioQueue.put(samples)
          1
        }
      )

      // After generation is done, signal the writer thread to stop
      audioQueue.put(FloatArray(0))
      writerThread.join()

      val tempDirPath = reactApplicationContext.cacheDir.absolutePath
      val timestamp = (System.currentTimeMillis() / 1000).toString()
      val filePath = "$tempDirPath/audio_$timestamp.wav"

      audio.save(filename = filePath)

      tts.free()
      audioTrack.stop()
      audioTrack.release()

      promise.resolve(filePath)
    } catch (e: Exception) {
      Log.e(NAME, "streamSpeech failed", e)
      promise.reject("STREAM_ERROR", "Failed to stream speech", e)
    }
  }

  override fun playWav(filePath: String): String {

//    val assetFileDescriptor = reactApplicationContext.assets.openFd("speaker_0.wav")
//
    val mediaPlayer = MediaPlayer()
    mediaPlayer.setDataSource(filePath)
//    mediaPlayer.setDataSource(
//      assetFileDescriptor.fileDescriptor,
//      assetFileDescriptor.startOffset,
//      assetFileDescriptor.length
//    )
    mediaPlayer.prepare()
    mediaPlayer.start()
    return "success"
  }

  companion object {
    const val NAME = "Wfloat"
  }
}
