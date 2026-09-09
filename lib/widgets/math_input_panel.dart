import 'package:flutter/material.dart';
import '../models/method_type.dart';

/// Panel de entrada de datos, configuración de parámetros y botones de ayuda matemática
class MathInputPanel extends StatefulWidget {
  final NumericalMethod selectedMethod;
  final ValueChanged<NumericalMethod> onMethodChanged;
  final String functionText;
  final String x0Text;
  final String x1Text;
  final String toleranceText;
  final String maxIterText;
  final bool useScientificNotation;
  final ValueChanged<bool> onNotationChanged;
  final VoidCallback onSolve;
  final VoidCallback onClear;
  final void Function(String function, String x0, String? x1) onApplyPreset;

  const MathInputPanel({
    super.key,
    required this.selectedMethod,
    required this.onMethodChanged,
    required this.functionText,
    required this.x0Text,
    required this.x1Text,
    required this.toleranceText,
    required this.maxIterText,
    required this.useScientificNotation,
    required this.onNotationChanged,
    required this.onSolve,
    required this.onClear,
    required this.onApplyPreset,
  });

  @override
  State<MathInputPanel> createState() => _MathInputPanelState();
}

class _MathInputPanelState extends State<MathInputPanel> {
  late TextEditingController _funcController;
  late TextEditingController _x0Controller;
  late TextEditingController _x1Controller;
  late TextEditingController _tolController;
  late TextEditingController _maxIterController;

  @override
  void initState() {
    super.initState();
    _funcController = TextEditingController(text: widget.functionText);
    _x0Controller = TextEditingController(text: widget.x0Text);
    _x1Controller = TextEditingController(text: widget.x1Text);
    _tolController = TextEditingController(text: widget.toleranceText);
    _maxIterController = TextEditingController(text: widget.maxIterText);
  }

  @override
  void didUpdateWidget(covariant MathInputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.functionText != widget.functionText && _funcController.text != widget.functionText) {
      _funcController.text = widget.functionText;
    }
    if (oldWidget.x0Text != widget.x0Text && _x0Controller.text != widget.x0Text) {
      _x0Controller.text = widget.x0Text;
    }
    if (oldWidget.x1Text != widget.x1Text && _x1Controller.text != widget.x1Text) {
      _x1Controller.text = widget.x1Text;
    }
    if (oldWidget.toleranceText != widget.toleranceText && _tolController.text != widget.toleranceText) {
      _tolController.text = widget.toleranceText;
    }
    if (oldWidget.maxIterText != widget.maxIterText && _maxIterController.text != widget.maxIterText) {
      _maxIterController.text = widget.maxIterText;
    }
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

  void _insertSymbol(String symbol) {
    final text = _funcController.text;
    final selection = _funcController.selection;
    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, symbol);
    _funcController.text = newText;
    _funcController.selection = TextSelection.collapsed(offset: start + symbol.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Selector de Método Numérico
            DropdownButtonFormField<NumericalMethod>(
              value: widget.selectedMethod,
              decoration: InputDecoration(
                labelText: 'Método Numérico',
                prefixIcon: const Icon(Icons.calculate_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              items: NumericalMethod.values.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(
                    method.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) widget.onMethodChanged(val);
              },
            ),

            const SizedBox(height: 6),
            Text(
              widget.selectedMethod.shortFormula,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'RobotoMono',
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // 2. Campo de Entrada para f(x)
            TextFormField(
              controller: _funcController,
              decoration: InputDecoration(
                labelText: 'Función f(x)',
                hintText: 'ej. x^3 - 4*x - 9',
                prefixIcon: const Icon(Icons.functions),
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
                  _buildChip('e^x'),
                  _buildChip('ln(x)'),
                  _buildChip('sqrt(x)'),
                  _buildChip('('),
                  _buildChip(')'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 3. Valores Iniciales (x0 y opcionalmente x1)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _x0Controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: widget.selectedMethod.primaryInitialLabel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                ),
                if (widget.selectedMethod.requiresTwoInitialPoints) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _x1Controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: widget.selectedMethod.secondaryInitialLabel,
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
                      labelText: 'Tolerancia (Tol)',
                      hintText: '0.0001',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _maxIterController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Máx. Iteraciones',
                      hintText: '50',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 5. Formato de visualización numérica
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Formato de números:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Decimal')),
                    ButtonSegment<bool>(value: true, label: Text('Científica')),
                  ],
                  selected: {widget.useScientificNotation},
                  onSelectionChanged: (Set<bool> newSelection) {
                    widget.onNotationChanged(newSelection.first);
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 6. Botones de Acción: Resolver y Limpiar
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: () {
                      _triggerSolve();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text('Resolver y Graficar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () {
                      _funcController.clear();
                      _x0Controller.clear();
                      _x1Controller.clear();
                      widget.onClear();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 7. Ejemplos Predeterminados para Pruebas Rápidas
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Ejemplos:', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                _buildExampleChip('x³ - 4x - 9', 'x^3 - 4*x - 9', '2', '3'),
                _buildExampleChip('cos(x) - x', 'cos(x) - x', '0.5', '1.0'),
                _buildExampleChip('e⁻ˣ - x', 'e^(-x) - x', '0.0', '1.0'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _triggerSolve() {
    // Sincronizar datos y lanzar solución
    widget.onApplyPreset(
      _funcController.text,
      _x0Controller.text,
      _x1Controller.text.isNotEmpty ? _x1Controller.text : null,
    );
    widget.onSolve();
  }

  Widget _buildChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'RobotoMono')),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onPressed: () => _insertSymbol(label),
      ),
    );
  }

  Widget _buildExampleChip(String label, String func, String x0, String x1) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        _funcController.text = func;
        _x0Controller.text = x0;
        _x1Controller.text = x1;
        widget.onApplyPreset(func, x0, x1);
      },
    );
  }
}
