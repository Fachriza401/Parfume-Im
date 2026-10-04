import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/models.dart';
import 'common.dart';

/// Default series colours: gold first, then a palette that stays legible on
/// both the dark and the light surface.
List<Color> defaultSeriesColors(AppPalette palette) => <Color>[
  AppColors.gold,
  palette.info,
  palette.success,
  palette.warning,
  palette.danger,
  Color.lerp(AppColors.gold, palette.info, 0.5)!,
  Color.lerp(AppColors.gold, palette.success, 0.5)!,
];

/// Shared axis/legend chrome so every chart reads as part of one system.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.legend = const <({String label, Color color})>[],
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<({String label, Color color})> legend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (legend.isNotEmpty)
                Icon(Icons.info_outline, size: 14, color: palette.textMuted),
            ],
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 10, color: palette.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          child,
          if (legend.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: <Widget>[
                for (final entry in legend)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        entry.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty placeholder so a chart never renders an axis with no data.
class ChartEmpty extends StatelessWidget {
  const ChartEmpty({
    super.key,
    this.height = 160,
    this.message = 'Belum ada data.',
  });

  final double height;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.palette.surfaceSunken,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(fontSize: 11, color: context.palette.textMuted),
    ),
  );
}

/// A single slice or bar.
class ChartSlice {
  const ChartSlice({
    required this.label,
    required this.value,
    required this.color,
    this.hint,
  });

  final String label;
  final double value;

  /// Colour used for the slice / bar fill.
  final Color color;

  /// Optional longer description shown in the legend.
  final String? hint;

  static List<ChartSlice> fromCategories(
    List<TopCategory> categories,
    AppPalette palette,
  ) {
    final colors = defaultSeriesColors(palette);
    return <ChartSlice>[
      for (var i = 0; i < categories.length; i++)
        ChartSlice(
          label: categories[i].name,
          value: categories[i].revenue.toDouble(),
          color: colors[i % colors.length],
          hint: '${categories[i].sold} terjual',
        ),
    ];
  }

  static List<ChartSlice> fromOrders(
    Map<String, int> counts,
    List<Color> colors,
  ) => <ChartSlice>[
    for (var i = 0; i < counts.length; i++)
      ChartSlice(
        label: counts.keys.elementAt(i),
        value: counts.values.elementAt(i).toDouble(),
        color: colors[i % colors.length],
      ),
  ];
}

/// Donut / pie chart drawn with a canvas so no extra dependency is needed.
class PieChartCard extends StatelessWidget {
  const PieChartCard({
    super.key,
    required this.slices,
    required this.title,
    this.subtitle,
    this.centerLabel,
    this.centerValue,
    this.emptyMessage = 'Belum ada data.',
  });

  final String title;
  final String? subtitle;
  final List<ChartSlice> slices;
  final String? centerLabel;
  final String? centerValue;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visible = slices.where((slice) => slice.value > 0).toList();

    if (visible.isEmpty) {
      return ChartCard(
        title: title,
        subtitle: subtitle,
        child: ChartEmpty(message: emptyMessage),
      );
    }

    final total = visible.fold<double>(0, (sum, slice) => sum + slice.value);

