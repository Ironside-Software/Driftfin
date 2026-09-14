import 'dart:convert';
import 'dart:io';

/// Completeness report for a single non-template ARB locale file.
class TranslationReport {
  const TranslationReport(this.fileName, this.missingKeys, this.emptyKeys);

  final String fileName;
  final List<String> missingKeys;
  final List<String> emptyKeys;

  bool get isComplete => missingKeys.isEmpty && emptyKeys.isEmpty;
}

/// Compares every `app_*.arb` file in [l10nDir] against the `app_en.arb`
/// template and reports keys that are missing or present-but-empty.
///
/// Keys starting with `@` (ICU metadata, `@@locale`, ...) are ignored since
/// only the template needs them.
List<TranslationReport> checkTranslationCompleteness(Directory l10nDir) {
  final templateFile = File('${l10nDir.path}/app_en.arb');
  final String templateText = templateFile.readAsStringSync();
  final Map<String, dynamic> template = jsonDecode(templateText);
  final templateKeys = <String>[];
  for (final key in template.keys) {
    if (!key.startsWith('@')) {
      templateKeys.add(key);
    }
  }
  templateKeys.sort();

  final arbFiles = <File>[];
  for (final entity in l10nDir.listSync()) {
    final isArb = entity is File && entity.path.endsWith('.arb');
    final isTemplate = entity.path == templateFile.path;
    if (isArb && !isTemplate) {
      arbFiles.add(entity);
    }
  }
  arbFiles.sort((a, b) => a.path.compareTo(b.path));

  final reports = <TranslationReport>[];
  for (final file in arbFiles) {
    reports.add(_checkFile(file, templateKeys));
  }
  return reports;
}

TranslationReport _checkFile(File file, List<String> templateKeys) {
  final String fileText = file.readAsStringSync();
  final Map<String, dynamic> data = jsonDecode(fileText);
  final missingKeys = <String>[];
  final emptyKeys = <String>[];

  for (final key in templateKeys) {
    if (!data.containsKey(key)) {
      missingKeys.add(key);
      continue;
    }
    final value = data[key];
    if (value is String && value.trim().isEmpty) {
      emptyKeys.add(key);
    }
  }

  final fileName = file.uri.pathSegments.last;
  return TranslationReport(fileName, missingKeys, emptyKeys);
}
