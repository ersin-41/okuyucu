import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'scan_record.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.onSave});

  final Future<bool> Function(String serial) onSave;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _serialController = TextEditingController();

  CameraController? _cameraController;
  List<String> _candidates = [];
  String? _cameraError;
  String? _recognizedText;
  bool _processing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Bu cihazda kullanılabilir kamera bulunamadı.');
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
    } catch (error) {
      if (mounted) setState(() => _cameraError = error.toString());
    }
  }

  Future<void> _captureAndRead() async {
    final camera = _cameraController;
    if (camera == null || _processing) return;

    setState(() => _processing = true);
    try {
      final picture = await camera.takePicture();
      final result = await _recognizer.processImage(
        InputImage.fromFilePath(picture.path),
      );
      final candidates = extractSerialCandidates(result.text);
      if (!mounted) return;
      setState(() {
        _recognizedText = result.text;
        _candidates = candidates;
        _serialController.text = candidates.length == 1 ? candidates.first : '';
      });
      if (result.text.trim().isEmpty) {
        _showMessage(
          'Metin okunamadı. Işığı ve odağı kontrol edip tekrar deneyin.',
        );
      } else if (candidates.isEmpty) {
        _showMessage('Seri numarası seçilemedi. Aşağıya elle yazabilirsiniz.');
      }
    } catch (error) {
      if (mounted) _showMessage('Fotoğraf okunamadı: $error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final serial = _serialController.text.trim();
    if (serial.isEmpty) {
      _showMessage('Kaydetmeden önce seri numarasını girin.');
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(serial);
      if (!mounted) return;
      if (saved) {
        Navigator.of(context).pop();
      } else {
        _showMessage('Bu seri numarası zaten kayıtlı.');
      }
    } catch (error) {
      if (mounted) _showMessage('Seri numarası kaydedilemedi: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _recognizer.close();
    _serialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _cameraController;
    return Scaffold(
      appBar: AppBar(title: const Text('Seri numarası tara')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Lastik üzerindeki kodu kadraja alın',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: camera != null && camera.value.isInitialized
                    ? CameraPreview(camera)
                    : _CameraPlaceholder(error: _cameraError),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: camera == null || _processing ? null : _captureAndRead,
              icon: _processing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.center_focus_strong_rounded),
              label: Text(_processing ? 'Okunuyor...' : 'Fotoğraf çek ve oku'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Seri numarası',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _serialController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Örn. AB12CD3456',
                prefixIcon: const Icon(Icons.tag_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            if (_candidates.length > 1) ...[
              const SizedBox(height: 14),
              Text(
                'Okunan olası kodlar',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _candidates
                    .map(
                      (candidate) => ActionChip(
                        label: Text(candidate),
                        onPressed: () =>
                            setState(() => _serialController.text = candidate),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_recognizedText != null && _candidates.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Okunan metin: ${_recognizedText!.replaceAll('\n', ' ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Kaydediliyor...' : 'Cihaza kaydet'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Metin tanıma internet bağlantısı olmadan cihazda yapılır.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error == null)
                const CircularProgressIndicator()
              else ...[
                Icon(
                  Icons.no_photography_outlined,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Kamera açılamadı\n$error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
