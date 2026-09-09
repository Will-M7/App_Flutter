/// Representa una iteración individual en el proceso de cálculo numérico
class IterationStep {
  /// Número de paso / iteración (i = 0, 1, 2, ...)
  final int stepNumber;

  /// Valor aproximado actual (x_i o c en Regla Falsa)
  final double currentX;

  /// Evaluación de la función en el punto actual: f(x_i)
  final double currentFx;

  /// Error aproximado relativo o absoluto (|x_{i} - x_{prev}| / |x_i| o similar)
  final double? error;

  /// Valor previo (x_{i-1}) útil para el método de la Secante
  final double? prevX;

  /// Valor f(x_{i-1})
  final double? prevFx;

  /// Próximo valor calculado (x_{i+1})
  final double? nextX;

  /// Derivada f'(x_i) para Newton-Raphson
  final double? derivativeFx;

  /// Límite inferior del intervalo [a] (Regla Falsa)
  final double? intervalA;

  /// f(a) (Regla Falsa)
  final double? fa;

  /// Límite superior del intervalo [b] (Regla Falsa)
  final double? intervalB;

  /// f(b) (Regla Falsa)
  final double? fb;

  /// Pendiente de la recta geométrica (tangente o secante) para dibujo
  final double? slope;

  /// Nota o comentario explicativo del paso
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
