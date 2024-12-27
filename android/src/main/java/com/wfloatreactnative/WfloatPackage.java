package com.wfloatreactnative;

import androidx.annotation.Nullable;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.module.model.ReactModuleInfoProvider;
import com.facebook.react.BaseReactPackage;

import java.util.Collections;
import java.util.List;

public class WfloatPackage extends BaseReactPackage {

  @Nullable
  @Override
  public NativeModule getModule(String name, ReactApplicationContext reactContext) {
          return null;
  }

  @Override
  public ReactModuleInfoProvider getReactModuleInfoProvider() {
      return null;
  }
}