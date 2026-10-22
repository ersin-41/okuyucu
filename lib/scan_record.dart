class ScanRecord {
  const ScanRecord({required this.serial, required this.scannedAt});

  final String serial;
  final DateTime scannedAt;

  Map<String, Object> toJson() => {
    'serial': serial,
    'scannedAt': scannedAt.toIso8601String(),
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      serial: json['serial'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
    );
  }
}

List<String> extractSerialCandidates(String text) {
  final candidates = <String>{};
  final tokenPattern = RegExp(r'[A-Z0-9-]{2,}');

  for (final match in tokenPattern.allMatches(text.toUpperCase())) {
    final candidate = match.group(0)!;
    if (RegExp(r'[A-Z]').hasMatch(candidate) &&
        RegExp(r'\d').hasMatch(candidate)) {
      candidates.add(candidate);
    }
  }

  return candidates.toList();
}
