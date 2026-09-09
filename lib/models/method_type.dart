/// Enumeración de los métodos numéricos soportados
enum NumericalMethod {
  newtonRaphson,
  secant,
  falsePosition,
}

/// Extensión para proveer nombres amigables, descripciones y requisitos de cada método
extension NumericalMethodExtension on NumericalMethod {
  String get displayName {
    switch (this) {
      case NumericalMethod.newtonRaphson:
        return 'Newton-Raphson';
      case NumericalMethod.secant:
        return 'Método de la Secante';
      case NumericalMethod.falsePosition:
        return 'Regla Falsa (Posición Falsa)';
    }
  }

  String get shortFormula {
    switch (this) {
      case NumericalMethod.newtonRaphson:
        return 'x_{i+1} = x_i - f(x_i) / f\'(x_i)';
      case NumericalMethod.secant:
        return 'x_{i+1} = x_i - f(x_i)(x_i - x_{i-1}) / [f(x_i) - f(x_{i-1})]';
      case NumericalMethod.falsePosition:
        return 'c = [a·f(b) - b·f(a)] / [f(b) - f(a)]';
    }
  }

  String get description {
    switch (this) {
      case NumericalMethod.newtonRaphson:
        return 'Método abierto de convergencia cuadrática rápida que utiliza la recta tangente y la primera derivada de la función en cada iteración.';
      case NumericalMethod.secant:
        return 'Método abierto que aproxima la derivada mediante diferencias finitas usando dos puntos iniciales y rectas secantes sucesivas.';
      case NumericalMethod.falsePosition:
        return 'Método cerrado (de intervalo) que interpola linealmente los extremos [a, b] garantizando la convergencia si f(a)·f(b) < 0.';
    }
  }

  /// Indica si el método requiere dos valores iniciales (ej. Secante o Intervalo [a,b])
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
