package com.vantage.control.vantage_control

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vantage/display")
      .setMethodCallHandler { call, result ->
        if (call.method != "setBrightness") {
          result.notImplemented()
          return@setMethodCallHandler
        }
        val value = (call.argument<Double>("value") ?: -1.0).toFloat()
        runOnUiThread {
          val attrs = window.attributes
          attrs.screenBrightness = value
          window.attributes = attrs
          result.success(null)
        }
      }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vantage/nvr")
      .setMethodCallHandler(NvrPlugin(applicationContext))
    flutterEngine.platformViewsController.registry
      .registerViewFactory("vantage_nvr/surface", NvrSurfaceFactory())
  }
}
