/// Экран настроек: ширина и длина прямоугольника в мм, цвет R, G, B.
/// Для каждого параметра — ползунок и числовое поле, синхронизированы.
/// Значения живут только в памяти (в состоянии этого экрана).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fullscreen_page.dart';
import 'mm.dart';
import 'screen_info.dart';

/// Параметры экрана настроек. Имя — часть ключей виджетов: slider_<имя>, field_<имя>, error_<имя>.
enum Param { width, length, r, g, b }

/// Шаг размеров, мм.
const double kMmStep = 0.5;

/// Минимальный размер, мм.
const double kMinMm = 1;

/// Верхний предел ввода с клавиатуры, мм (больше экрана можно — прямоугольник обрежется).
const double kMaxInputMm = 1000;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ScreenInfo? _info;

  final Map<Param, double> _v = {
    Param.width: 30,
    Param.length: 50,
    Param.r: 255,
    Param.g: 255,
    Param.b: 255,
  };
  final Map<Param, TextEditingController> _c = {};
  final Map<Param, String?> _err = {};

  @override
  void initState() {
    super.initState();
    for (final p in Param.values) {
      _c[p] = TextEditingController(text: _fmt(p, _v[p]!));
    }
    ScreenInfo.load().then((info) {
      if (mounted) {
        setState(() => _info = info);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  static bool _isMm(Param p) => p == Param.width || p == Param.length;

  static String _fmt(Param p, double v) =>
      _isMm(p) ? formatMm(v) : v.round().toString();

  static double _snap(Param p, double v) =>
      _isMm(p) ? roundToStep(v, kMmStep) : v.roundToDouble();

  static double _min(Param p) => _isMm(p) ? kMinMm : 0.0;

  /// Предел ввода с клавиатуры.
  static double _inputMax(Param p) => _isMm(p) ? kMaxInputMm : 255.0;

  /// Верхняя граница ползунка: для мм — размер экрана по этой оси, округлённый вниз.
  double _sliderMax(Param p, ScreenInfo info) => switch (p) {
        Param.width => info.maxWidthMm,
        Param.length => info.maxHeightMm,
        Param.r || Param.g || Param.b => 255.0,
      };

  static String _label(Param p) => switch (p) {
        Param.width => 'Ширина (горизонталь), мм',
        Param.length => 'Длина (вертикаль), мм',
        Param.r => 'Красный (R), 0–255',
        Param.g => 'Зелёный (G), 0–255',
        Param.b => 'Синий (B), 0–255',
      };

  Color get _color => Color.fromARGB(
        255,
        _v[Param.r]!.round(),
        _v[Param.g]!.round(),
        _v[Param.b]!.round(),
      );

  void _fromSlider(Param p, double x) {
    final v = _snap(p, x);
    setState(() {
      _v[p] = v;
      _err[p] = null;
      _c[p]!.text = _fmt(p, v);
    });
  }

  void _fromField(Param p, String text) {
    final x = parseNumber(text);
    setState(() {
      if (x == null || x < _min(p) || x > _inputMax(p)) {
        _err[p] = _isMm(p)
            ? 'Введите число от ${formatMm(kMinMm)} до ${formatMm(kMaxInputMm)}'
            : 'Введите целое число от 0 до 255';
        return;
      }
      _v[p] = _snap(p, x);
      _err[p] = null;
    });
  }

  /// После ввода — показать принятое значение (округлённое до шага).
  void _normalize(Param p) {
    setState(() {
      _c[p]!.text = _fmt(p, _v[p]!);
      _err[p] = null;
    });
  }

  void _show(ScreenInfo info) {
    FocusScope.of(context).unfocus();
    for (final p in Param.values) {
      _normalize(p);
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenPage(
          widthMm: _v[Param.width]!,
          lengthMm: _v[Param.length]!,
          color: _color,
          xdpi: info.xdpi,
          ydpi: info.ydpi,
        ),
      ),
    );
  }

  Widget _row(Param p, ScreenInfo info) {
    final min = _min(p);
    final max = _sliderMax(p, info);
    final step = _isMm(p) ? kMmStep : 1.0;
    final value = _v[p]!.clamp(min, max).toDouble();
    final err = _err[p];
    final errorColor = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_label(p), style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  key: ValueKey('slider_${p.name}'),
                  value: value,
                  min: min,
                  max: max,
                  divisions: ((max - min) / step).round(),
                  label: _fmt(p, value),
                  onChanged: (x) => _fromSlider(p, x),
                ),
              ),
              SizedBox(
                width: 88,
                child: TextField(
                  key: ValueKey('field_${p.name}'),
                  controller: _c[p],
                  keyboardType: TextInputType.numberWithOptions(decimal: _isMm(p)),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      _isMm(p) ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
                    ),
                  ],
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    error: err != null ? const SizedBox.shrink() : null,
                  ),
                  onChanged: (t) => _fromField(p, t),
                  onSubmitted: (_) => _normalize(p),
                ),
              ),
            ],
          ),
          if (err != null)
            Text(
              err,
              key: ValueKey('error_${p.name}'),
              style: TextStyle(color: errorColor),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: const Text('Прямоугольник мм')),
      body: info == null
          ? const Center(child: CircularProgressIndicator())
          : _body(info),
    );
  }

  Widget _body(ScreenInfo info) {
    final errorColor = Theme.of(context).colorScheme.error;
    final w = _v[Param.width]!;
    final l = _v[Param.length]!;
    final overW = w > info.widthMm;
    final overL = l > info.heightMm;
    final overParts = [if (overW) 'по ширине', if (overL) 'по длине'];
    final screenLine = 'Экран: ${format1(info.widthMm)} × ${format1(info.heightMm)} мм '
        '(xdpi ${format1(info.xdpi)}, ydpi ${format1(info.ydpi)})';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in Param.values) _row(p, info),
          const SizedBox(height: 4),
          Container(
            key: const ValueKey('swatch'),
            height: 48,
            decoration: BoxDecoration(
              color: _color,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Text(screenLine, key: const ValueKey('screen_line')),
          if (info.dpiSubstituted)
            Text(
              'Телефон сообщил неправдоподобные xdpi/ydpi '
              '(${format1(info.xdpiRaw)}, ${format1(info.ydpiRaw)}) — '
              'взят densityDpi ${format1(info.densityDpi)}. Проверьте линейкой.',
              style: TextStyle(color: errorColor),
            ),
          if (!info.fromPhone)
            Text(
              'Нет данных от телефона — размер оценён по devicePixelRatio и может быть неточным.',
              style: TextStyle(color: errorColor),
            ),
          if (overParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Прямоугольник больше экрана ${overParts.join(' и ')} — '
              'в полноэкранном режиме он будет обрезан краями экрана.',
              key: const ValueKey('oversize_warning'),
              style: TextStyle(color: errorColor, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('show'),
            onPressed: () => _show(info),
            child: const Text('Показать'),
          ),
        ],
      ),
    );
  }
}
