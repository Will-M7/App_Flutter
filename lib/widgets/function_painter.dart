import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/calculation_result.dart';
import '../models/iteration_step.dart';
import '../models/method_type.dart';
import '../services/math_parser_service.dart';

/// CustomPainter para renderizar el plano cartesiano, curva de la función y geometría paso a paso
class FunctionPainter extends CustomPainter {
  final String functionExpression;
  final CalculationResult? result;
  final int currentStepIndex;
  final MathParserService parserService;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final bool showGrid;
  final bool isDarkTheme;

  FunctionPainter({
    required this.functionExpression,
    this.result,
    required this.currentStepIndex,
    required this.parserService,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    this.showGrid = true,
    this.isDarkTheme = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Colores del tema
    final bgColor = isDarkTheme ? const Color(0xFF1E1E2C) : const Color(0xFFFAFAFC);
    final gridColor = isDarkTheme ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final axisColor = isDarkTheme ? Colors.white.withOpacity(0.7) : Colors.black87;
    final curveColor = const Color(0xFF29B6F6);
    final textStyle = TextStyle(
      color: isDarkTheme ? Colors.white60 : Colors.black54,
      fontSize: 10,
      fontFamily: 'RobotoMono',
    );

    // 1. Fondo
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Factores de transformación
    final double rangeX = maxX - minX == 0 ? 1.0 : (maxX - minX);
    final double rangeY = maxY - minY == 0 ? 1.0 : (maxY - minY);

    double toScreenX(double x) => ((x - minX) / rangeX) * size.width;
    double toScreenY(double y) => size.height - (((y - minY) / rangeY) * size.height);

    // 2. Cuadrícula y Marcas
    if (showGrid) {
      _drawGrid(canvas, size, toScreenX, toScreenY, gridColor, textStyle);
    }

    // 3. Ejes Cartesianos X e Y
    _drawAxes(canvas, size, toScreenX, toScreenY, axisColor, textStyle);

    // 4. Curva f(x)
    _drawFunctionCurve(canvas, size, toScreenX, toScreenY, curveColor);

    // 5. Geometría paso a paso según el método
    if (result != null && result!.steps.isNotEmpty && currentStepIndex >= 0) {
      final safeIndex = currentStepIndex.clamp(0, result!.steps.length - 1);
      final step = result!.steps[safeIndex];

      switch (result!.method) {
        case NumericalMethod.newtonRaphson:
          _drawNewtonRaphsonStep(canvas, size, step, toScreenX, toScreenY);
          break;
        case NumericalMethod.secant:
          _drawSecantStep(canvas, size, step, toScreenX, toScreenY);
          break;
        case NumericalMethod.falsePosition:
          _drawFalsePositionStep(canvas, size, step, toScreenX, toScreenY);
          break;
      }
    }
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    double Function(double) toX,
    double Function(double) toY,
    Color gridColor,
    TextStyle textStyle,
  ) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    final double stepX = _calculateOptimalGridStep(maxX - minX);
    final double stepY = _calculateOptimalGridStep(maxY - minY);

    final double firstX = (minX / stepX).floor() * stepX;
    for (double x = firstX; x <= maxX; x += stepX) {
      final sx = toX(x);
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), gridPaint);
    }

    final double firstY = (minY / stepY).floor() * stepY;
    for (double y = firstY; y <= maxY; y += stepY) {
      final sy = toY(y);
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), gridPaint);
    }
  }

  void _drawAxes(
    Canvas canvas,
    Size size,
    double Function(double) toX,
    double Function(double) toY,
    Color axisColor,
    TextStyle textStyle,
  ) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.8;

    final double originX = toX(0.0).clamp(0.0, size.width);
    final double originY = toY(0.0).clamp(0.0, size.height);

    // Eje X (y = 0)
    if (minY <= 0 && maxY >= 0) {
      canvas.drawLine(Offset(0, originY), Offset(size.width, originY), axisPaint);
    }

    // Eje Y (x = 0)
    if (minX <= 0 && maxX >= 0) {
      canvas.drawLine(Offset(originX, 0), Offset(originX, size.height), axisPaint);
    }

    // Etiquetas numéricas en Eje X
    final double stepX = _calculateOptimalGridStep(maxX - minX);
    final double firstX = (minX / stepX).floor() * stepX;
    for (double x = firstX; x <= maxX; x += stepX) {
      if (x.abs() < 1e-6) continue;
      final sx = toX(x);
      final textSpan = TextSpan(text: _formatTick(x), style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final labelY = (minY <= 0 && maxY >= 0) ? originY + 4 : size.height - 16;
      textPainter.paint(canvas, Offset(sx - textPainter.width / 2, labelY.clamp(0.0, size.height - 16)));
    }

    // Etiquetas numéricas en Eje Y
    final double stepY = _calculateOptimalGridStep(maxY - minY);
    final double firstY = (minY / stepY).floor() * stepY;
    for (double y = firstY; y <= maxY; y += stepY) {
      if (y.abs() < 1e-6) continue;
      final sy = toY(y);
      final textSpan = TextSpan(text: _formatTick(y), style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final labelX = (minX <= 0 && maxX >= 0) ? originX + 5 : 5.0;
      textPainter.paint(canvas, Offset(labelX.clamp(0.0, size.width - textPainter.width - 5), sy - textPainter.height / 2));
    }
  }

  void _drawFunctionCurve(
    Canvas canvas,
    Size size,
    double Function(double) toX,
    double Function(double) toY,
    Color curveColor,
  ) {
    if (functionExpression.trim().isEmpty) return;

    final curvePaint = Paint()
      ..color = curveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final int samples = (size.width * 1.5).toInt().clamp(200, 1000);
    final double dx = (maxX - minX) / samples;

    Path? currentPath;

    for (int i = 0; i <= samples; i++) {
      final double x = minX + i * dx;
      try {
        final double y = parserService.evaluate(functionExpression, x);
        if (y.isNaN || y.isInfinite) {
          if (currentPath != null) {
            canvas.drawPath(currentPath, curvePaint);
            currentPath = null;
          }
          continue;
        }

        final sx = toX(x);
        final sy = toY(y);

        // Descartar saltos discontinuos extremos (asíntotas)
        if (sy < -size.height * 2 || sy > size.height * 3) {
          if (currentPath != null) {
            canvas.drawPath(currentPath, curvePaint);
            currentPath = null;
          }
          continue;
        }

        if (currentPath == null) {
          currentPath = Path()..moveTo(sx, sy);
        } else {
          currentPath.lineTo(sx, sy);
        }
      } catch (_) {
        if (currentPath != null) {
          canvas.drawPath(currentPath, curvePaint);
          currentPath = null;
        }
      }
    }

    if (currentPath != null) {
      canvas.drawPath(currentPath, curvePaint);
    }
  }

  /// Visualización geométrica de Newton-Raphson: Tangente que corta el eje X
  void _drawNewtonRaphsonStep(
    Canvas canvas,
    Size size,
    IterationStep step,
    double Function(double) toX,
    double Function(double) toY,
  ) {
    final double xi = step.currentX;
    final double fxi = step.currentFx;
    final double? slope = step.slope ?? step.derivativeFx;
    final double? nextX = step.nextX;

    final ptSx = toX(xi);
    final ptSy = toY(fxi);
    final zeroSy = toY(0.0);

    // 1. Línea vertical discontinua desde (xi, 0) hasta (xi, f(xi))
    _drawDashedLine(
      canvas,
      Offset(ptSx, zeroSy),
      Offset(ptSx, ptSy),
      Colors.amber.withOpacity(0.8),
      1.5,
    );

    // 2. Recta Tangente: y - f(xi) = m * (x - xi) -> y = f(xi) + m*(x - xi)
    if (slope != null && slope.abs() > 1e-12) {
      final tangentPaint = Paint()
        ..color = const Color(0xFFFF5252) // Rojo vibrante
        ..strokeWidth = 2.0;

      final double tMinX = minX - (maxX - minX) * 0.2;
      final double tMaxX = maxX + (maxX - minX) * 0.2;

      final double y1 = fxi + slope * (tMinX - xi);
      final double y2 = fxi + slope * (tMaxX - xi);

      canvas.drawLine(
        Offset(toX(tMinX), toY(y1)),
        Offset(toX(tMaxX), toY(y2)),
        tangentPaint,
      );
    }

    // 3. Punto de evaluación (xi, f(xi))
    _drawPointWithHalo(canvas, Offset(ptSx, ptSy), const Color(0xFFFFC107), 6.0, 'P($xi, ${fxi.toStringAsFixed(3)})');

    // 4. Punto proyectado en el eje X: (xi, 0)
    _drawPointWithHalo(canvas, Offset(ptSx, zeroSy), Colors.amber, 4.0, 'x_{${step.stepNumber}}');

    // 5. Nuevo punto calculado x_{i+1} en el corte del eje X
    if (nextX != null) {
      final nextSx = toX(nextX);
      _drawPointWithHalo(
        canvas,
        Offset(nextSx, zeroSy),
        const Color(0xFF00E676), // Verde neón
        6.5,
        'x_{${step.stepNumber + 1}}',
      );

      // Flecha indicadora de avance
      _drawArrow(canvas, Offset(ptSx, zeroSy), Offset(nextSx, zeroSy), const Color(0xFF00E676));
    }
  }

  /// Visualización geométrica de Secante: Línea secante que une dos puntos anteriores y corta el eje X
  void _drawSecantStep(
    Canvas canvas,
    Size size,
    IterationStep step,
    double Function(double) toX,
    double Function(double) toY,
  ) {
    final double currX = step.currentX;
    final double currFx = step.currentFx;
    final double? prevX = step.prevX;
    final double? prevFx = step.prevFx;
    final double? nextX = step.nextX;

    final currSx = toX(currX);
    final currSy = toY(currFx);
    final zeroSy = toY(0.0);

    // Punto actual (xi, f(xi))
    _drawPointWithHalo(canvas, Offset(currSx, currSy), const Color(0xFFFF9800), 6.0, '($currX, ${currFx.toStringAsFixed(3)})');
    _drawDashedLine(canvas, Offset(currSx, zeroSy), Offset(currSx, currSy), Colors.orangeAccent.withOpacity(0.7), 1.5);

    if (prevX != null && prevFx != null) {
      final prevSx = toX(prevX);
      final prevSy = toY(prevFx);

      // Punto anterior (x_{i-1}, f(x_{i-1}))
      _drawPointWithHalo(canvas, Offset(prevSx, prevSy), const Color(0xFFAB47BC), 6.0, '($prevX, ${prevFx.toStringAsFixed(3)})');
      _drawDashedLine(canvas, Offset(prevSx, zeroSy), Offset(prevSx, prevSy), Colors.purpleAccent.withOpacity(0.7), 1.5);

      // Recta secante que pasa por ambos puntos
      final secantPaint = Paint()
        ..color = const Color(0xFFFF5252)
        ..strokeWidth = 2.0;

      final double slope = (currFx - prevFx) / (currX - prevX == 0 ? 1e-12 : (currX - prevX));
      final double tMinX = minX - (maxX - minX) * 0.2;
      final double tMaxX = maxX + (maxX - minX) * 0.2;

      final double y1 = currFx + slope * (tMinX - currX);
      final double y2 = currFx + slope * (tMaxX - currX);

      canvas.drawLine(
        Offset(toX(tMinX), toY(y1)),
        Offset(toX(tMaxX), toY(y2)),
        secantPaint,
      );
    }

    // Nuevo corte con el eje X: x_{i+1}
    if (nextX != null) {
      final nextSx = toX(nextX);
      _drawPointWithHalo(
        canvas,
        Offset(nextSx, zeroSy),
        const Color(0xFF00E676),
        6.5,
        'x_{${step.stepNumber + 1}}',
      );
    }
  }

  /// Visualización geométrica de Regla Falsa: Intervalo [a, b], cuerda secante y corte c
  void _drawFalsePositionStep(
    Canvas canvas,
    Size size,
    IterationStep step,
    double Function(double) toX,
    double Function(double) toY,
  ) {
    final double? a = step.intervalA;
    final double? b = step.intervalB;
    final double? fa = step.fa;
    final double? fb = step.fb;
    final double c = step.currentX;
    final double fc = step.currentFx;
    final double zeroSy = toY(0.0);

    if (a != null && b != null && fa != null && fb != null) {
      final aSx = toX(a);
      final bSx = toX(b);
      final aSy = toY(fa);
      final bSy = toY(fb);

      // 1. Zona sombreada del intervalo [a, b]
      final intervalPaint = Paint()
        ..color = Colors.teal.withOpacity(0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(math.min(aSx, bSx), 0, math.max(aSx, bSx), size.height),
        intervalPaint,
      );

      // 2. Líneas verticales en los límites a y b
      _drawDashedLine(canvas, Offset(aSx, zeroSy), Offset(aSx, aSy), Colors.tealAccent, 1.5);
      _drawDashedLine(canvas, Offset(bSx, zeroSy), Offset(bSx, bSy), Colors.tealAccent, 1.5);

      // 3. Recta Cuerda (Secante entre [a, f(a)] y [b, f(b)])
      final chordPaint = Paint()
        ..color = const Color(0xFFFF5252)
        ..strokeWidth = 2.2;
      canvas.drawLine(Offset(aSx, aSy), Offset(bSx, bSy), chordPaint);

      // 4. Puntos en los extremos
      _drawPointWithHalo(canvas, Offset(aSx, aSy), Colors.tealAccent, 5.5, 'a ($a)');
      _drawPointWithHalo(canvas, Offset(bSx, bSy), Colors.cyanAccent, 5.5, 'b ($b)');
    }

    // 5. Punto de aproximación c en el eje X y en la curva f(c)
    final cSx = toX(c);
    final cSy = toY(fc);

    _drawDashedLine(canvas, Offset(cSx, zeroSy), Offset(cSx, cSy), Colors.greenAccent, 1.5);
    _drawPointWithHalo(canvas, Offset(cSx, zeroSy), const Color(0xFF00E676), 6.5, 'c = ${c.toStringAsFixed(4)}');
    _drawPointWithHalo(canvas, Offset(cSx, cSy), const Color(0xFFFFD54F), 5.0, 'f(c)');
  }

  void _drawPointWithHalo(
    Canvas canvas,
    Offset center,
    Color color,
    double radius,
    String? label,
  ) {
    // Halo translúcido exterior
    final haloPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 2.0, haloPaint);

    // Núcleo sólido
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, corePaint);

    // Borde blanco de contraste
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Etiqueta
    if (label != null) {
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black.withOpacity(0.6),
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(center.dx + 8, center.dy - textPainter.height / 2));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    final double distance = (p2 - p1).distance;
    final double dx = (p2.dx - p1.dx) / distance;
    final double dy = (p2.dy - p1.dy) / distance;

    double currentDist = 0.0;
    while (currentDist < distance) {
      final double len = math.min(dashWidth, distance - currentDist);
      final start = Offset(p1.dx + dx * currentDist, p1.dy + dy * currentDist);
      final end = Offset(p1.dx + dx * (currentDist + len), p1.dy + dy * (currentDist + len));
      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Color color) {
    if ((end - start).distance < 12) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final double angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const double arrowSize = 6.0;

    canvas.drawLine(
      mid,
      Offset(
        mid.dx - arrowSize * math.cos(angle - math.pi / 6),
        mid.dy - arrowSize * math.sin(angle - math.pi / 6),
      ),
      paint,
    );
    canvas.drawLine(
      mid,
      Offset(
        mid.dx - arrowSize * math.cos(angle + math.pi / 6),
        mid.dy - arrowSize * math.sin(angle + math.pi / 6),
      ),
      paint,
    );
  }

  double _calculateOptimalGridStep(double range) {
    if (range <= 0) return 1.0;
    final double exponent = (math.log(range / 6) / math.ln10).floorToDouble();
    final double fraction = (range / 6) / math.pow(10, exponent);

    double step;
    if (fraction <= 1.5) {
      step = 1.0;
    } else if (fraction <= 3.5) {
      step = 2.0;
    } else if (fraction <= 7.5) {
      step = 5.0;
    } else {
      step = 10.0;
    }
    return step * math.pow(10, exponent);
  }

  String _formatTick(double val) {
    if (val.abs() >= 10000 || (val.abs() < 0.001 && val.abs() > 0)) {
      return val.toStringAsExponential(1);
    }
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  bool shouldRepaint(covariant FunctionPainter oldDelegate) {
    return oldDelegate.functionExpression != functionExpression ||
        oldDelegate.currentStepIndex != currentStepIndex ||
        oldDelegate.result != result ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.isDarkTheme != isDarkTheme;
  }
}
