import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';

void main() => runApp(const ReceiptScannerExampleApp());

/// Demo app exercising every [ScanReceiptOptions] field and rendering the
/// returned images, OCR output, and EXIF metadata.
class ReceiptScannerExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ReceiptScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Receipt Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3B5BFE), useMaterial3: true),
      home: const ScanScreen(),
    );
  }
}

/// The single demo screen: scan-option controls on top, results below.
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
  bool _includeExif = true;
  int _maxPages = 1;
  double _quality = 0.82;
  bool _autoRotate = true;
  double _minimumTextHeight = 0;
  bool _includeGpsExif = false;
  bool _includeRawExif = false;
  bool _cropAutoConfirm = false;

  // OCR-floor gate (a separate `scan(ocrFloor:)` argument, not a native option).
  bool _floorEnabled = true;
  int _floorMinTextLength = 12;
  int _floorMinLines = 2;
  double _floorMinConfidence = 0;

  bool _scanning = false;
  ScanReceiptResult? _result;
  ({String code, String message})? _error;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _runScan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await scan(
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
      );
      if (mounted) setState(() => _result = result);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = (code: e.code, message: e.message ?? ''));
    } on Object catch (e) {
      if (mounted) setState(() => _error = (code: 'error', message: '$e'));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
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
            onPressed: _scanning ? null : _runScan,
            icon: _scanning
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_source == ScanSource.camera ? Icons.photo_camera : Icons.photo_library),
            label: Text(_source == ScanSource.camera ? '카메라로 스캔' : '갤러리에서 가져오기'),
          ),
          if (_error != null) _errorCard(_error!),
          if (_result != null && _error == null) ..._resultSection(_result!),
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
            segments: const [
              ButtonSegment(value: ScanSource.camera, label: Text('카메라'), icon: Icon(Icons.photo_camera)),
              ButtonSegment(value: ScanSource.gallery, label: Text('갤러리'), icon: Icon(Icons.photo_library)),
            ],
            selected: {_source},
            onSelectionChanged: (s) => setState(() => _source = s.first),
          ),
          if (_source == ScanSource.gallery) ...[
            const SizedBox(height: 12),
            _InfoBanner(
              _isIOS
                  ? '📐 iOS: 문서 모서리를 자동 감지하고 드래그 핸들로 원근 보정이 가능합니다'
                  : '📷 Android: 갤러리에서 영수증 사진을 선택한 뒤 드래그 핸들로 모서리를 보정하세요',
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
            title: const Text('OCR — 한국어 + 라틴 텍스트 인식'),
            value: _ocr,
            onChanged: (v) => setState(() => _ocr = v),
          ),
          SwitchListTile(
            title: const Text('EXIF 메타데이터 포함'),
            value: _includeExif,
            onChanged: (v) => setState(() => _includeExif = v),
          ),
          _Stepper(
            label: '최대 페이지 수 (maxPages)',
            value: _maxPages,
            min: 1,
            max: 10,
            onChanged: (v) => setState(() => _maxPages = v),
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
            subtitle: Text(_includeExif ? '원본에 박힌 GPS만 복사 — 위치 권한 요청 없음' : 'EXIF 포함이 켜져 있어야 적용됩니다'),
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

  // ── Result ─────────────────────────────────────────────────────────────────

  List<Widget> _resultSection(ScanReceiptResult result) {
    final warn = result.status != ScanStatus.success;
    return [
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: warn ? Colors.orange.shade100 : Colors.green.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _statusSummary(result),
          style: TextStyle(fontWeight: FontWeight.w600, color: warn ? Colors.orange.shade900 : Colors.green.shade900),
        ),
      ),
      for (final (i, img) in result.images.indexed) _ImageCard(image: img, index: i),
      if (result.rejectedImages.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('거부된 이미지 (rejectedImages)', style: Theme.of(context).textTheme.titleMedium),
        for (final (i, img) in result.rejectedImages.indexed) _ImageCard(image: img, index: i),
      ],
    ];
  }

  Widget _errorCard(({String code, String message}) error) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '스캔 오류',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade900),
          ),
          const SizedBox(height: 4),
          Text(
            error.code,
            style: TextStyle(fontFamily: 'monospace', color: Colors.red.shade700),
          ),
          if (error.message.isNotEmpty) Text(error.message, style: TextStyle(color: Colors.red.shade700)),
        ],
      ),
    );
  }

  String _statusSummary(ScanReceiptResult result) {
    switch (result.status) {
      case ScanStatus.success:
        return '✅ 스캔 성공 — ${result.images.length}페이지';
      case ScanStatus.rejected:
        return '⚠️ OCR 기준 미달 — ${result.rejectedImages.length}페이지 거부됨';
      case ScanStatus.cancelled:
        return '⚪ 스캔 취소됨';
    }
  }
}

// ── Reusable pieces ──────────────────────────────────────────────────────────

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
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(subtitle!, style: theme.textTheme.bodySmall),
            ),
          Card(
            margin: EdgeInsets.zero,
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
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
                child: Text(label, style: TextStyle(color: disabled ? theme.disabledColor : null)),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge!, style: theme.textTheme.labelSmall),
                ),
              ],
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint!, style: theme.textTheme.bodySmall),
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

/// Renders one [ReceiptImage] — preview, origin, file info, OCR, and EXIF.
class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.image, required this.index});

  final ReceiptImage image;
  final int index;

  @override
  Widget build(BuildContext context) {
    final quality = image.ocrQuality;
    final exif = image.exif;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('페이지 ${index + 1}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(Uri.parse(image.uri).toFilePath()),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(height: 120, child: Center(child: Text('(미리보기를 불러올 수 없습니다)'))),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [const Text('이미지 출처  '), _OriginChip(image.imageOrigin)]),
            ExpansionTile(
              title: const Text('파일 정보'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                _MetaRow('파일명', image.fileName),
                _MetaRow('해상도', '${image.width} × ${image.height}'),
                _MetaRow('크기', '${(image.fileSize / 1024).toStringAsFixed(1)} KB'),
                _MetaRow('형식', image.mimeType),
              ],
            ),
            if (quality != null)
              ExpansionTile(
                title: const Text('OCR 품질'),
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  _MetaRow('글자 수', '${quality.textLength}'),
                  _MetaRow('줄 수', '${quality.lineCount}'),
                  _MetaRow(
                    '신뢰도',
                    quality.confidence == null ? '—' : '${(quality.confidence! * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            if (image.ocrText != null)
              ExpansionTile(
                title: const Text('OCR 텍스트'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      image.ocrText!.trim().isEmpty ? '(인식된 텍스트 없음)' : image.ocrText!.trim(),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
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
    return ExpansionTile(
      title: Text(raw == null ? 'EXIF' : 'EXIF (raw · ${raw.length} keys)'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        if (rows.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              origin == ImageOrigin.camera ? '스캐너가 원본 EXIF를 내보내지 않아 기기 정보만 합성됩니다' : '추가 EXIF 필드 없음',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ...rows,
        if (raw != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text('$raw', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
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
    final (label, color) = switch (origin) {
      ImageOrigin.camera => ('카메라', Colors.green),
      ImageOrigin.screenshot => ('스크린샷', Colors.blue),
      ImageOrigin.download => ('다운로드', Colors.orange),
      ImageOrigin.unknown => ('알 수 없음', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color.shade800, fontSize: 12)),
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
          SizedBox(width: 80, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
