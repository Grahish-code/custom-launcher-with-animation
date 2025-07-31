// MainActivity.kt
package com.example.virtual_pet

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    companion object {
        private const val WALLPAPER_CHANNEL = "com.example.virtual_pet/wallpaper"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Register your existing app launcher plugin
        flutterEngine.plugins.add(LaunchableAppsPlugin())

        // Register the new wallpaper analysis plugin
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WALLPAPER_CHANNEL)
            .setMethodCallHandler(WallpaperPlugin(this))

        flutterEngine.plugins.add(WidgetPlugin())
    }
}