import 'dart:math' as math;
import 'package:math_expressions/math_expressions.dart';

/// Servicio encargado del análisis, parseo, derivación y evaluación numérica de funciones f(x)
class MathParserService {
  final Parser _parser = Parser();

  /// Limpia y normaliza la expresión matemática ingresada por el usuario
  String sanitizeExpression(String input) {
    String cleaned = input.trim();
    if (cleaned.isEmpty) return '';

    // Reemplazos de símbolos comunes y espacios
    cleaned = cleaned.replaceAll('×', '*').replaceAll('÷', '/');
    cleaned = cleaned.replaceAll(',', '.');

    // Manejo de ln(x) -> ln(x) o log(x)
    // En math_expressions 'ln' existe como Ln, pero 'log' es logaritmo en base 10 o natural según versión.
    // Estandarizamos funciones
    cleaned = cleaned.replaceAll(RegExp(r'\bexp\b'), 'e^');

    // Inserción de multiplicación implícita:
    // Número seguido de variable: 4x -> 4*x, 3.5x -> 3.5*x
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z\(])'),
      (match) => '${match.group(1)}*${match.group(2)}',
    );

    // Paréntesis de cierre seguido de paréntesis de apertura: (x+1)(x-1) -> (x+1)*(x-1)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\)\s*\('),
      (match) => ')*(',
    );

    // Paréntesis de cierre seguido de variable o número: )x -> )*x
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\)\s*([0-9a-zA-Z])'),
      (match) => ')*${match.group(1)}',
    );

    // Variable seguida de paréntesis de apertura si no es función conocida
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!sin|cos|tan|cot|sec|csc|asin|acos|atan|sqrt|log|ln|abs)\bx\s*\('),
      (match) => 'x*(',
    );

    return cleaned;
  }

  /// Valida la sintaxis de una expresión matemática
  String? validateExpression(String expressionText) {
    if (expressionText.trim().isEmpty) {
      return 'Por favor ingresa una función f(x).';
    }

    try {
      final sanitized = sanitizeExpression(expressionText);
      final Expression exp = _parser.parse(sanitized);

      // Probamos evaluar en un punto de prueba genérico (ej. x = 1.0)
      final cm = ContextModel();
      cm.bindVariable(Variable('x'), Number(1.0));
      cm.bindVariable(Variable('e'), Number(math.e));
      cm.bindVariable(Variable('pi'), Number(math.pi));

      final val = exp.evaluate(EvaluationType.REAL, cm);
      if (val is double && (val.isNaN || val.isInfinite)) {
        // Puede ser indeterminación en x=1, pero la sintaxis es válida
      }
      return null; // Sintaxis válida
    } catch (e) {
      return 'Sintaxis de función inválida: ${e.toString().replaceAll('FormatException: ', '')}';
    }
  }

  /// Evalúa f(x) en un valor específico de x
  double evaluate(String expressionText, double x) {
    try {
      final sanitized = sanitizeExpression(expressionText);
      final Expression exp = _parser.parse(sanitized);
      final cm = ContextModel();
      cm.bindVariable(Variable('x'), Number(x));
      cm.bindVariable(Variable('e'), Number(math.e));
      cm.bindVariable(Variable('pi'), Number(math.pi));

      final dynamic result = exp.evaluate(EvaluationType.REAL, cm);
      if (result is num) {
        final dResult = result.toDouble();
        if (dResult.isNaN || dResult.isInfinite) {
          throw Exception('Resultado no real o indeterminado en x = $x');
        }
        return dResult;
      }
      throw Exception('No se pudo calcular el valor numérico.');
    } catch (e) {
      throw Exception('Error al evaluar f($x): ${e.toString()}');
    }
  }

  /// Obtiene la expresión analítica de la derivada f'(x) si es posible
  String? getAnalyticalDerivativeString(String expressionText) {
    try {
      final sanitized = sanitizeExpression(expressionText);
      final Expression exp = _parser.parse(sanitized);
      final Expression derivativeExp = exp.derive('x');
      final simplified = derivativeExp.simplify();
      return simplified.toString();
    } catch (_) {
      // Si la función analítica contiene operadores no diferenciables analíticamente
      return null;
    }
  }

  /// Evalúa la derivada f'(x), intentando primero la analítica y como respaldo diferencias finitas
  double evaluateDerivative(String expressionText, double x) {
    // 1. Intento Analítico
    try {
      final sanitized = sanitizeExpression(expressionText);
      final Expression exp = _parser.parse(sanitized);
      final Expression derivativeExp = exp.derive('x');
      final cm = ContextModel();
      cm.bindVariable(Variable('x'), Number(x));
      cm.bindVariable(Variable('e'), Number(math.e));
      cm.bindVariable(Variable('pi'), Number(math.pi));

      final dynamic result = derivativeExp.evaluate(EvaluationType.REAL, cm);
      if (result is num && !result.isNaN && !result.isInfinite) {
        return result.toDouble();
      }
    } catch (_) {
      // Fallback a derivada numérica
    }

    // 2. Respaldo por Diferencias Finitas Centrales de 4to orden
    // f'(x) ≈ (-f(x+2h) + 8f(x+h) - 8f(x-h) + f(x-2h)) / (12h)
    const double h = 1e-6;
    try {
      final double fPlus2h = evaluate(expressionText, x + 2 * h);
      final double fPlusH = evaluate(expressionText, x + h);
      final double fMinusH = evaluate(expressionText, x - h);
      final double fMinus2h = evaluate(expressionText, x - 2 * h);

      final double numDeriv = (-fPlus2h + 8 * fPlusH - 8 * fMinusH + fMinus2h) / (12 * h);
      if (numDeriv.isNaN || numDeriv.isInfinite) {
        throw Exception('Derivada indefinida en x = $x');
      }
      return numDeriv;
    } catch (e) {
      // Diferencia central básica
      final double fPlusH = evaluate(expressionText, x + h);
      final double fMinusH = evaluate(expressionText, x - h);
      return (fPlusH - fMinusH) / (2 * h);
    }
  }
}
