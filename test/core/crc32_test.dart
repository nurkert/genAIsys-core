import 'package:flutter_test/flutter_test.dart';
import 'package:genaisys/core/storage/crc32.dart';

void main() {
  group('Crc32', () {
    test('empty string produces known CRC32', () {
      // CRC32 of empty string is 0x00000000.
      expect(Crc32.ofString(''), 0);
      expect(Crc32.hexOfString(''), '00000000');
    });

    test('known test vector — "123456789"', () {
      // Standard CRC32 test vector: CRC32("123456789") = 0xCBF43926.
      expect(Crc32.ofString('123456789'), 0xCBF43926);
      expect(Crc32.hexOfString('123456789'), 'cbf43926');
    });

    test('consistent for same input', () {
      const input = 'Genaisys autopilot state integrity';
      final a = Crc32.hexOfString(input);
      final b = Crc32.hexOfString(input);
      expect(a, b);
      expect(a.length, 8);
    });

    test('different inputs produce different checksums', () {
      final a = Crc32.hexOfString('alpha');
      final b = Crc32.hexOfString('bravo');
      expect(a, isNot(b));
    });

    test('ofBytes matches ofString for ASCII', () {
      const text = 'hello';
      final fromString = Crc32.ofString(text);
      final fromBytes = Crc32.ofBytes(text.codeUnits);
      expect(fromString, fromBytes);
    });

    test('hex output is zero-padded to 8 characters', () {
      // Any input whose CRC starts with leading zeros must still be 8 chars.
      final hex = Crc32.hexOfString('');
      expect(hex.length, 8);
    });
  });
}
