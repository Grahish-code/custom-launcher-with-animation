// WorkingWidgetPlugin.kt
// This implementation works WITHOUT system permissions
package com.example.virtual_pet

import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.util.concurrent.ConcurrentHashMap

class WorkingWidgetPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: android.app.Activity? = null
    private var binding: ActivityPluginBinding? = null

    // Widget management
    private lateinit var appWidgetManager: AppWidgetManager
    private var appWidgetHost: AppWidgetHost? = null
    private val widgetViews = ConcurrentHashMap<Int, AppWidgetHostView>()
    private var hostId = 12345
    private var pendingResult: Result? = null

    companion object {
        private const val CHANNEL = "com.example.virtual_pet/working_widgets"
        private const val REQUEST_PICK_APPWIDGET = 9
        private const val REQUEST_CREATE_APPWIDGET = 10
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        appWidgetManager = AppWidgetManager.getInstance(context)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stopListening()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        this.activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initializeWidgetHost" -> {
                hostId = call.argument<Int>("hostId") ?: 12345
                result.success(initializeWidgetHost())
            }
            "startListening" -> {
                result.success(startListening())
            }
            "stopListening" -> {
                result.success(stopListening())
            }
            "addWidgetFromPicker" -> {
                addWidgetFromPicker(result)
            }
            "getActiveWidgets" -> {
                result.success(getActiveWidgets())
            }
            "captureWidget" -> {
                val appWidgetId = call.argument<Int>("appWidgetId")
                val width = call.argument<Int>("width") ?: 320
                val height = call.argument<Int>("height") ?: 180
                if (appWidgetId != null) {
                    result.success(captureWidget(appWidgetId, width, height))
                } else {
                    result.error("INVALID_PARAMS", "Missing appWidgetId", null)
                }
            }
            "removeWidget" -> {
                val appWidgetId = call.argument<Int>("appWidgetId")
                if (appWidgetId != null) {
                    result.success(removeWidget(appWidgetId))
                } else {
                    result.error("INVALID_PARAMS", "Missing appWidgetId", null)
                }
            }
            "canBindWidgets" -> {
                result.success(canBindWidgets())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeWidgetHost(): Boolean {
        return try {
            if (appWidgetHost == null) {
                appWidgetHost = AppWidgetHost(context, hostId)
            }
            println("✅ Widget host initialized with ID: $hostId")
            true
        } catch (e: Exception) {
            println("❌ Error initializing widget host: $e")
            false
        }
    }

    private fun startListening(): Boolean {
        return try {
            appWidgetHost?.startListening()
            println("✅ Widget host started listening")
            true
        } catch (e: Exception) {
            println("❌ Error starting widget host: $e")
            false
        }
    }

    private fun stopListening(): Boolean {
        return try {
            appWidgetHost?.stopListening()
            widgetViews.clear()
            println("✅ Widget host stopped listening")
            true
        } catch (e: Exception) {
            println("❌ Error stopping widget host: $e")
            false
        }
    }

    private fun addWidgetFromPicker(result: Result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        try {
            pendingResult = result

            // Allocate a new widget ID
            val appWidgetId = appWidgetHost?.allocateAppWidgetId()
            if (appWidgetId == null) {
                result.error("ALLOCATION_FAILED", "Failed to allocate widget ID", null)
                return
            }

            println("🎯 Allocated widget ID: $appWidgetId")

            // Create intent to pick widget
            val pickIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_PICK).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }

            // Start the picker activity
            activity?.startActivityForResult(pickIntent, REQUEST_PICK_APPWIDGET)
            println("📱 Started widget picker activity")

        } catch (e: Exception) {
            println("❌ Error launching widget picker: $e")
            result.error("PICKER_ERROR", "Failed to launch widget picker: ${e.message}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_PICK_APPWIDGET -> {
                return handleWidgetPickResult(resultCode, data)
            }
            REQUEST_CREATE_APPWIDGET -> {
                return handleWidgetConfigResult(resultCode, data)
            }
        }
        return false
    }

    private fun handleWidgetPickResult(resultCode: Int, data: Intent?): Boolean {
        if (resultCode == android.app.Activity.RESULT_CANCELED) {
            println("❌ Widget picker cancelled")
            pendingResult?.success(mapOf(
                "success" to false,
                "message" to "Widget selection cancelled"
            ))
            pendingResult = null
            return true
        }

        if (resultCode != android.app.Activity.RESULT_OK || data == null) {
            println("❌ Widget picker failed")
            pendingResult?.success(mapOf(
                "success" to false,
                "message" to "Widget selection failed"
            ))
            pendingResult = null
            return true
        }

        val appWidgetId = data.getIntExtraIdFromHost(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        if (appWidgetId == -1) {
            println("❌ Invalid widget ID received")
            pendingResult?.success(mapOf(
                "success" to false,
                "message" to "Invalid widget ID"
            ))
            pendingResult = null
            return true
        }

        // Check if the widget needs configuration
        val appWidgetInfo = appWidgetManager.getAppWidgetInfo(appWidgetId)
        if (appWidgetInfo?.configure != null) {
            // Widget needs configuration
            println("🔧 Widget needs configuration, launching config activity")
            launchWidgetConfiguration(appWidgetId, appWidgetInfo.configure)
        } else {
            // Widget is ready to use
            println("✅ Widget ready, creating view")
            createWidgetView(appWidgetId, appWidgetInfo)
        }

        return true
    }

    private fun launchWidgetConfiguration(appWidgetId: Int, configComponent: ComponentName) {
        try {
            val configIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE).apply {
                component = configComponent
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            activity?.startActivityForResult(configIntent, REQUEST_CREATE_APPWIDGET)
        } catch (e: Exception) {
            println("❌ Error launching widget configuration: $e")
            // Try to create widget without configuration
            createWidgetView(appWidgetId, appWidgetManager.getAppWidgetInfo(appWidgetId))
        }
    }

    private fun handleWidgetConfigResult(resultCode: Int, data: Intent?): Boolean {
        if (resultCode == android.app.Activity.RESULT_CANCELED) {
            println("❌ Widget configuration cancelled")
            pendingResult?.success(mapOf(
                "success" to false,
                "message" to "Widget configuration cancelled"
            ))
            pendingResult = null
            return true
        }

        val appWidgetId = data?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1) ?: -1
        if (appWidgetId != -1) {
            val appWidgetInfo = appWidgetManager.getAppWidgetInfo(appWidgetId)
            createWidgetView(appWidgetId, appWidgetInfo)
        }

        return true
    }

    private fun createWidgetView(appWidgetId: Int, appWidgetInfo: AppWidgetProviderInfo?) {
        try {
            if (appWidgetInfo == null) {
                println("❌ No widget info available for ID: $appWidgetId")
                pendingResult?.success(mapOf(
                    "success" to false,
                    "message" to "Widget info not available"
                ))
                pendingResult = null
                return
            }

            // Create the widget host view
            val hostView = appWidgetHost?.createView(context, appWidgetId, appWidgetInfo)
            if (hostView != null) {
                widgetViews[appWidgetId] = hostView
                println("✅ Created widget view for ID: $appWidgetId")

                pendingResult?.success(mapOf(
                    "success" to true,
                    "message" to "Widget added successfully",
                    "appWidgetId" to appWidgetId,
                    "widgetLabel" to (appWidgetInfo.label ?: "Unknown Widget"),
                    "packageName" to appWidgetInfo.provider.packageName
                ))
            } else {
                println("❌ Failed to create widget view")
                pendingResult?.success(mapOf(
                    "success" to false,
                    "message" to "Failed to create widget view"
                ))
            }
        } catch (e: Exception) {
            println("❌ Error creating widget view: $e")
            pendingResult?.success(mapOf(
                "success" to false,
                "message" to "Error creating widget: ${e.message}"
            ))
        }

        pendingResult = null
    }

    private fun getActiveWidgets(): List<Map<String, Any>> {
        return try {
            val widgets = mutableListOf<Map<String, Any>>()

            widgetViews.forEach { (appWidgetId, hostView) ->
                val appWidgetInfo = appWidgetManager.getAppWidgetInfo(appWidgetId)
                if (appWidgetInfo != null) {
                    widgets.add(mapOf(
                        "appWidgetId" to appWidgetId,
                        "label" to (appWidgetInfo.label ?: "Unknown Widget"),
                        "packageName" to appWidgetInfo.provider.packageName,
                        "className" to appWidgetInfo.provider.className,
                        "minWidth" to appWidgetInfo.minWidth,
                        "minHeight" to appWidgetInfo.minHeight,
                        "isConfigured" to true
                    ))
                }
            }

            println("📱 Found ${widgets.size} active widgets")
            widgets
        } catch (e: Exception) {
            println("❌ Error getting active widgets: $e")
            emptyList()
        }
    }

    private fun captureWidget(appWidgetId: Int, width: Int, height: Int): Map<String, Any>? {
        return try {
            val hostView = widgetViews[appWidgetId]
            if (hostView == null) {
                println("❌ Widget view not found for ID: $appWidgetId")
                return null
            }

            // Measure and layout the view
            val widthMeasureSpec = android.view.View.MeasureSpec.makeMeasureSpec(width, android.view.View.MeasureSpec.EXACTLY)
            val heightMeasureSpec = android.view.View.MeasureSpec.makeMeasureSpec(height, android.view.View.MeasureSpec.EXACTLY)

            hostView.measure(widthMeasureSpec, heightMeasureSpec)
            hostView.layout(0, 0, hostView.measuredWidth, hostView.measuredHeight)

            // Create bitmap and draw the view
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            hostView.draw(canvas)

            // Convert bitmap to byte array
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            val imageBytes = outputStream.toByteArray()

            println("✅ Captured widget $appWidgetId as bitmap (${imageBytes.size} bytes)")

            mapOf(
                "appWidgetId" to appWidgetId,
                "imageBytes" to imageBytes,
                "width" to width,
                "height" to height,
                "isValid" to true
            )
        } catch (e: Exception) {
            println("❌ Error capturing widget $appWidgetId: $e")
            null
        }
    }

    private fun removeWidget(appWidgetId: Int): Boolean {
        return try {
            // Remove from host
            appWidgetHost?.deleteAppWidgetId(appWidgetId)

            // Remove from our tracking
            widgetViews.remove(appWidgetId)

            println("✅ Removed widget: $appWidgetId")
            true
        } catch (e: Exception) {
            println("❌ Error removing widget $appWidgetId: $e")
            false
        }
    }

    private fun canBindWidgets(): Boolean {
        return appWidgetManager.isRequestPinAppWidgetSupported
    }

    // Extension function to safely get int extra
    private fun Intent.getIntExtraIdFromHost(name: String, defaultValue: Int): Int {
        return try {
            getIntExtra(name, defaultValue)
        } catch (e: Exception) {
            defaultValue
        }
    }
}