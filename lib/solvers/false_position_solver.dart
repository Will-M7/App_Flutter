import 'dart:math' as math;
import '../models/calculation_result.dart';
import '../models/iteration_step.dart';
import '../models/method_type.dart';
import 'base_solver.dart';

/// Implementación del Método de Regla Falsa (Posición Falsa)
class FalsePositionSolver extends BaseSolver {
  FalsePositionSolver({super.parserService});

  @override
  NumericalMethod get method => NumericalMethod.falsePosition;

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
        errorMessage: 'El método de Regla Falsa requiere dos límites de intervalo [a, b].',
      );
    }

    if (initialX0 >= initialX1) {
      // Intercambiar si a > b para mantener orden natural
      final temp = initialX0;
      initialX0 = initialX1;
      initialX1 = temp;
    }

    if ((initialX1 - initialX0).abs() < 1e-12) {
      return CalculationResult.failure(
        method: method,
        rawFunction: functionExpression,
        errorMessage: 'Los límites del intervalo [a, b] no pueden ser idénticos.',
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

    double a = initialX0;
    double b = initialX1;
    double fa;
    double fb;

    try {
      fa = parserService.evaluate(functionExpression, a);
      fb = parserService.evaluate(functionExpression, b);
    } catch (e) {
      stopwatch.stop();
      return CalculationResult.failure(
        method: method,
        rawFunction: functionExpression,
        errorMessage: 'Error al evaluar los extremos del intervalo: $e',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    // Verificar si alguno de los extremos es raíz exacta
    if (fa.abs() <= tolerance) {
      steps.add(IterationStep(
        stepNumber: 0,
        currentX: a,
        currentFx: fa,
        intervalA: a,
        fa: fa,
        intervalB: b,
        fb: fb,
        error: 0.0,
        note: 'El extremo inferior a = $a ya es una raíz de la función.',
      ));
      stopwatch.stop();
      return CalculationResult(
        isSuccess: true,
        method: method,
        rawFunction: functionExpression,
        root: a,
        finalFx: fa,
        finalError: 0.0,
        steps: steps,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    if (fb.abs() <= tolerance) {
      steps.add(IterationStep(
        stepNumber: 0,
        currentX: b,
        currentFx: fb,
        intervalA: a,
        fa: fa,
        intervalB: b,
        fb: fb,
        error: 0.0,
        note: 'El extremo superior b = $b ya es una raíz de la función.',
      ));
      stopwatch.stop();
      return CalculationResult(
        isSuccess: true,
        method: method,
        rawFunction: functionExpression,
        root: b,
        finalFx: fb,
        finalError: 0.0,
        steps: steps,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    // Teorema de Bolzano: f(a)*f(b) debe ser menor a 0
    if (fa * fb > 0) {
      stopwatch.stop();
      return CalculationResult.failure(
        method: method,
        rawFunction: functionExpression,
        errorMessage: 'No se cumple el Teorema de Bolzano en [$a, $b]: f($a) = $fa y f($b) = $fb tienen el mismo signo. '
            'Debe existir un cambio de signo (f(a)·f(b) < 0) para garantizar una raíz en el intervalo.',
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    double? prevC;

    for (int i = 0; i <= maxIterations; i++) {
      final double denom = fb - fa;
      if (denom.abs() < 1e-15) {
        stopwatch.stop();
        return CalculationResult.failure(
          method: method,
          rawFunction: functionExpression,
          errorMessage: 'Denominador nulo f(b) - f(a) en la iteración $i.',
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Fórmula de Regla Falsa: c = (a*fb - b*fa) / (fb - fa)
      final double c = (a * fb - b * fa) / denom;
      final double slope = (fb - fa) / (b - a);

      double fc;
      try {
        fc = parserService.evaluate(functionExpression, c);
      } catch (e) {
        stopwatch.stop();
        return CalculationResult.failure(
          method: method,
          rawFunction: functionExpression,
          errorMessage: 'Error al evaluar f($c): $e',
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      double? error;
      if (prevC != null) {
        final denomErr = c.abs() > 1e-12 ? c.abs() : 1.0;
        error = (c - prevC).abs() / denomErr;
      }

      steps.add(IterationStep(
        stepNumber: i + 1,
        currentX: c,
        currentFx: fc,
        intervalA: a,
        fa: fa,
        intervalB: b,
        fb: fb,
        slope: slope,
        error: error,
        note: 'Intervalo [$a, $b] → c = $c, f(c) = $fc',
      ));

      // Criterio de parada
      if (fc.abs() <= tolerance || (error != null && error <= tolerance)) {
        stopwatch.stop();
        return CalculationResult(
          isSuccess: true,
          method: method,
          rawFunction: functionExpression,
          root: c,
          finalFx: fc,
          finalError: error ?? 0.0,
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Actualizar intervalo según signo
      if (fa * fc < 0) {
        b = c;
        fb = fc;
      } else {
        a = c;
        fa = fc;
      }

      prevC = c;
    }

    stopwatch.stop();
    return CalculationResult.failure(
      method: method,
      rawFunction: functionExpression,
      errorMessage: 'Se alcanzó el número máximo de iteraciones ($maxIterations) sin alcanzar la tolerancia ($tolerance). '
          'Último punto c = ${steps.last.currentX}, f(c) = ${steps.last.currentFx}.',
      steps: steps,
      executionTimeMs: stopwatch.elapsedMilliseconds,
    );
  }
}
