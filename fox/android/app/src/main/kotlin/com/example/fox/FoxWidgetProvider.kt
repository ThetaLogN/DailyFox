package com.example.fox

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.example.fox.R // Explicit import for R

class FoxWidgetProvider : AppWidgetProvider() {
    companion object {
        const val CHANNEL = "com.example.fox/widget"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        // Initialize Flutter engine
        val flutterEngine = FlutterEngine(context)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        // Set up platform channel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val sharedPrefs = context.getSharedPreferences("FoxAppPrefs", Context.MODE_PRIVATE)
        val rating = sharedPrefs.getInt("rating", 7)
        val animationPhase = (System.currentTimeMillis() / 5000 % 6).toInt()

        // Call Flutter to generate widget UI as a bitmap
        channel.invokeMethod("getWidgetBitmap", mapOf("rating" to rating, "animationPhase" to animationPhase), object : MethodChannel.Result {
            override fun success(result: Any?) {
                val bytes = result as? ByteArray
                if (bytes != null) {
                    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    val views = RemoteViews(context.packageName, R.layout.widget_layout) // Line 43
                    views.setImageViewBitmap(R.id.widget_image, bitmap) // Line 44
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
                flutterEngine.destroy()
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                Log.e("FoxWidgetProvider", "Error getting bitmap: $errorMessage")
                flutterEngine.destroy()
            }

            override fun notImplemented() {
                Log.e("FoxWidgetProvider", "Method not implemented")
                flutterEngine.destroy()
            }
        })
    }
}