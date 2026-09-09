import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MetodosNumericosApp());
}

// =============================================================================
// ENUMS Y MODELOS DE DATOS
// =============================================================================

/// Métodos numéricos disponibles
enum NumericalMethod {
  newtonRaphson,
  secant,
  falsePosition,
}

extension NumericalMethodExtension on NumericalMethod {
  String get displayName {
    switch (this) {
      case NumericalMethod.newtonRaphson:
        return 'Método de Newton-Raphson';
      case NumericalMethod.secant:
        return 'Método de la Secante';
      case NumericalMethod.falsePosition:
        return 'Método de Regla Falsa (False Position)';
    }
  }

  String get shortFormula {
    switch (this) {
      case NumericalMethod.newtonRaphson:
        return 'x_{i+1} = x_i - f(x_i) / f\'(x_i)';
      case NumericalMethod.secant:
        return 'x_{i+1} = x_i - [f(x_i)·(x_i - x_{i-1})] / [f(x_i) - f(x_{i-1})]';
      case NumericalMethod.falsePosition:
        return 'c = [a·f(b) - b·f(a)] / [f(b) - f(a)]';
    }
  }

  String get description {
    switch (this) {
      case NumericalMethod.newtonRaphson:
        return 'Método abierto de rápida convergencia cuadrática que emplea la recta tangente y la primera derivada en cada iteración.';
      case NumericalMethod.secant:
        return 'Método abierto que aproxima la derivada mediante diferencias finitas usando dos puntos iniciales y rectas secantes.';
      case NumericalMethod.falsePosition:
        return 'Método cerrado de intervalo que une los extremos [a, b] con una cuerda secante, garantizando convergencia si f(a)·f(b) < 0.';
    }
  }

  bool get requiresTwoInitialPoints {
    switch (this) {
      case NumericalMethod.newtonRaphson:
        return false;
      case NumericalMethod.secant:
      case NumericalMethod.falsePosition:
        return true;
    }
  }

  String get primaryInitialLabel {
    switch (this) {
      case NumericalMethod.newtonRaphson:
        return 'Valor Inicial (x₀)';
      case NumericalMethod.secant:
        return 'Primer punto (x₀)';
      case NumericalMethod.falsePosition:
        return 'Límite Inferior (a)';
    }
  }

  String get secondaryInitialLabel {
    switch (this) {
      case NumericalMethod.newtonRaphson:
        return '';
      case NumericalMethod.secant:
        return 'Segundo punto (x₁)';
      case NumericalMethod.falsePosition:
        return 'Límite Superior (b)';
    }
  }
}

/// Modo de vista activa seleccionada por los 3 botones principales
enum ActiveViewMode {
  calcular, // Muestra únicamente la tarjeta de resultado/raíz
  graficar, // Muestra únicamente el gráfico interactivo 2D
  cuadros,  // Muestra únicamente la tabla de iteraciones
}

/// Representa el registro de un paso individual en el algoritmo
class IterationStep {
  final int stepNumber;
  final double currentX;
  final double currentFx;
  final double? error;
  final double? prevX;
  final double? prevFx;
  final double? nextX;
  final double? derivativeFx;
  final double? intervalA;
  final double? fa;
  final double? intervalB;
  final double? fb;
  final double? slope;
  final String? note;

  const IterationStep({
    required this.stepNumber,
    required this.currentX,
    required this.currentFx,
    this.error,
    this.prevX,
    this.prevFx,
    this.nextX,
    this.derivativeFx,
    this.intervalA,
    this.fa,
    this.intervalB,
    this.fb,
    this.slope,
    this.note,
  });
}

/// Resultado consolidado del cálculo numérico
class CalculationResult {
  final bool isSuccess;
  final NumericalMethod method;
  final String rawFunction;
  final String sanitizedFunction;
  final String? derivativeString;
  final double? root;
  final double? finalFx;
  final double? finalError;
  final List<IterationStep> steps;
  final String? errorMessage;
  final int executionTimeMs;

  const CalculationResult({
    required this.isSuccess,
    required this.method,
    required this.rawFunction,
    required this.sanitizedFunction,
    this.derivativeString,
    this.root,
    this.finalFx,
    this.finalError,
    required this.steps,
    this.errorMessage,
    this.executionTimeMs = 0,
  });

  factory CalculationResult.failure({
    required NumericalMethod method,
    required String rawFunction,
    required String sanitizedFunction,
    required String errorMessage,
    List<IterationStep> steps = const [],
    int executionTimeMs = 0,
  }) {
    return CalculationResult(
      isSuccess: false,
      method: method,
      rawFunction: rawFunction,
      sanitizedFunction: sanitizedFunction,
      steps: steps,
      errorMessage: errorMessage,
      executionTimeMs: executionTimeMs,
    );
  }
}

// =============================================================================
// FORMATEADOR Y SANITIZADOR DE ENTRADA / PORTAPAPELES
// =============================================================================

/// Formateador de texto que intercepta la entrada del usuario o pegado (Ctrl+V)
/// y sanea automáticamente caracteres tipográficos de Word, PDF o sitios web.
class MathExpressionInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = MathParserService.cleanClipboardText(newValue.text);
    if (cleaned == newValue.text) {
      return newValue;
    }

    // Calcular la nueva posición del cursor ajustada
    final int newOffset = (newValue.selection.baseOffset + (cleaned.length - newValue.text.length))
        .clamp(0, cleaned.length);

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

// =============================================================================
// PREPROCESADOR MATEMÁTICO ROBUSTO Y SERVICIO DE EVALUACIÓN
// =============================================================================

class MathParserService {
  final Parser _parser = Parser();

  /// Limpia texto proveniente del portapapeles (Word, PDF, navegadores web)
  static String cleanClipboardText(String input) {
    if (input.isEmpty) return '';

    String text = input;

    // 1. Eliminar caracteres invisibles, saltos de línea y espacios de ancho cero
    text = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u00AD\u200E\u200F]'), '');
    text = text.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    // Espacios especiales y no rompibles a espacio estándar
    text = text.replaceAll(RegExp(r'[\u00A0\u202F\u2007\u2000-\u200A]'), ' ');

    // 2. Normalización de Guiones y Menos Tipográficos
    // en-dash (–), em-dash (—), minus sign (−), figure dash (‒), horizontal bar (―), fullwidth hyphen (－)
    text = text.replaceAll(RegExp(r'[\u2010-\u2015\u2212\uFE63\uFF0D]'), '-');

    // 3. Normalización de Multiplicación y División Tipográfica
    // ×, ✕, ✖, ·, •, ⋅, ∗ -> *
    text = text.replaceAll(RegExp(r'[\u00D7\u2715\u2716\u00B7\u2022\u22C5\u2217]'), '*');
    // ÷, ∕, ⁄ -> /
    text = text.replaceAll(RegExp(r'[\u00F7\u2215\u2044]'), '/');

    // 4. Conversión de Superíndices Unicode a potencias con '^'
    // ej. x², x³, x⁴, e⁻ˣ
    text = text.replaceAll('⁰', '^0')
               .replaceAll('¹', '^1')
               .replaceAll('²', '^2')
               .replaceAll('³', '^3')
               .replaceAll('⁴', '^4')
               .replaceAll('⁵', '^5')
               .replaceAll('⁶', '^6')
               .replaceAll('⁷', '^7')
               .replaceAll('⁸', '^8')
               .replaceAll('⁹', '^9')
               .replaceAll('⁺', '^+')
               .replaceAll('⁻', '^-')
               .replaceAll('ˣ', '^x');

