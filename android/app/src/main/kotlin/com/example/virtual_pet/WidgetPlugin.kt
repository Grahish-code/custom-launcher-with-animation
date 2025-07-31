package com.example.virtual_pet

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.appwidget.AppWidgetHostView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class WidgetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    ActivityAware, PluginRegistry.ActivityResultListener {

    private lateinit var context: Context
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private lateinit var appWidgetManager: AppWidgetManager
    private lateinit var appWidgetHost: AppWidgetHost

    private val BIND_REQUEST_CODE = 9001
    private val pendingBindRequests = mutableMapOf<Int, MethodChannel.Result>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.example.virtual_pet/widgets")
        channel?.setMethodCallHandler(this)

        appWidgetManager = AppWidgetManager.getInstance(context)
        appWidgetHost = AppWidgetHost(context, 1024)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailableWidgets" -> {
                val providers = appWidgetManager.installedProviders
                val list = providers.map {
                    mapOf(
                        "packageName" to it.provider.packageName,
                        "className" to it.provider.className,
                        "label" to it.label,
                        "minWidth" to it.minWidth,
                        "minHeight" to it.minHeight,
                        "minResizeWidth" to it.minResizeWidth,
                        "minResizeHeight" to it.minResizeHeight,
                        "resizeMode" to it.resizeMode,
                        "widgetCategory" to it.widgetCategory
                    )
                }
                result.success(list)
            }

            "pickWidget" -> {
                val widgetId = appWidgetHost.allocateAppWidgetId()
                val pickIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_PICK)
                pickIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                (activity as? Activity)?.startActivityForResult(pickIntent, 1025)
                result.success(widgetId)
            }

            "addWidget" -> {
                val packageName = call.argument<String>("packageName")
                val className = call.argument<String>("className")
                val width = call.argument<Int>("width") ?: 300
                val height = call.argument<Int>("height") ?: 200

                val provider = ComponentName(packageName!!, className!!)
                val widgetId = appWidgetHost.allocateAppWidgetId()

                if (appWidgetManager.bindAppWidgetIdIfAllowed(widgetId, provider)) {
                    finalizeWidget(widgetId, width, height, result)
                } else {
                    pendingBindRequests[widgetId] = result

                    val bindIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, provider)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER_PROFILE, provider)
                        }
                    }

                    (activity as? Activity)?.startActivityForResult(bindIntent, BIND_REQUEST_CODE)
                }
            }

            "getWidgetView" -> {
                val widgetId = call.argument<Int>("widgetId") ?: return result.error("INVALID", "Missing widgetId", null)
                val width = call.argument<Int>("width") ?: 300
                val height = call.argument<Int>("height") ?: 200

                try {
                    val bytes = captureWidgetBitmap(widgetId, width, height)
                    result.success(
                        mapOf(
                            "widgetId" to widgetId,
                            "imageBytes" to bytes,
                            "width" to width,
                            "height" to height
                        )
                    )
                } catch (e: Exception) {
                    Log.e("WidgetPlugin", "Error getting widget view", e)
                    result.error("ERROR", "Failed to get widget view: ${e.message}", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun finalizeWidget(widgetId: Int, width: Int, height: Int, result: MethodChannel.Result?) {
        val views = appWidgetManager.getAppWidgetInfo(widgetId)?.configure
        try {
            appWidgetManager.updateAppWidget(widgetId, RemoteViews(context.packageName, android.R.layout.simple_list_item_1))
            result?.success(
                mapOf(
                    "widgetId" to widgetId,
                    "success" to true,
                    "needsPermission" to false,
                    "width" to width,
                    "height" to height
                )
            )
        } catch (e: Exception) {
            Log.e("WidgetPlugin", "❌ Failed to add widget", e)
            result?.success(
                mapOf(
                    "widgetId" to widgetId,
                    "success" to false,
                    "needsPermission" to false,
                    "width" to width,
                    "height" to height
                )
            )
        }
    }

    private fun captureWidgetBitmap(widgetId: Int, width: Int, height: Int): ByteArray {
        if (width <= 0 || height <= 0) throw IllegalArgumentException("width and height must be > 0")

        val hostView = appWidgetHost.createView(context, widgetId, appWidgetManager.getAppWidgetInfo(widgetId))
        hostView.setAppWidget(widgetId, appWidgetManager.getAppWidgetInfo(widgetId))
        hostView.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        )
        hostView.layout(0, 0, width, height)

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        hostView.draw(canvas)

        val outputStream = java.io.ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        return outputStream.toByteArray()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == BIND_REQUEST_CODE) {
            val widgetId = data?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1) ?: -1
            val result = pendingBindRequests.remove(widgetId)
            val width = 300
            val height = 200

            if (resultCode == Activity.RESULT_OK && widgetId != -1) {
                finalizeWidget(widgetId, width, height, result)
            } else {
                result?.success(
                    mapOf(
                        "widgetId" to widgetId,
                        "success" to false,
                        "needsPermission" to true,
                        "width" to width,
                        "height" to height
                    )
                )
            }
            return true
        }
        return false
    }
}
