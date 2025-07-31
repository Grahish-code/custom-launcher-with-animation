// WallpaperPlugin.kt
package com.example.virtual_pet

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import android.view.View
import android.view.Window
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import kotlin.math.pow

class WallpaperPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "WallpaperPlugin"
        private const val SAMPLE_SIZE = 20 // Size to downscale image for analysis
        private const val DARK_THRESHOLD = 0.6 // 60% dark pixels = dark wallpaper
        private const val LUMINANCE_THRESHOLD = 128 // Pixel brightness threshold
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDarkWallpaper" -> {
                try {
                    val byteArray = call.argument<ByteArray>("image")
                    if (byteArray != null) {
                        val isDark = isBitmapDark(byteArray)

                        // Update status bar colors from native side
                        updateStatusBarColors(isDark)

                        Log.d(TAG, "Wallpaper analysis complete: ${if (isDark) "DARK" else "LIGHT"}")
                        result.success(isDark)
                    } else {
                        Log.e(TAG, "Image bytes are null")
                        result.error("NULL_IMAGE", "Image bytes are null", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error analyzing wallpaper: ${e.message}", e)
                    result.error("ANALYSIS_ERROR", "Failed to analyze wallpaper: ${e.message}", null)
                }
            }
            "updateStatusBar" -> {
                try {
                    val isDark = call.argument<Boolean>("isDark") ?: false
                    updateStatusBarColors(isDark)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Error updating status bar: ${e.message}", e)
                    result.error("STATUS_BAR_ERROR", e.message, null)
                }
            }
            else -> {
                Log.w(TAG, "Unknown method: ${call.method}")
                result.notImplemented()
            }
        }
    }

    private fun updateStatusBarColors(isDarkWallpaper: Boolean) {
        try {
            val activity = context as? Activity ?: return
            val window = activity.window

            activity.runOnUiThread {
                // Make status bar transparent
                window.statusBarColor = android.graphics.Color.TRANSPARENT
                window.navigationBarColor = android.graphics.Color.TRANSPARENT

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    // Android 11+ approach
                    val controller = WindowCompat.getInsetsController(window, window.decorView)
                    controller.isAppearanceLightStatusBars = !isDarkWallpaper
                    controller.isAppearanceLightNavigationBars = !isDarkWallpaper
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    // Android 6+ approach
                    var flags = window.decorView.systemUiVisibility

                    if (isDarkWallpaper) {
                        // Dark wallpaper = light icons (remove light status bar flag)
                        flags = flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
                    } else {
                        // Light wallpaper = dark icons (add light status bar flag)
                        flags = flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                    }

                    // Navigation bar for Android 8+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (isDarkWallpaper) {
                            flags = flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv()
                        } else {
                            flags = flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
                        }
                    }

                    window.decorView.systemUiVisibility = flags
                }

                Log.d(TAG, "Native status bar updated: ${if (isDarkWallpaper) "Light icons" else "Dark icons"}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update status bar natively: ${e.message}", e)
        }
    }

    private fun isBitmapDark(imageBytes: ByteArray): Boolean {
        val inputStream = ByteArrayInputStream(imageBytes)
        val originalBitmap = BitmapFactory.decodeStream(inputStream)

        if (originalBitmap == null) {
            Log.e(TAG, "Failed to decode bitmap from bytes")
            return false // Default to light wallpaper
        }

        // Create a small sample bitmap for faster analysis
        val resizedBitmap = try {
            Bitmap.createScaledBitmap(originalBitmap, SAMPLE_SIZE, SAMPLE_SIZE, true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to resize bitmap: ${e.message}")
            originalBitmap.recycle()
            return false
        }

        var darkPixels = 0
        val totalPixels = SAMPLE_SIZE * SAMPLE_SIZE
        var totalLuminance = 0.0

        // Analyze each pixel
        for (x in 0 until SAMPLE_SIZE) {
            for (y in 0 until SAMPLE_SIZE) {
                try {
                    val pixel = resizedBitmap.getPixel(x, y)

                    // Extract RGB values
                    val r = (pixel shr 16) and 0xff
                    val g = (pixel shr 8) and 0xff
                    val b = pixel and 0xff

                    // Calculate luminance using standard formula
                    // ITU-R BT.709 standard for HDTV
                    val luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b)
                    totalLuminance += luminance

                    // Count as dark pixel if below threshold
                    if (luminance < LUMINANCE_THRESHOLD) {
                        darkPixels++
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error reading pixel at ($x, $y): ${e.message}")
                }
            }
        }

        // Clean up memory
        if (resizedBitmap != originalBitmap) {
            resizedBitmap.recycle()
        }
        originalBitmap.recycle()

        // Calculate statistics
        val darkPixelRatio = darkPixels.toDouble() / totalPixels
        val averageLuminance = totalLuminance / totalPixels
        val isDark = darkPixelRatio >= DARK_THRESHOLD

        // Log detailed analysis
        Log.d(TAG, """
            Wallpaper Analysis Results:
            - Total pixels analyzed: $totalPixels
            - Dark pixels: $darkPixels
            - Dark pixel ratio: ${String.format("%.2f", darkPixelRatio * 100)}%
            - Average luminance: ${String.format("%.1f", averageLuminance)}/255
            - Result: ${if (isDark) "DARK" else "LIGHT"} wallpaper
            - Status bar icons should be: ${if (isDark) "LIGHT" else "DARK"}
        """.trimIndent())

        return isDark
    }
}