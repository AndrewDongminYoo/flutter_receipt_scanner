import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, PlatformException;
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';

void main() => runApp(const ReceiptScannerExampleApp());

/// Asana-inspired design tokens (warm coral productivity canvas). Coral is
/// reserved for the primary action and active selection; chrome stays neutral.
abstract final class _Asana {
  static const coral = Color(0xFFF06A6A);
  static const coralHover = Color(0xFFE5544F);
  static const coralSoft = Color(0xFFFCE8E6);
  static const ink = Color(0xFF1E1F21);
  static const inkMuted = Color(0xFF6D6E6F);
  static const canvas = Color(0xFFFAF9F8);
  static const surface1 = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF6F5F3);
  static const surface3 = Color(0xFFEDECE9);
  static const border = Color(0xFFE4E4E4);
  static const success = Color(0xFF37A66B);
  static const warning = Color(0xFFF1BD6C);
  static const warningInk = Color(0xFF8A5A1B);
  static const error = Color(0xFFE8384F);

  // Color-coding accents for image origin (paired with a text label, never
  // color-only). Muted so many can coexist calmly.
  static const green = Color(0xFF2E7D4F);
  static const greenSoft = Color(0x2662D26F);
  static const blue = Color(0xFF35589E);
  static const blueSoft = Color(0x264573D2);
  static const amber = Color(0xFF8A5A1B);
  static const amberSoft = Color(0x26F1BD6C);
}

/// Demo app exercising every [ScanReceiptOptions] field and rendering the
/// returned images, OCR output, and EXIF metadata.
class ReceiptScannerExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ReceiptScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: _Asana.coral, brightness: Brightness.light).copyWith(
      primary: _Asana.coral,
      onPrimary: Colors.white,
      primaryContainer: _Asana.coralSoft,
      onPrimaryContainer: _Asana.coralHover,
      surface: _Asana.surface1,
      onSurface: _Asana.ink,
      onSurfaceVariant: _Asana.inkMuted,
      surfaceContainerHighest: _Asana.surface2,
      surfaceContainerHigh: _Asana.surface2,
      secondaryContainer: _Asana.surface3,
      onSecondaryContainer: _Asana.inkMuted,
      outline: _Asana.border,
      error: _Asana.error,
    );

    return MaterialApp(
      title: 'Receipt Scanner',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: _Asana.canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: _Asana.canvas,
          foregroundColor: _Asana.ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(color: _Asana.ink, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          color: _Asana.surface1,
          surfaceTintColor: Colors.transparent,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            shape: const StadiumBorder(),
          ),
        ),
        chipTheme: const ChipThemeData(
          selectedColor: _Asana.coralSoft,
          backgroundColor: _Asana.surface2,
          checkmarkColor: _Asana.coralHover,
          side: BorderSide.none,
          shape: StadiumBorder(),
        ),
      ),
      home: const ScanScreen(),
    );
  }
}

/// The option-form screen. Runs a scan and pushes [ResultScreen] with the result.
class ScanScreen extends StatefulWidget {
  /// Creates the scan screen.
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Scan options — each mirrors a ScanReceiptOptions field.
  ScanSource _source = ScanSource.camera;
  bool _ocr = true;
  final TextEditingController _ocrLanguagesController = TextEditingController(text: 'ko-KR, en-US');
  bool _includeExif = true;
  int _maxPages = 1;
  double _quality = 0.82;
  bool _autoRotate = true;
  bool _ocrGeometry = false;
  double _minimumTextHeight = 0;
  bool _includeGpsExif = false;
  bool _includeRawExif = false;
  bool _cropAutoConfirm = false;
  bool _mergeOcrPages = false;

  // OCR-floor gate (a separate `scan(ocrFloor:)` argument, not a native option).
  bool _floorEnabled = true;
  int _floorMinTextLength = 12;
  int _floorMinLines = 2;
  double _floorMinConfidence = 0;

  bool _scanning = false;
  bool _loadingCapabilities = false;
  ({String code, String message})? _error;

  @override
  void dispose() {
    _ocrLanguagesController.dispose();
    super.dispose();
  }

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  bool get _canMergeOcrPages => _source == ScanSource.camera && _ocr && _maxPages >= 2;

