package com.wfloat

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule

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

  override fun generate(options: ReadableMap, promise: Promise) {
    promise.reject(
      "UNIMPLEMENTED",
      "generate is only implemented on iOS right now."
    )
  }

  override fun play(promise: Promise) {
    promise.reject(
      "UNIMPLEMENTED",
      "play is only implemented on iOS right now."
    )
  }

  override fun pause(promise: Promise) {
    promise.reject(
      "UNIMPLEMENTED",
      "pause is only implemented on iOS right now."
    )
  }

  companion object {
    const val NAME = "Wfloat"
  }
}
