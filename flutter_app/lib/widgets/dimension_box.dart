import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../locale_store.dart';
import '../models.dart';
import '../theme.dart';

/// O'lcham chizmasi: quti shaklida eni (E), bo'yi (B) va chuqurligi (Ch) —
/// chizmachilikdagi kabi o'lcham chiziqlari bilan, HAQIQIY nisbatda; pastida
/// hajm (m³). Qiymatlar metrda (`widthM`, `heightM`, `depthM`).
class DimensionBox extends StatelessWidget {
  final double widthM;
  final double heightM;
  final double depthM;
  const DimensionBox(
      {super.key,
      required this.widthM,
      required this.heightM,
      required this.depthM});

  static String _cm(double m) => '${(m * 100).round()} sm';

  /// Hajm m³ (3 xona aniqlik, ortiqcha nollarsiz): 0.342
  static String volume(double w, double h, double d) {
    final v = w * h * d;
    final s = v >= 1 ? v.toStringAsFixed(2) : v.toStringAsFixed(3);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _BoxPainter(
                w: widthM,
                h: heightM,
                d: depthM,
                wLabel: '${loc.t('dim_width')} ${_cm(widthM)}',
                hLabel: '${loc.t('dim_height')} ${_cm(heightM)}',
                dLabel: '${loc.t('dim_depth')} ${_cm(depthM)}',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '${loc.t('dim_volume')}: ${volume(widthM, heightM, depthM)} m³',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Faqat HAQIQIY o'lcham bo'lsa qaytaradi: avvalo 3D model geometriyasi (`bbox_*`),
  /// bo'lmasa variantning o'zi — lekin variant standart 1×1×1 m (to'ldirilmagan
  /// qiymat) bo'lsa o'lcham ko'rsatilmaydi (soxta "100×100×100 sm" chiqmasligi uchun).
  static ({double w, double h, double d})? resolve(Model3D? model, Variant? v) {
    double? w = model?.bboxWidthValue,
        h = model?.bboxHeightValue,
        d = model?.bboxDepthValue;
    if (w == null || h == null || d == null) {
      if (v == null) return null;
      w = v.widthValue;
      h = v.heightValue;
      d = v.depthValue;
      if (w == 1 && h == 1 && d == 1) return null;
    }
    if (w <= 0 || h <= 0 || d <= 0) return null;
    return (w: w, h: h, d: d);
  }
}

class _BoxPainter extends CustomPainter {
  final double w, h, d;
  final String wLabel, hLabel, dLabel;
  _BoxPainter({
    required this.w,
    required this.h,
    required this.d,
    required this.wLabel,
    required this.hLabel,
    required this.dLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Oblique (kabinet) proyeksiya: old yuz = eni × bo'yi, chuqurlik 45° da 0.5 masshtabda.
    const depthK = 0.5;
    const margin = 8.0;
    const labelRoom = 28.0; // o'lcham chiziqlari va yozuvlar uchun
    final availW = size.width - margin * 2 - labelRoom;
    final availH = size.height - margin * 2 - labelRoom;
    // 1 metr = k piksel (hamma o'qda bir xil — nisbat haqiqiy)
    final k = [
      availW / (w + d * depthK * 0.7071),
      availH / (h + d * depthK * 0.7071),
    ].reduce((a, b) => a < b ? a : b);
    final fw = w * k, fh = h * k;
    final dx = d * k * depthK * 0.7071, dy = d * k * depthK * 0.7071;

    final totalW = fw + dx, totalH = fh + dy;
    final left = (size.width - totalW) / 2 - 8;
    final top = (size.height - labelRoom - totalH) / 2 + dy;

    final fl = Offset(left, top + fh); // old-past-chap
    final fr = Offset(left + fw, top + fh);
    final tl = Offset(left, top);
    final tr = Offset(left + fw, top);
    final bo = Offset(dx, -dy);

    final front = Path()..addPolygon([tl, tr, fr, fl], true);
    final topFace = Path()..addPolygon([tl, tr, tr + bo, tl + bo], true);
    final side = Path()..addPolygon([tr, tr + bo, fr + bo, fr], true);

    canvas.drawPath(topFace, Paint()..color = AppColors.backgroundAlt);
    canvas.drawPath(side, Paint()..color = AppColors.border);
    canvas.drawPath(front, Paint()..color = AppColors.card);
    final edge = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(front, edge);
    canvas.drawPath(topFace, edge);
    canvas.drawPath(side, edge);

    // O'lcham chiziqlari (uchlarida strelka) — chizmachilikdagi kabi.
    final dim = Paint()
      ..color = AppColors.brandSecondary
      ..strokeWidth = 1.2;
    void arrowLine(Offset a, Offset b) {
      canvas.drawLine(a, b, dim);
      final v = (b - a);
      final len = v.distance;
      if (len < 1) return;
      final u = v / len;
      final n = Offset(-u.dy, u.dx);
      for (final p in [a, b]) {
        final dir = p == a ? u : -u;
        canvas.drawLine(p, p + dir * 7 + n * 3.2, dim);
        canvas.drawLine(p, p + dir * 7 - n * 3.2, dim);
      }
    }

    void text(String s, Offset center, {double angle = 0}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      // Yozuv ostiga yengil fon — chiziq ustiga tushsa ham o'qiladi.
      final r = Rect.fromCenter(
          center: Offset.zero, width: tp.width + 8, height: tp.height + 2);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()..color = AppColors.background);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Eni — old yuz tagida
    final wa = fl + const Offset(0, 16), wb = fr + const Offset(0, 16);
    arrowLine(wa, wb);
    text(wLabel, (wa + wb) / 2 + const Offset(0, 12));
    // Bo'yi — old yuzning chap tomonida (vertikal)
    final ha = tl + const Offset(-16, 0), hb = fl + const Offset(-16, 0);
    arrowLine(ha, hb);
    text(hLabel, (ha + hb) / 2 + const Offset(-12, 0), angle: -1.5708);
    // Chuqurlik — o'ng yon tomon pastki qirrasi bo'ylab
    final da = fr + const Offset(0, 14), db = fr + bo + const Offset(0, 14);
    arrowLine(da + const Offset(10, -4), db + const Offset(10, -4));
    text(dLabel, (da + db) / 2 + const Offset(30, -20), angle: -0.7854);
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) =>
      old.w != w ||
      old.h != h ||
      old.d != d ||
      old.wLabel != wLabel ||
      old.hLabel != hLabel ||
      old.dLabel != dLabel;
}
