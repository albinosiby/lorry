// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import '../../../lib/l10n/catalog.dart';
import 'inventory.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

void main() {
  final values = <String>{};
  for (final file in Directory(
    '../../lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') ||
        file.path.contains('l10n') ||
        file.path.contains('app_config')) {
      continue;
    }
    final visitor = Strings();
    parseString(content: file.readAsStringSync()).unit.accept(visitor);
    values.addAll(visitor.values);
  }
  final missing =
      values
          .where(
            (s) =>
                translateUi(s, 'ml') == s &&
                !s.startsWith('[') &&
                !s.contains('Supabase') &&
                !s.contains('Firebase') &&
                !RegExp(
                  r'^(YOUR|SUPABASE|GOOGLE|OSM|[A-Z_]{4,}_|[0-9A-Z]{5}$)',
                ).hasMatch(s) &&
                !s.contains('yyyy') &&
                !s.contains('MMM') &&
                !s.contains('h:mm') &&
                !s.startsWith('^') &&
                !s.startsWith('\\') &&
                !s.contains('http') &&
                !s.contains('Id') &&
                !s.startsWith('@') &&
                !s.contains('docs/'),
          )
          .toList()
        ..sort();
  stdout.writeln(jsonEncode(missing));
  stdout.writeln('${missing.length} missing');
}
