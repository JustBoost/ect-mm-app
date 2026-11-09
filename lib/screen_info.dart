/// Реальная плотность пикселей и размер экрана — из MainActivity.kt через MethodChannel.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'mm.dart';

class ScreenInfo {
  const ScreenInfo({
    required this.xdpi,
    required this.ydpi,
    required this.xdpiRaw,
    required this.ydpiRaw,
    required this.densityDpi,
    required this.widthPx,
    required this.heightPx,
    required this.fromPhone,
  });

  /// Плотность по горизонтали и вертикали, которой пользуемся (точек на дюйм).
  final double xdpi;
  final double ydpi;

  /// Что сообщил телефон (displayMetrics.xdpi/ydpi) до проверки правдоподобия.
  final double xdpiRaw;
  final double ydpiRaw;

  /// Обобщённая плотность Android (displayMetrics.densityDpi) — запасное значение.
  final double densityDpi;

  /// Полный экран в физических пикселях (портрет): ширина и высота.
  final int widthPx;
  final int heightPx;

  /// false — платформенная часть не ответила, значения оценены по devicePixelRatio.
  final bool fromPhone;

  static const MethodChannel channel = MethodChannel('rect_mm/screen');

  /// Физическая ширина экрана (по горизонтали), мм.
  double get widthMm => physicalPxToMm(widthPx.toDouble(), xdpi);

  /// Физическая высота экрана (по вертикали), мм.
  double get heightMm => physicalPxToMm(heightPx.toDouble(), ydpi);

  /// Верхняя граница ползунка: размер экрана, округлённый вниз до целого мм.
  double get maxWidthMm => _atLeast2(widthMm.floorToDouble());
  double get maxHeightMm => _atLeast2(heightMm.floorToDouble());

  /// xdpi/ydpi от телефона неправдоподобны — подставлен densityDpi.
  bool get dpiSubstituted => xdpi != xdpiRaw || ydpi != ydpiRaw;

  static double _atLeast2(double v) => v < 2 ? 2 : v;

  factory ScreenInfo.fromMap(Map<String, Object?> m) {
    double d(String k) => (m[k] as num).toDouble();
    final density = d('densityDpi');
    final x = d('xdpi');
    final y = d('ydpi');
    return ScreenInfo(
      // повторная проверка (то же правило, что в MainActivity.kt)
      xdpi: isPlausibleDpi(x) ? x : density,
      ydpi: isPlausibleDpi(y) ? y : density,
      xdpiRaw: m.containsKey('xdpiRaw') ? d('xdpiRaw') : x,
      ydpiRaw: m.containsKey('ydpiRaw') ? d('ydpiRaw') : y,
      densityDpi: density,
      widthPx: (m['widthPx'] as num).toInt(),
      heightPx: (m['heightPx'] as num).toInt(),
      fromPhone: true,
    );
  }

  /// Без платформенной части: dpi = 160 × devicePixelRatio (определение логического пикселя Android).
  static ScreenInfo fallback() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final dpr = view?.devicePixelRatio ?? 1.0;
    final size = view?.physicalSize ?? Size.zero;
    final dpi = 160.0 * dpr;
    return ScreenInfo(
      xdpi: dpi,
      ydpi: dpi,
      xdpiRaw: dpi,
      ydpiRaw: dpi,
      densityDpi: dpi,
      widthPx: size.width.round(),
      heightPx: size.height.round(),
      fromPhone: false,
    );
  }

  static Future<ScreenInfo> load() async {
    try {
      final m = await channel.invokeMapMethod<String, Object?>('getMetrics');
      if (m != null) {
        return ScreenInfo.fromMap(m);
      }
    } catch (_) {
      // нет платформенной части или неожиданный ответ — оценка ниже
    }
    return fallback();
  }

  /// Не гасить экран, пока показан прямоугольник. Ошибка канала не критична.
  static Future<void> keepScreenOn(bool on) async {
    try {
      await channel.invokeMethod<void>('keepScreenOn', on);
    } catch (_) {
      // нет платформенной части (тесты) — не критично
    }
  }
}