  Future<void> _showCapabilities() async {
    // The flag guards the query only — the dialog is modal, so it blocks
    // further taps on its own. Holding the flag across the dialog would leave
    // the button spinning for as long as the dialog stays open.
    setState(() => _loadingCapabilities = true);
    OcrCapabilities? capabilities;
    try {
      capabilities = await getOcrCapabilities();
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.code} - ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _loadingCapabilities = false);
    }

    if (!mounted || capabilities == null) return;
    final resolved = capabilities;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final content = resolved is IosOcrCapabilities
            ? 'iOS Supported Languages:\n${resolved.supportedLanguages.join(', ')}'
            : (resolved as AndroidOcrCapabilities).models.map((m) => '${m.script}: ${m.status.name}').join('\n');
        return AlertDialog(
          title: const Text('OCR Capabilities'),
          content: Text(content),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        );
      },
    );
  }

  Future<void> _runScan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    ScanReceiptResult? result;
    ({String code, String message})? error;
    try {
      result = await scan(
        options: ScanReceiptOptions(
          source: _source,
          ocr: _ocr,
          includeExif: _includeExif,
          includeGpsExif: _includeGpsExif,
          includeRawExif: _includeRawExif,
          maxPages: _maxPages,
          quality: _quality,
          autoRotate: _autoRotate,
          cropAutoConfirm: _cropAutoConfirm,
          minimumTextHeight: _minimumTextHeight,
          ocrGeometry: _ocrGeometry,
          ocrLanguages: _ocr
              ? _ocrLanguagesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
              : const [],
        ),
        ocrFloor: _floorEnabled
            ? OcrFloorOrDisabled.floor(
                OcrFloor(
                  minTextLength: _floorMinTextLength,
                  minLines: _floorMinLines,
                  minConfidence: _floorMinConfidence,
                ),
              )
            : const OcrFloorOrDisabled.disabled(),
        mergeOcrPages: _mergeOcrPages,
      );
    } on PlatformException catch (e) {
      error = (code: e.code, message: e.message ?? '');
    } on Object catch (e) {
      error = (code: 'error', message: '$e');
    }

    if (!mounted) return;
    setState(() {
      _scanning = false;
      _error = error;
    });
    if (result == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(result: result!, source: _source),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Scanner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sourceSection(),
          _basicSection(),
          _precisionSection(),
          _exifSection(),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('scan_button'),
            onPressed: _scanning ? null : _runScan,
            icon: _scanning
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_source == ScanSource.camera ? Icons.photo_camera : Icons.photo_library),
            label: Text(_source == ScanSource.camera ? '카메라로 스캔' : '갤러리에서 가져오기'),
          ),
          if (_error != null) _errorCard(_error!),
        ],
      ),
    );
  }

  // ── Option sections ────────────────────────────────────────────────────────

  Widget _sourceSection() {
    return _Section(
      title: '스캔 방식',
      subtitle: '카메라로 직접 촬영하거나 갤러리에서 영수증 사진을 가져오세요',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ScanSource>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: _Asana.coralSoft,
              selectedForegroundColor: _Asana.coralHover,
              foregroundColor: _Asana.inkMuted,
            ),
            segments: const [
              ButtonSegment(value: ScanSource.camera, label: Text('카메라'), icon: Icon(Icons.photo_camera)),
              ButtonSegment(value: ScanSource.gallery, label: Text('갤러리'), icon: Icon(Icons.photo_library)),
            ],
            selected: {_source},
            onSelectionChanged: (selection) => setState(() {
              _source = selection.first;
              if (_source != ScanSource.camera) _mergeOcrPages = false;
            }),
          ),
          if (_source == ScanSource.gallery) ...[
            const SizedBox(height: 12),
            _InfoBanner(
              _isIOS ? 'iOS: 문서 모서리를 자동 감지하고 드래그 핸들로 원근 보정이 가능합니다' : 'Android: 갤러리에서 영수증 사진을 선택한 뒤 드래그 핸들로 모서리를 보정하세요',
            ),
          ],
        ],
      ),
    );
  }

  Widget _basicSection() {
    return _Section(
      title: '스캔 옵션',
      subtitle: '처리할 데이터와 품질을 설정하세요',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('OCR · 한국어 + 라틴 텍스트 인식'),
            value: _ocr,
            onChanged: (value) => setState(() {
              _ocr = value;
              if (!_ocr) _mergeOcrPages = false;
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _ocrLanguagesController,
              enabled: _ocr,
              decoration: const InputDecoration(
                labelText: 'OCR Languages (BCP 47)',
                hintText: 'e.g., ko-KR, en-US',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              // Disabled while a query is in flight — repeated taps would
              // otherwise stack one dialog per tap.
              onPressed: _loadingCapabilities ? null : _showCapabilities,
              icon: _loadingCapabilities
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.language),
              label: const Text('Check Capabilities'),
            ),
          ),
          SwitchListTile(
            title: const Text('EXIF 메타데이터 포함'),
            value: _includeExif,
            onChanged: (v) => setState(() => _includeExif = v),
          ),
          _Stepper(
            key: const Key('max_pages_stepper'),
            label: '최대 페이지 수 (maxPages)',
            value: _maxPages,
            min: 1,
            max: 10,
            onChanged: (value) => setState(() {
              _maxPages = value;
              if (_maxPages < 2) _mergeOcrPages = false;
            }),
          ),
          SwitchListTile(
            title: const Text('여러 페이지 OCR 이어붙이기 (mergeOcrPages)'),
            subtitle: Text(
              !_ocr
                  ? 'OCR이 켜져 있어야 사용할 수 있습니다'
                  : _source != ScanSource.camera
                  ? '카메라 스캔에서만 사용할 수 있습니다'
                  : _maxPages < 2
                  ? '최대 페이지 수를 2 이상으로 설정하세요'
                  : '촬영 순서대로 OCR 텍스트를 이어붙이고 경계 진단을 반환합니다',
            ),
            value: _mergeOcrPages,
            onChanged: _canMergeOcrPages ? (value) => setState(() => _mergeOcrPages = value) : null,
          ),
          _ChipRow<double>(
            label: 'JPEG 품질 (quality)',
            values: const [0.5, 0.7, 0.82, 0.95, 1],
            selected: _quality,
            format: (v) => v == 0.82 ? '0.82·기본' : v.toStringAsFixed(2),
            onChanged: (v) => setState(() => _quality = v),
          ),
        ],
      ),
    );
  }

  Widget _precisionSection() {
    return _Section(
      title: 'OCR 정밀도',
      subtitle: '회전 보정 · 작은 글자 인식 · 인식 결과 게이트',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('자동 회전 보정 (autoRotate)'),
            subtitle: _ocr ? null : const Text('OCR이 켜져 있어야 적용됩니다'),
            value: _autoRotate,
            onChanged: _ocr ? (v) => setState(() => _autoRotate = v) : null,
          ),
          SwitchListTile(
            title: const Text('줄별 OCR 좌표 (ocrGeometry)'),
            subtitle: Text(_ocr ? '줄 단위 텍스트 박스를 ocrLines로 반환합니다' : 'OCR이 켜져 있어야 적용됩니다'),
            value: _ocrGeometry,
            onChanged: _ocr ? (v) => setState(() => _ocrGeometry = v) : null,
          ),
          _ChipRow<double>(
            label: '최소 텍스트 높이 (minimumTextHeight)',
            badge: 'iOS',
            values: const [0, 0.02, 0.05, 0.1],
            selected: _minimumTextHeight,
            format: (v) => v == 0 ? '기본(1/32)' : v.toStringAsFixed(2),
            hint: !_isIOS
                ? 'Android(ML Kit)에는 대응 항목이 없어 무시됩니다'
                : (!_ocr ? 'OCR이 켜져 있어야 적용됩니다' : '값을 낮추면 작은 글자 인식률이 올라갑니다'),
            onChanged: (_isIOS && _ocr) ? (v) => setState(() => _minimumTextHeight = v) : null,
          ),
          SwitchListTile(
            title: const Text('OCR 최소 기준 (ocrFloor)'),
            subtitle: Text(_ocr ? '기준 미달 이미지는 rejectedImages로 분류됩니다' : 'OCR이 켜져 있어야 적용됩니다'),
            value: _floorEnabled,
            onChanged: _ocr ? (v) => setState(() => _floorEnabled = v) : null,
          ),
          if (_ocr && _floorEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                children: [
                  _Stepper(
                    label: 'minTextLength',
                    value: _floorMinTextLength,
                    min: 0,
                    max: 200,
                    onChanged: (v) => setState(() => _floorMinTextLength = v),
                  ),
                  _Stepper(
                    label: 'minLines',
                    value: _floorMinLines,
                    min: 0,
                    max: 50,
                    onChanged: (v) => setState(() => _floorMinLines = v),
                  ),
                  _ChipRow<double>(
                    label: 'minConfidence',
                    values: const [0, 0.3, 0.5, 0.7],
                    selected: _floorMinConfidence,
                    format: (v) => v == 0 ? '0·off' : v.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _floorMinConfidence = v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _exifSection() {
    return _Section(
      title: 'EXIF & 크롭',
      subtitle: '메타데이터 범위와 크롭 동작',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('GPS EXIF 포함 (includeGpsExif)'),
            subtitle: Text(_includeExif ? '원본에 박힌 GPS만 복사 · 위치 권한 요청 없음' : 'EXIF 포함이 켜져 있어야 적용됩니다'),
            value: _includeGpsExif,
            onChanged: _includeExif ? (v) => setState(() => _includeGpsExif = v) : null,
          ),
          SwitchListTile(
            title: const Text('원본 raw EXIF 포함 (includeRawExif)'),
            subtitle: Text(_includeExif ? '화이트리스트 밖 태그까지 exif.raw로 노출' : 'EXIF 포함이 켜져 있어야 적용됩니다'),
            value: _includeRawExif,
            onChanged: _includeExif ? (v) => setState(() => _includeRawExif = v) : null,
          ),
          SwitchListTile(
            title: const Text('크롭 자동 확정 (cropAutoConfirm)'),
            subtitle: Text(
              _source == ScanSource.gallery ? '문서 감지 신뢰도가 높으면 크롭 편집기를 건너뜁니다 (iOS 전용)' : 'source가 gallery일 때만 적용됩니다',
            ),
            value: _cropAutoConfirm,
            onChanged: _source == ScanSource.gallery ? (v) => setState(() => _cropAutoConfirm = v) : null,
          ),
        ],
      ),
    );
  }

  Widget _errorCard(({String code, String message}) error) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Asana.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Asana.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: _Asana.error),
              const SizedBox(width: 6),
              Text(
                '스캔 오류',
                style: TextStyle(fontWeight: FontWeight.w700, color: _Asana.error),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            error.code,
            style: const TextStyle(fontFamily: 'monospace', color: _Asana.inkMuted),
          ),
          if (error.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(error.message, style: const TextStyle(color: _Asana.inkMuted)),
            ),
        ],
      ),
    );
  }
}

