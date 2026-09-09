import 'package:flutter/material.dart';
import '../models/calculation_result.dart';
import '../models/method_type.dart';
import '../services/math_parser_service.dart';
import '../solvers/false_position_solver.dart';
import '../solvers/newton_raphson_solver.dart';
import '../solvers/secant_solver.dart';
import '../widgets/graph_2d_viewer.dart';
import '../widgets/iteration_table_view.dart';
import '../widgets/math_input_panel.dart';
import '../widgets/result_summary_card.dart';
import '../widgets/step_navigation_bar.dart';

/// Pantalla Principal Adaptable (Mobile y Desktop) para Métodos Numéricos
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

  // Solvers
  late final NewtonRaphsonSolver _newtonSolver;
  late final SecantSolver _secantSolver;
  late final FalsePositionSolver _falsePositionSolver;

  // Estado de entrada
  NumericalMethod _selectedMethod = NumericalMethod.newtonRaphson;
  String _functionText = 'x^3 - 4*x - 9';
  String _x0Text = '2';
  String _x1Text = '3';
  String _toleranceText = '0.0001';
  String _maxIterText = '50';
  bool _useScientificNotation = false;

  // Estado de resultados
  CalculationResult? _calculationResult;
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _newtonSolver = NewtonRaphsonSolver(parserService: _parserService);
    _secantSolver = SecantSolver(parserService: _parserService);
    _falsePositionSolver = FalsePositionSolver(parserService: _parserService);

    // Ejecución inicial demostrativa al cargar la app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _solveCurrentMethod();
    });
  }

  void _solveCurrentMethod() {
    final double? x0 = double.tryParse(_x0Text.replaceAll(',', '.'));
    final double? x1 = _x1Text.isNotEmpty ? double.tryParse(_x1Text.replaceAll(',', '.')) : null;
    final double tolerance = double.tryParse(_toleranceText.replaceAll(',', '.')) ?? 0.0001;
    final int maxIter = int.tryParse(_maxIterText) ?? 50;

    if (x0 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un valor numérico válido para el punto inicial.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    CalculationResult result;

    switch (_selectedMethod) {
      case NumericalMethod.newtonRaphson:
        result = _newtonSolver.solve(
          functionExpression: _functionText,
          initialX0: x0,
          tolerance: tolerance,
          maxIterations: maxIter,
        );
        break;
      case NumericalMethod.secant:
        result = _secantSolver.solve(
          functionExpression: _functionText,
          initialX0: x0,
          initialX1: x1,
          tolerance: tolerance,
          maxIterations: maxIter,
        );
        break;
      case NumericalMethod.falsePosition:
        result = _falsePositionSolver.solve(
          functionExpression: _functionText,
          initialX0: x0,
          initialX1: x1,
          tolerance: tolerance,
          maxIterations: maxIter,
        );
        break;
    }

    setState(() {
      _calculationResult = result;
      _currentStepIndex = result.steps.isNotEmpty ? result.steps.length - 1 : 0;
    });

    if (!result.isSuccess && result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _clearAll() {
    setState(() {
      _functionText = '';
      _x0Text = '';
      _x1Text = '';
      _calculationResult = null;
      _currentStepIndex = 0;
    });
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
              child: Icon(Icons.show_chart_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Métodos Numéricos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Visualizador de Raíces de Ecuaciones', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;

          if (isDesktop) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  /// Layout optimizado para PC / Escritorio con distribución multicanal
  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Izquierdo: Entrada de datos y resumen
          SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  MathInputPanel(
                    selectedMethod: _selectedMethod,
                    onMethodChanged: (method) {
                      setState(() {
                        _selectedMethod = method;
                      });
                      _solveCurrentMethod();
                    },
                    functionText: _functionText,
                    x0Text: _x0Text,
                    x1Text: _x1Text,
                    toleranceText: _toleranceText,
                    maxIterText: _maxIterText,
                    useScientificNotation: _useScientificNotation,
                    onNotationChanged: (val) {
                      setState(() {
                        _useScientificNotation = val;
                      });
                    },
                    onSolve: _solveCurrentMethod,
                    onClear: _clearAll,
                    onApplyPreset: (fn, x0, x1) {
                      setState(() {
                        _functionText = fn;
                        _x0Text = x0;
                        _x1Text = x1 ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ResultSummaryCard(
                    result: _calculationResult,
                    useScientificNotation: _useScientificNotation,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Panel Derecho: Gráfico 2D, controles de paso y tabla de iteraciones
          Expanded(
            child: Column(
              children: [
                // Gráfico 2D
                Expanded(
                  flex: 5,
                  child: Graph2DViewer(
                    functionExpression: _functionText,
                    result: _calculationResult,
                    currentStepIndex: _currentStepIndex,
                    parserService: _parserService,
                  ),
                ),

                const SizedBox(height: 10),

                // Barra de Navegación de Pasos
                StepNavigationBar(
                  result: _calculationResult,
                  currentStepIndex: _currentStepIndex,
                  onStepChanged: (idx) {
                    setState(() {
                      _currentStepIndex = idx;
                    });
                  },
                ),

                const SizedBox(height: 10),

                // Tabla de Iteraciones
                Expanded(
                  flex: 4,
                  child: IterationTableView(
                    result: _calculationResult,
                    selectedStepIndex: _currentStepIndex,
                    onStepSelected: (idx) {
                      setState(() {
                        _currentStepIndex = idx;
                      });
                    },
                    useScientificNotation: _useScientificNotation,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Layout optimizado para Móviles / Pantallas verticales con Pestañas
  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.show_chart), text: 'Gráfico 2D'),
              Tab(icon: Icon(Icons.input), text: 'Entrada'),
              Tab(icon: Icon(Icons.table_rows), text: 'Tabla'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Pestaña 1: Gráfico y navegación
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: Graph2DViewer(
                          functionExpression: _functionText,
                          result: _calculationResult,
                          currentStepIndex: _currentStepIndex,
                          parserService: _parserService,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StepNavigationBar(
                        result: _calculationResult,
                        currentStepIndex: _currentStepIndex,
                        onStepChanged: (idx) {
                          setState(() {
                            _currentStepIndex = idx;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      ResultSummaryCard(
                        result: _calculationResult,
                        useScientificNotation: _useScientificNotation,
                      ),
                    ],
                  ),
                ),

                // Pestaña 2: Entrada de Parámetros
                SingleChildScrollView(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      MathInputPanel(
                        selectedMethod: _selectedMethod,
                        onMethodChanged: (method) {
                          setState(() {
                            _selectedMethod = method;
                          });
                        },
                        functionText: _functionText,
                        x0Text: _x0Text,
                        x1Text: _x1Text,
                        toleranceText: _toleranceText,
                        maxIterText: _maxIterText,
                        useScientificNotation: _useScientificNotation,
                        onNotationChanged: (val) {
                          setState(() {
                            _useScientificNotation = val;
                          });
                        },
                        onSolve: () {
                          _solveCurrentMethod();
                          DefaultTabController.of(context).animateTo(0);
                        },
                        onClear: _clearAll,
                        onApplyPreset: (fn, x0, x1) {
                          setState(() {
                            _functionText = fn;
                            _x0Text = x0;
                            _x1Text = x1 ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      ResultSummaryCard(
                        result: _calculationResult,
                        useScientificNotation: _useScientificNotation,
                      ),
                    ],
                  ),
                ),

                // Pestaña 3: Tabla de Iteraciones
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: IterationTableView(
                    result: _calculationResult,
                    selectedStepIndex: _currentStepIndex,
                    onStepSelected: (idx) {
                      setState(() {
                        _currentStepIndex = idx;
                      });
                    },
                    useScientificNotation: _useScientificNotation,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
