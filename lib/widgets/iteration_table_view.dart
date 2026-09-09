import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/calculation_result.dart';
import '../models/method_type.dart';

/// Tabla interactiva con el historial de iteraciones, formatos de precisión y selección de paso
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

  String _formatNumber(double? val) {
    if (val == null) return '-';
    if (useScientificNotation) {
      if (val.abs() == 0.0) return '0.0000e+0';
      return val.toStringAsExponential(5);
    } else {
      // Decimal de alta precisión (8 decimales)
      if (val.abs() < 1e-12 && val != 0) {
        return val.toStringAsExponential(5);
      }
      return val.toStringAsFixed(7).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
  }

  void _copyToClipboard(BuildContext context) {
    if (result == null || result!.steps.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('=== TABLA DE ITERACIONES: ${result!.method.displayName} ===');
    buffer.writeln('Función: f(x) = ${result!.rawFunction}');
    buffer.writeln('Paso\tx_i\tf(x_i)\tError');

    for (final step in result!.steps) {
      buffer.writeln(
        '${step.stepNumber}\t${_formatNumber(step.currentX)}\t${_formatNumber(step.currentFx)}\t${_formatNumber(step.error)}',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tabla copiada al portapapeles.'),
        duration: Duration(seconds: 2),
      ),
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
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Ingresa los parámetros y presiona "Resolver y Graficar" para ver la tabla de iteraciones.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
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
          // Encabezado de la tarjeta con título y botón de copiar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Historial de Iteraciones (${steps.length} pasos)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copiar tabla',
                  onPressed: () => _copyToClipboard(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tabla con scroll horizontal y vertical
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  columnSpacing: 20,
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
                  ),
                  columns: _buildColumns(method),
                  rows: List<DataRow>.generate(steps.length, (index) {
                    final step = steps[index];
                    final isSelected = index == selectedStepIndex;

                    return DataRow(
                      selected: isSelected,
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (isSelected) {
                          return theme.colorScheme.primary.withOpacity(0.18);
                        }
                        if (index % 2 == 1) {
                          return isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015);
                        }
                        return null;
                      }),
                      onSelectChanged: (_) {
                        onStepSelected(index);
                      },
                      cells: _buildCells(step, method),
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
      const DataColumn(
        label: Text('i (Paso)', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      DataColumn(
        label: Text(
          method == NumericalMethod.falsePosition ? 'c (Aprox.)' : 'xᵢ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const DataColumn(
        label: Text('f(xᵢ)', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      if (method == NumericalMethod.newtonRaphson)
        const DataColumn(
          label: Text('f\'(xᵢ)', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      if (method == NumericalMethod.falsePosition) ...[
        const DataColumn(
          label: Text('a', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const DataColumn(
          label: Text('b', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
      const DataColumn(
        label: Text('Error Aprox. (Eₐ)', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
  }

  List<DataCell> _buildCells(dynamic step, NumericalMethod method) {
    const monoStyle = TextStyle(fontFamily: 'RobotoMono', fontSize: 12);

    return [
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${step.stepNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
      DataCell(Text(_formatNumber(step.currentX), style: monoStyle)),
      DataCell(Text(_formatNumber(step.currentFx), style: monoStyle)),
      if (method == NumericalMethod.newtonRaphson)
        DataCell(Text(_formatNumber(step.derivativeFx), style: monoStyle)),
      if (method == NumericalMethod.falsePosition) ...[
        DataCell(Text(_formatNumber(step.intervalA), style: monoStyle)),
        DataCell(Text(_formatNumber(step.intervalB), style: monoStyle)),
      ],
      DataCell(
        Text(
          step.error != null ? _formatNumber(step.error) : '-',
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
