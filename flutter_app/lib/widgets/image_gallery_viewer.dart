import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../locale_store.dart';

/// Mahsulot rasmini to'liq ekranda ochadi (marketplace uslubidagi galereya):
/// pinch/ikki marta bosish bilan zoom, o'ngga-chapga surib almashtirish,
/// "1 / 5" hisoblagich va ixcham nuqtalar. Joriy rasm o'zgarsa
/// [onIndexChanged] chaqiriladi — mahsulot sahifasidagi galereya shu bilan
/// sinxron turadi.
Future<void> showImageGallery(
  BuildContext context,
  List<String> urls, {
  int initialIndex = 0,
  ValueChanged<int>? onIndexChanged,
}) {
  if (urls.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.97),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => _GalleryScreen(
        urls: urls,
        initialIndex: initialIndex.clamp(0, urls.length - 1),
        onIndexChanged: onIndexChanged,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _GalleryScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;
  const _GalleryScreen({required this.urls, required this.initialIndex, this.onIndexChanged});

  @override
  State<_GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<_GalleryScreen> {
  static const _maxDots = 7;
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Qo'shni rasmlar oldindan yuklanadi — surilganda bo'sh joy ko'rinmaydi.
    for (final i in [_index - 1, _index + 1]) {
      if (i >= 0 && i < widget.urls.length) {
        precacheImage(NetworkImage(widget.urls[i]), context);
      }
    }
  }

  void _onPage(int i) {
    setState(() {
      _index = i;
      _zoomed = false;
    });
    widget.onIndexChanged?.call(i);
    didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    final count = widget.urls.length;
    final multi = count > 1;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: count,
            // Rasm kattalashtirilganda barmoq rasmni siljitadi, sahifani emas.
            physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            onPageChanged: _onPage,
            itemBuilder: (_, i) => _ZoomablePage(
              url: widget.urls[i],
              errorText: loc.t('gallery_image_error'),
              onZoomChanged: (z) {
                if (i == _index && z != _zoomed) setState(() => _zoomed = z);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (multi) _pill(Text('${_index + 1} / $count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]))),
                  const Spacer(),
                  Material(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: loc.t('common_close'),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (multi)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(child: _dots(count)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: child,
      );

  /// Ko'p rasmda nuqtalar oynasi [_maxDots] bilan cheklanadi, chetlari kichrayadi.
  Widget _dots(int count) {
    final visible = math.min(count, _maxDots);
    final start = (_index - _maxDots ~/ 2).clamp(0, math.max(0, count - _maxDots));
    return _pill(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(visible, (k) {
          final i = start + k;
          final active = i == _index;
          final edge = count > _maxDots && ((k == 0 && i > 0) || (k == visible - 1 && i < count - 1));
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 20 : (edge ? 4 : 6),
            height: active ? 8 : (edge ? 4 : 6),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}

/// Bitta rasm: pinch-zoom, ikki marta bosish bilan 1x <-> 2.5x, yuklanish
/// va xato holatlari.
class _ZoomablePage extends StatefulWidget {
  final String url;
  final String errorText;
  final ValueChanged<bool> onZoomChanged;
  const _ZoomablePage({required this.url, required this.errorText, required this.onZoomChanged});

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Offset _tapPos = Offset.zero;
  Matrix4Tween? _tween;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = _tween;
      if (t != null) _controller.value = t.evaluate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    });
    _controller.addListener(() => widget.onZoomChanged(_controller.value.getMaxScaleOnAxis() > 1.01));
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final begin = _controller.value;
    final zoomedIn = begin.getMaxScaleOnAxis() > 1.01;
    final Matrix4 end;
    if (zoomedIn) {
      end = Matrix4.identity();
    } else {
      const s = 2.5;
      end = Matrix4.translationValues(-_tapPos.dx * (s - 1), -_tapPos.dy * (s - 1), 0) *
          Matrix4.diagonal3Values(s, s, 1);
    }
    _tween = Matrix4Tween(begin: begin, end: end);
    _anim
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tapPos = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        child: SizedBox.expand(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))),
            errorBuilder: (_, __, ___) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 40),
                  const SizedBox(height: 8),
                  Text(widget.errorText, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