    // 5. Normalizar variables matemáticas unicode (ej. 𝑥 matemática de fórmulas Word/LaTeX)
    text = text.replaceAll(RegExp(r'[\u{1D45F}\u{1D43B}\u{1D48F}\u{1D4C3}\u{1D52F}\u{1D563}\u{1D597}\u{1D5CB}\u{1D5FF}\u{1D633}\u{1D667}\u{1D69B}]', unicode: true), 'x');
    text = text.replaceAll(RegExp(r'[\u{1D44E}\u{1D482}\u{1D51E}\u{1D552}\u{1D586}\u{1D5BA}\u{1D5EE}\u{1D622}\u{1D656}\u{1D68A}]', unicode: true), 'a');
    text = text.replaceAll(RegExp(r'[\u{1D44F}\u{1D483}\u{1D51F}\u{1D553}\u{1D587}\u{1D5BB}\u{1D5EF}\u{1D623}\u{1D657}\u{1D68B}]', unicode: true), 'b');

    // 6. Eliminar comillas tipográficas o caracteres extraños que puedan romper el parser
    text = text.replaceAll(RegExp(r'[\u2018\u2019\u201C\u201D\u2032\u2033]'), '');

    return text;
  }

  /// Preprocesa y limpia la función f(x), agregando automáticamente multiplicaciones implícitas
  String sanitizeExpression(String input) {
    String text = cleanClipboardText(input).trim();
    if (text.isEmpty) return '';

    // Reemplazos de comas decimales por puntos
    text = text.replaceAll(',', '.');

    // Corregir potencias dobles accidentales como '^^' -> '^'
    text = text.replaceAll(RegExp(r'\^{2,}'), '^');

    // exp(expr) -> e^(expr) para compatibilidad estándar
    text = text.replaceAll(RegExp(r'\bexp\s*\('), 'e^(');
    // Normalizar mayúsculas de funciones
    text = text.replaceAll('SIN', 'sin').replaceAll('COS', 'cos').replaceAll('TAN', 'tan');
    text = text.replaceAll('SQRT', 'sqrt').replaceAll('LN', 'ln').replaceAll('LOG', 'log');

    // Multiplicación implícita: Número seguido de variable o paréntesis
    // ej: '2x' -> '2*x', '5.2(x+1)' -> '5.2*(x+1)', '3e' -> '3*e'
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z\(])'),
      (match) => '${match.group(1)}*${match.group(2)}',
    );

    // Multiplicación implícita: Paréntesis cerrado seguido de paréntesis abierto
    // ej: '(x+1)(x-1)' -> '(x+1)*(x-1)'
    text = text.replaceAllMapped(
      RegExp(r'\)\s*\('),
      (match) => ')*(',
    );

    // Multiplicación implícita: Paréntesis cerrado seguido de número o variable
    // ej: '(x+1)2' -> '(x+1)*2', '(x+1)x' -> '(x+1)*x'
    text = text.replaceAllMapped(
      RegExp(r'\)\s*([0-9a-zA-Z])'),
      (match) => ')*${match.group(1)}',
    );

    // Multiplicación implícita: Variable x seguida de paréntesis abierto
    // ej: 'x(2)' -> 'x*(2)', 'x(x+1)' -> 'x*(x+1)'
    text = text.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z])([xX])\s*\('),
      (match) => '${match.group(1)}*(',
    );

    // Multiplicación implícita: Variable x seguida de función matemática o e^
    // ej: 'xsin(x)' -> 'x*sin(x)', 'xcos(x)' -> 'x*cos(x)', 'xe^x' -> 'x*e^x'
    text = text.replaceAllMapped(
      RegExp(r'(?<![a-zA-Z])([xX])\s*(sin|cos|tan|sqrt|ln|log|e\^|e)'),
      (match) => '${match.group(1)}*${match.group(2)}',
    );

    return text;
  }

  /// Valida la sintaxis matemática de la expresión
  String? validateExpression(String expressionText) {
    final cleaned = cleanClipboardText(expressionText).trim();
    if (cleaned.isEmpty) {
      return 'Por favor ingresa una función f(x).';
    }

    try {
      final sanitized = sanitizeExpression(cleaned);
      final Expression exp = _parser.parse(sanitized);

      final cm = ContextModel();
      cm.bindVariable(Variable('x'), Number(1.0));
      cm.bindVariable(Variable('e'), Number(math.e));
      cm.bindVariable(Variable('pi'), Number(math.pi));

      final dynamic val = exp.evaluate(EvaluationType.REAL, cm);
      if (val is double && (val.isNaN || val.isInfinite)) {
        // Expresión sintácticamente válida aunque tenga singularidad en 1
      }
      return null;
    } catch (e) {
      final msg = e.toString().replaceAll('FormatException: ', '').replaceAll('Exception: ', '');
      return 'Sintaxis de función no válida: $msg';
    }
  }

  /// Evalúa f(x) numéricamente
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
        final d = result.toDouble();
        if (d.isNaN || d.isInfinite) {
          throw Exception('Resultado indeterminado o división por cero en x = $x');
        }
        return d;
      }
      throw Exception('No se obtuvo un valor numérico real.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Obtiene la derivada analítica en formato texto
  String? getAnalyticalDerivativeString(String expressionText) {
    try {
      final sanitized = sanitizeExpression(expressionText);
      final Expression exp = _parser.parse(sanitized);
      final Expression dExp = exp.derive('x');
      return dExp.simplify().toString();
    } catch (_) {
      return null;
    }
  }

  /// Evalúa f'(x) analíticamente o por diferencias finitas centrales
  double evaluateDerivative(String expressionText, double x) {
    // 1. Intento Analítico
    try {
      final sanitized = sanitizeExpression(expressionText);
      final Expression exp = _parser.parse(sanitized);
      final Expression dExp = exp.derive('x');
      final cm = ContextModel();
      cm.bindVariable(Variable('x'), Number(x));
      cm.bindVariable(Variable('e'), Number(math.e));
      cm.bindVariable(Variable('pi'), Number(math.pi));

      final dynamic result = dExp.evaluate(EvaluationType.REAL, cm);
      if (result is num && !result.isNaN && !result.isInfinite) {
        return result.toDouble();
      }
    } catch (_) {}

    // 2. Respaldo numérico por diferencias finitas centrales de alta precisión
    const double h = 1e-6;
    try {
      final double fPlus2h = evaluate(expressionText, x + 2 * h);
      final double fPlusH = evaluate(expressionText, x + h);
      final double fMinusH = evaluate(expressionText, x - h);
      final double fMinus2h = evaluate(expressionText, x - 2 * h);
      return (-fPlus2h + 8 * fPlusH - 8 * fMinusH + fMinus2h) / (12 * h);
    } catch (_) {
      final double fPlusH = evaluate(expressionText, x + h);
      final double fMinusH = evaluate(expressionText, x - h);
      return (fPlusH - fMinusH) / (2 * h);
    }
  }
}

// =============================================================================
// SOLVERS NUMÉRICOS
// =============================================================================

class NumericalSolversEngine {
  final MathParserService parser;

  NumericalSolversEngine(this.parser);

