import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'localize_ui.dart' show Edit;

class Validation extends RecursiveAstVisitor<void> {
  final edits = <Edit>[];
  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == 'validator' &&
        node.expression is FunctionExpression) {
      final function = node.expression as FunctionExpression;
      if (function.body is ExpressionFunctionBody) {
        final body = (function.body as ExpressionFunctionBody).expression;
        if (body is MethodInvocation &&
            body.methodName.name == 'localizeOptional') {
          final call = body.argumentList.arguments.last;
          String? original;
          if (call is FunctionExpressionInvocation) {
            final target = call.function;
            original =
                (target is ParenthesizedExpression ? target.expression : target)
                    .toSource();
          } else if (call is MethodInvocation &&
              call.methodName.name == 'call') {
            original = call.target?.toSource();
          }
          if (original != null) {
            edits.add(
              Edit(node.expression.offset, node.expression.length, original),
            );
          }
        }
      }
    }
    super.visitNamedExpression(node);
  }

  void field(String name, ArgumentList args) {
    if (name != 'TextFormField' ||
        args.arguments.any(
          (a) => a is NamedExpression && a.name.label.name == 'errorBuilder',
        )) {
      return;
    }
    edits.add(
      Edit(
        args.leftParenthesis.end,
        0,
        'errorBuilder: (context, message) => LocalizedText(message), ',
      ),
    );
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) field(node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    field(node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }
}

void main() {
  for (final file in Directory(
    '../../lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('l10n')) continue;
    var text = file.readAsStringSync();
    if (!text.contains('app_localizations.dart')) continue;
    final visitor = Validation();
    parseString(content: text).unit.accept(visitor);
    for (final edit
        in visitor.edits..sort((a, b) => b.offset.compareTo(a.offset))) {
      text = text.replaceRange(
        edit.offset,
        edit.offset + edit.length,
        edit.text,
      );
    }
    if (visitor.edits.isNotEmpty) file.writeAsStringSync(text);
  }
}
