import 'package:flutter_test/flutter_test.dart';
import 'package:rect_mm/mm.dart';
import 'package:rect_mm/screen_info.dart';

void main() {
  group('формула мм -> пиксели', () {
    test('25,4 мм при 401 dpi = 401 физический пиксель', () {
      expect(mmToPhysicalPx(25.4, 401), closeTo(401, 1e-9));
    });

    test('25,4 мм при 401 dpi и devicePixelRatio 2,625 = 152,76 логических', () {
      expect(mmToLogicalPx(25.4, 401, 2.625), closeTo(152.76, 0.005));
      expect(physicalToLogicalPx(401, 2.625), closeTo(152.7619, 1e-4));
    });

    test('прямоугольник 30 × 50 мм на OnePlus 5T (401 dpi)', () {
      expect(mmToPhysicalPx(30, 401), closeTo(473.622, 1e-3));
      expect(mmToPhysicalPx(50, 401), closeTo(789.370, 1e-3));
    });

    test('обратный перевод: экран 1080 × 2160 пикселей при 401 dpi', () {
      expect(physicalPxToMm(1080, 401), closeTo(68.409, 1e-3));
      expect(physicalPxToMm(2160, 401), closeTo(136.818, 1e-3));
      expect(physicalPxToMm(mmToPhysicalPx(42.5, 401), 401), closeTo(42.5, 1e-9));
    });
  });

  group('вспомогательные функции', () {
    test('правдоподобие dpi: 100…1000', () {
      expect(isPlausibleDpi(401), isTrue);
      expect(isPlausibleDpi(100), isTrue);
      expect(isPlausibleDpi(1000), isTrue);
      expect(isPlausibleDpi(99.9), isFalse);
      expect(isPlausibleDpi(1000.1), isFalse);
      expect(isPlausibleDpi(0), isFalse);
      expect(isPlausibleDpi(double.nan), isFalse);
    });

    test('шаг 0,5 мм', () {
      expect(roundToStep(30.2, 0.5), 30.0);
      expect(roundToStep(30.3, 0.5), 30.5);
      expect(roundToStep(30.8, 0.5), 31.0);
    });

    test('привязка к сетке пикселей: та же чётность, что у экрана, погрешность <= 1 пикселя', () {
      expect(snapToPixelGrid(473.622, 1080), 474);
      expect(snapToPixelGrid(789.370, 2160), 790);
      for (var px = 10.0; px < 3000; px += 7.3) {
        for (final screen in [1080, 2160, 1081]) {
          final s = snapToPixelGrid(px, screen);
          expect((screen - s.toInt()).isEven, isTrue, reason: 'px=$px screen=$screen');
          expect((s - px).abs(), lessThanOrEqualTo(1.0), reason: 'px=$px screen=$screen');
        }
      }
    });

    test('разбор и вывод чисел', () {
      expect(parseNumber('30,5'), 30.5);
      expect(parseNumber(' 30.5 '), 30.5);
      expect(parseNumber('255'), 255);
      expect(parseNumber(''), isNull);
      expect(parseNumber('abc'), isNull);
      expect(formatMm(30), '30');
      expect(formatMm(30.5), '30,5');
      expect(format1(68.409), '68,4');
    });
  });

  group('ScreenInfo из ответа MainActivity', () {
    test('нормальные xdpi/ydpi', () {
      final i = ScreenInfo.fromMap({
        'xdpi': 401.0,
        'ydpi': 401.0,
        'xdpiRaw': 401.0,
        'ydpiRaw': 401.0,
        'densityDpi': 420.0,
        'widthPx': 1080,
        'heightPx': 2160,
      });
      expect(i.xdpi, 401);
      expect(i.dpiSubstituted, isFalse);
      expect(i.widthMm, closeTo(68.409, 1e-3));
      expect(i.heightMm, closeTo(136.818, 1e-3));
      expect(i.maxWidthMm, 68);
      expect(i.maxHeightMm, 136);
    });

    test('неправдоподобный dpi заменяется на densityDpi', () {
      final i = ScreenInfo.fromMap({
        'xdpi': 50.0,
        'ydpi': 401.0,
        'densityDpi': 420.0,
        'widthPx': 1080,
        'heightPx': 2160,
      });
      expect(i.xdpi, 420);
      expect(i.ydpi, 401);
      expect(i.dpiSubstituted, isTrue);
    });
  });
}
