package com.andrey.rect_mm

import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Пакет com.andrey.rect_mm = namespace в android/app/build.gradle и путь, который сгенерировал бы
// `flutter create --org com.andrey --project-name rect_mm` (страховочный шаг CI этот файл не трогает).
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Канал lib/screen_info.dart: реальная плотность пикселей экрана и не гасить экран.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rect_mm/screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMetrics" -> result.success(screenMetrics())
                    "keepScreenOn" -> {
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // xdpi/ydpi — физическая плотность пикселей по горизонтали/вертикали, как её сообщает телефон.
    // Если значение явно неправдоподобно (<100 или >1000, бывает на части прошивок) — берём densityDpi.
    // widthPx/heightPx — полный экран в пикселях (getRealMetrics: вместе с областью системных панелей).
    @Suppress("DEPRECATION")
    private fun screenMetrics(): Map<String, Any> {
        val dm = resources.displayMetrics
        val real = DisplayMetrics()
        windowManager.defaultDisplay.getRealMetrics(real)
        val density = dm.densityDpi.toDouble()
        val xRaw = dm.xdpi.toDouble()
        val yRaw = dm.ydpi.toDouble()
        return mapOf(
            "xdpi" to (if (plausible(xRaw)) xRaw else density),
            "ydpi" to (if (plausible(yRaw)) yRaw else density),
            "xdpiRaw" to xRaw,
            "ydpiRaw" to yRaw,
            "densityDpi" to density,
            "widthPx" to real.widthPixels,
            "heightPx" to real.heightPixels,
        )
    }

    private fun plausible(v: Double): Boolean = !v.isNaN() && v >= 100.0 && v <= 1000.0
}