  /// Método de Newton-Raphson
  CalculationResult solveNewtonRaphson({
    required String rawFunction,
    required double x0,
    required double tolerance,
    required int maxIterations,
  }) {
    final sw = Stopwatch()..start();
    final sanitized = parser.sanitizeExpression(rawFunction);
    final syntaxErr = parser.validateExpression(rawFunction);
    if (syntaxErr != null) {
      return CalculationResult.failure(
        method: NumericalMethod.newtonRaphson,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: syntaxErr,
      );
    }

    final derivativeStr = parser.getAnalyticalDerivativeString(rawFunction);
    final List<IterationStep> steps = [];
    double currentX = x0;

    for (int i = 0; i <= maxIterations; i++) {
      double fx;
      double dfx;

      try {
        fx = parser.evaluate(rawFunction, currentX);
      } catch (e) {
        sw.stop();
        return CalculationResult.failure(
          method: NumericalMethod.newtonRaphson,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          errorMessage: 'Error al evaluar f($currentX): $e',
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
        );
      }

      try {
        dfx = parser.evaluateDerivative(rawFunction, currentX);
      } catch (e) {
        sw.stop();
        return CalculationResult.failure(
          method: NumericalMethod.newtonRaphson,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          errorMessage: 'Error al evaluar f\'($currentX): $e',
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
        );
      }

      if (dfx.abs() < 1e-12) {
        sw.stop();
        return CalculationResult.failure(
          method: NumericalMethod.newtonRaphson,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          errorMessage: 'Derivada nula (f\'($currentX) ≈ 0) en la iteración $i. La tangente es horizontal.',
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
        );
      }

      final double nextX = currentX - (fx / dfx);
      double? error;
      if (i > 0) {
        final denom = nextX.abs() > 1e-12 ? nextX.abs() : 1.0;
        error = (nextX - currentX).abs() / denom;
      }

      steps.add(IterationStep(
        stepNumber: i,
        currentX: currentX,
        currentFx: fx,
        derivativeFx: dfx,
        nextX: nextX,
        slope: dfx,
        error: error,
        note: 'x_{$i} = $currentX, f(x) = $fx, f\'(x) = $dfx → x_{${i + 1}} = $nextX',
      ));

      if (fx.abs() <= tolerance || (error != null && error <= tolerance)) {
        sw.stop();
        return CalculationResult(
          isSuccess: true,
          method: NumericalMethod.newtonRaphson,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          derivativeString: derivativeStr,
          root: currentX,
          finalFx: fx,
          finalError: error ?? 0.0,
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
        );
      }

      if (nextX.isNaN || nextX.isInfinite || nextX.abs() > 1e12) {
        sw.stop();
        return CalculationResult.failure(
          method: NumericalMethod.newtonRaphson,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          errorMessage: 'El método divergió (x_{${i+1}} = $nextX). Prueba con un valor inicial más cercano.',
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
        );
      }

      currentX = nextX;
    }

    sw.stop();
    return CalculationResult.failure(
      method: NumericalMethod.newtonRaphson,
      rawFunction: rawFunction,
      sanitizedFunction: sanitized,
      errorMessage: 'Se superó el límite de $maxIterations iteraciones sin converger a la tolerancia $tolerance.',
      steps: steps,
      executionTimeMs: sw.elapsedMilliseconds,
    );
  }

