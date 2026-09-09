import '../models/calculation_result.dart';
import '../models/method_type.dart';
import '../services/math_parser_service.dart';

/// Interfaz abstracta para los algoritmos de resolución numéricos
abstract class BaseSolver {
  final MathParserService parserService;

  BaseSolver({MathParserService? parserService})
      : parserService = parserService ?? MathParserService();

  NumericalMethod get method;

  /// Resuelve la ecuación f(x) = 0 según los parámetros dados
  CalculationResult solve({
    required String functionExpression,
    required double initialX0,
    double? initialX1,
    required double tolerance,
    required int maxIterations,
  });
}