    return ChartCard(
      title: title,
      subtitle: subtitle,
      legend: <({String label, Color color})>[
        for (final slice in visible)
          (
            label: total > 0
                ? '${slice.label} ${(slice.value / total * 100).toStringAsFixed(0)}%'
                : slice.label,
            color: slice.color,
          ),
      ],
      child: SizedBox(
        height: 168,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 168,
              height: 168,
              child: CustomPaint(
                painter: _PiePainter(
                  slices: visible,
                  trackColor: palette.surfaceSunken,
                  borderColor: palette.surface,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (centerValue != null)
                        Text(
                          centerValue!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (centerLabel != null)
                        Text(
                          centerLabel!,
                          style: TextStyle(
                            fontSize: 9,
                            color: palette.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final slice in visible.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: slice.color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              slice.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.slices,
    required this.trackColor,
    required this.borderColor,
  });

  final List<ChartSlice> slices;
  final Color trackColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final stroke = math.min(size.width, size.height) * 0.42;
    final radius = stroke / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;

    canvas.drawCircle(centre, radius, track);

    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    if (total <= 0) return;

    var start = -math.pi / 2;
    final separator = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = borderColor;

    for (final slice in slices) {
      final sweep = (slice.value / total) * math.pi * 2;
      if (sweep <= 0) continue;

      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = slice.color,
      );

      canvas.drawArc(rect, start, sweep, false, separator);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.trackColor != trackColor;
}

/// One plotted series for [LineChartCard].
class LineSeries {
  const LineSeries({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final List<double> values;
  final Color color;
}

/// Line chart with a soft gradient fill under the curve.
class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.title,
    required this.labels,
    required this.series,
    this.subtitle,
    this.emptyMessage = 'Belum ada data.',
    this.height = 190,
    this.valueFormatter,
  });

  final String title;
  final String? subtitle;
  final List<String> labels;
  final List<LineSeries> series;
  final String emptyMessage;
  final double height;
  final String Function(double)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasData = series.any((entry) => entry.values.any((v) => v > 0));

    if (!hasData) {
      return ChartCard(
        title: title,
        subtitle: subtitle,
        child: ChartEmpty(message: emptyMessage),
      );
    }

    return ChartCard(
      title: title,
      subtitle: subtitle,
      legend: <({String label, Color color})>[
        for (final entry in series) (label: entry.label, color: entry.color),
      ],
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _LinePainter(
            series: series,
            labels: labels,
            gridColor: palette.border,
            labelColor: palette.textMuted,
            valueFormatter: valueFormatter ?? Formatters.rupiahShort,
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.series,
    required this.labels,
    required this.gridColor,
    required this.labelColor,
    required this.valueFormatter,
  });

  final List<LineSeries> series;
  final List<String> labels;
  final Color gridColor;
  final Color labelColor;
  final String Function(double) valueFormatter;

  @override
  void paint(Canvas canvas, Size size) {
    const leftGutter = 40.0;
    const bottomGutter = 20.0;

    final plot = Rect.fromLTWH(
      leftGutter,
      4,
      math.max(1.0, size.width - leftGutter),
      math.max(1.0, size.height - bottomGutter - 4),
    );

    var maxValue = 0.0;
    for (final entry in series) {
      for (final value in entry.values) {
        if (value > maxValue) maxValue = value;
      }
    }
    if (maxValue <= 0) maxValue = 1;
    // Round the ceiling up so the top gridline is a readable number.
    final step = _niceStep(maxValue);
    maxValue = (maxValue / step).ceil() * step;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final axisFont = const TextStyle(fontSize: 8, fontWeight: FontWeight.w500);

    for (var i = 0; i <= 4; i++) {
      final t = i / 4;
      final y = plot.bottom - (plot.height * t);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

      textPainter
        ..text = TextSpan(
          text: valueFormatter(maxValue * t),
          style: axisFont.copyWith(color: labelColor),
        )
        ..layout();
      textPainter.paint(
        canvas,
        Offset(plot.left - textPainter.width - 4, y - textPainter.height / 2),
      );
    }

    // X axis labels, thinned out so they never overlap on a narrow phone.
    final count = labels.length;
    if (count > 0) {
      final stepX = count > 8 ? (count / 4).ceil() : 1;
      for (var i = 0; i < count; i += stepX) {
        textPainter
          ..text = TextSpan(
            text: labels[i],
            style: axisFont.copyWith(color: labelColor),
          )
          ..layout();
        final x =
            plot.left +
            (count == 1 ? plot.width / 2 : plot.width * i / (count - 1)) -
            textPainter.width / 2;
        textPainter.paint(
          canvas,
          Offset(
            x.clamp(0.0, plot.right - textPainter.width).toDouble(),
            plot.bottom + 4,
          ),
        );
      }
    }

    for (final entry in series) {
      if (entry.values.isEmpty) continue;

      final points = <Offset>[];
      for (var i = 0; i < entry.values.length; i++) {
        final x = entry.values.length == 1
            ? plot.center.dx
            : plot.left + plot.width * i / (entry.values.length - 1);
        final y = plot.bottom - (plot.height * (entry.values[i] / maxValue));
        points.add(Offset(x, y));
      }

      if (points.length == 1) {
        canvas.drawCircle(points.first, 3.5, Paint()..color = entry.color);
        continue;
      }

      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final current = points[i];
        final midX = (previous.dx + current.dx) / 2;
        path.cubicTo(
          midX,
          previous.dy,
          midX,
          current.dy,
          current.dx,
          current.dy,
        );
      }

      final fill = Path.from(path)
        ..lineTo(points.last.dx, plot.bottom)
        ..lineTo(points.first.dx, plot.bottom)
        ..close();

      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              entry.color.withValues(alpha: 0.30),
              entry.color.withValues(alpha: 0.02),
            ],
          ).createShader(plot),
      );

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = entry.color,
      );

      for (final point in points) {
        canvas.drawCircle(point, 2.6, Paint()..color = entry.color);
      }
    }
  }

  static double _niceStep(double maxValue) {
    if (maxValue <= 0) return 1;
    final raw = maxValue / 4;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final normalised = raw / magnitude;
    final nice = normalised <= 1
        ? 1.0
        : normalised <= 2
        ? 2.0
        : normalised <= 5
        ? 5.0
        : 10.0;
    return nice * magnitude;
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.labels != labels;
}

