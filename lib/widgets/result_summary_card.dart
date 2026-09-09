import 'package:flutter/material.dart';
import '../models/calculation_result.dart';
import '../models/method_type.dart';

/// Tarjeta de resumen con badges de convergencia, raíz aproximada, derivados y alertas de error
class ResultSummaryCard extends StatelessWidget {
  final CalculationResult? result;
  final bool useScientificNotation;

  const ResultSummaryCard({
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
    if (result == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final res = result!;

    if (!res.isSuccess) {
      return Card(
        color: theme.colorScheme.errorContainer.withOpacity(0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atención en el cálculo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      res.errorMessage ?? 'Ocurrió un error no especificado durante la ejecución.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onErrorContainer,
                      ),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cabecera con Badge de Convergencia
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Convergencia Exitosa',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${res.executionTimeMs} ms',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // 2. Raíz y f(raíz)
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Raíz Aproximada (x*)',
                    value: _format(res.root),
                    icon: Icons.adjust,
                    color: theme.colorScheme.primary,
                    isHighlight: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Valor f(x*)',
                    value: _format(res.finalFx),
                    icon: Icons.functions,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 3. Error final e Iteraciones totales
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Error Final (Eₐ)',
                    value: _format(res.finalError),
                    icon: Icons.speed,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total de Iteraciones',
                    value: '${res.steps.length}',
                    icon: Icons.format_list_numbered,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),

            // 4. Derivada analítica si aplica (Newton-Raphson)
            if (res.method == NumericalMethod.newtonRaphson && res.derivativeString != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.architecture, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Derivada analítica: f\'(x) = ${res.derivativeString}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'RobotoMono',
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'RobotoMono',
            ),
          ),
        ],
      ),
    );
  }
}
