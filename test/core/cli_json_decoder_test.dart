import 'package:flutter_test/flutter_test.dart';

import 'package:genaisys/core/cli/cli_json_decoder.dart';

void main() {
  const decoder = CliJsonDecoder();

  test('decodeJsonLine parses object line', () {
    final map = decoder.decodeJsonLine('{"ok":true,"count":2}');
    expect(map, isNotNull);
    expect(map!['ok'], true);
    expect(map['count'], 2);
  });

  test('decodeJsonLine returns null for invalid json', () {
    final map = decoder.decodeJsonLine('not-json');
    expect(map, isNull);
  });

  test('decodeFirstJsonLine skips empty lines', () {
    final map = decoder.decodeFirstJsonLine('\n\n{"value":"yes"}\n');
    expect(map, isNotNull);
    expect(map!['value'], 'yes');
  });

  test('decodeFirstJsonLine skips non-json lines', () {
    final map = decoder.decodeFirstJsonLine('log line\n{"value":"yes"}\nother');
    expect(map, isNotNull);
    expect(map!['value'], 'yes');
  });
}
