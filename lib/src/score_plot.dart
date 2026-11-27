part of 'app.dart';

class ScorePlot extends CustomPainter {
  ScorePlot(
    this.scores,
    this.aqua,
    this.pink,
    this.muted, {
    this.firstLabel,
    this.lastLabel,
  });
  final Color aqua, pink, muted;
  final List<int> scores;
  final String? firstLabel, lastLabel;
  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;
    final max = scores.reduce((a, b) => a > b ? a : b);
    final min = scores.reduce((a, b) => a < b ? a : b);

    // Subtle horizontal stage guide lines with min/max score labels
    final gridPaint = Paint()
      ..color = muted.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (var g = 0; g < 3; g++) {
      final gy = 18 + (size.height - 48) * (g / 2);
      canvas.drawLine(Offset(12, gy), Offset(size.width - 12, gy), gridPaint);
    }
    void drawAxisLabel(String text, double x, double y, {bool rightAlign = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Inter',
            color: muted.withValues(alpha: 0.85),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rightAlign ? x - tp.width : x, y));
    }

    drawAxisLabel(number(max), 12, 4);
    if (max != min) {
      drawAxisLabel(number(min), 12, size.height - 36);
    }
    if (firstLabel != null) {
      drawAxisLabel(firstLabel!, 12, size.height - 14);
    }
    if (lastLabel != null && lastLabel != firstLabel) {
      drawAxisLabel(lastLabel!, size.width - 12, size.height - 14, rightAlign: true);
    }

    final points = <Offset>[];
    for (var i = 0; i < scores.length; i++) {
      final x =
          16 +
          (size.width - 32) *
              (scores.length == 1 ? 0.5 : i / (scores.length - 1));
      final y =
          18 +
          (size.height - 48) *
              (max == min ? 0.5 : 1 - (scores[i] - min) / (max - min));
      points.add(Offset(x, y));
    }

    if (points.length >= 2) {
      final area = Path()..moveTo(points.first.dx, size.height - 24);
      for (final p in points) {
        area.lineTo(p.dx, p.dy);
      }
      area
        ..lineTo(points.last.dx, size.height - 24)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              aqua.withValues(alpha: 0.24),
              pink.withValues(alpha: 0.02),
            ],
          ).createShader(Offset.zero & size),
      );

      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        line.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..shader = LinearGradient(
            colors: [aqua, pink],
          ).createShader(Offset.zero & size)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final nodeColor = i == points.length - 1 ? pink : aqua;
      canvas.drawCircle(p, 7, Paint()..color = nodeColor.withValues(alpha: 0.25));
      canvas.drawCircle(p, 4.5, Paint()..color = nodeColor);
      canvas.drawCircle(p, 2.0, Paint()..color = Colors.white);
      if (scores.length <= 6 && firstLabel == null) {
        final text = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              fontFamily: 'Inter',
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(p.dx - text.width / 2, size.height - 15));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScorePlot oldDelegate) =>
      !listEquals(oldDelegate.scores, scores) ||
      oldDelegate.aqua != aqua ||
      oldDelegate.pink != pink ||
      oldDelegate.muted != muted ||
      oldDelegate.firstLabel != firstLabel ||
      oldDelegate.lastLabel != lastLabel;
}
