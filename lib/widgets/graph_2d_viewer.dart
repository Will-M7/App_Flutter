import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/calculation_result.dart';
import '../models/method_type.dart';
import '../services/math_parser_service.dart';
import 'function_painter.dart';

/// Visor gráfico interactivo 2D con zoom, pan y controles flotantes
class Graph2DViewer extends StatefulWidget {
  final String functionExpression;
  final CalculationResult? result;
  final int currentStepIndex;
  final MathParserService parserService;

  const Graph2DViewer({
    super.key,
    required this.functionExpression,
    this.result,
    required this.currentStepIndex,
    required this.parserService,
  });

  @override
  State<Graph2DViewer> createState() => _Graph2DViewerState();
}

class _Graph2DViewerState extends State<Graph2DViewer> {
  double _minX = -5.0;
  double _maxX = 5.0;
  double _minY = -5.0;
  double _maxY = 5.0;
  bool _showGrid = true;

  // Seguimiento de gestos
  Offset? _lastFocalPoint;

  @override
  void initState() {
    super.initState();
    _autoFitView();
  }

  @override
  void didUpdateWidget(covariant Graph2DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result ||
        oldWidget.functionExpression != widget.functionExpression) {
      _autoFitView();
    }
  }

  /// Ajusta automáticamente el visor para encuadrar los puntos clave y la función
  void _autoFitView() {
    double minX = -4.0;
    double maxX = 4.0;
    double minY = -4.0;
    double maxY = 4.0;

    final result = widget.result;
    if (result != null && result.steps.isNotEmpty) {
      final List<double> xVals = [];
      final List<double> yVals = [0.0];

      for (final step in result.steps) {
        xVals.add(step.currentX);
        yVals.add(step.currentFx);
        if (step.prevX != null) xVals.add(step.prevX!);
        if (step.nextX != null) xVals.add(step.nextX!);
        if (step.intervalA != null) xVals.add(step.intervalA!);
        if (step.intervalB != null) xVals.add(step.intervalB!);
      }

      if (xVals.isNotEmpty) {
        final xMinVal = xVals.reduce(math.min);
        final xMaxVal = xVals.reduce(math.max);
        final yMinVal = yVals.reduce(math.min);
        final yMaxVal = yVals.reduce(math.max);

        final spanX = (xMaxVal - xMinVal).abs();
        final paddingX = spanX < 1e-4 ? 2.0 : spanX * 0.4;
        minX = xMinVal - paddingX;
        maxX = xMaxVal + paddingX;

        final spanY = (yMaxVal - yMinVal).abs();
        final paddingY = spanY < 1e-4 ? 2.0 : spanY * 0.4;
        minY = yMinVal - paddingY;
        maxY = yMaxVal + paddingY;
      }
    }

    setState(() {
      _minX = minX;
      _maxX = maxX;
      _minY = minY;
      _maxY = maxY;
    });
  }

  void _zoom(double factor, [Offset? focalPoint, Size? size]) {
    setState(() {
      final cx = (size != null && focalPoint != null)
          ? _minX + (focalPoint.dx / size.width) * (_maxX - _minX)
          : (_minX + _maxX) / 2;
      final cy = (size != null && focalPoint != null)
          ? _minY + ((size.height - focalPoint.dy) / size.height) * (_maxY - _minY)
          : (_minY + _maxY) / 2;

      final halfSpanX = ((_maxX - _minX) * factor) / 2;
      final halfSpanY = ((_maxY - _minY) * factor) / 2;

      _minX = cx - halfSpanX;
      _maxX = cx + halfSpanX;
      _minY = cy - halfSpanY;
      _maxY = cy + halfSpanY;
    });
  }

  void _pan(double dx, double dy, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final worldDx = -dx * (_maxX - _minX) / size.width;
    final worldDy = dy * (_maxY - _minY) / size.height;

    setState(() {
      _minX += worldDx;
      _maxX += worldDx;
      _minY += worldDy;
      _maxY += worldDy;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 1. Lienzo gráfico interactivo
              Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final factor = pointerSignal.scrollDelta.dy > 0 ? 1.15 : 0.85;
                    _zoom(factor, pointerSignal.localPosition, size);
                  }
                },
                child: GestureDetector(
                  onScaleStart: (details) {
                    _lastFocalPoint = details.localFocalPoint;
                  },
                  onScaleUpdate: (details) {
                    if (_lastFocalPoint != null) {
                      final dx = details.localFocalPoint.dx - _lastFocalPoint!.dx;
                      final dy = details.localFocalPoint.dy - _lastFocalPoint!.dy;
                      _pan(dx, dy, size);
                      _lastFocalPoint = details.localFocalPoint;
                    }
                    if (details.scale != 1.0) {
                      final factor = 1.0 / details.scale;
                      _zoom(factor, details.localFocalPoint, size);
                    }
                  },
                  onDoubleTap: _autoFitView,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: FunctionPainter(
                      functionExpression: widget.functionExpression,
                      result: widget.result,
                      currentStepIndex: widget.currentStepIndex,
                      parserService: widget.parserService,
                      minX: _minX,
                      maxX: _maxX,
                      minY: _minY,
                      maxY: _maxY,
                      showGrid: _showGrid,
                      isDarkTheme: isDark,
                    ),
                  ),
                ),
              ),

              // 2. Leyenda en la esquina superior izquierda
              Positioned(
                top: 12,
                left: 12,
                child: _buildLegendCard(isDark),
              ),

              // 3. Barra de herramientas flotante en la esquina superior derecha
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF262837) : Colors.white).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Acercar (Zoom +)',
                        onPressed: () => _zoom(0.8),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove, size: 20),
                        tooltip: 'Alejar (Zoom -)',
                        onPressed: () => _zoom(1.25),
                      ),
                      const Divider(height: 1),
                      IconButton(
                        icon: const Icon(Icons.crop_free, size: 20),
                        tooltip: 'Centrar / Auto-ajuste',
                        onPressed: _autoFitView,
                      ),
                      IconButton(
                        icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off, size: 20),
                        tooltip: _showGrid ? 'Ocultar cuadrícula' : 'Mostrar cuadrícula',
                        onPressed: () {
                          setState(() {
                            _showGrid = !_showGrid;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Indicador de coordenadas del rango en la esquina inferior izquierda
              Positioned(
                bottom: 8,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'X: [${_minX.toStringAsFixed(2)}, ${_maxX.toStringAsFixed(2)}]  '
                    'Y: [${_minY.toStringAsFixed(2)}, ${_maxY.toStringAsFixed(2)}]',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'RobotoMono'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF262837) : Colors.white).withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 3, color: const Color(0xFF29B6F6)),
              const SizedBox(width: 6),
              const Text('f(x)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          if (widget.result != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 3,
                  color: const Color(0xFFFF5252),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.result!.method == NumericalMethod.newtonRaphson
                      ? 'Tangente'
                      : widget.result!.method == NumericalMethod.secant
                          ? 'Secante'
                          : 'Cuerda [a,b]',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Nueva aprox. (xᵢ₊₁)', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
