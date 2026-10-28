package com.mferman.wordsandmonsters

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Canal para que el juego (Dart) pida vibraciones al teléfono.
    // Se usa el motor de vibración real: más fuerte y fiable que el "toque"
    // de botones, que muchos teléfonos traen desactivado.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wordsandmonsters/vibration")
            .setMethodCallHandler { call, result ->
                if (call.method == "vibrate") {
                    val ms = (call.argument<Int>("ms") ?: 60).toLong()
                    val amplitude = call.argument<Int>("amplitude") ?: 200
                    vibrate(ms, amplitude)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun vibrate(ms: Long, amplitude: Int) {
        val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(ms, amplitude.coerceIn(1, 255)))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(ms)
        }
    }
}
