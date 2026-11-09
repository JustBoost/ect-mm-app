// Имя файла widget_test.dart выбрано намеренно: страховочный `flutter create .` в CI
// не пишет поверх существующих файлов и не добавит свой шаблонный тест со счётчиком.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rect_mm/main.dart';
import 'package:rect_mm/mm.dart';
import 'package:rect_mm/screen_info.dart';

const double kDpi = 401;
const double kDpr = 2.625;

/// Телефон OnePlus 5T: экран 1080 × 2160, 401 dpi, devicePixelRatio 2,625; ответ MainActivity замокан.
Future<List<MethodCall>> _setUpPhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = kDpr;
  addTearDown(tester.view.reset);
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(ScreenInfo.channel, (call) async {
    calls.add(call);
    if (call.method == 'getMetrics') {
      return <String, Object>{
        'xdpi': kDpi,
        'ydpi': kDpi,
        'xdpiRaw': kDpi,
        'ydpiRaw': kDpi,
        'densityDpi': 420.0,
        'widthPx': 1080,
        'heightPx': 2160,
      };
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(ScreenInfo.channel, null));
  await tester.pumpWidget(const RectApp());
  await tester.pumpAndSettle();
  return calls;
}

Finder _key(String k) => find.byKey(ValueKey(k));

double _slider(WidgetTester tester, String id) => tester.widget<Slider>(_key('slider_$id')).value;

String _field(WidgetTester tester, String id) => tester.widget<TextField>(_key('field_$id')).controller!.text;

Color _boxColor(WidgetTester tester, String k) => tester.widget<ColoredBox>(_key(k)).color;

Color _swatchColor(WidgetTester tester) =>
    (tester.widget<Container>(_key('swatch')).decoration! as BoxDecoration).color!;

void main() {
  testWidgets('настройки: умолчания, строка экрана, синхронизация полей и ползунков', (tester) async {
    final calls = await _setUpPhone(tester);
    expect(calls.map((c) => c.method), contains('getMetrics'));

    expect(find.text('Ширина (горизонталь), мм'), findsOneWidget);
    expect(find.text('Длина (вертикаль), мм'), findsOneWidget);
    expect(find.text('Показать'), findsOneWidget);
    expect(find.text('Экран: 68,4 × 136,8 мм (xdpi 401,0, ydpi 401,0)'), findsOneWidget);

    // умолчания 30 × 50 мм, цвет 255,255,255
    expect(_field(tester, 'width'), '30');
    expect(_field(tester, 'length'), '50');
    expect(_slider(tester, 'width'), 30);
    expect(_slider(tester, 'length'), 50);
    for (final c in ['r', 'g', 'b']) {
      expect(_field(tester, c), '255');
      expect(_slider(tester, c), 255);
    }
    expect(_swatchColor(tester), const Color.fromARGB(255, 255, 255, 255));

    // диапазон ползунков мм: 1…размер экрана, округлённый вниз; шаг 0,5
    final w = tester.widget<Slider>(_key('slider_width'));
    expect(w.min, 1);
    expect(w.max, 68);
    expect(w.divisions, 134);
    expect(tester.widget<Slider>(_key('slider_length')).max, 136);

    // поле -> ползунок (запятая и точка, округление до 0,5 мм)
    await tester.enterText(_key('field_width'), '40');
    await tester.pump();
    expect(_slider(tester, 'width'), 40);
    await tester.enterText(_key('field_length'), '55,3');
    await tester.pump();
    expect(_slider(tester, 'length'), 55.5);

    // ползунок -> поле
    tester.widget<Slider>(_key('slider_length')).onChanged!(60.5);
    await tester.pump();
    expect(_field(tester, 'length'), '60,5');
    expect(_slider(tester, 'length'), 60.5);

    // настоящее перетаскивание ползунка G до упора влево -> 0
    await tester.ensureVisible(_key('slider_g'));
    await tester.drag(_key('slider_g'), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(_slider(tester, 'g'), 0);
    expect(_field(tester, 'g'), '0');

    // поле B -> ползунок; неверное значение R не принимается
    await tester.enterText(_key('field_b'), '0');
    await tester.pump();
    expect(_slider(tester, 'b'), 0);
    await tester.enterText(_key('field_r'), '300');
    await tester.pump();
    expect(_key('error_r'), findsOneWidget);
    expect(_slider(tester, 'r'), 255);
    await tester.enterText(_key('field_r'), '255');
    await tester.pump();
    expect(_key('error_r'), findsNothing);

    expect(_swatchColor(tester), const Color.fromARGB(255, 255, 0, 0));
    expect(_key('oversize_warning'), findsNothing);
  });

  testWidgets('«Показать»: чёрный фон, прямоугольник нужного цвета и размера по центру; касание — назад', (tester) async {
    final calls = await _setUpPhone(tester);

    await tester.enterText(_key('field_width'), '40');
    await tester.enterText(_key('field_length'), '60,5');
    await tester.enterText(_key('field_g'), '0');
    await tester.enterText(_key('field_b'), '128');
    await tester.pump();

    await tester.ensureVisible(_key('show'));
    await tester.tap(_key('show'));
    await tester.pumpAndSettle();

    expect(_boxColor(tester, 'fullscreen'), Colors.black);
    expect(_boxColor(tester, 'rect'), const Color.fromARGB(255, 255, 0, 128));
    final full = tester.getSize(_key('fullscreen'));
    expect(full.width, closeTo(1080 / kDpr, 1e-6));
    expect(full.height, closeTo(2160 / kDpr, 1e-6));

    // размер: mm / 25.4 * 401 / 2.625 логических (с точностью до 1 физического пикселя)
    final size = tester.getSize(_key('rect'));
    expect(size.width, closeTo(mmToLogicalPx(40, kDpi, kDpr), 1 / kDpr + 1e-9));
    expect(size.height, closeTo(mmToLogicalPx(60.5, kDpi, kDpr), 1 / kDpr + 1e-9));
    // по центру
    final screen = tester.getRect(_key('fullscreen'));
    expect(tester.getCenter(_key('rect')).dx, closeTo(screen.center.dx, 1e-6));
    expect(tester.getCenter(_key('rect')).dy, closeTo(screen.center.dy, 1e-6));
    expect(calls.where((c) => c.method == 'keepScreenOn').map((c) => c.arguments), contains(true));

    // касание у края экрана — назад к настройкам с прежними значениями
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(_key('fullscreen'), findsNothing);
    expect(_key('show'), findsOneWidget);
    expect(_field(tester, 'width'), '40');
    expect(_field(tester, 'length'), '60,5');
    expect(_field(tester, 'b'), '128');
    expect(calls.where((c) => c.method == 'keepScreenOn').map((c) => c.arguments), contains(false));
  });

  testWidgets('больше экрана: предупреждение красным, в полноэкранном режиме — обрезка без масштабирования', (tester) async {
    await _setUpPhone(tester);

    await tester.enterText(_key('field_width'), '100');
    await tester.pump();
    expect(_key('oversize_warning'), findsOneWidget);
    expect(find.textContaining('по ширине'), findsOneWidget);
    // ползунок упирается в край диапазона, значение в поле — введённое
    expect(_slider(tester, 'width'), 68);
    expect(_field(tester, 'width'), '100');

    await tester.ensureVisible(_key('show'));
    await tester.tap(_key('show'));
    await tester.pumpAndSettle();

    final screen = tester.getSize(_key('fullscreen'));
    final rect = tester.getSize(_key('rect'));
    expect(rect.width, closeTo(mmToLogicalPx(100, kDpi, kDpr), 1 / kDpr + 1e-9));
    expect(rect.width, greaterThan(screen.width));

    // системная кнопка «Назад»: то же сообщение, что присылает Android
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(_key('fullscreen'), findsNothing);
    expect(_field(tester, 'width'), '100');
  });
}
