package com.example.virtual_pet

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream

class LaunchableAppsPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "launchable_apps")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getLaunchableApps" -> {
                Thread {
                    try {
                        val apps = getLaunchableApps()
                        // Run on main thread for result
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.success(apps)
                        }
                    } catch (e: Exception) {
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.error("ERROR", "Failed: ${e.message}", null)
                        }
                    }
                }.start()
            }
            "launchApp" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    try {
                        val intent = context.packageManager.getLaunchIntentForPackage(packageName)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("ERROR", "App not found", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Launch failed: ${e.message}", null)
                    }
                } else {
                    result.error("ERROR", "Package name is null", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    // get a sorted list of all launch able apps in the android
    private fun getLaunchableApps(): List<Map<String, Any>> {

        // the below line is the main tool for getting app info , QueryInstalled pacakages , getting icons and label
        val packageManager = context.packageManager
        // the below 2 line is responsible for for finding all the app with launchable main activities
        //This combo filters out things like background services, broadcast receivers, etc. — only real user-visible apps will be matched.
        // by applying below filter i just get the name or category of launchable apps , not there infor that i will get when i match them form pacaketmanager
        val intent = Intent(Intent.ACTION_MAIN, null)
        intent.addCategory(Intent.CATEGORY_LAUNCHER)

        //Asks PackageManager for all activities that match the intent above.
        //Returns a list of ResolveInfo objects — one for each launchable app activity.(means giving me the full info of those apps which are launchable )
        val activities = packageManager.queryIntentActivities(intent, 0)
        //Initializes an empty list to store each app’s data in a Map<String, Any> for
        val apps = mutableListOf<Map<String, Any>>()

        for (activity in activities) {
            try {
                val packageName = activity.activityInfo.packageName ?: continue
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                val appName = packageManager.getApplicationLabel(appInfo)?.toString() ?: "Unknown"

                // Get icon safely
                val iconBytes = try {
                    val icon = packageManager.getApplicationIcon(packageName)
                    drawableToByteArray(icon)
                } catch (e: Exception) {
                    createDefaultIcon()
                }

                apps.add(mapOf(
                    "appName" to appName,
                    "packageName" to packageName,
                    "icon" to iconBytes
                ))
            } catch (e: Exception) {
                // Skip problematic apps
                continue
            }
        }

        return apps.sortedBy { it["appName"] as String }
    }

    private fun drawableToByteArray(drawable: Drawable?): ByteArray {
        if (drawable == null) return createDefaultIcon()

        return try {
            val bitmap = when {
                drawable is BitmapDrawable && drawable.bitmap != null -> drawable.bitmap
                else -> {
                    val width = maxOf(drawable.intrinsicWidth, 48)
                    val height = maxOf(drawable.intrinsicHeight, 48)
                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bitmap)
                    drawable.setBounds(0, 0, width, height)
                    drawable.draw(canvas)
                    bitmap
                }
            }

            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            createDefaultIcon()
        }
    }

    private fun createDefaultIcon(): ByteArray {
        val bitmap = Bitmap.createBitmap(48, 48, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.GRAY)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
        return stream.toByteArray()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}