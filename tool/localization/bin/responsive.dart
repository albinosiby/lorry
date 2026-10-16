// Targeted mechanical layout fixes identified by the six-locale widget tests.
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'localize_ui.dart' show Edit;

class Rows extends RecursiveAstVisitor<void> {
  final rows=<({AstNode node, SimpleIdentifier? name, ArgumentList args})>[];
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if(node.target==null && node.methodName.name=='Row') rows.add((node:node,name:node.methodName,args:node.argumentList));
    super.visitMethodInvocation(node);
  }
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if(node.constructorName.type.name.lexeme=='Row') rows.add((node:node,name:null,args:node.argumentList));
    super.visitInstanceCreationExpression(node);
  }
}
void main() {
  const specs = {
    'vehicles/screens/vehicles_screen.dart': [
      (wrap:true, needles:['Registered Fleet (']),
      (wrap:true, needles:['truck.registrationNumber','truck.isDefault']),
      (wrap:false, needles:['RC & Compliance Vault']),
    ],
    'availability/screens/availability_screen.dart':[
      (wrap:false, needles:['Icon(icon, size: 14, color: valueColor)']),
      (wrap:true, needles:['_buildHsrpPlate(registration)']),
      (wrap:true, needles:['Available from']),
    ],
    'finance/screens/finance_screen.dart':[
      (wrap:false, needles:['Transaction Ledger']),
      (wrap:true, needles:["DateFormat('MMMM yyyy').format(DateTime.now())",'marginPercent']),
      (wrap:true, needles:["'this month'"]),
      (wrap:false, needles:["'Freight Income'"]),
      (wrap:false, needles:["'Fleet Expense'"]),
    ],
    'customer_trucks/screens/customer_trucks_screen.dart':[
      (wrap:false, needles:['LIVE FLEET RADAR']),
    ],
  };
  for(final entry in specs.entries) {
    final file=File('../../lib/modules/${entry.key}');
    var source=file.readAsStringSync();
    final visitor=Rows();
    parseString(content:source).unit.accept(visitor);
    final edits=<Edit>[];
    for(final spec in entry.value) {
      final choices=visitor.rows.where((row)=>spec.needles.every(row.node.toSource().contains)).toList()
        ..sort((a,b)=>a.node.length.compareTo(b.node.length));
      if(choices.isEmpty) continue;
      final row=choices.first;
      final children=(row.args.arguments.whereType<NamedExpression>().firstWhere((a)=>a.name.label.name=='children').expression as ListLiteral);
      if(spec.wrap) {
        final offset=row.name?.offset ?? (row.node as InstanceCreationExpression).constructorName.offset;
        edits.add(Edit(offset,3,'Wrap'));
        edits.add(Edit(row.args.leftParenthesis.end,0,'spacing: 8, runSpacing: 8, '));
        for(final arg in row.args.arguments.whereType<NamedExpression>()) {
          if(const ['mainAxisSize','mainAxisAlignment','crossAxisAlignment','textBaseline'].contains(arg.name.label.name)) {
            var end=arg.end;
            while(end<source.length && source[end].trim().isEmpty) {end++;}
            if(source[end]==',') end++;
            edits.add(Edit(arg.offset,end-arg.offset,''));
          }
        }
        for(final child in children.elements) {
          if(RegExp(r'^(const )?Spacer\(').hasMatch(child.toSource())) {
            var end=child.end;
            while(end<source.length && source[end].trim().isEmpty) {end++;}
            if(source[end]==',') end++;
            edits.add(Edit(child.offset,end-child.offset,''));
          }
        }
      } else {
        for(final child in children.elements) {
          if(RegExp(r'^(const )?(LocalizedText|Text)\(').hasMatch(child.toSource())) {
            edits.add(Edit(child.offset,0,'Flexible(child: '));
            edits.add(Edit(child.end,0,')'));
          }
        }
      }
    }
    for(final edit in edits..sort((a,b)=>b.offset.compareTo(a.offset))) {
      source=source.replaceRange(edit.offset,edit.offset+edit.length,edit.text);
    }
    file.writeAsStringSync(source);
  }
}
