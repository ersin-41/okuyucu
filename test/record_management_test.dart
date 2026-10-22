import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastik_seri_takip/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageKey = 'scanned_tire_serials';

  List<Map<String, dynamic>> recordsForTest() => [
    {
      'serial': 'AB12CD3456',
      'scannedAt': '2026-10-22T12:30:00.000Z',
      'note': 'Ön lastik',
    },
    {
      'serial': 'ZX98YU7654',
      'scannedAt': '2026-10-22T12:31:00.000Z',
      'note': '',
    },
  ];

  testWidgets('editing a record updates its serial and note', (tester) async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(recordsForTest()),
    });

    await tester.pumpWidget(const LastikSeriTakipApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kaydı düzenle').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'AB12CD9999');
    await tester.enterText(find.byType(TextFormField).at(1), 'Arka lastik');
    await tester.tap(find.text('Değişiklikleri kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('AB12CD9999'), findsOneWidget);
    expect(find.text('Arka lastik'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    final saved = (jsonDecode(preferences.getString(storageKey)!) as List)
        .map((record) => Map<String, dynamic>.from(record as Map))
        .toList();
    expect(saved.first['serial'], 'AB12CD9999');
    expect(saved.first['note'], 'Arka lastik');
  });

  testWidgets('selected records can be deleted together', (tester) async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(recordsForTest()),
    });

    await tester.pumpWidget(const LastikSeriTakipApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kayıtları seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AB12CD3456'));
    await tester.pumpAndSettle();
    expect(find.text('1 kayıt seçildi'), findsOneWidget);

    await tester.tap(find.byTooltip('Seçilenleri sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seçilenleri sil'));
    await tester.pumpAndSettle();

    expect(find.text('AB12CD3456'), findsNothing);
    expect(find.text('ZX98YU7654'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    final saved = jsonDecode(preferences.getString(storageKey)!) as List;
    expect(saved, hasLength(1));
    expect(saved.single['serial'], 'ZX98YU7654');
  });
}
