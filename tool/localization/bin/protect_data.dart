import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Protect extends RecursiveAstVisitor<void> {
  final offsets = <int>[];
  void inspect(int offset, ArgumentList arguments) {
    if (arguments.arguments.isEmpty) return;
    final source = arguments.arguments.first.toSource();
    if (RegExp(
          r'\.(name|address|cargo|phone|otherPhone|driverName|customerName|registrationNumber|registrationLabel|pickupLabel|destinationLabel|openingHours|location|note|specialNote|currentLocation|preferredDestination|photoPath|companyName)$',
        ).hasMatch(source) ||
        const {
          'name',
          'initial',
          'firstName',
          'phone',
          'address',
          'value',
          'registration',
          'cargo',
          'selectedPlaceName',
        }.contains(source)) {
      offsets.add(offset);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == 'LocalizedText') {
      inspect(node.methodName.offset, node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'LocalizedText') {
      inspect(node.constructorName.offset, node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }
}

void main() {
  for (final file in Directory(
    '../../lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('l10n')) continue;
    var source = file.readAsStringSync();
    final visitor = Protect();
    parseString(content: source).unit.accept(visitor);
    for (final offset in visitor.offsets..sort((a, b) => b.compareTo(a))) {
      source = source.replaceRange(offset, offset + 13, 'Text');
    }
    if (visitor.offsets.isNotEmpty) file.writeAsStringSync(source);
  }
}
