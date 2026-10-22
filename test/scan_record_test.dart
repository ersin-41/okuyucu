import 'package:flutter_test/flutter_test.dart';
import 'package:lastik_seri_takip/scan_record.dart';

void main() {
  group('extractSerialCandidates', () {
    test('finds unique variable-length alphanumeric codes', () {
      expect(extractSerialCandidates('DOT AB12CD3456 ab12cd3456 ZX9Y8'), [
        'AB12CD3456',
        'ZX9Y8',
      ]);
    });

    test('ignores words and number-only date codes', () {
      expect(extractSerialCandidates('DOT 2024 MADE IN TURKEY'), isEmpty);
    });

    test('accepts hyphenated codes', () {
      expect(extractSerialCandidates('DOT AB12-CD345'), ['AB12-CD345']);
    });

    test('does not assume a fixed serial length', () {
      expect(extractSerialCandidates('A1 AB12CD34567890'), [
        'A1',
        'AB12CD34567890',
      ]);
    });
  });

  test('ScanRecord can be serialized and restored', () {
    final original = ScanRecord(
      serial: 'AB12CD3456',
      scannedAt: DateTime.utc(2026, 10, 22, 12, 30),
      note: 'Ön lastik',
    );

    final restored = ScanRecord.fromJson(original.toJson());

    expect(restored.serial, original.serial);
    expect(restored.scannedAt, original.scannedAt);
    expect(restored.note, original.note);
  });

  test('ScanRecord restores older records without a note', () {
    final restored = ScanRecord.fromJson({
      'serial': 'AB12CD3456',
      'scannedAt': '2026-10-22T12:30:00.000Z',
    });

    expect(restored.note, isEmpty);
  });
}
