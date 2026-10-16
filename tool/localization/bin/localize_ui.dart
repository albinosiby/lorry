// AST-based mechanical migration. Does not alter stored data or API values.
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Edit {
  Edit(this.offset, this.length, this.text);
  final int offset, length;
  final String text;
}

class Migrate extends RecursiveAstVisitor<void> {
  final edits = <Edit>[];
  final removed = <int>{};
  final bool apply;
  Migrate(this.apply);
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == 'Text') {
      edits.add(Edit(node.methodName.offset, 4, 'LocalizedText'));
    }
    if (node.target == null && node.methodName.name == 'InputDecoration') {
      removeConst(node);
      edits.add(Edit(node.offset, 0, 'localizedDecoration(context, '));
      edits.add(Edit(node.end, 0, ')'));
    }
    super.visitMethodInvocation(node);
  }

  void removeConst(AstNode node) {
    for (AstNode? current = node; current != null; current = current.parent) {
      final token = switch (current) {
        InstanceCreationExpression() => current.keyword,
        ListLiteral() => current.constKeyword,
        SetOrMapLiteral() => current.constKeyword,
        _ => null,
      };
      if (token?.lexeme == 'const' && removed.add(token!.offset)) {
        edits.add(Edit(token.offset, token.length, ''));
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name.lexeme;
    if (name == 'Text' && node.constructorName.name == null) {
      edits.add(Edit(node.constructorName.offset, 4, 'LocalizedText'));
    }
    if (name == 'InputDecoration') {
      removeConst(node);
      edits.add(Edit(node.offset, 0, 'localizedDecoration(context, '));
      edits.add(Edit(node.end, 0, ')'));
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final name = node.name.label.name;
    if (name == 'tooltip' ||
        (name == 'label' &&
            node.parent?.parent is InstanceCreationExpression &&
            (node.parent!.parent as InstanceCreationExpression)
                    .constructorName
                    .type
                    .name
                    .lexeme ==
                'NavigationDestination')) {
      removeConst(node);
      edits.add(Edit(node.expression.offset, 0, 'localize(context, '));
      edits.add(Edit(node.expression.end, 0, ')'));
    }
    if (name == 'validator') {
      edits.add(
        Edit(
          node.expression.offset,
          0,
          '(value) => localizeOptional(context, (',
        ),
      );
      edits.add(Edit(node.expression.end, 0, ')(value))'));
    }
    super.visitNamedExpression(node);
  }
}

void main(List<String> args) {
  for (final file in Directory(
    '../../lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') ||
        file.path.contains('l10n') ||
        !(file.path.contains('screens') ||
            file.path.contains('widgets') ||
            file.path.contains('design_system'))) {
      continue;
    }
    final source = file.readAsStringSync();
    if (source.contains(
      "import 'package:lorry_link/l10n/app_localizations.dart';",
    )) {
      continue;
    }
    final visitor = Migrate(true);
    parseString(content: source).unit.accept(visitor);
    if (visitor.edits.isEmpty) continue;
    visitor.edits.sort((a, b) => b.offset.compareTo(a.offset));
    var result = source;
    for (final edit in visitor.edits) {
      result = result.replaceRange(
        edit.offset,
        edit.offset + edit.length,
        edit.text,
      );
    }
    result =
        "import 'package:lorry_link/l10n/app_localizations.dart';\n$result";
    if (args.contains('--apply')) file.writeAsStringSync(result);
    stdout.writeln('${file.path}: ${visitor.edits.length} edits');
  }
}
