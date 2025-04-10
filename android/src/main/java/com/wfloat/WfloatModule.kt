package com.wfloat

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.Promise
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

@ReactModule(name = WfloatModule.NAME)
class WfloatModule(reactContext: ReactApplicationContext) :
  NativeWfloatSpec(reactContext) {

  override fun getName(): String {
    return NAME
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
    promise.resolve("stub")
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