/// The result screen: status summary, per-page image cards, and rejected images.
class ResultScreen extends StatelessWidget {
  /// Creates the result screen for a completed [result].
  const ResultScreen({required this.result, required this.source, super.key});

  /// The scan outcome to render.
  final ScanReceiptResult result;

  /// The source path the scan used, for the section description.
  final ScanSource source;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스캔 결과')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(result),
          if (result.mergedOcr case final mergedOcr?) ...[
            const SizedBox(height: 16),
            _MergedOcrCard(mergedOcr, discardedPageCount: result.discardedPageCount),
          ],
          if (result.images.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              source == ScanSource.gallery ? '갤러리에서 가져와 원근 보정된 이미지' : '카메라 문서 스캐너로 촬영된 이미지',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            for (final (i, img) in result.images.indexed) _ImageCard(image: img, index: i),
          ],
          if (result.rejectedImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '거부된 이미지 (rejectedImages)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text('ocrFloor 기준을 충족하지 못해 images에서 제외된 캡처입니다', style: Theme.of(context).textTheme.bodySmall),
            for (final (i, img) in result.rejectedImages.indexed) _ImageCard(image: img, index: i),
          ],
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.refresh),
            label: const Text('다시 스캔하기'),
          ),
        ],
      ),
    );
  }
}

