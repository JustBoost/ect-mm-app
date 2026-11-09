/// Перевод миллиметров в пиксели экрана и обратно — чистые функции без Flutter.
///
/// Физические пиксели: phys_px = mm / 25.4 * dpi (dpi — реальная плотность пикселей
/// экрана по этой оси: xdpi по горизонтали, ydpi по вертикали).
/// Логические пиксели Flutter: logical = phys_px / devicePixelRatio.
library;

/// Миллиметров в дюйме.
const double mmPerInch = 25.4;

/// Миллиметры -> физические пиксели экрана при плотности [dpi] (точек на дюйм).
double mmToPhysicalPx(double mm, double dpi) => mm / mmPerInch * dpi;

/// Физические пиксели -> логические пиксели Flutter.
double physicalToLogicalPx(double physicalPx, double devicePixelRatio) =>
    physicalPx / devicePixelRatio;

/// Миллиметры -> логические пиксели Flutter.
double mmToLogicalPx(double mm, double dpi, double devicePixelRatio) =>
    physicalToLogicalPx(mmToPhysicalPx(mm, dpi), devicePixelRatio);

/// Физические пиксели -> миллиметры при плотности [dpi].
double physicalPxToMm(double physicalPx, double dpi) =>
    physicalPx / dpi * mmPerInch;

/// Правдоподобная плотность экрана телефона: 100…1000 точек на дюйм.
bool isPlausibleDpi(double dpi) => !dpi.isNaN && dpi >= 100 && dpi <= 1000;

/// Округление до шага [step] (0,5 мм для размеров).
double roundToStep(double value, double step) => step * (value / step).round();

/// Целое число физических пикселей, ближайшее к [physicalPx], той же чётности,
/// что и размер экрана [screenPx] по этой оси. Тогда прямоугольник по центру
/// ложится ровно на сетку пикселей (резкие края); погрешность — не больше 1 пикселя
/// (≈0,06 мм при 401 dpi).
double snapToPixelGrid(double physicalPx, int screenPx) {
  if (physicalPx <= 0) {
    return 0;
  }
  final n = physicalPx.round();
  if ((screenPx - n).isEven) {
    return n.toDouble();
  }
  final down = n - 1;
  final up = n + 1;
  if (down > 0 && (physicalPx - down).abs() <= (up - physicalPx).abs()) {
    return down.toDouble();
  }
  return up.toDouble();
}

/// Разбор числа из поля ввода: допускается и запятая, и точка. null — не число.
double? parseNumber(String text) {
  final v = double.tryParse(text.trim().replaceAll(',', '.'));
  if (v == null || v.isNaN || v.isInfinite) {
    return null;
  }
  return v;
}

/// Миллиметры для поля ввода: «30», «30,5».
String formatMm(double mm) {
  if (mm == mm.truncateToDouble()) {
    return mm.toInt().toString();
  }
  return mm.toStringAsFixed(1).replaceAll('.', ',');
}

/// Число с одним знаком после запятой: «68,4».
String format1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
