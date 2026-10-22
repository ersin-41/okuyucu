import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scan_record.dart';
import 'scanner_page.dart';

void main() {
  runApp(const LastikSeriTakipApp());
}

class LastikSeriTakipApp extends StatelessWidget {
  const LastikSeriTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF187A55);
    return MaterialApp(
      title: 'Lastik Seri Takip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          surface: const Color(0xFFF7F8F6),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F6),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const ScanListPage(),
    );
  }
}

class ScanListPage extends StatefulWidget {
  const ScanListPage({super.key});

  @override
  State<ScanListPage> createState() => _ScanListPageState();
}

class _ScanListPageState extends State<ScanListPage> {
  static const _storageKey = 'scanned_tire_serials';

  List<ScanRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(_storageKey);
      final records = stored == null
          ? <ScanRecord>[]
          : (jsonDecode(stored) as List<dynamic>)
                .map(
                  (item) => ScanRecord.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Kayıtlar yüklenemedi: $error');
    }
  }

  Future<bool> _saveSerial(String value) async {
    final serial = value.trim().toUpperCase();
    if (serial.isEmpty) return false;
    if (_records.any((record) => record.serial == serial)) return false;

    final updated = [
      ScanRecord(serial: serial, scannedAt: DateTime.now()),
      ..._records,
    ];
    await _persist(updated);
    if (!mounted) return false;
    setState(() => _records = updated);
    return true;
  }

  Future<void> _deleteRecord(ScanRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı sil?'),
        content: Text('${record.serial} seri numarası silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = _records
        .where(
          (item) =>
              item.scannedAt != record.scannedAt ||
              item.serial != record.serial,
        )
        .toList();
    try {
      await _persist(updated);
      if (mounted) setState(() => _records = updated);
    } catch (error) {
      if (mounted) _showMessage('Kayıt silinemedi: $error');
    }
  }

  Future<void> _persist(List<ScanRecord> records) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
    if (!saved) throw StateError('Cihaza kayıt yapılamadı.');
  }

  Future<void> _exportRecords() async {
    if (_records.isEmpty) {
      _showMessage('Dışa aktarmak için önce bir seri numarası kaydedin.');
      return;
    }

    try {
      final workbook = Excel.createExcel();
      workbook.rename('Sheet1', 'Seri Numaraları');
      final sheet = workbook['Seri Numaraları'];
      sheet.appendRow([
        TextCellValue('Seri Numarası'),
        TextCellValue('Okunma Tarihi'),
      ]);
      for (final record in _records.reversed) {
        sheet.appendRow([
          TextCellValue(record.serial),
          TextCellValue(
            DateFormat('dd.MM.yyyy HH:mm').format(record.scannedAt),
          ),
        ]);
      }

      final bytes = workbook.encode();
      if (bytes == null) throw StateError('Excel dosyası oluşturulamadı.');
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}lastik_seri_listesi.xlsx',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Lastik seri numaraları',
          text: 'Kaydedilen lastik seri numaraları',
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Dışa aktarma başarısız oldu: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ScannerPage(onSave: _saveSerial)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lastik Seri Takip',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Excel olarak paylaş',
            onPressed: _loading ? null : _exportRecords,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: _SummaryCard(count: _records.length),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton.icon(
                      onPressed: _openScanner,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Seri numarası tara'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Kaydedilenler',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_records.length} kayıt',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _records.isEmpty
                        ? const _EmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _records.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final record = _records[index];
                              return _RecordTile(
                                record: record,
                                onDelete: () => _deleteRecord(record),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF176B4B), Color(0xFF21875F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seri numaralarınız',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$count',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bu cihazda güvenle saklanır',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.tire_repair_rounded, color: Colors.white, size: 54),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onDelete});

  final ScanRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.check_rounded,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          record.serial,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        subtitle: Text(
          DateFormat('dd.MM.yyyy · HH:mm').format(record.scannedAt),
        ),
        trailing: IconButton(
          tooltip: 'Kaydı sil',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz kayıt yok',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lastik üzerindeki seri numarasını tarayarak listenizi oluşturmaya başlayın.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