class _MergedOcrCard extends StatelessWidget {
  const _MergedOcrCard(this.result, {required this.discardedPageCount});

  final MergedOcrResult result;

  /// maxPages 초과로 네이티브에서 폐기된 페이지 수 (iOS에서만 0보다 클 수 있음).
  final int discardedPageCount;

  void _copyText(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result.text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('병합된 OCR 텍스트를 복사했습니다'), duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final unmatchedBoundaries = result.unmatchedBoundaryIndexes.map((index) => '${index + 1}–${index + 2}').join(', ');
    final rejectedPages = result.rejectedPageIndexes.map((index) => '${index + 1}').join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '병합된 OCR',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _Asana.ink),
                  ),
                ),
                Text(
                  result.isComplete ? '완전한 병합' : '확인 필요',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: result.isComplete ? _Asana.success : _Asana.warningInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _MetaRow('페이지 수', '${result.pageUris.length}'),
            if (discardedPageCount > 0) _MetaRow('폐기된 페이지', '$discardedPageCount장 (maxPages 초과로 미처리)'),
            _MetaRow('경계 미확인', unmatchedBoundaries.isEmpty ? '없음' : unmatchedBoundaries),
            _MetaRow('OCR 기준 미달', rejectedPages.isEmpty ? '없음' : rejectedPages),
            _DetailTile(
              title: '이어붙인 텍스트',
              initiallyExpanded: true,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: result.text.isEmpty ? null : () => _copyText(context),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('복사'),
                  ),
                ),
                SelectableText(
                  result.text.isEmpty ? '(인식된 텍스트 없음)' : result.text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _Asana.ink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable pieces ──────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner(this.result);

  final ScanReceiptResult result;

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg, text) = switch (result.status) {
      ScanStatus.success => (
        Icons.check_circle,
        _Asana.success,
        _Asana.success.withValues(alpha: 0.12),
        '스캔 성공 · ${result.images.length}페이지',
      ),
      ScanStatus.rejected => (
        Icons.error_outline,
        _Asana.warningInk,
        _Asana.warning.withValues(alpha: 0.2),
        'OCR 기준 미달 · ${result.rejectedImages.length}페이지 거부됨',
      ),
      ScanStatus.cancelled => (Icons.remove_circle_outline, _Asana.inkMuted, _Asana.surface2, '스캔 취소됨'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: _Asana.ink),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: _Asana.inkMuted)),
            ),
          Card(
            child: Padding(padding: const EdgeInsets.all(8), child: child),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _Asana.coralSoft, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.crop_free, size: 18, color: _Asana.coralHover),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: _Asana.ink)),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton.filledTonal(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center)),
          IconButton.filledTonal(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.format,
    required this.onChanged,
    this.badge,
    this.hint,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) format;
  final ValueChanged<T>? onChanged;
  final String? badge;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(label, style: TextStyle(color: disabled ? theme.disabledColor : _Asana.ink)),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _Asana.surface3, borderRadius: BorderRadius.circular(6)),
                  child: Text(badge!, style: const TextStyle(fontSize: 11, color: _Asana.inkMuted)),
                ),
              ],
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint!, style: theme.textTheme.bodySmall?.copyWith(color: _Asana.inkMuted)),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(format(v)),
                  selected: v == selected,
                  onSelected: disabled ? null : (_) => onChanged!(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An [ExpansionTile] with no divider lines and a soft, rounded content panel
/// that sets its body apart from the surrounding card.
class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.title, required this.children, this.initiallyExpanded = false});

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, color: _Asana.ink),
      ),
      initiallyExpanded: initiallyExpanded,
      // Empty borders remove ExpansionTile's default top/bottom divider lines.
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _Asana.surface2, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }
}