/// Vertical bars with a value label on top of the tallest one.
class BarChartCard extends StatelessWidget {
  const BarChartCard({
    super.key,
    required this.title,
    required this.slices,
    this.subtitle,
    this.emptyMessage = 'Belum ada data.',
    this.height = 190,
    this.valueFormatter,
  });

  final String title;
  final String? subtitle;
  final List<ChartSlice> slices;
  final String emptyMessage;
  final double height;
  final String Function(double)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return ChartCard(
        title: title,
        subtitle: subtitle,
        child: ChartEmpty(message: emptyMessage),
      );
    }

    return ChartCard(
      title: title,
      subtitle: subtitle,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _BarPainter(
            slices: slices,
            gridColor: context.palette.border,
            labelColor: context.palette.textMuted,
            valueFormatter: valueFormatter ?? Formatters.rupiahShort,
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.slices,
    required this.gridColor,
    required this.labelColor,
    required this.valueFormatter,
  });

  final List<ChartSlice> slices;
  final Color gridColor;
  final Color labelColor;
  final String Function(double) valueFormatter;

  @override
  void paint(Canvas canvas, Size size) {
    const bottomGutter = 34.0;
    final plot = Rect.fromLTWH(
      0,
      8,
      size.width,
      math.max(1.0, size.height - bottomGutter - 8),
    );

    var maxValue = 0.0;
    for (final slice in slices) {
      if (slice.value > maxValue) maxValue = slice.value;
    }
    if (maxValue <= 0) maxValue = 1;
    final step = _LinePainter._niceStep(maxValue);
    maxValue = (maxValue / step).ceil() * step;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const axisFont = TextStyle(fontSize: 8, fontWeight: FontWeight.w500);

    for (var i = 0; i <= 3; i++) {
      final t = i / 3;
      final y = plot.bottom - plot.height * t;
      canvas.drawLine(Offset(0, y), Offset(plot.right, y), gridPaint);

      textPainter
        ..text = TextSpan(
          text: valueFormatter(maxValue * t),
          style: axisFont.copyWith(color: labelColor),
        )
        ..layout(maxWidth: plot.width);
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    final slot = plot.width / slices.length;
    final barWidth = math.min(22.0, slot * 0.62);

    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final barHeight = (plot.height * (slice.value / maxValue))
          .clamp(0.0, plot.height)
          .toDouble();
      final centreX = slot * i + slot / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centreX - barWidth / 2,
          plot.bottom - barHeight,
          barWidth,
          math.max(barHeight, 2.0),
        ),
        const Radius.circular(5),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[slice.color.withValues(alpha: 0.55), slice.color],
          ).createShader(rect.outerRect),
      );

      // Rotated category label under every bar.
      textPainter
        ..text = TextSpan(
          text: slice.label,
          style: axisFont.copyWith(color: labelColor),
        )
        ..layout();
      canvas.save();
      canvas.translate(centreX + textPainter.height / 2, plot.bottom + 6);
      canvas.rotate(math.pi / 4);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) => oldDelegate.slices != slices;
}

/// Converts the dashboard sales series into the labels the charts expect.
({List<String> labels, LineSeries revenue, LineSeries orders}) dailySalesSeries(
  List<DailySales> sales,
  AppPalette palette,
) {
  final ordered = sales.reversed.toList(growable: false);

  return (
    labels: <String>[for (final day in ordered) Formatters.date(day.date)],
    revenue: LineSeries(
      label: 'Pendapatan',
      values: <double>[for (final day in ordered) day.revenue],
      color: AppColors.gold,
    ),
    orders: LineSeries(
      label: 'Pesanan',
      values: <double>[for (final day in ordered) day.orders.toDouble()],
      color: palette.info,
    ),
  );
}
