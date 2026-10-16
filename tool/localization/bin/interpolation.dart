import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'localize_ui.dart' show Edit;

class UiArguments extends RecursiveAstVisitor<void> {
  final edits=<Edit>[];
  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    var inUi=false;
    for(AstNode? parent=node.parent;parent!=null;parent=parent.parent) {
      if(parent is MethodInvocation && parent.methodName.name=='LocalizedText' ||
          parent is InstanceCreationExpression && parent.constructorName.type.name.lexeme=='LocalizedText') {
        inUi=true;break;
      }
      if(parent is Statement) break;
    }
    final source=node.expression.toSource();
    final isUi = RegExp(r'\.(vehicle|vehicleType|bodyType|weightLabel|vehicleLengthLabel|paymentLabel|type\.label)$').hasMatch(source) ||
        source.startsWith('statusLabel(') || source=='_timeGreeting()' ||
        node.expression is ConditionalExpression;
    if(inUi && isUi && !source.startsWith('localize(')) {
      // Braces are mandatory when replacing a simple $variable interpolation.
      edits.add(Edit(node.offset,node.length,'\${localize(context, $source)}'));
    }
    super.visitInterpolationExpression(node);
  }
}
void main() {
  for(final file in Directory('../../lib').listSync(recursive:true).whereType<File>()) {
    if(!file.path.endsWith('.dart') || file.path.contains('l10n')) continue;
    var source=file.readAsStringSync();
    if(!source.contains('app_localizations.dart')) continue;
    final visitor=UiArguments();
    parseString(content:source).unit.accept(visitor);
    for(final edit in visitor.edits..sort((a,b)=>b.offset.compareTo(a.offset))) {
      source=source.replaceRange(edit.offset,edit.offset+edit.length,edit.text);
    }
    if(visitor.edits.isNotEmpty) file.writeAsStringSync(source);
  }
}