/// Renders one [ReceiptImage] — preview, origin, file info, OCR, and EXIF.
class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.image, required this.index});

  final ReceiptImage image;
  final int index;

  void _copyOcr(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('OCR 텍스트를 복사했습니다'), duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final quality = image.ocrQuality;
    final exif = image.exif;
    final ocrText = image.ocrText?.trim();
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '페이지 ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: _Asana.ink),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(Uri.parse(image.uri).toFilePath()),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 120,
                  child: Center(
                    child: Text('(미리보기를 불러올 수 없습니다)', style: TextStyle(color: _Asana.inkMuted)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('이미지 출처  ', style: TextStyle(color: _Asana.inkMuted)),
                _OriginChip(image.imageOrigin),
              ],
            ),
            _DetailTile(
              title: '파일 정보',
              children: [
                _MetaRow('파일명', image.fileName),
                _MetaRow('해상도', '${image.width} × ${image.height}'),
                _MetaRow('크기', '${(image.fileSize / 1024).toStringAsFixed(1)} KB'),
                _MetaRow('형식', image.mimeType),
              ],
            ),
            if (quality != null)
              _DetailTile(
                title: 'OCR 품질',
                initiallyExpanded: true,
                children: [
                  _MetaRow('글자 수', '${quality.textLength}'),
                  _MetaRow('줄 수', '${quality.lineCount}'),
                  _MetaRow(
                    '신뢰도',
                    quality.confidence == null ? '측정 안 됨' : '${(quality.confidence! * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            if (ocrText != null)
              _DetailTile(
                title: 'OCR 텍스트',
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        onPressed: ocrText.isEmpty ? null : () => _copyOcr(context, ocrText),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('복사'),
                        style: TextButton.styleFrom(
                          foregroundColor: _Asana.coralHover,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  SelectableText(
                    ocrText.isEmpty ? '(인식된 텍스트 없음)' : ocrText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _Asana.ink),
                  ),
                ],
              ),
            if (exif != null) _ExifPart(exif: exif, origin: image.imageOrigin),
          ],
        ),
      ),
    );
  }
}

