# Solucionador de Métodos Numéricos - Raíces de Ecuaciones

Aplicación multiplataforma desarrollada en **Flutter (Dart)** diseñada para resolver, analizar y visualizar gráficamente métodos numéricos orientados al cálculo de raíces de ecuaciones no lineales.

## 🚀 Características Principales

* **Métodos Numéricos Implementados:**
  * **Newton-Raphson** (con cálculo de derivada analítica y respaldo por diferencias finitas).
  * **Secante** (con validación de errores y divisiones).
  * **Regla Falsa / False Position** (con verificación de cambio de signo según el Teorema de Bolzano).
* **Parser y Preprocesador Matemático Inteligente:**
  * Soporte para multiplicación implícita (ej. conversión automática de `2x` a `2*x`, `5(x+1)` a `5*(x+1)`).
  * Reconocimiento de funciones trigonométricas (`sin`, `cos`, `tan`), logaritmos (`ln`, `log`), exponenciales (`e^x`) y potencias (`^`).
  * Sanitización avanzada del portapapeles: limpia automáticamente caracteres especiales o guiones tipográficos al pegar ecuaciones (`Ctrl+V`) desde PDFs, Word o la web.
* **Interfaz de Control Modular (Botones Separados):**
  * **Calcular:** Ejecuta el algoritmo numérico y despliega la tarjeta resumen con la raíz aproximada, error aproximado y número total de iteraciones.
  * **Graficar:** Muestra exclusivamente el lienzo interactivo 2D con la curva de la función y las construcciones geométricas paso a paso (tangentes o secantes).
  * **Cuadros:** Presenta la tabla detallada con el historial completo de cada iteración, permitiendo alternar entre formato decimal de alta precisión y notación científica.
* **Gráfico 2D Avanzado:**
  * Ejes cartesianos con marcas de graduación (ticks) y etiquetas numéricas adaptativas.
  * Sistema estricto de recorte (`ClipRect`) para evitar desbordamientos visuales de la curva.
  * Botón de expansión para alternar a **Modo Pantalla Completa** de forma instantánea.
* **Multiplataforma:** Optimizado para ejecutarse fluidamente en equipos de escritorio (**Windows**) y dispositivos móviles (**Android**).

## 🛠️ Tecnologías y Dependencias

* **Flutter SDK** (v3.x o superior)
* **Dart**
* **math_expressions** (^2.7.0) - Para el análisis sintáctico y evaluación dinámica de expresiones matemáticas.
* **intl** (^0.19.0) - Para el manejo y formato de números.

## 📦 Instrucciones de Instalación y Ejecución

1. Clona este repositorio o descarga el código fuente en tu computadora.
2. Abre una terminal en la carpeta raíz del proyecto y descarga las dependencias:
   ```bash
   flutter pub get