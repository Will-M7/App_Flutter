import 'iteration_step.dart';
import 'method_type.dart';

/// Estado y resultado final de la ejecución del método numérico
class CalculationResult {
  /// Indica si el algoritmo convergió exitosamente
  final bool isSuccess;

  /// Método numérico utilizado
  final NumericalMethod method;

  /// Expresión de la función f(x) ingresada
  final String rawFunction;

  /// Expresión de la derivada analítica calculada (si aplica)
  final String? derivativeString;

  /// Valor final aproximado de la raíz encontrada
  final double? root;

  /// Valor de f(raíz)
  final double? finalFx;

  /// Error final alcanzado
  final double? finalError;

  /// Lista de todos los pasos e iteraciones calculadas
  final List<IterationStep> steps;

  /// Mensaje de error o advertencia en español si no hubo convergencia
  final String? errorMessage;

  /// Tiempo de cálculo en milisegundos
  final int executionTimeMs;

  const CalculationResult({
    required this.isSuccess,
    required this.method,
    required this.rawFunction,
    this.derivativeString,
    this.root,
    this.finalFx,
    this.finalError,
    required this.steps,
    this.errorMessage,
    this.executionTimeMs = 0,
  });

  /// Factory para construir un resultado fallido
  factory CalculationResult.failure({
    required NumericalMethod method,
    required String rawFunction,
    required String errorMessage,
    List<IterationStep> steps = const [],
    int executionTimeMs = 0,
  }) {
    return CalculationResult(
      isSuccess: false,
      method: method,
      rawFunction: rawFunction,
      steps: steps,
      errorMessage: errorMessage,
      executionTimeMs: executionTimeMs,
    );
  }
}