class _ExifPart extends StatelessWidget {
  const _ExifPart({required this.exif, required this.origin});

  final ReceiptExif exif;
  final ImageOrigin origin;

  @override
  Widget build(BuildContext context) {
    final gps = exif.gps;
    final rows = <Widget>[
      if (exif.dateTimeOriginal != null) _MetaRow('촬영일시', exif.dateTimeOriginal!),
      if (exif.make != null) _MetaRow('제조사', exif.make!),
      if (exif.model != null) _MetaRow('기기 모델', exif.model!),
      if (exif.software != null) _MetaRow('소프트웨어', exif.software!),
      if (exif.orientation != null) _MetaRow('방향 태그', '${exif.orientation}'),
      if (gps != null) _MetaRow('GPS', '${gps.latitude.toStringAsFixed(5)}, ${gps.longitude.toStringAsFixed(5)}'),
    ];
    final raw = exif.raw;
    return _DetailTile(
      title: raw == null ? 'EXIF' : 'EXIF (raw · ${raw.length} keys)',
      children: [
        if (rows.isEmpty)
          Text(
            origin == ImageOrigin.camera ? '스캐너가 원본 EXIF를 내보내지 않아 기기 정보만 합성됩니다' : '추가 EXIF 필드 없음',
            style: const TextStyle(fontSize: 12, color: _Asana.inkMuted),
          )
        else
          ...rows,
        if (raw != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SelectableText(
              '$raw',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: _Asana.inkMuted),
            ),
          ),
      ],
    );
  }
}

class _OriginChip extends StatelessWidget {
  const _OriginChip(this.origin);

  final ImageOrigin origin;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (origin) {
      ImageOrigin.camera => ('카메라', _Asana.green, _Asana.greenSoft),
      ImageOrigin.screenshot => ('스크린샷', _Asana.blue, _Asana.blueSoft),
      ImageOrigin.download => ('다운로드', _Asana.amber, _Asana.amberSoft),
      ImageOrigin.unknown => ('알 수 없음', _Asana.inkMuted, _Asana.surface3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12, color: _Asana.inkMuted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: _Asana.ink)),
          ),
        ],
      ),
    );
  }
}
