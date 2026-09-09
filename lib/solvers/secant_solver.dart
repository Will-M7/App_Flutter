import 'dart:math' as math;
import '../models/calculation_result.dart';
import '../models/iteration_step.dart';
import '../models/method_type.dart';
import 'base_solver.dart';

/// Implementación del Método de la Secante
class SecantSolver extends BaseSolver {
  SecantSolver({super.parserService});

  @override
  NumericalMethod get method => NumericalMethod.secant;

  @override
  CalculationResult solve({
    required String functionExpression,
    required double initialX0,
    double? initialX1,
    required double tolerance,
    required int maxIterations,
  }) {
    final stopwatch = Stopwatch()..start();
    final List<IterationStep> steps = [];

    if (initialX1 == null) {
      return CalculationResult.failure(
        method: method,
        rawFunction: functionExpression,
        errorMessage: 'El método de la Secante requiere dos puntos iniciales (x₀ y x₁).',
      );
    }

    if ((initialX1 - initialX0).abs() < 1e-12) {
      return CalculationResult.failure(
        method: method,
        rawFunction: functionExpression,
        errorMessage: 'Los puntos iniciales x₀ y x₁ no pueden ser iguales.',
      );
    }

    // Validar sintaxis
    final syntaxError = parserService.validateExpression(functionExpression);
    if (syntaxError != null) {
      return CalculationResult.failure(
        method: method,
        rawFunction: functionExpression,
        errorMessage: syntaxError,
      );
    }

    double xPrev = initialX0;
    double xCurr = initialX1;
    double fxPrev;
    double fxCurr;

    try {
      fxPrev = parserService.evaluate(functionExpression, xPrev);
      fxCurr = parserService.evaluate(functionExpression, xCurr);
    } catch (e) {
      stopwatch.stop();
      return CalculationResult.failure(
        method: method,
        rawFunction: functionExpression,
        errorMessage: 'Error al evaluar valores iniciales: $e',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    // Paso inicial 0 (x0)
    steps.add(IterationStep(
      stepNumber: 0,
      currentX: xPrev,
      currentFx: fxPrev,
      note: 'Punto inicial x₀ = $xPrev, f(x₀) = $fxPrev',
    ));

    // Si x0 ya es raíz
    if (fxPrev.abs() <= tolerance) {
      stopwatch.stop();
      return CalculationResult(
        isSuccess: true,
        method: method,
        rawFunction: functionExpression,
        root: xPrev,
        finalFx: fxPrev,
        finalError: 0.0,
        steps: steps,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    // Iteración 1 (x1)
    final double err1 = (xCurr - xPrev).abs() / (xCurr.abs() > 1e-12 ? xCurr.abs() : 1.0);
    final double secantSlope0 = (fxCurr - fxPrev) / (xCurr - xPrev);
    final double nextX0 = xCurr - (fxCurr * (xCurr - xPrev)) / (fxCurr - fxPrev == 0 ? 1e-14 : (fxCurr - fxPrev));

    steps.add(IterationStep(
      stepNumber: 1,
      currentX: xCurr,
      currentFx: fxCurr,
      prevX: xPrev,
      prevFx: fxPrev,
      nextX: nextX0,
      slope: secantSlope0,
      error: err1,
      note: 'Punto inicial x₁ = $xCurr, f(x₁) = $fxCurr',
    ));

    if (fxCurr.abs() <= tolerance || err1 <= tolerance) {
      stopwatch.stop();
      return CalculationResult(
        isSuccess: true,
        method: method,
        rawFunction: functionExpression,
        root: xCurr,
        finalFx: fxCurr,
        finalError: err1,
        steps: steps,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    for (int i = 2; i <= maxIterations + 1; i++) {
      final double denom = fxCurr - fxPrev;
      if (denom.abs() < 1e-14) {
        stopwatch.stop();
        return CalculationResult.failure(
          method: method,
          rawFunction: functionExpression,
          errorMessage: 'División por cero en el paso $i: f(x_{${i-1}}) ≈ f(x_{${i-2}}) ($fxCurr ≈ $fxPrev). '
              'La recta secante es horizontal y no corta el eje X.',
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      final double slope = (fxCurr - fxPrev) / (xCurr - xPrev);
      final double xNext = xCurr - (fxCurr * (xCurr - xPrev)) / denom;

      double fxNext;
      try {
        fxNext = parserService.evaluate(functionExpression, xNext);
      } catch (e) {
        stopwatch.stop();
        return CalculationResult.failure(
          method: method,
          rawFunction: functionExpression,
          errorMessage: 'Error al evaluar f(x) en x = $xNext: $e',
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      final double error = (xNext - xCurr).abs() / (xNext.abs() > 1e-12 ? xNext.abs() : 1.0);

      steps.add(IterationStep(
        stepNumber: i,
        currentX: xNext,
        currentFx: fxNext,
        prevX: xCurr,
        prevFx: fxCurr,
        nextX: xNext,
        slope: slope,
        error: error,
        note: 'Secante entre ($xCurr, $fxCurr) y ($xNext, $fxNext)',
      ));

      if (fxNext.abs() <= tolerance || error <= tolerance) {
        stopwatch.stop();
        return CalculationResult(
          isSuccess: true,
          method: method,
          rawFunction: functionExpression,
          root: xNext,
          finalFx: fxNext,
          finalError: error,
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      if (xNext.isNaN || xNext.isInfinite || xNext.abs() > 1e12) {
        stopwatch.stop();
        return CalculationResult.failure(
          method: method,
          rawFunction: functionExpression,
          errorMessage: 'El método divergió (x_{$i} = $xNext). Intenta con otros valores iniciales.',
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      xPrev = xCurr;
      fxPrev = fxCurr;
      xCurr = xNext;
      fxCurr = fxNext;
    }

    stopwatch.stop();
    return CalculationResult.failure(
      method: method,
      rawFunction: functionExpression,
      errorMessage: 'Se alcanzó el número máximo de iteraciones ($maxIterations) sin converger. '
          'Última aproximación: x = $xCurr, |f(x)| = ${fxCurr.abs()}.',
      steps: steps,
      executionTimeMs: stopwatch.elapsedMilliseconds,
    );
  }
}
