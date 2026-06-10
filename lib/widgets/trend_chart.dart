import 'package:flutter/material.dart';
import '../models/i18n.dart';
import '../models/revenue_record.dart';
import '../main.dart'; // 引入 formatMoney

class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.data,
    required this.metric,
    required this.reportCurrency,
  });

  final List<DimensionTotal> data;
  final String metric;
  final String reportCurrency;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Center(child: Text(I18n.t('chart_no_data')));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final chartRect = Rect.fromLTWH(44, 8, size.width - 60, size.height - 48);

        return MouseRegion(
          onHover: (event) {
            final localPos = event.localPosition;
            int? closestIndex;
            double minDistance = double.infinity;

            for (var i = 0; i < widget.data.length; i++) {
              final x = widget.data.length == 1
                  ? chartRect.center.dx
                  : chartRect.left + chartRect.width * i / (widget.data.length - 1);
              final distanceX = (localPos.dx - x).abs();
              if (distanceX < minDistance) {
                minDistance = distanceX;
                closestIndex = i;
              }
            }

            final double maxHoverDistance = widget.data.length > 1
                ? (chartRect.width / (widget.data.length - 1)) / 2
                : 30.0;

            if (closestIndex != null &&
                minDistance < maxHoverDistance &&
                localPos.dy >= chartRect.top &&
                localPos.dy <= chartRect.bottom + 20) {
              if (_hoveredIndex != closestIndex) {
                setState(() {
                  _hoveredIndex = closestIndex;
                });
              }
            } else {
              if (_hoveredIndex != null) {
                setState(() {
                  _hoveredIndex = null;
                });
              }
            }
          },
          onExit: (event) {
            if (_hoveredIndex != null) {
              setState(() {
                _hoveredIndex = null;
              });
            }
          },
          child: CustomPaint(
            painter: TrendPainter(
              data: widget.data,
              metric: widget.metric,
              reportCurrency: widget.reportCurrency,
              color: Theme.of(context).colorScheme.primary,
              gridColor: const Color(0xffe1e6e1),
              labelColor: const Color(0xff59675f),
              hoveredIndex: _hoveredIndex,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class TrendPainter extends CustomPainter {
  const TrendPainter({
    required this.data,
    required this.metric,
    required this.reportCurrency,
    required this.color,
    required this.gridColor,
    required this.labelColor,
    this.hoveredIndex,
  });

  final List<DimensionTotal> data;
  final String metric;
  final String reportCurrency;
  final Color color;
  final Color gridColor;
  final Color labelColor;
  final int? hoveredIndex;

  int _getValue(DimensionTotal item) {
    switch (metric) {
      case 'gross':
        return item.grossAmountCents;
      case 'refund':
        return item.refundsAmountCents;
      case 'net':
      default:
        return item.netAmountCents;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final values = data.map(_getValue).toList();
    final maxValue = values.fold<int>(1, (max, value) => value > max ? value : max);
    final chartRect = Rect.fromLTWH(44, 8, size.width - 60, size.height - 48);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    for (var i = 0; i <= 3; i++) {
      final y = chartRect.top + chartRect.height * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1
          ? chartRect.center.dx
          : chartRect.left + chartRect.width * i / (data.length - 1);
      final y =
          chartRect.bottom -
          chartRect.height * _getValue(data[i]) / maxValue;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    final area = Path.from(path)
      ..lineTo(points.last.dx, chartRect.bottom)
      ..lineTo(points.first.dx, chartRect.bottom)
      ..close();
    canvas.drawPath(area, fillPaint);

    final dotPaint = Paint()..color = color;
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < data.length; i++) {
      textPainter.text = TextSpan(
        text: data[i].label.substring(5),
        style: TextStyle(color: labelColor, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2, chartRect.bottom + 12),
      );
    }

    // 绘制 Hover 高亮及 Tooltip
    if (hoveredIndex != null && hoveredIndex! < points.length) {
      final activePoint = points[hoveredIndex!];
      
      // 1. 绘制高亮数据点，外层填充，内层白色
      final highlightPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(activePoint, 7, highlightPaint);
      canvas.drawCircle(activePoint, 4, whitePaint);

      // 2. 准备 Tooltip 文本并计算环比
      final monthText = data[hoveredIndex!].label;
      final moneyText = '${formatMoney(_getValue(data[hoveredIndex!]))} $reportCurrency';
      
      double? mom;
      if (hoveredIndex! > 0) {
        final prevVal = _getValue(data[hoveredIndex! - 1]);
        final currVal = _getValue(data[hoveredIndex!]);
        if (prevVal != 0) {
          mom = (currVal - prevVal) / prevVal.abs() * 100;
        }
      }
      
      final textStyle = const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500);
      final monthSpan = TextSpan(text: '$monthText\n', style: textStyle.copyWith(color: Colors.white70));
      final moneySpan = TextSpan(
        text: mom != null ? '$moneyText\n' : moneyText,
        style: textStyle.copyWith(fontWeight: FontWeight.bold),
      );
      
      TextSpan? momSpan;
      if (mom != null) {
        final isUp = mom >= 0;
        final momSign = isUp ? '+' : '';
        final momString = '$momSign${mom.toStringAsFixed(1)}%';
        momSpan = TextSpan(
          text: '${I18n.t('kpi_mom')}$momString',
          style: textStyle.copyWith(
            color: isUp ? const Color(0xff81c784) : const Color(0xffe57373),
            fontWeight: FontWeight.bold,
          ),
        );
      }
      
      final tooltipPainter = TextPainter(
        text: TextSpan(
          children: [
            monthSpan,
            moneySpan,
            // ignore: use_null_aware_elements
            if (momSpan != null) momSpan,
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      
      // 3. 计算 Tooltip 框的位置
      final tooltipWidth = tooltipPainter.width + 16;
      final tooltipHeight = tooltipPainter.height + 12;
      
      double tooltipX = activePoint.dx - tooltipWidth / 2;
      double tooltipY = activePoint.dy - tooltipHeight - 12;
      
      // 左右边界避让
      if (tooltipX < chartRect.left) {
        tooltipX = chartRect.left + 4;
      } else if (tooltipX + tooltipWidth > chartRect.right) {
        tooltipX = chartRect.right - tooltipWidth - 4;
      }
      
      // 上边界避让，如果偏高，移到点下方
      if (tooltipY < chartRect.top) {
        tooltipY = activePoint.dy + 12;
      }
      
      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(6),
      );
      
      // 4. 绘制 Tooltip 阴影与背景
      final tooltipBgPaint = Paint()
        ..color = const Color(0xff1f2d25).withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        tooltipRect.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      
      canvas.drawRRect(tooltipRect, tooltipBgPaint);
      
      // 5. 绘制文字
      tooltipPainter.paint(
        canvas,
        Offset(tooltipX + 8, tooltipY + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrendPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.metric != metric ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.reportCurrency != reportCurrency;
  }
}
