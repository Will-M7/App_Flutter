Solucionador de Métodos Numéricos
Análisis y Cálculo de Raíces de Ecuaciones No Lineales
Aplicación multiplataforma desarrollada en Flutter (Dart) diseñada para resolver, analizar y visualizar de manera gráfica métodos numéricos orientados al cálculo de raíces de ecuaciones no lineales.

Características Principales
Métodos Numéricos Implementados

Newton-Raphson: Cálculo de derivada analítica con respaldo por diferencias finitas.

Secante: Validación estricta de errores y control de divisiones.

Regla Falsa (False Position): Verificación de cambio de signo basada en el Teorema de Bolzano.

Parser y Preprocesador Matemático

Soporte para multiplicación implícita (conversión automática de 2x a 2*x y 5(x+1) a 5*(x+1)).

Reconocimiento de funciones trigonométricas (sin, cos, tan), logarítmicas (ln, log), exponenciales (e^x) y potencias (^).

Sanitización avanzada del portapapeles para la limpieza de caracteres especiales y guiones tipográficos al importar ecuaciones desde fuentes externas (PDFs, Word o navegadores).

Interfaz de Control Modular

Calcular: Ejecuta el algoritmo numérico y genera una tarjeta de resumen con la raíz aproximada, el error aproximado y el número total de iteraciones.

Graficar: Despliega el lienzo interactivo 2D con la representación gráfica de la función y las construcciones geométricas correspondientes a cada iteración.

Cuadros: Presenta una tabla detallada con el historial completo de cada iteración, permitiendo alternar entre formato decimal de alta precisión y notación científica.

Gráfico 2D Avanzado

Ejes cartesianos con marcas de graduación (ticks) y etiquetas numéricas adaptativas.

Sistema de recorte estricto (ClipRect) para evitar desbordamientos visuales de la curva.

Funcionalidad de expansión para visualización en modo de pantalla completa.

Soporte Multiplataforma

Optimizado para su ejecución en entornos de escritorio (Windows) y dispositivos móviles (Android).

Tecnologías y Dependencias
Flutter SDK: Versión 3.x o superior.

Dart: Lenguaje de programación base.

math_expressions (^2.7.0): Análisis sintáctico y evaluación dinámica de expresiones matemáticas.

intl (^0.19.0): Manejo y formato estandarizado de valores numéricos.

Instrucciones de Instalación y Ejecución
Clonar el repositorio o descargar el código fuente en el equipo local.

Abrir una terminal en la carpeta raíz del proyecto y ejecutar la descarga de dependencias:

Bash
flutter pub get
Ejecutar la aplicación según la plataforma de destino:

Para Windows (Escritorio):

Bash
flutter run -d windows
Para Android (Requiere cable USB y depuración USB activada):

Bash
flutter run -d android
Para compilar el archivo instalable de distribución en Android (APK):

Bash
flutter build apk --release
El archivo ejecutable se generará en la ruta: build\app\outputs\flutter-apk\app-release.apk
