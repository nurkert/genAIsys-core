import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/services/init_input_service.dart';

void main() {
  late InitInputService service;
  late Directory tempDir;

  setUp(() {
    service = InitInputService();
    tempDir = Directory.systemTemp.createTempSync('genaisys_init_input_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('fromText', () {
    test('returns correct normalized text and type', () {
      const text = 'Hello, world!';
      final result = service.fromText(text);

      expect(result.normalizedText, text);
      expect(result.sourcePayload, '<inline>');
      expect(result.type, InitInputType.plainText);
    });

    test('handles empty string', () {
      final result = service.fromText('');
      expect(result.normalizedText, '');
      expect(result.type, InitInputType.plainText);
    });
  });

  group('fromFile', () {
    test('reads .txt file correctly', () {
      final file = File('${tempDir.path}/input.txt')
        ..writeAsStringSync('Some text content');

      final result = service.fromFile(file.path);

      expect(result.normalizedText, 'Some text content');
      expect(result.sourcePayload, file.path);
      expect(result.type, InitInputType.plainText);
    });

    test('reads .md file correctly', () {
      final file = File('${tempDir.path}/README.md')
        ..writeAsStringSync('# Title\n\nDescription here.');

      final result = service.fromFile(file.path);

      expect(result.normalizedText, '# Title\n\nDescription here.');
      expect(result.sourcePayload, file.path);
      expect(result.type, InitInputType.plainText);
    });

    test('throws FileSystemException for non-existent path', () {
      expect(
        () => service.fromFile('${tempDir.path}/does_not_exist.txt'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('fromPdf', () {
    test('throws StateError when pdftotext is missing or fails', () {
      // Use a path that exists but is not a valid PDF so pdftotext exits non-0.
      final fakePdf = File('${tempDir.path}/fake.pdf')
        ..writeAsStringSync('not a real pdf');

      // Either pdftotext is not installed (StateError) or it fails on a
      // non-PDF (also StateError). Either way a StateError must be thrown.
      expect(
        () => service.fromPdf(fakePdf.path),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError for non-existent PDF', () {
      expect(
        () => service.fromPdf('${tempDir.path}/missing.pdf'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('autoDetect', () {
    test('delegates to fromFile for .txt path', () {
      final file = File('${tempDir.path}/doc.txt')
        ..writeAsStringSync('txt content');

      final result = service.autoDetect(file.path);

      expect(result.normalizedText, 'txt content');
      expect(result.type, InitInputType.plainText);
    });

    test('delegates to fromFile for .md path', () {
      final file = File('${tempDir.path}/doc.md')
        ..writeAsStringSync('md content');

      final result = service.autoDetect(file.path);

      expect(result.normalizedText, 'md content');
      expect(result.type, InitInputType.plainText);
    });

    test('delegates to fromPdf for .pdf extension (case-insensitive)', () {
      final fakePdf = File('${tempDir.path}/doc.PDF')
        ..writeAsStringSync('not a pdf');

      // Expect a StateError because the file is not a valid PDF.
      expect(
        () => service.autoDetect(fakePdf.path),
        throwsA(isA<StateError>()),
      );
    });
  });
}