  /// Método de la Secante
  CalculationResult solveSecant({
    required String rawFunction,
    required double x0,
    required double? x1,
    required double tolerance,
    required int maxIterations,
  }) {
    final sw = Stopwatch()..start();
    final sanitized = parser.sanitizeExpression(rawFunction);

    if (x1 == null) {
      return CalculationResult.failure(
        method: NumericalMethod.secant,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: 'El método de la Secante requiere dos puntos iniciales (x₀ y x₁).',
      );
    }

    if ((x1 - x0).abs() < 1e-12) {
      return CalculationResult.failure(
        method: NumericalMethod.secant,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: 'Los puntos iniciales x₀ y x₁ no pueden ser iguales.',
      );
    }

    final syntaxErr = parser.validateExpression(rawFunction);
    if (syntaxErr != null) {
      return CalculationResult.failure(
        method: NumericalMethod.secant,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: syntaxErr,
      );
    }

    final List<IterationStep> steps = [];
    double xPrev = x0;
    double xCurr = x1;
    double fxPrev;
    double fxCurr;

    try {
      fxPrev = parser.evaluate(rawFunction, xPrev);
      fxCurr = parser.evaluate(rawFunction, xCurr);
    } catch (e) {
      sw.stop();
      return CalculationResult.failure(
        method: NumericalMethod.secant,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: 'Error al evaluar puntos iniciales: $e',
        executionTimeMs: sw.elapsedMilliseconds,
      );
    }

    steps.add(IterationStep(
      stepNumber: 0,
      currentX: xPrev,
      currentFx: fxPrev,
      note: 'Punto inicial x₀ = $xPrev, f(x₀) = $fxPrev',
    ));

    if (fxPrev.abs() <= tolerance) {
      sw.stop();
      return CalculationResult(
        isSuccess: true,
        method: NumericalMethod.secant,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        root: xPrev,
        finalFx: fxPrev,
        finalError: 0.0,
        steps: steps,
        executionTimeMs: sw.elapsedMilliseconds,
      );
    }

    final double err1 = (xCurr - xPrev).abs() / (xCurr.abs() > 1e-12 ? xCurr.abs() : 1.0);
    final double slope0 = (fxCurr - fxPrev) / (xCurr - xPrev);
    final double nextX0 = xCurr - (fxCurr * (xCurr - xPrev)) / (fxCurr - fxPrev == 0 ? 1e-14 : (fxCurr - fxPrev));

    steps.add(IterationStep(
      stepNumber: 1,
      currentX: xCurr,
      currentFx: fxCurr,
      prevX: xPrev,
      prevFx: fxPrev,
      nextX: nextX0,
      slope: slope0,
      error: err1,
      note: 'Punto inicial x₁ = $xCurr, f(x₁) = $fxCurr',
    ));

    if (fxCurr.abs() <= tolerance || err1 <= tolerance) {
      sw.stop();
      return CalculationResult(
        isSuccess: true,
        method: NumericalMethod.secant,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        root: xCurr,
        finalFx: fxCurr,
        finalError: err1,
        steps: steps,
        executionTimeMs: sw.elapsedMilliseconds,
      );
    }

    for (int i = 2; i <= maxIterations + 1; i++) {
      final double denom = fxCurr - fxPrev;
      if (denom.abs() < 1e-14) {
        sw.stop();
        return CalculationResult.failure(
          method: NumericalMethod.secant,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          errorMessage: 'División por cero en el paso $i: f(x_{${i-1}}) ≈ f(x_{${i-2}}). Secante horizontal.',
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
        );
      }

      final double slope = (fxCurr - fxPrev) / (xCurr - xPrev);
      final double xNext = xCurr - (fxCurr * (xCurr - xPrev)) / denom;

      double fxNext;
      try {
        fxNext = parser.evaluate(rawFunction, xNext);
      } catch (e) {
        sw.stop();
        return CalculationResult.failure(
          method: NumericalMethod.secant,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          errorMessage: 'Error al evaluar f($xNext): $e',
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
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
        sw.stop();
        return CalculationResult(
          isSuccess: true,
          method: NumericalMethod.secant,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          root: xNext,
          finalFx: fxNext,
          finalError: error,
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
        );
      }

      xPrev = xCurr;
      fxPrev = fxCurr;
      xCurr = xNext;
      fxCurr = fxNext;
    }

    sw.stop();
    return CalculationResult.failure(
      method: NumericalMethod.secant,
      rawFunction: rawFunction,
      sanitizedFunction: sanitized,
      errorMessage: 'Se alcanzó el límite de $maxIterations iteraciones sin converger.',
      steps: steps,
      executionTimeMs: sw.elapsedMilliseconds,
    );
  }

  /// Método de Regla Falsa (Posición Falsa)
  CalculationResult solveFalsePosition({
    required String rawFunction,
    required double aVal,
    required double? bVal,
    required double tolerance,
    required int maxIterations,
  }) {
    final sw = Stopwatch()..start();
    final sanitized = parser.sanitizeExpression(rawFunction);

    if (bVal == null) {
      return CalculationResult.failure(
        method: NumericalMethod.falsePosition,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: 'El método de Regla Falsa requiere límites [a, b].',
      );
    }

    double a = aVal;
    double b = bVal;
    if (a >= b) {
      final temp = a;
      a = b;
      b = temp;
    }

    if ((b - a).abs() < 1e-12) {
      return CalculationResult.failure(
        method: NumericalMethod.falsePosition,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: 'Los límites del intervalo [a, b] no pueden ser idénticos.',
      );
    }

    final syntaxErr = parser.validateExpression(rawFunction);
    if (syntaxErr != null) {
      return CalculationResult.failure(
        method: NumericalMethod.falsePosition,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: syntaxErr,
      );
    }

    final List<IterationStep> steps = [];
    double fa;
    double fb;

    try {
      fa = parser.evaluate(rawFunction, a);
      fb = parser.evaluate(rawFunction, b);
    } catch (e) {
      sw.stop();
      return CalculationResult.failure(
        method: NumericalMethod.falsePosition,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: 'Error al evaluar extremos del intervalo: $e',
        executionTimeMs: sw.elapsedMilliseconds,
      );
    }

    // Teorema de Bolzano
    if (fa * fb > 0) {
      sw.stop();
      return CalculationResult.failure(
        method: NumericalMethod.falsePosition,
        rawFunction: rawFunction,
        sanitizedFunction: sanitized,
        errorMessage: 'No se cumple el Teorema de Bolzano en [$a, $b]: f($a)=$fa y f($b)=$fb tienen el mismo signo. '
            'Debe haber cambio de signo (f(a)·f(b) < 0).',
        executionTimeMs: sw.elapsedMilliseconds,
      );
    }

    double? prevC;

    for (int i = 0; i <= maxIterations; i++) {
      final double denom = fb - fa;
      if (denom.abs() < 1e-15) {
        sw.stop();
        return CalculationResult.failure(
          method: NumericalMethod.falsePosition,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          errorMessage: 'Denominador nulo f(b) - f(a) en la iteración $i.',
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
        );
      }

      final double c = (a * fb - b * fa) / denom;
      final double slope = (fb - fa) / (b - a);

      double fc;
      try {
        fc = parser.evaluate(rawFunction, c);
      } catch (e) {
        sw.stop();
        return CalculationResult.failure(
          method: NumericalMethod.falsePosition,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          errorMessage: 'Error al evaluar f($c): $e',
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
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

      if (fc.abs() <= tolerance || (error != null && error <= tolerance)) {
        sw.stop();
        return CalculationResult(
          isSuccess: true,
          method: NumericalMethod.falsePosition,
          rawFunction: rawFunction,
          sanitizedFunction: sanitized,
          root: c,
          finalFx: fc,
          finalError: error ?? 0.0,
          steps: steps,
          executionTimeMs: sw.elapsedMilliseconds,
        );
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

    sw.stop();
    return CalculationResult.failure(
      method: NumericalMethod.falsePosition,
      rawFunction: rawFunction,
      sanitizedFunction: sanitized,
      errorMessage: 'Se alcanzó el límite de $maxIterations iteraciones sin alcanzar la tolerancia $tolerance.',
      steps: steps,
      executionTimeMs: sw.elapsedMilliseconds,
    );
  }
}

// =============================================================================
// CUSTOM PAINTER DEL GRÁFICO 2D (CON RECORTE ESTRICTO Y EJES NUMERADOS)
// =============================================================================

class FunctionGraphPainter extends CustomPainter {
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

  FunctionGraphPainter({
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

    // APLICACIÓN ESTRICTA DE CLIP RECT PARA EVITAR CUALQUIER DESBORDAMIENTO
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final bgColor = isDarkTheme ? const Color(0xFF131B2E) : const Color(0xFFFAFAFC);
    final gridColor = isDarkTheme ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final axisColor = isDarkTheme ? Colors.white.withOpacity(0.75) : Colors.black87;
    const curveColor = Color(0xFF00B0FF);
    final textStyle = TextStyle(
      color: isDarkTheme ? Colors.white70 : Colors.black87,
      fontSize: 10,
      fontFamily: 'RobotoMono',
      fontWeight: FontWeight.w500,
    );

    // 1. Fondo del lienzo
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = bgColor);

    final double rangeX = (maxX - minX).abs() < 1e-6 ? 1.0 : (maxX - minX);
    final double rangeY = (maxY - minY).abs() < 1e-6 ? 1.0 : (maxY - minY);

    double toScreenX(double x) => ((x - minX) / rangeX) * size.width;
    double toScreenY(double y) => size.height - (((y - minY) / rangeY) * size.height);

    // 2. Cuadrícula
    if (showGrid) {
      _drawGrid(canvas, size, toScreenX, toScreenY, gridColor);
    }

    // 3. Ejes Cartesianos con Marcas y Numeración
    _drawAxesWithTicks(canvas, size, toScreenX, toScreenY, axisColor, textStyle);

    // 4. Curva continua f(x)
    _drawFunctionCurve(canvas, size, toScreenX, toScreenY, curveColor);

    // 5. Geometría interactiva paso a paso
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

    canvas.restore();
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    double Function(double) toX,
    double Function(double) toY,
    Color gridColor,
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

  void _drawAxesWithTicks(
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

    final tickPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5;

    final double originX = toX(0.0).clamp(0.0, size.width);
    final double originY = toY(0.0).clamp(0.0, size.height);

    // Eje X
    if (minY <= 0 && maxY >= 0) {
      canvas.drawLine(Offset(0, originY), Offset(size.width, originY), axisPaint);
    }

    // Eje Y
    if (minX <= 0 && maxX >= 0) {
      canvas.drawLine(Offset(originX, 0), Offset(originX, size.height), axisPaint);
    }

    // Ticks y Etiquetas en Eje X
    final double stepX = _calculateOptimalGridStep(maxX - minX);
    final double firstX = (minX / stepX).floor() * stepX;
    for (double x = firstX; x <= maxX; x += stepX) {
      final sx = toX(x);
      canvas.drawLine(Offset(sx, originY - 3), Offset(sx, originY + 3), tickPaint);

      if (x.abs() < 1e-7) continue;
      final textSpan = TextSpan(text: _formatTick(x), style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final labelY = (originY + 5).clamp(4.0, size.height - tp.height - 4);
      tp.paint(canvas, Offset(sx - tp.width / 2, labelY));
    }

    // Ticks y Etiquetas en Eje Y
    final double stepY = _calculateOptimalGridStep(maxY - minY);
    final double firstY = (minY / stepY).floor() * stepY;
    for (double y = firstY; y <= maxY; y += stepY) {
      final sy = toY(y);
      canvas.drawLine(Offset(originX - 3, sy), Offset(originX + 3, sy), tickPaint);

      if (y.abs() < 1e-7) continue;
      final textSpan = TextSpan(text: _formatTick(y), style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final labelX = (originX + 6).clamp(4.0, size.width - tp.width - 4);
      tp.paint(canvas, Offset(labelX, sy - tp.height / 2));
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
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final int samples = (size.width * 1.5).toInt().clamp(250, 1200);
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

        if (sy < -size.height * 3 || sy > size.height * 4) {
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

    _drawDashedLine(canvas, Offset(ptSx, zeroSy), Offset(ptSx, ptSy), Colors.amber.withOpacity(0.85), 1.6);

    if (slope != null && slope.abs() > 1e-12) {
      final tangentPaint = Paint()
        ..color = const Color(0xFFFF3D00)
        ..strokeWidth = 2.2;

      final double tMinX = minX - (maxX - minX) * 0.3;
      final double tMaxX = maxX + (maxX - minX) * 0.3;
      final double y1 = fxi + slope * (tMinX - xi);
      final double y2 = fxi + slope * (tMaxX - xi);

      canvas.drawLine(Offset(toX(tMinX), toY(y1)), Offset(toX(tMaxX), toY(y2)), tangentPaint);
    }

    _drawPointWithHalo(canvas, Offset(ptSx, ptSy), const Color(0xFFFFC107), 6.0, 'P($xi, ${fxi.toStringAsFixed(2)})');
    _drawPointWithHalo(canvas, Offset(ptSx, zeroSy), Colors.amber, 4.5, 'x_{${step.stepNumber}}');

    if (nextX != null) {
      final nextSx = toX(nextX);
      _drawPointWithHalo(canvas, Offset(nextSx, zeroSy), const Color(0xFF00E676), 6.5, 'x_{${step.stepNumber + 1}}');
      _drawArrow(canvas, Offset(ptSx, zeroSy), Offset(nextSx, zeroSy), const Color(0xFF00E676));
    }
  }

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

    _drawPointWithHalo(canvas, Offset(currSx, currSy), const Color(0xFFFF9800), 6.0, '($currX, ${currFx.toStringAsFixed(2)})');
    _drawDashedLine(canvas, Offset(currSx, zeroSy), Offset(currSx, currSy), Colors.orangeAccent.withOpacity(0.8), 1.5);

    if (prevX != null && prevFx != null) {
      final prevSx = toX(prevX);
      final prevSy = toY(prevFx);

      _drawPointWithHalo(canvas, Offset(prevSx, prevSy), const Color(0xFFAB47BC), 6.0, '($prevX, ${prevFx.toStringAsFixed(2)})');
      _drawDashedLine(canvas, Offset(prevSx, zeroSy), Offset(prevSx, prevSy), Colors.purpleAccent.withOpacity(0.8), 1.5);

      final secantPaint = Paint()
        ..color = const Color(0xFFFF3D00)
        ..strokeWidth = 2.2;

      final double slope = (currFx - prevFx) / (currX - prevX == 0 ? 1e-12 : (currX - prevX));
      final double tMinX = minX - (maxX - minX) * 0.3;
      final double tMaxX = maxX + (maxX - minX) * 0.3;
      final double y1 = currFx + slope * (tMinX - currX);
      final double y2 = currFx + slope * (tMaxX - currX);

      canvas.drawLine(Offset(toX(tMinX), toY(y1)), Offset(toX(tMaxX), toY(y2)), secantPaint);
    }

    if (nextX != null) {
      final nextSx = toX(nextX);
      _drawPointWithHalo(canvas, Offset(nextSx, zeroSy), const Color(0xFF00E676), 6.5, 'x_{${step.stepNumber + 1}}');
    }
  }

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

      final intervalPaint = Paint()
        ..color = Colors.teal.withOpacity(0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(math.min(aSx, bSx), 0, math.max(aSx, bSx), size.height),
        intervalPaint,
      );

      _drawDashedLine(canvas, Offset(aSx, zeroSy), Offset(aSx, aSy), Colors.tealAccent, 1.5);
      _drawDashedLine(canvas, Offset(bSx, zeroSy), Offset(bSx, bSy), Colors.tealAccent, 1.5);

      final chordPaint = Paint()
        ..color = const Color(0xFFFF3D00)
        ..strokeWidth = 2.2;
      canvas.drawLine(Offset(aSx, aSy), Offset(bSx, bSy), chordPaint);

      _drawPointWithHalo(canvas, Offset(aSx, aSy), Colors.tealAccent, 5.5, 'a ($a)');
      _drawPointWithHalo(canvas, Offset(bSx, bSy), Colors.cyanAccent, 5.5, 'b ($b)');
    }

    final cSx = toX(c);
    final cSy = toY(fc);
    _drawDashedLine(canvas, Offset(cSx, zeroSy), Offset(cSx, cSy), Colors.greenAccent, 1.5);
    _drawPointWithHalo(canvas, Offset(cSx, zeroSy), const Color(0xFF00E676), 6.5, 'c = ${c.toStringAsFixed(3)}');
    _drawPointWithHalo(canvas, Offset(cSx, cSy), const Color(0xFFFFD54F), 5.0, 'f(c)');
  }

  void _drawPointWithHalo(Canvas canvas, Offset center, Color color, double radius, String? label) {
    canvas.drawCircle(center, radius * 2.0, Paint()..color = color.withOpacity(0.35));
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(center, radius, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);

    if (label != null) {
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black.withOpacity(0.65),
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(center.dx + 8, center.dy - tp.height / 2));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color, double strokeWidth) {
    final paint = Paint()..color = color..strokeWidth = strokeWidth;
    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    final double distance = (p2 - p1).distance;
    if (distance < 1) return;
    final double dx = (p2.dx - p1.dx) / distance;
    final double dy = (p2.dy - p1.dy) / distance;

    double currentDist = 0.0;
    while (currentDist < distance) {
      final double len = math.min(dashWidth, distance - currentDist);
      canvas.drawLine(
        Offset(p1.dx + dx * currentDist, p1.dy + dy * currentDist),
        Offset(p1.dx + dx * (currentDist + len), p1.dy + dy * (currentDist + len)),
        paint,
      );
      currentDist += dashWidth + dashSpace;
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Color color) {
    if ((end - start).distance < 12) return;
    final paint = Paint()..color = color..strokeWidth = 2.0;
    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final double angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const double arrowSize = 6.0;

    canvas.drawLine(mid, Offset(mid.dx - arrowSize * math.cos(angle - math.pi / 6), mid.dy - arrowSize * math.sin(angle - math.pi / 6)), paint);
    canvas.drawLine(mid, Offset(mid.dx - arrowSize * math.cos(angle + math.pi / 6), mid.dy - arrowSize * math.sin(angle + math.pi / 6)), paint);
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
  bool shouldRepaint(covariant FunctionGraphPainter oldDelegate) {
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

// =============================================================================
// WIDGET INTERACTIVO DEL GRÁFICO 2D (CON PANTALLA COMPLETA Y NAVEGACIÓN)
// =============================================================================

class InteractiveGraphWidget extends StatefulWidget {
  final String functionExpression;
  final CalculationResult? result;
  final int currentStepIndex;
  final MathParserService parserService;
  final ValueChanged<int> onStepChanged;
  final bool isFullScreen;

  const InteractiveGraphWidget({
    super.key,
    required this.functionExpression,
    required this.result,
    required this.currentStepIndex,
    required this.parserService,
    required this.onStepChanged,
    this.isFullScreen = false,
  });

  @override
  State<InteractiveGraphWidget> createState() => _InteractiveGraphWidgetState();
}

class _InteractiveGraphWidgetState extends State<InteractiveGraphWidget> {
  double _minX = -5.0;
  double _maxX = 5.0;
  double _minY = -5.0;
  double _maxY = 5.0;
  bool _showGrid = true;
  Offset? _lastFocalPoint;

  Timer? _playbackTimer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _autoFitView();
  }

  @override
  void didUpdateWidget(covariant InteractiveGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result || oldWidget.functionExpression != widget.functionExpression) {
      _autoFitView();
      _stopPlayback();
    }
  }

  @override
  void dispose() {
    _stopPlayback();
    super.dispose();
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (_isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      if (widget.result == null || widget.result!.steps.isEmpty) return;
      setState(() => _isPlaying = true);
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
        final totalSteps = widget.result!.steps.length;
        if (widget.currentStepIndex + 1 < totalSteps) {
          widget.onStepChanged(widget.currentStepIndex + 1);
        } else {
          _stopPlayback();
        }
      });
    }
  }

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
        final paddingX = spanX < 1e-4 ? 2.0 : spanX * 0.45;
        minX = xMinVal - paddingX;
        maxX = xMaxVal + paddingX;

        final spanY = (yMaxVal - yMinVal).abs();
        final paddingY = spanY < 1e-4 ? 2.0 : spanY * 0.45;
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

  void _openFullScreenDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text('Gráfico 2D Ampliado - ${widget.result?.method.displayName ?? 'f(x)'}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_exit, size: 28),
                  tooltip: 'Reducir / Cerrar Pantalla Completa',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(12.0),
              child: InteractiveGraphWidget(
                functionExpression: widget.functionExpression,
                result: widget.result,
                currentStepIndex: widget.currentStepIndex,
                parserService: widget.parserService,
                onStepChanged: widget.onStepChanged,
                isFullScreen: true,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalSteps = widget.result?.steps.length ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. ÁREA DEL LIENZO CON CLIPRECT ESTRICTO
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);

                return ClipRect(
                  child: Stack(
                    children: [
                      // Lienzo Interactivo
                      Listener(
                        onPointerSignal: (signal) {
                          if (signal is PointerScrollEvent) {
                            final factor = signal.scrollDelta.dy > 0 ? 1.15 : 0.85;
                            _zoom(factor, signal.localPosition, size);
                          }
                        },
                        child: GestureDetector(
                          onScaleStart: (details) => _lastFocalPoint = details.localFocalPoint,
                          onScaleUpdate: (details) {
                            if (_lastFocalPoint != null) {
                              final dx = details.localFocalPoint.dx - _lastFocalPoint!.dx;
                              final dy = details.localFocalPoint.dy - _lastFocalPoint!.dy;
                              _pan(dx, dy, size);
                              _lastFocalPoint = details.localFocalPoint;
                            }
                            if (details.scale != 1.0) {
                              _zoom(1.0 / details.scale, details.localFocalPoint, size);
                            }
                          },
                          onDoubleTap: _autoFitView,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: FunctionGraphPainter(
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

                      // Leyenda (Superior Izquierda)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _buildLegend(isDark),
                      ),

                      // Botonera de herramientas y BOTÓN DE PANTALLA COMPLETA (Superior Derecha)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  widget.isFullScreen ? Icons.fullscreen_exit : Icons.open_in_full,
                                  color: theme.colorScheme.primary,
                                ),
                                tooltip: widget.isFullScreen ? 'Reducir tamaño' : 'Ver en Pantalla Completa',
                                onPressed: () {
                                  if (widget.isFullScreen) {
                                    Navigator.of(context).pop();
                                  } else {
                                    _openFullScreenDialog(context);
                                  }
                                },
                              ),
                              const Divider(height: 1),
                              IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                tooltip: 'Acercar (+)',
                                onPressed: () => _zoom(0.8),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove, size: 20),
                                tooltip: 'Alejar (-)',
                                onPressed: () => _zoom(1.25),
                              ),
                              IconButton(
                                icon: const Icon(Icons.crop_free, size: 20),
                                tooltip: 'Auto-Ajuste / Centrar',
                                onPressed: _autoFitView,
                              ),
                              IconButton(
                                icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off, size: 20),
                                tooltip: _showGrid ? 'Ocultar cuadrícula' : 'Mostrar cuadrícula',
                                onPressed: () => setState(() => _showGrid = !_showGrid),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Coordenadas del Rango (Inferior Izquierda)
                      Positioned(
                        bottom: 8,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
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
            ),
          ),

          // 2. CONTROLES DE PASO A PASO Y AUTO-PLAY
          if (totalSteps > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.3))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.first_page),
                        tooltip: 'Paso inicial',
                        onPressed: widget.currentStepIndex > 0 ? () => widget.onStepChanged(0) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Paso anterior',
                        onPressed: widget.currentStepIndex > 0 ? () => widget.onStepChanged(widget.currentStepIndex - 1) : null,
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _togglePlayback,
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Pausa' : 'Auto-Play'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Siguiente paso',
                        onPressed: widget.currentStepIndex < totalSteps - 1 ? () => widget.onStepChanged(widget.currentStepIndex + 1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.last_page),
                        tooltip: 'Paso final',
                        onPressed: widget.currentStepIndex < totalSteps - 1 ? () => widget.onStepChanged(totalSteps - 1) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Paso ${widget.currentStepIndex + 1} de $totalSteps',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: widget.currentStepIndex.toDouble().clamp(0.0, (totalSteps - 1).toDouble()),
                          min: 0.0,
                          max: (totalSteps - 1).toDouble().clamp(0.0, double.infinity),
                          divisions: totalSteps > 1 ? totalSteps - 1 : 1,
                          onChanged: (v) {
                            _stopPlayback();
                            widget.onStepChanged(v.toInt());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 3, color: const Color(0xFF00B0FF)),
              const SizedBox(width: 6),
              const Text('f(x)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          if (widget.result != null) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 3, color: const Color(0xFFFF3D00)),
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
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle)),
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

// =============================================================================
// VISTA DE LA TABLA DE ITERACIONES (CUADROS)
// =============================================================================

class IterationTableView extends StatelessWidget {
  final CalculationResult? result;
  final int selectedStepIndex;
  final ValueChanged<int> onStepSelected;
  final bool useScientificNotation;

  const IterationTableView({
    super.key,
    required this.result,
    required this.selectedStepIndex,
    required this.onStepSelected,
    required this.useScientificNotation,
  });

  String _format(double? val) {
    if (val == null) return '-';
    if (useScientificNotation) {
      if (val.abs() == 0.0) return '0.0000e+0';
      return val.toStringAsExponential(5);
    } else {
      if (val.abs() < 1e-12 && val != 0) return val.toStringAsExponential(5);
      return val.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
  }

  void _copyToClipboard(BuildContext context) {
    if (result == null || result!.steps.isEmpty) return;
    final buf = StringBuffer();
    buf.writeln('=== TABLA DE ITERACIONES: ${result!.method.displayName} ===');
    buf.writeln('Función: f(x) = ${result!.rawFunction}');
    buf.writeln('Paso\tx_i\tf(x_i)\tError');
    for (final s in result!.steps) {
      buf.writeln('${s.stepNumber}\t${_format(s.currentX)}\t${_format(s.currentFx)}\t${_format(s.error)}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tabla de iteraciones copiada al portapapeles.'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (result == null || result!.steps.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'No hay iteraciones calculadas. Presiona "Calcular" o "Cuadros" para procesar la función.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final steps = result!.steps;
    final method = result!.method;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.table_chart_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Cuadros de Iteraciones (${steps.length} pasos)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copiar tabla',
                  onPressed: () => _copyToClipboard(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  columnSpacing: 22,
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  ),
                  columns: _buildColumns(method),
                  rows: List<DataRow>.generate(steps.length, (idx) {
                    final s = steps[idx];
                    final isSelected = idx == selectedStepIndex;
                    return DataRow(
                      selected: isSelected,
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (isSelected) return theme.colorScheme.primary.withOpacity(0.18);
                        if (idx % 2 == 1) return isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02);
                        return null;
                      }),
                      onSelectChanged: (_) => onStepSelected(idx),
                      cells: _buildCells(s, method),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns(NumericalMethod method) {
    return [
      const DataColumn(label: Text('i (Paso)', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(
        label: Text(
          method == NumericalMethod.falsePosition ? 'c (Aprox.)' : 'xᵢ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const DataColumn(label: Text('f(xᵢ)', style: TextStyle(fontWeight: FontWeight.bold))),
      if (method == NumericalMethod.newtonRaphson)
        const DataColumn(label: Text('f\'(xᵢ)', style: TextStyle(fontWeight: FontWeight.bold))),
      if (method == NumericalMethod.falsePosition) ...[
        const DataColumn(label: Text('a', style: TextStyle(fontWeight: FontWeight.bold))),
        const DataColumn(label: Text('b', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      const DataColumn(label: Text('Error Aprox. (Eₐ)', style: TextStyle(fontWeight: FontWeight.bold))),
    ];
  }

  List<DataCell> _buildCells(IterationStep step, NumericalMethod method) {
    const mono = TextStyle(fontFamily: 'RobotoMono', fontSize: 12);
    return [
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
          child: Text('${step.stepNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
      DataCell(Text(_format(step.currentX), style: mono)),
      DataCell(Text(_format(step.currentFx), style: mono)),
      if (method == NumericalMethod.newtonRaphson) DataCell(Text(_format(step.derivativeFx), style: mono)),
      if (method == NumericalMethod.falsePosition) ...[
        DataCell(Text(_format(step.intervalA), style: mono)),
        DataCell(Text(_format(step.intervalB), style: mono)),
      ],
      DataCell(
        Text(
          step.error != null ? _format(step.error) : '-',
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 12,
            color: step.error != null && step.error! <= 0.001 ? Colors.green : null,
            fontWeight: step.error != null && step.error! <= 0.001 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    ];
  }
}

// =============================================================================
// TARJETA DE RESULTADO / CÁLCULO (SOLO RAÍZ Y MÉTRICAS)
// =============================================================================

class ResultMetricCard extends StatelessWidget {
  final CalculationResult? result;
  final bool useScientificNotation;

  const ResultMetricCard({
    super.key,
    required this.result,
    required this.useScientificNotation,
  });

  String _format(double? val) {
    if (val == null) return '-';
    if (useScientificNotation) {
      if (val.abs() == 0.0) return '0.0000e+0';
      return val.toStringAsExponential(5);
    } else {
      if (val.abs() < 1e-12 && val != 0) return val.toStringAsExponential(5);
      return val.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Presiona el botón "Calcular" para resolver la raíz de la ecuación.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final res = result!;

    if (!res.isSuccess) {
      return Card(
        color: theme.colorScheme.errorContainer.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.error),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No se pudo converger a la raíz',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      res.errorMessage ?? 'Ocurrió un error inesperado durante el cálculo.',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Raíz Calculada con Éxito',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.green),
                    ),
                  ],
                ),
                Chip(
                  label: Text('${res.executionTimeMs} ms', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: theme.colorScheme.primaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildTile(
                    label: 'Raíz Aproximada (x*)',
                    value: _format(res.root),
                    icon: Icons.adjust,
                    color: theme.colorScheme.primary,
                    isBig: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTile(
                    label: 'Valor f(x*)',
                    value: _format(res.finalFx),
                    icon: Icons.functions,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTile(
                    label: 'Error Final (Eₐ)',
                    value: _format(res.finalError),
                    icon: Icons.speed,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTile(
                    label: 'Iteraciones Totales',
                    value: '${res.steps.length}',
                    icon: Icons.format_list_numbered,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            if (res.method == NumericalMethod.newtonRaphson && res.derivativeString != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.architecture, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Derivada analítica calculada: f\'(x) = ${res.derivativeString}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'RobotoMono', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isBig = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: isBig ? 18 : 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'RobotoMono',
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PANTALLA PRINCIPAL CON SANITIZACIÓN ROBUSTA Y 3 BOTONES SEPARADOS
// =============================================================================

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MathParserService _parserService = MathParserService();
  late final NumericalSolversEngine _engine;

  // Controladores de texto
  late TextEditingController _funcController;
  late TextEditingController _x0Controller;
  late TextEditingController _x1Controller;
  late TextEditingController _tolController;
  late TextEditingController _maxIterController;

  NumericalMethod _selectedMethod = NumericalMethod.newtonRaphson;
  bool _useScientificNotation = false;

  // Modo de vista activa por los 3 botones
  ActiveViewMode _activeView = ActiveViewMode.calcular;

  CalculationResult? _result;
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _engine = NumericalSolversEngine(_parserService);

    _funcController = TextEditingController(text: 'x^3 - 4*x - 9');
    _x0Controller = TextEditingController(text: '2');
    _x1Controller = TextEditingController(text: '3');
    _tolController = TextEditingController(text: '0.0001');
    _maxIterController = TextEditingController(text: '50');

    // Ejecución inicial demostrativa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeCalculation(andSwitchViewTo: ActiveViewMode.calcular);
    });
  }

  @override
  void dispose() {
    _funcController.dispose();
    _x0Controller.dispose();
    _x1Controller.dispose();
    _tolController.dispose();
    _maxIterController.dispose();
    super.dispose();
  }

  void _insertSymbol(String sym) {
    final text = _funcController.text;
    final selection = _funcController.selection;
    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, sym);
    _funcController.text = newText;
    _funcController.selection = TextSelection.collapsed(offset: start + sym.length);
  }

  /// Pega y limpia texto desde el portapapeles directamente
  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        final cleaned = MathParserService.cleanClipboardText(data.text!);
        _insertSymbol(cleaned);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Texto pegado y sanitizado automáticamente.'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _executeCalculation({ActiveViewMode? andSwitchViewTo}) {
    final double? x0 = double.tryParse(_x0Controller.text.replaceAll(',', '.'));
    final double? x1 = _x1Controller.text.isNotEmpty ? double.tryParse(_x1Controller.text.replaceAll(',', '.')) : null;
    final double tol = double.tryParse(_tolController.text.replaceAll(',', '.')) ?? 0.0001;
    final int maxIter = int.tryParse(_maxIterController.text) ?? 50;

    if (x0 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un valor numérico para el punto inicial.')),
      );
      return;
    }

    CalculationResult res;
    switch (_selectedMethod) {
      case NumericalMethod.newtonRaphson:
        res = _engine.solveNewtonRaphson(
          rawFunction: _funcController.text,
          x0: x0,
          tolerance: tol,
          maxIterations: maxIter,
        );
        break;
      case NumericalMethod.secant:
        res = _engine.solveSecant(
          rawFunction: _funcController.text,
          x0: x0,
          x1: x1,
          tolerance: tol,
          maxIterations: maxIter,
        );
        break;
      case NumericalMethod.falsePosition:
        res = _engine.solveFalsePosition(
          rawFunction: _funcController.text,
          aVal: x0,
          bVal: x1,
          tolerance: tol,
          maxIterations: maxIter,
        );
        break;
    }

    setState(() {
      _result = res;
      _currentStepIndex = res.steps.isNotEmpty ? res.steps.length - 1 : 0;
      if (andSwitchViewTo != null) {
        _activeView = andSwitchViewTo;
      }
    });

    if (!res.isSuccess && res.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage!),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.calculate, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Métodos Numéricos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Newton-Raphson | Secante | Regla Falsa', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? 'Modo Claro' : 'Modo Oscuro',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 950;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel Izquierdo: Formulario con los 3 Botones
        SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: _buildInputCard(),
          ),
        ),
        const SizedBox(width: 16),
        // Panel Derecho: Vista activa seleccionada (Calcular / Graficar / Cuadros)
        Expanded(
          child: _buildActiveViewContent(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildInputCard(),
          const SizedBox(height: 16),
          SizedBox(
            height: 480,
            child: _buildActiveViewContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Selector de Método Numérico
            DropdownButtonFormField<NumericalMethod>(
              value: _selectedMethod,
              decoration: InputDecoration(
                labelText: 'Método Numérico',
                prefixIcon: const Icon(Icons.functions),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              items: NumericalMethod.values.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMethod = val);
                  _executeCalculation(andSwitchViewTo: _activeView);
                }
              },
            ),
            const SizedBox(height: 6),
            Text(
              _selectedMethod.shortFormula,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'RobotoMono',
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // 2. Campo de Texto f(x) con Sanitizador de Pegado (TextInputFormatter)
            TextFormField(
              controller: _funcController,
              inputFormatters: [MathExpressionInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Función f(x)',
                hintText: 'ej. 2x^3 - 5x - 8, x(x-2) o cos(x)-x',
                prefixIcon: const Icon(Icons.edit_note),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded, size: 20),
                  tooltip: 'Pegar desde portapapeles (Ctrl+V)',
                  onPressed: _pasteFromClipboard,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 8),

            // Atajos matemáticos rápidos
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('x'),
                  _buildChip('^2'),
                  _buildChip('^3'),
                  _buildChip('+'),
                  _buildChip('-'),
                  _buildChip('*'),
                  _buildChip('/'),
                  _buildChip('sin(x)'),
                  _buildChip('cos(x)'),
                  _buildChip('tan(x)'),
                  _buildChip('e^x'),
                  _buildChip('ln(x)'),
                  _buildChip('sqrt(x)'),
                  _buildChip('('),
                  _buildChip(')'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Valores Iniciales
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _x0Controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: _selectedMethod.primaryInitialLabel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                ),
                if (_selectedMethod.requiresTwoInitialPoints) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _x1Controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: _selectedMethod.secondaryInitialLabel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // 4. Tolerancia y Máximo de Iteraciones
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tolController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Tolerancia',
                      hintText: '0.0001',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _maxIterController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Máx. Iter.',
                      hintText: '50',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Formato Numérico
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Formato:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Decimal')),
                    ButtonSegment<bool>(value: true, label: Text('Científica')),
                  ],
                  selected: {_useScientificNotation},
                  onSelectionChanged: (set) => setState(() => _useScientificNotation = set.first),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 6. LOS TRES BOTONES SEPARADOS (CALCULAR, GRAFICAR, CUADROS)
            Row(
              children: [
                // BOTÓN 1: CALCULAR
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeView == ActiveViewMode.calcular ? theme.colorScheme.primary : null,
                      foregroundColor: _activeView == ActiveViewMode.calcular ? Colors.white : null,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _executeCalculation(andSwitchViewTo: ActiveViewMode.calcular),
                    icon: const Icon(Icons.calculate, size: 18),
                    label: const Text('Calcular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),

                // BOTÓN 2: GRAFICAR
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeView == ActiveViewMode.graficar ? Colors.teal : null,
                      foregroundColor: _activeView == ActiveViewMode.graficar ? Colors.white : null,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (_result == null) {
                        _executeCalculation(andSwitchViewTo: ActiveViewMode.graficar);
                      } else {
                        setState(() => _activeView = ActiveViewMode.graficar);
                      }
                    },
                    icon: const Icon(Icons.show_chart, size: 18),
                    label: const Text('Graficar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),

                // BOTÓN 3: CUADROS
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeView == ActiveViewMode.cuadros ? Colors.indigo : null,
                      foregroundColor: _activeView == ActiveViewMode.cuadros ? Colors.white : null,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (_result == null) {
                        _executeCalculation(andSwitchViewTo: ActiveViewMode.cuadros);
                      } else {
                        setState(() => _activeView = ActiveViewMode.cuadros);
                      }
                    },
                    icon: const Icon(Icons.table_view, size: 18),
                    label: const Text('Cuadros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 7. Ejemplos rápidos
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Ejemplos:', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                _buildExampleChip('x³ - 4x - 9', 'x^3 - 4*x - 9', '2', '3'),
                _buildExampleChip('cos(x) - x', 'cos(x) - x', '0.5', '1.0'),
                _buildExampleChip('e⁻ˣ - x', 'e^(-x) - x', '0.0', '1.0'),
                _buildExampleChip('2x² - 8', '2x^2 - 8', '1.0', '3.0'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveViewContent() {
    switch (_activeView) {
      case ActiveViewMode.calcular:
        return ResultMetricCard(
          result: _result,
          useScientificNotation: _useScientificNotation,
        );
      case ActiveViewMode.graficar:
        return InteractiveGraphWidget(
          functionExpression: _funcController.text,
          result: _result,
          currentStepIndex: _currentStepIndex,
          parserService: _parserService,
          onStepChanged: (idx) => setState(() => _currentStepIndex = idx),
        );
      case ActiveViewMode.cuadros:
        return IterationTableView(
          result: _result,
          selectedStepIndex: _currentStepIndex,
          onStepSelected: (idx) => setState(() => _currentStepIndex = idx),
          useScientificNotation: _useScientificNotation,
        );
    }
  }

  Widget _buildChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'RobotoMono')),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onPressed: () => _insertSymbol(label),
      ),
    );
  }

  Widget _buildExampleChip(String label, String fn, String x0, String x1) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _funcController.text = fn;
          _x0Controller.text = x0;
          _x1Controller.text = x1;
        });
        _executeCalculation(andSwitchViewTo: _activeView);
      },
    );
  }
}

// =============================================================================
// APP PRINCIPAL Y TEMA MATERIAL 3
// =============================================================================

class MetodosNumericosApp extends StatefulWidget {
  const MetodosNumericosApp({super.key});

  @override
  State<MetodosNumericosApp> createState() => _MetodosNumericosAppState();
}

class _MetodosNumericosAppState extends State<MetodosNumericosApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF0D9488);

    return MaterialApp(
      title: 'Métodos Numéricos - Raíces de Ecuaciones',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light, surface: const Color(0xFFF8FAFC)),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, backgroundColor: Colors.white),
        cardTheme: CardThemeData(color: Colors.white, elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        fontFamily: 'Segoe UI',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark, surface: const Color(0xFF1E293B)),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, backgroundColor: Color(0xFF1E293B)),
        cardTheme: CardThemeData(color: const Color(0xFF1E293B), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        fontFamily: 'Segoe UI',
      ),
      home: HomeScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}