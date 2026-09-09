import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:math_expressions/math_expressions.dart';

// Test of corrected solvers
void main() {
  group('Mathematical Solvers Exact Verification', () {
    final parser = Parser();

    double eval(String expr, double x) {
      String clean = expr.replaceAll('e^(-x)', 'e^(-1*x)');
      clean = clean.replaceAllMapped(
        RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z\(])'),
        (match) => '${match.group(1)}*${match.group(2)}',
      );
      final e = parser.parse(clean);
      final cm = ContextModel();
      cm.bindVariable(Variable('x'), Number(x));
      cm.bindVariable(Variable('e'), Number(math.e));
      return (e.evaluate(EvaluationType.REAL, cm) as num).toDouble();
    }

    double evalDeriv(String expr, double x) {
      const double h = 1e-6;
      final double fPlus = eval(expr, x + h);
      final double fMinus = eval(expr, x - h);
      return (fPlus - fMinus) / (2 * h);
    }

    test('Newton-Raphson benchmark test: f(x) = e^(-x) + x^2 - 3*x - 2, x0 = 3', () {
      const func = 'e^(-x) + x^2 - 3*x - 2';
      const tol = 0.0001;
      double currX = 3.0;
      int step = 0;

      final List<Map<String, dynamic>> steps = [];
      double fx0 = eval(func, currX);
      double dfx0 = evalDeriv(func, currX);
      steps.add({'step': 0, 'x': currX, 'fx': fx0, 'dfx': dfx0, 'ea': null});

      for (int i = 0; i < 50; i++) {
        double fx = eval(func, currX);
        double dfx = evalDeriv(func, currX);
        double nextX = currX - (fx / dfx);
        double nextFx = eval(func, nextX);
        double nextDfx = evalDeriv(func, nextX);
        double ea = (nextX - currX).abs() / nextX.abs();

        steps.add({'step': i + 1, 'x': nextX, 'fx': nextFx, 'dfx': nextDfx, 'ea': ea});

        if (ea <= tol) {
          step = i + 1;
          currX = nextX;
          break;
        }
        currX = nextX;
      }

      // Step 4 is expected to satisfy Ea <= 0.0001
      expect(step, equals(4));
      expect((currX - 3.554606379).abs() < 1e-5, isTrue);
    });

    test('Secant benchmark test: f(x) = e^(-x) + x^2 - 3*x - 2, x0 = 3, x1 = 4', () {
      const func = 'e^(-x) + x^2 - 3*x - 2';
      const tol = 0.0001;
      double xPrev = 3.0;
      double xCurr = 4.0;
      double fxPrev = eval(func, xPrev);
      double fxCurr = eval(func, xCurr);
      int finalIter = 0;
      double finalRoot = 0.0;

      for (int k = 1; k <= 50; k++) {
        double xNext = xCurr - (fxCurr * (xCurr - xPrev)) / (fxCurr - fxPrev);
        double fxNext = eval(func, xNext);
        double ea = (xNext - xCurr).abs() / xNext.abs();

        if (ea <= tol) {
          finalIter = k;
          finalRoot = xNext;
          break;
        }
        xPrev = xCurr;
        fxPrev = fxCurr;
        xCurr = xNext;
        fxCurr = fxNext;
      }

      // Iteration 4 is expected to produce x5 = 3.554606217 with Ea <= 0.0001
      expect(finalIter, equals(4));
      expect((finalRoot - 3.554606217).abs() < 1e-5, isTrue);
    });

    test('False Position benchmark test: f(x) = e^(-x) + x^2 - 3*x - 2, a = 3, b = 4', () {
      const func = 'e^(-x) + x^2 - 3*x - 2';
      const tol = 0.0001;
      double a = 3.0;
      double b = 4.0;
      double fa = eval(func, a);
      double fb = eval(func, b);
      double? prevC;
      int finalIter = 0;
      double finalRoot = 0.0;

      for (int k = 1; k <= 50; k++) {
        double c = (a * fb - b * fa) / (fb - fa);
        double fc = eval(func, c);
        double? ea = prevC != null ? (c - prevC).abs() / c.abs() : null;

        if (ea != null && ea <= tol) {
          finalIter = k;
          finalRoot = c;
          break;
        }

        if (fa * fc < 0) {
          b = c;
          fb = fc;
        } else {
          a = c;
          fa = fc;
        }
        prevC = c;
      }

      // Iteration 5 is expected to satisfy Ea <= 0.0001 with root ~ 3.554600084
      expect(finalIter, equals(5));
      expect((finalRoot - 3.554600084).abs() < 1e-5, isTrue);
    });
  });
}
