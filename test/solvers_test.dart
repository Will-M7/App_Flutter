import 'package:flutter_test/flutter_test.dart';
import 'package:metodos_numericos_raices/models/method_type.dart';
import 'package:metodos_numericos_raices/services/math_parser_service.dart';
import 'package:metodos_numericos_raices/solvers/false_position_solver.dart';
import 'package:metodos_numericos_raices/solvers/newton_raphson_solver.dart';
import 'package:metodos_numericos_raices/solvers/secant_solver.dart';

void main() {
  group('MathParserService Tests', () {
    final parser = MathParserService();

    test('Evaluate polynomial x^3 - 4*x - 9', () {
      final res = parser.evaluate('x^3 - 4*x - 9', 2.0);
      expect(res, equals(8 - 8 - 9)); // -9
    });

    test('Evaluate derivative of x^3 - 4*x - 9 at x = 2', () {
      // f'(x) = 3*x^2 - 4 -> f'(2) = 12 - 4 = 8
      final dres = parser.evaluateDerivative('x^3 - 4*x - 9', 2.0);
      expect((dres - 8.0).abs() < 1e-4, isTrue);
    });

    test('Evaluate trigonometric and exponential functions', () {
      final cosRes = parser.evaluate('cos(x) - x', 0.0);
      expect(cosRes, equals(1.0));

      final expRes = parser.evaluate('e^(-x) - x', 0.0);
      expect(expRes, equals(1.0));
    });
  });

  group('Numerical Solvers Tests', () {
    final parser = MathParserService();

    test('Newton-Raphson finds root of x^3 - 4*x - 9', () {
      final solver = NewtonRaphsonSolver(parserService: parser);
      final result = solver.solve(
        functionExpression: 'x^3 - 4*x - 9',
        initialX0: 2.0,
        tolerance: 0.0001,
        maxIterations: 50,
      );

      expect(result.isSuccess, isTrue);
      expect(result.root, isNotNull);
      expect((result.root! - 2.7065).abs() < 0.001, isTrue);
      expect(result.steps.isNotEmpty, isTrue);
    });

    test('Secant method finds root of x^3 - 4*x - 9', () {
      final solver = SecantSolver(parserService: parser);
      final result = solver.solve(
        functionExpression: 'x^3 - 4*x - 9',
        initialX0: 2.0,
        initialX1: 3.0,
        tolerance: 0.0001,
        maxIterations: 50,
      );

      expect(result.isSuccess, isTrue);
      expect(result.root, isNotNull);
      expect((result.root! - 2.7065).abs() < 0.001, isTrue);
    });

    test('False Position finds root of x^3 - 4*x - 9 in [2, 3]', () {
      final solver = FalsePositionSolver(parserService: parser);
      final result = solver.solve(
        functionExpression: 'x^3 - 4*x - 9',
        initialX0: 2.0,
        initialX1: 3.0,
        tolerance: 0.0001,
        maxIterations: 50,
      );

      expect(result.isSuccess, isTrue);
      expect(result.root, isNotNull);
      expect((result.root! - 2.7065).abs() < 0.001, isTrue);
    });

    test('False Position detects Bolzano violation', () {
      final solver = FalsePositionSolver(parserService: parser);
      // In [0, 1], f(0) = -9, f(1) = 1 - 4 - 9 = -12 (both negative)
      final result = solver.solve(
        functionExpression: 'x^3 - 4*x - 9',
        initialX0: 0.0,
        initialX1: 1.0,
        tolerance: 0.0001,
        maxIterations: 50,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Bolzano'));
    });
  });
}
