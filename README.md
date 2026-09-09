#  Solucionador de Métodos Numéricos

Aplicación multiplataforma desarrollada en **Flutter (Dart)** para resolver, analizar y visualizar gráficamente métodos numéricos orientados al **cálculo de raíces de ecuaciones no lineales**.

El sistema permite ingresar una función matemática, configurar los parámetros de cálculo y observar tanto el resultado numérico como el comportamiento de cada iteración mediante tablas y gráficos interactivos.

---

##  Características principales

###  Métodos numéricos implementados

La aplicación incluye los siguientes métodos para aproximar raíces de ecuaciones no lineales:

#### Newton-Raphson

* Cálculo iterativo de raíces mediante la fórmula de Newton.
* Uso de **derivada analítica** cuando es posible.
* Respaldo mediante **diferencias finitas** para el cálculo de la derivada.
* Control de errores y número máximo de iteraciones.

#### Secante

* Aproximación de raíces utilizando dos valores iniciales.
* No requiere calcular explícitamente la derivada.
* Validación de divisiones y situaciones numéricamente inestables.
* Control del error aproximado en cada iteración.

#### Regla Falsa — False Position

* Método basado en intervalos.
* Verificación automática del **cambio de signo**.
* Validación basada en el **Teorema de Bolzano**.
* Actualización progresiva del intervalo hasta encontrar una aproximación de la raíz.

---

##  Parser y preprocesador matemático

La aplicación incluye un sistema de procesamiento de expresiones que permite escribir ecuaciones de una forma más natural.

### Multiplicación implícita

Convierte automáticamente expresiones como:

```text
2x
```

en:

```text
2*x
```

También admite expresiones como:

```text
5(x + 1)
```

y las interpreta como:

```text
5*(x + 1)
```

### Funciones matemáticas compatibles

El parser reconoce expresiones que incluyen:

```text
sin(x)
cos(x)
tan(x)

ln(x)
log(x)

e^x

x^2
x^3
```

También permite combinar operaciones, funciones y potencias dentro de una misma expresión.

---

##  Sanitización de ecuaciones

Al copiar ecuaciones desde documentos externos como:

* PDF
* Microsoft Word
* Navegadores web
* Documentos académicos

pueden aparecer caracteres especiales que provoquen errores de interpretación.

Por ello, la aplicación incorpora un sistema de **sanitización del portapapeles** encargado de limpiar y normalizar automáticamente:

* Guiones tipográficos.
* Símbolos especiales.
* Espacios innecesarios.
* Caracteres incompatibles.
* Formatos matemáticos provenientes de otras aplicaciones.

Esto facilita pegar directamente una ecuación dentro del solucionador.

---

##  Interfaz de control modular

La interfaz está organizada principalmente en tres acciones.

###  Calcular

Ejecuta el método numérico seleccionado y muestra un resumen con:

* Raíz aproximada.
* Error aproximado.
* Número total de iteraciones.
* Estado del cálculo.

---

###  Graficar

Genera una representación gráfica de la función ingresada.

Dependiendo del método seleccionado, también permite observar las construcciones geométricas relacionadas con las iteraciones realizadas.

---

###  Cuadros

Muestra el historial completo de cálculo mediante una tabla de iteraciones.

Permite visualizar valores como:

* Número de iteración.
* Aproximaciones realizadas.
* Valores de la función.
* Error aproximado.
* Variables utilizadas por cada método.

Además, los resultados pueden visualizarse utilizando:

* **Formato decimal de alta precisión.**
* **Notación científica.**

---

#  Gráfico 2D interactivo

La aplicación incorpora un sistema propio de visualización gráfica para analizar el comportamiento de las funciones.

Entre sus características se encuentran:

* Ejes cartesianos `X` y `Y`.
* Marcas de graduación automáticas.
* Etiquetas numéricas adaptativas.
* Representación gráfica de la función.
* Visualización de construcciones asociadas a cada método.
* Control de desbordamiento mediante `ClipRect`.
* Adaptación a diferentes tamaños de pantalla.
* Modo de visualización ampliada o pantalla completa.

---

##  Soporte multiplataforma

El proyecto está desarrollado con Flutter y actualmente está orientado principalmente a:

| Plataforma | Soporte      |
| ---------- | ------------ |
|  Windows |  Compatible |
|  Android |  Compatible |

La misma base de código permite mantener una interfaz y lógica consistentes entre escritorio y dispositivos móviles.

---

#  Tecnologías utilizadas

| Tecnología                  | Uso                                                    |
| --------------------------- | ------------------------------------------------------ |
| **Flutter 3.x+**            | Framework principal de la aplicación                   |
| **Dart**                    | Lenguaje de programación                               |
| **math_expressions ^2.7.0** | Interpretación y evaluación de expresiones matemáticas |
| **intl ^0.19.0**            | Formato y representación de valores numéricos          |

---

#  Instalación y ejecución

## 1. Clonar el repositorio

```bash
git clone https://github.com/Will-M7/App_Flutter.git
```

---

## 2. Instalar las dependencias

Ejecutar:

```bash
flutter pub get
```

---

## 3. Ejecutar la aplicación

###  Windows

```bash
flutter run -d windows
```

###  Android

Con un dispositivo conectado mediante USB y con la **depuración USB activada**:

```bash
flutter run -d android
```

También puede utilizarse un emulador configurado desde Android Studio.

---

#  Generar APK para Android

Para generar una versión de distribución:

```bash
flutter build apk --release
```

Una vez finalizada la compilación, el APK se encontrará en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

#  Flujo básico de uso

```text
1. Ingresar la función f(x)
        ↓
2. Seleccionar el método numérico
        ↓
3. Configurar valores iniciales y tolerancia
        ↓
4. Ejecutar el cálculo
        ↓
5. Obtener la raíz aproximada
        ↓
6. Revisar las iteraciones
        ↓
7. Analizar la función mediante el gráfico 2D
```

---

#  Objetivo del proyecto

El objetivo de esta aplicación es facilitar el aprendizaje y aplicación de **métodos numéricos para ecuaciones no lineales**, proporcionando en una misma herramienta:

* Resolución automática.
* Visualización gráfica.
* Historial de iteraciones.
* Control de errores.
* Interpretación flexible de ecuaciones.
* Ejecución tanto en escritorio como en dispositivos móviles.

De esta manera, el usuario no solo obtiene una aproximación de la raíz, sino que también puede analizar el proceso seguido por cada algoritmo.

---

##  Métodos disponibles

```text
✓ Newton-Raphson
✓ Secante
✓ Regla Falsa
```

---

##  Desarrollo

Proyecto desarrollado utilizando **Flutter y Dart** como aplicación multiplataforma orientada al análisis y resolución de problemas de **Métodos Numéricos** .
