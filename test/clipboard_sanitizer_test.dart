import 'package:flutter_test/flutter_test.dart';
import 'package:math_expressions/math_expressions.dart';

// Import local service testing
void main() {
  group('Clipboard and Paste Sanitization Tests', () {
    String cleanClipboardText(String input) {
      if (input.isEmpty) return '';
      String text = input;
      text = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u00AD\u200E\u200F]'), '');
      text = text.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
      text = text.replaceAll(RegExp(r'[\u00A0\u202F\u2007\u2000-\u200A]'), ' ');
      text = text.replaceAll(RegExp(r'[\u2010-\u2015\u2212\uFE63\uFF0D]'), '-');
      text = text.replaceAll(RegExp(r'[\u00D7\u2715\u2716\u00B7\u2022\u22C5\u2217]'), '*');
      text = text.replaceAll(RegExp(r'[\u00F7\u2215\u2044]'), '/');
      text = text.replaceAll('⁰', '^0')
                 .replaceAll('¹', '^1')
                 .replaceAll('²', '^2')
                 .replaceAll('³', '^3')
                 .replaceAll('⁴', '^4')
                 .replaceAll('⁵', '^5')
                 .replaceAll('⁶', '^6')
                 .replaceAll('⁷', '^7')
                 .replaceAll('⁸', '^8')
                 .replaceAll('⁹', '^9')
                 .replaceAll('⁺', '^+')
                 .replaceAll('⁻', '^-')
                 .replaceAll('ˣ', '^x');
      text = text.replaceAll(RegExp(r'[\u2018\u2019\u201C\u201D\u2032\u2033]'), '');
      return text;
    }

    String sanitizeExpression(String input) {
      String text = cleanClipboardText(input).trim();
      if (text.isEmpty) return '';
      text = text.replaceAll(',', '.');
      text = text.replaceAll(RegExp(r'\^{2,}'), '^');
      text = text.replaceAll(RegExp(r'\bexp\s*\('), 'e^(');
      text = text.replaceAll('SIN', 'sin').replaceAll('COS', 'cos').replaceAll('TAN', 'tan');
      text = text.replaceAll('SQRT', 'sqrt').replaceAll('LN', 'ln').replaceAll('LOG', 'log');
      text = text.replaceAllMapped(
        RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z\(])'),
        (match) => '${match.group(1)}*${match.group(2)}',
      );
      text = text.replaceAllMapped(RegExp(r'\)\s*\('), (match) => ')*(');
      text = text.replaceAllMapped(RegExp(r'\)\s*([0-9a-zA-Z])'), (match) => ')*${match.group(1)}');
      text = text.replaceAllMapped(RegExp(r'(?<![a-zA-Z])([xX])\s*\('), (match) => '${match.group(1)}*(');
      text = text.replaceAllMapped(
        RegExp(r'(?<![a-zA-Z])([xX])\s*(sin|cos|tan|sqrt|ln|log|e\^|e)'),
        (match) => '${match.group(1)}*${match.group(2)}',
      );
      return text;
    }

    test('Clean typographical dashes and minus signs from Word/PDFs', () {
      // en-dash, em-dash, math minus
      final input = 'x³ – 4x − 9 — 2';
      final cleaned = cleanClipboardText(input);
      expect(cleaned, equals('x^3 - 4x - 9 - 2'));
    });

    test('Clean Unicode superscripts and invisible zero-width spaces', () {
      final input = 'x\u200B² + 3x\uFEFF - 5';
      final sanitized = sanitizeExpression(input);
      expect(sanitized, equals('x^2 + 3*x - 5'));
    });

    test('Clean multiplication dots and signs', () {
      final input = '2 · x × cos(x)';
      final sanitized = sanitizeExpression(input);
      expect(sanitized, equals('2 * x * cos(x)'));
    });

    test('Math parser successfully parses sanitized pasted formula', () {
      final input = '2x³ − 4x – 9';
      final sanitized = sanitizeExpression(input);
      final parser = Parser();
      final exp = parser.parse(sanitized);
      final cm = ContextModel();
      cm.bindVariable(Variable('x'), Number(2.0));
      final res = exp.evaluate(EvaluationType.REAL, cm);
      // 2*(2^3) - 4*(2) - 9 = 16 - 8 - 9 = -1
      expect(res, equals(-1.0));
    });
  });
}
