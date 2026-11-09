/// Полноэкранный режим: чёрный фон, системные панели скрыты, прямоугольник заданного
/// физического размера и цвета строго по центру. Касание или «Назад» — к настройкам.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mm.dart';
import 'screen_info.dart';

class FullscreenPage extends StatefulWidget {
  const FullscreenPage({
    super.key,
    required this.widthMm,
    required this.lengthMm,
    required this.color,
    required this.xdpi,
    required this.ydpi,
  });

  /// Ширина — по горизонтали экрана, мм.
  final double widthMm;

  /// Длина — по вертикали экрана, мм.
  final double lengthMm;
  final Color color;
  final double xdpi;
  final double ydpi;

  @override
  State<FullscreenPage> createState() => _FullscreenPageState();
}

/// Пауза перед повторным скрытием системных панелей. Android не даёт скрыть их примерно 1 с
/// после закрытия клавиатуры (ввод числа -> сразу «Показать»), поэтому скрываем ещё раз.
const Duration kHideBarsRetryDelay = Duration(milliseconds: 1200);

class _FullscreenPageState extends State<FullscreenPage> with WidgetsBindingObserver {
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hideBars();
    _scheduleHideBars();
    _safe(() => SystemChrome.setSystemUIChangeCallback(_onSystemUiChange));
    ScreenInfo.keepScreenOn(true);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _safe(() => SystemChrome.setSystemUIChangeCallback(null));
    _safe(() => SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        ));
    ScreenInfo.keepScreenOn(false);
    super.dispose();
  }

  /// Возврат приложения на передний план — снова скрыть панели (сразу и после паузы).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _hideBars();
      _scheduleHideBars();
    }
  }

  /// Панели показались (свайп от края и т.п.) — через паузу скрыть снова.
  Future<void> _onSystemUiChange(bool systemOverlaysAreVisible) async {
    if (systemOverlaysAreVisible && mounted) {
      _scheduleHideBars();
    }
  }

  void _hideBars() {
    _safe(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  void _scheduleHideBars() {
    _hideTimer?.cancel();
    _hideTimer = Timer(kHideBarsRetryDelay, () {
      _hideTimer = null;
      if (mounted) {
        _hideBars();
      }
    });
  }

  static Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      // нет платформенной части (тесты) — не критично
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Размер окна в физических пикселях (в режиме immersiveSticky — весь экран).
    final screenWPx = (size.width * dpr).round();
    final screenHPx = (size.height * dpr).round();
    // phys_px = mm / 25.4 * dpi, затем к целому пикселю той же чётности, что экран (по центру без полупикселей).
    final wPhys = snapToPixelGrid(mmToPhysicalPx(widget.widthMm, widget.xdpi), screenWPx);
    final hPhys = snapToPixelGrid(mmToPhysicalPx(widget.lengthMm, widget.ydpi), screenHPx);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: ColoredBox(
        key: const ValueKey('fullscreen'),
        color: Colors.black,
        // Больше экрана — не масштабируется, а обрезается краями экрана.
        child: ClipRect(
          child: OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.center,
            child: SizedBox(
              width: physicalToLogicalPx(wPhys, dpr),
              height: physicalToLogicalPx(hPhys, dpr),
              child: ColoredBox(
                key: const ValueKey('rect'),
                color: widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
