package com.wfloat

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.Promise

@ReactModule(name = WfloatModule.NAME)
class WfloatModule(reactContext: ReactApplicationContext) :
  NativeWfloatSpec(reactContext) {

  override fun getName(): String {
    return NAME
  }

  override fun speech(modelPath: String, inputText: String): String {
    return "stub"
  }

  override fun streamSpeech(modelPath: String, inputText: String, promise: Promise) {
    promise.resolve("stub")
  }

  override fun playWav(filePath: String): String {
    return "stub"
  }

  companion object {
    const val NAME = "Wfloat"
  }
}