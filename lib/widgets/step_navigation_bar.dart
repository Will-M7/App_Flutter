import 'dart:async';
import 'package:flutter/material.dart';
import '../models/calculation_result.dart';

/// Barra de navegación e interactividad paso a paso (Anterior, Siguiente, Reiniciar, Auto-Play)
class StepNavigationBar extends StatefulWidget {
  final CalculationResult? result;
  final int currentStepIndex;
  final ValueChanged<int> onStepChanged;

  const StepNavigationBar({
    super.key,
    required this.result,
    required this.currentStepIndex,
    required this.onStepChanged,
  });

  @override
  State<StepNavigationBar> createState() => _StepNavigationBarState();
}

class _StepNavigationBarState extends State<StepNavigationBar> {
  Timer? _playbackTimer;
  bool _isPlaying = false;

  @override
  void didUpdateWidget(covariant StepNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
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
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      if (widget.result == null || widget.result!.steps.isEmpty) return;

      setState(() {
        _isPlaying = true;
      });

      _playbackTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
        final totalSteps = widget.result!.steps.length;
        if (widget.currentStepIndex + 1 < totalSteps) {
          widget.onStepChanged(widget.currentStepIndex + 1);
        } else {
          // Finalizó la reproducción
          _stopPlayback();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;

    if (result == null || result.steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalSteps = result.steps.length;
    final currentIndex = widget.currentStepIndex.clamp(0, totalSteps - 1);
    final currentStep = result.steps[currentIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Controles de Botones y Slider
          Row(
            children: [
              // Botón Reiniciar
              IconButton(
                icon: const Icon(Icons.first_page),
                tooltip: 'Reiniciar al paso inicial',
                onPressed: currentIndex > 0
                    ? () {
                        _stopPlayback();
                        widget.onStepChanged(0);
                      }
                    : null,
              ),

              // Botón Paso Anterior
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Paso anterior',
                onPressed: currentIndex > 0
                    ? () {
                        _stopPlayback();
                        widget.onStepChanged(currentIndex - 1);
                      }
                    : null,
              ),

              // Botón Reproducir / Pausar
              FilledButton.tonalIcon(
                onPressed: _togglePlayback,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_isPlaying ? 'Pausa' : 'Auto-Play'),
              ),

              // Botón Siguiente Paso
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Siguiente paso',
                onPressed: currentIndex < totalSteps - 1
                    ? () {
                        _stopPlayback();
                        widget.onStepChanged(currentIndex + 1);
                      }
                    : null,
              ),

              // Botón Último Paso
              IconButton(
                icon: const Icon(Icons.last_page),
                tooltip: 'Ir al resultado final',
                onPressed: currentIndex < totalSteps - 1
                    ? () {
                        _stopPlayback();
                        widget.onStepChanged(totalSteps - 1);
                      }
                    : null,
              ),

              const SizedBox(width: 8),

              // Indicador de Paso
              Text(
                'Paso ${currentIndex + 1} de $totalSteps',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),

              const SizedBox(width: 8),

              // Slider deslizable
              Expanded(
                child: Slider(
                  value: currentIndex.toDouble(),
                  min: 0.0,
                  max: (totalSteps - 1).toDouble().clamp(0.0, double.infinity),
                  divisions: totalSteps > 1 ? totalSteps - 1 : 1,
                  label: 'Paso ${currentIndex + 1}',
                  onChanged: (val) {
                    _stopPlayback();
                    widget.onStepChanged(val.toInt());
                  },
                ),
              ),
            ],
          ),

          // 2. Descripción explicativa del paso actual
          if (currentStep.note != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentStep.note!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'RobotoMono',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
