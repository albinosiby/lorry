import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Strings extends RecursiveAstVisitor<void> {
  final values = <String>{};
  @override
  void visitStringInterpolation(StringInterpolation node) {
    var index = 0;
    final text = node.elements.map((element) => element is InterpolationString
        ? element.value : '{${index++}}').join();
    add(text);
  }
  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.parent is AdjacentStrings) return;
    add(node.value);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    if (node.stringValue case final String text) add(text);
  }

  void add(String text) {
    if (RegExp(r'[A-Za-z]').hasMatch(text) &&
        !text.startsWith('package:') &&
        !text.startsWith('dart:') &&
        !text.endsWith('.dart') &&
        !text.startsWith('/') &&
        !RegExp(r'^[a-z_./:0-9-]+$').hasMatch(text)) {
      values.add(text);
    }
  }
}

void main() {
  final values = <String>{};
  for (final file in Directory(
    '../../lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('l10n')) continue;
    final visitor = Strings();
    parseString(content: file.readAsStringSync()).unit.accept(visitor);
    values.addAll(visitor.values);
  }
  final sorted = values.toList()..sort();
  stdout.writeln(jsonEncode(sorted));
}
