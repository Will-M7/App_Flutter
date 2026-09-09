import 'dart:math' as math;
import '../models/calculation_result.dart';
import '../models/iteration_step.dart';
import '../models/method_type.dart';
import 'base_solver.dart';

/// Implementación del Método de Newton-Raphson
class NewtonRaphsonSolver extends BaseSolver {
  NewtonRaphsonSolver({super.parserService});

  @override
  NumericalMethod get method => NumericalMethod.newtonRaphson;

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

    // Validar sintaxis
    final syntaxError = parserService.validateExpression(functionExpression);
    if (syntaxError != null) {
      return CalculationResult.failure(
        method: method,
        rawFunction: functionExpression,
        errorMessage: syntaxError,
      );
    }

    final derivativeStr = parserService.getAnalyticalDerivativeString(functionExpression);
    double currentX = initialX0;

    for (int i = 0; i <= maxIterations; i++) {
      double fx;
      double dfx;

      try {
        fx = parserService.evaluate(functionExpression, currentX);
      } catch (e) {
        stopwatch.stop();
        return CalculationResult.failure(
          method: method,
          rawFunction: functionExpression,
          errorMessage: 'Error evaluando f(x) en x = $currentX: $e',
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Evaluar derivada
      try {
        dfx = parserService.evaluateDerivative(functionExpression, currentX);
      } catch (e) {
        stopwatch.stop();
        return CalculationResult.failure(
          method: method,
          rawFunction: functionExpression,
          errorMessage: 'Error evaluando derivada f\'(x) en x = $currentX: $e',
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Verificar derivada nula
      if (dfx.abs() < 1e-12) {
        stopwatch.stop();
        return CalculationResult.failure(
          method: method,
          rawFunction: functionExpression,
          errorMessage: 'Derivada nula (f\'($currentX) ≈ 0) en la iteración $i. '
              'La recta tangente es horizontal y no corta el eje X.',
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Calcular siguiente x: x_{i+1} = x_i - f(x_i)/f'(x_i)
      final double nextX = currentX - (fx / dfx);

      // Calcular error aproximado
      double? error;
      if (i > 0) {
        final denom = nextX.abs() > 1e-12 ? nextX.abs() : 1.0;
        error = ((nextX - currentX).abs() / denom);
      }

      steps.add(IterationStep(
        stepNumber: i,
        currentX: currentX,
        currentFx: fx,
        derivativeFx: dfx,
        nextX: nextX,
        slope: dfx,
        error: error,
        note: 'x_{$i} = $currentX, f(x_{$i}) = $fx, f\'(x_{$i}) = $dfx → x_{${i + 1}} = $nextX',
      ));

      // Comprobar criterio de parada: |f(currentX)| < tol o error < tol
      if (fx.abs() <= tolerance || (error != null && error <= tolerance)) {
        stopwatch.stop();
        return CalculationResult(
          isSuccess: true,
          method: method,
          rawFunction: functionExpression,
          derivativeString: derivativeStr,
          root: currentX,
          finalFx: fx,
          finalError: error ?? 0.0,
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Verificar si diverge
      if (nextX.isNaN || nextX.isInfinite || nextX.abs() > 1e12) {
        stopwatch.stop();
        return CalculationResult.failure(
          method: method,
          rawFunction: functionExpression,
          errorMessage: 'El método divergió o generó valores fuera de escala (x_{${i+1}} = $nextX). '
              'Intenta con otro valor inicial x₀ más cercano a la raíz.',
          steps: steps,
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      currentX = nextX;
    }

    stopwatch.stop();
    return CalculationResult.failure(
      method: method,
      rawFunction: functionExpression,
      errorMessage: 'Se alcanzó el número máximo de iteraciones ($maxIterations) sin cumplir la tolerancia especificada ($tolerance). '
          'Última aproximación: x = $currentX, |f(x)| = ${steps.last.currentFx.abs()}.',
      steps: steps,
      executionTimeMs: stopwatch.elapsedMilliseconds,
    );
  }
}
