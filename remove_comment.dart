import 'dart:io';

void main() {
  final file = File('lib/app/minify_app.dart');
  final lines = file.readAsLinesSync();
  final uncommentedLines = lines.map((line) {
    var uncommentedLine = line;
    while (uncommentedLine.startsWith('//')) {
      uncommentedLine = uncommentedLine.replaceFirst(RegExp(r'^\/\/\s*'), '');
    }
    return uncommentedLine;
  }).toList();
  file.writeAsStringSync(uncommentedLines.join('\n'));
}
