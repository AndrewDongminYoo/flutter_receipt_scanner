# Native Port Map — RN receipt-scanner → Flutter federated plugin

**Date:** 2026-07-11
**Author:** research phase (faithful port; IP cleared, operator owns both repos — personal account AndrewDongminYoo)
**Source of truth:** the RN native code in `react-native-receipt-scanner` (iOS Obj-C++ / Android Kotlin).
**Target:** `flutter_receipt_scanner` federated plugin, driven by Pigeon `ReceiptScannerApi.scan(options)` (`@async`).

## 0. How to read this document

For every feature below: (a) the algorithm as implemented in RN, (b) framework APIs, (c) which Pigeon `ScanOptions` fields drive it and which `ScanResult` / `ReceiptImage` / `ReceiptExif` fields it fills, (d) iOS↔Android asymmetries, (e) ADR gotchas.

**The RN _code_ is authoritative — the RN _docs_ have drifted in three places.** Where a doc and the code disagree, implement the code and I flag the drift inline with **[DOC DRIFT]**.

### 0.1 Pigeon boundary contract (read first — differs from RN's JS envelope)

The RN JS layer (`scan.tsx`) owns the OCR-floor acceptance gate and the quality derivation. In the Flutter port the _app-facing Dart package_ already owns those. Therefore the **native** side must behave exactly like the RN native side did (which also did not floor-gate):

- **`ScanResult.status` from native is only `success` or `cancelled`. Never emit `rejected`.** The Dart layer applies the floor and re-partitions into `images` / `rejectedImages`.
- **`ScanResult.rejectedImages` is always an empty list from native** (the Pigeon field is non-null; send `[]`). All processed captures go into `images`.
- **`OcrQuality`: native fills `confidence` only.** Leave `textLength` and `lineCount` null — Dart derives them from `ocrText`. (RN native sent `ocrQuality = {confidence}` and JS re-derived the other two; mirror that.)
- **`ReceiptImage.imageOrigin` is always present** (non-null in schema). `exif`, `ocrText`, `ocrQuality` are conditional on options.
- Errors: RN rejected the Promise with codes (`SCAN_IN_PROGRESS`, `NO_ACTIVITY`, `NOT_SUPPORTED`/`SCANNER_INIT_FAILED`, `PROCESSING_FAILED`, `OUT_OF_MEMORY`). In Pigeon, fail the completion with `PigeonError`/`FlutterError` using the same codes.
- **Do NOT port the RN "module name string must match across 3 files" rule** — Pigeon generates channel names. Not applicable.
- `ReceiptExif.raw` is `Map<String, Object?>`. iOS forwards String/Number/Array values; Android forwards all-String. The map type holds both — keep the platform difference, do not coerce.

### 0.2 Target scaffolding anchors (where `scan()` lands today)

- **iOS:** `ReceiptScannerApiImpl.swift` (`ReceiptScannerApiImpl: NSObject, ReceiptScannerApi`), registered by `FlutterReceiptScannerPlugin.register(with:)` which retains `apiImpl` statically. Camera path is already sketched (camera-only, no EXIF, no rotation, no gallery). Extend this class; add per-flow delegate objects held with strong refs (see §Async-lifecycle risk).
- **Android:** `FlutterReceiptScannerPlugin.kt` — currently `scan()` returns `unimplemented` and the class is **not** `ActivityAware`. The port must make it (or a delegate it owns) implement `ActivityAware` + `PluginRegistry.ActivityResultListener` to receive the GMS scanner and `CropEditorActivity` results. This is the single biggest structural change from the skeleton.
- Pigeon schema: `flutter_receipt_scanner/pigeons/messages.dart`. Enums `ScanSource{camera,gallery}`, `ImageOrigin{camera,screenshot,download,unknown}`, `ScanStatus{success,cancelled,rejected}`.

---

## 1. Camera path

### 1.1 iOS (`RNDocumentCameraDelegate.m`, entry `ReceiptScanner.mm`)

**Algorithm**

1. `scan()` runs on `DispatchQueue.main`. Guard: if a scan delegate is already retained, reject `SCAN_IN_PROGRESS`. Resolve the presenting VC (skeleton already has `topViewController()`); if none → reject `NO_ACTIVITY`.
2. If `!VNDocumentCameraViewController.isSupported` → reject `NOT_SUPPORTED`.
3. Present `VNDocumentCameraViewController` full-screen, delegate = a retained `RNDocumentCameraDelegate`.
4. On `didFinishWith scan:` — dismiss, then hop to a **global background queue**:
   - `deletePreviousSessionFiles()` (temp lifecycle, §3).
   - `limit = min(scan.pageCount, maxPages)`. Loop `0..<limit`:
     - `page = scan.imageOfPage(at:i)`; `normalized = normalizeOrientation(page)` (§3).
     - If `ocr`: run `recognizeAndDetectRotationInImage:` on the normalized UIImage → `{text, rotationDegrees, meanConfidence}` (§5, §6). **OCR runs before JPEG encode.**
     - If `autoRotate && rotationDegrees != 0`: `cgImageByRotating:degrees:` the CGImage (bakes rotation into pixels).
     - `processImage:` with `sourceRef:NULL` (VisionKit exposes no source EXIF) → EXIF is **synthesized** from device (§4). `includeGpsExif:NO` on camera path always.
     - Build `ReceiptImage` with `imageOrigin = camera`.
   - If all pages failed and `limit>0` → reject `PROCESSING_FAILED`; else resolve `{status:success, images}` back on main queue.
5. `didCancel` → resolve `{status:cancelled, images:[]}`. `didFailWithError` → reject `CAMERA_FAILED`.

**Framework APIs:** `VisionKit.VNDocumentCameraViewController`, `VNDocumentCameraScan.imageOfPage(at:)`.

**Options consumed:** `maxPages` (page cap), `quality`, `ocr`, `autoRotate`, `includeExif`, `includeRawExif`, `minimumTextHeight`. **Fills:** `uri,width,height,fileName,mimeType,fileSize,imageOrigin=camera`, optional `ocrText/ocrQuality.confidence/exif`.

### 1.2 Android (`ReceiptScannerModule.kt` camera branch)

**Algorithm**

1. Guard `pendingPromise != null` → reject `SCAN_IN_PROGRESS`. Resolve `currentActivity` or reject `NO_ACTIVITY`. Parse options, `executor.execute { deletePreviousSessionFiles() }`, store `pendingPromise`/`pendingOptions`.
2. Build `GmsDocumentScannerOptions`: `.setGalleryImportAllowed(false)` (critical — see ADR-005; in-camera gallery import goes through GMS which strips EXIF and collapses origin to unknown), `.setPageLimit(maxPages)`, `RESULT_FORMAT_JPEG`, `SCANNER_MODE_FULL`.
3. `GmsDocumentScanning.getClient(...).getStartScanIntent(activity)` → on success `activity.startIntentSenderForResult(intentSender, SCAN_REQUEST_CODE, …)`; on failure reject `SCANNER_INIT_FAILED` (special-case `GmsNetworkStack`/`AuthPII` messages → friendly Play-Services text).
4. `onActivityResult(SCAN_REQUEST_CODE)` → `handleCameraResult`: `RESULT_CANCELED` → `buildCancelled()`; else parse `GmsDocumentScanningResult.fromActivityResultIntent(data)`, iterate `.pages`. On the single-thread `executor`:
   - `imageProcessor.process(page.imageUri, quality, includeExif, includeGpsExif, includeRawExif, synthesizeDeviceInfo = true)` (§3/§4).
   - `runOcr(...)` on the encoded file (§5) — **OCR runs after encode** on Android.
   - `applyAutoRotateIfNeeded(file, rotationDegrees, autoRotate, quality)` → rotates file in place (§6).
   - `writeExifToFile(file, exifData)` — **must run last** (§4.3).
   - `ResultBuilder.buildImage(..., imageOrigin = "camera", confidence)`.
   - Close the shared `OcrProcessor`; resolve `buildSuccess(images)`.

**Framework APIs:** `com.google.android.gms:play-services-mlkit-document-scanner:16.0.0` (`GmsDocumentScanner`, `GmsDocumentScanningResult`), `startIntentSenderForResult`.

**Options consumed:** same as iOS except `minimumTextHeight` is **ignored** (ML Kit has no equivalent) and `cropAutoConfirm` is irrelevant to camera.

### 1.3 Asymmetries / gotchas

- **maxPages** is a page-count cap on both (GMS `setPageLimit` vs iOS `min(pageCount, maxPages)`).
- iOS OCRs the in-memory CGImage before encoding; Android OCRs the written JPEG file. Same user-visible result, different order (platform-asymmetries §2.4).
- Camera EXIF is synthesized on both because the scanner re-encodes and drops source EXIF (§4.2).
- **Flutter porting note:** the GMS `startIntentSenderForResult` result arrives via the _Activity result listener_, so the plugin must be `ActivityAware`. Hold the Pigeon `callback` across the round trip in a `pendingCallback` field (mirror `pendingPromise`).

---

## 2. Gallery path + custom crop editor

Both platforms: system photo picker → detect a document quad → present a 4-handle crop editor (unless auto-confirmed on iOS) → perspective-correct → process. **`source: "gallery"` never uses the platform document scanner.**

### 2.1 iOS (`RNGalleryPickerDelegate.m` + `RNCropEditorViewController.m`)

**Picker & auth**

- If `PHPhotoLibrary.authorizationStatus == notDetermined`, request authorization (only to populate `PHPickerResult.assetIdentifier` for origin detection — the picker itself works without it). Present `PHPickerViewController`:
  - `config.filter = imagesFilter`, `config.selectionLimit = maxPages`.
  - If authorized/limited: init config `initWithPhotoLibrary:` so `assetIdentifier` is populated.

**Per-photo serialization (ADR / AGENTS.md anti-pattern — load-bearing)**

- `didFinishPicking` with 0 results → `cancelled`. Else dismiss, `deletePreviousSessionFiles`, then process **one photo at a time** via `queuedItems`+`queueIndex`+`processNextQueuedItem`. **Never** fan out N `present` calls in a for-loop — UIKit silently rejects all but the first, and the rejected editors' completion blocks never fire → the Promise hangs forever. Chain the next item from inside `didFinishOneItem:`.

**Per item**

1. `earlyOrigin = originForPickerResult(item)` — synchronous `PHAsset` fetch; returns `screenshot` if `mediaSubtypes & PHAssetMediaSubtypePhotoScreenshot`, else nil (§7).
2. `loadDataRepresentationForTypeIdentifier: UTTypeImage` → `NSData`. Wrap `CGImageSourceCreateWithData` in an ARC holder (`RNCGImageSourceHolder`) so every early-return path releases it. `UIImage imageWithData:`.
3. `detectCornersForImage:` (§2.3). If `cropAutoConfirm && corners && confidence >= 0.85` → skip editor, `applyCropAndFinishImage:` directly on the background thread.
4. Otherwise present `RNCropEditorViewController` (main queue) seeded with the detected corners (or nil → 10% inset default). On confirm the editor renders the crop on a background thread and calls back with a `CGImageRef`; on cancel → nil → skip this photo, continue batch.
5. `processAndFinishCGImage:` — OCR (before encode), optional rotate, `processImage:` with the real `sourceHolder.ref` (real source EXIF), `includeGpsExif` honored. Determine `imageOrigin` (§7). Append result, continue queue.

**Crop editor (`RNCropEditorViewController`) — ADR-004 constraints MUST port verbatim (they fail only on real devices):**

- Corners kept in **CIImage coords** (origin bottom-left, Y up). Detected corners are expanded by `kDetectedCropExpansionFactor = 1.12` about their centroid, then clamped to image size. No detection → 10% inset quad.
- **`UIButton` + `UIControlEventTouchUpInside`, never `UIBarButtonItem`** (target-action silently fails in modal RN paths).
- Button bar anchored to **`view.bottomAnchor constant:-34`**, NOT `safeAreaLayoutGuide.bottomAnchor` (safe-area guide can report 0 → bar lands in the home-indicator gesture zone). The `-34` is specifically the Face-ID home-indicator zone height.
- **Add the 4 handle views BEFORE the button bar in `viewDidLoad`** — UIKit hit-tests subviews in reverse; the bar must be last so it wins taps near the image bottom.
- Handle radius 16, drag clamps to the fitted `imageRectInView`, `CAShapeLayer` overlay draws the quad. Coordinate conversion `viewPointFromCIPoint`/`ciPointFromViewPoint` accounts for aspect-fit letterboxing.
- Confirm dismisses immediately, then renders `perspectiveCorrectedCGImage:corners:` on a background queue.
- Localized strings: `RNReceiptScanner_cropInstruction` / `_cancelButton` / `_confirmButton` (defaults "Drag the corners to frame the document" / "Cancel" / "Use Photo").

**Framework APIs:** `PhotosUI.PHPickerViewController`, `Photos.PHAsset`, `Vision` (`VNDetectDocumentSegmentationRequest`, `VNDetectRectanglesRequest`), `CoreImage.CIPerspectiveCorrection`, `UIKit`, `UniformTypeIdentifiers`.

### 2.2 Android (`CropEditorActivity.kt` + `QuadCropView.kt`, dispatched by `ReceiptScannerModule.handleGalleryResult`)

**Flow**

1. Module starts `CropEditorActivity` via `startActivityForResult(GALLERY_REQUEST_CODE)`, passing `EXTRA_MAX_IMAGES = maxPages`.
2. Activity opens the **system photo picker** via `ActivityResultContracts.PickVisualMedia` (maxImages==1) or `PickMultipleVisualMedia(maxImages)`. Launched from `onPostResume` guarded by `galleryPickerLaunched`.
3. Empty pick → `RESULT_CANCELED`, finish. Else enqueue URIs (`pendingUris`), build the crop UI once (`hasBuiltUI`), then `loadNextImage()` sequentially.
4. Per image: decode sampled (`decodeBitmapSampled`, `PREVIEW_MAX_DIM=2048`) → `applyExifRotation` → fit-center into the `ImageView`. `originalWidth/Height = oriented.dims * sample` (full-res space). Seed `QuadCropView` with the 10% inset (`DEFAULT_INSET_FRACTION=0.1`), then `detectCornersFromText` (§2.3) updates the quad if it finds one.
5. Confirm (`onConfirmTapped`): read corners via `getCornersInImageSpace(...)` → full-res pixels. Copy the picked bytes to a `receipt_pick_<ts>_<i>.jpg` cache file (the picker URI permission expires when the activity finishes). Store `(cachedFileUri, corners)`. `loadNextImage()`; when queue empties, `returnAllResults()` packs `EXTRA_ORIGINAL_URIS: String[]` + `EXTRA_ALL_CORNERS: FloatArray[8×N]` and `setResult(RESULT_OK)`.
6. `handleGalleryResult` in the module: for each `(uriStr, corners8)` on the executor:
   - `imageProcessor.processGallery(uri, corners, quality, includeExif, includeGpsExif, includeRawExif)` — re-decodes at `GALLERY_MAX_DIM=3072`, re-applies EXIF rotation, **scales corners by `1/sample`** to match the decoded bitmap, perspective-corrects, encodes JPEG, reads EXIF (forced `orientation=NORMAL`) (§3/§4).
   - `inferOrigin(uri, exifData)` (§7); `runOcr`; `applyAutoRotateIfNeeded`; `writeExifToFile` (last); `buildImage`.
   - `buildSuccess`. Wrap in `try/catch(OutOfMemoryError)` → reject `OUT_OF_MEMORY`.

**Crop view (`QuadCropView`)** — deliberately mirrors iOS: handle radius 16dp, touch radius 40dp, accent `0xFF007AFF`, fill accent@0x33, stroke accent@0xE6. Corner order fixed `tl[0],tr[1],br[2],bl[3]`. `userHasAdjusted` gate: once the user drags a handle, late-arriving auto-detection (`setCorners`) is ignored so it can't overwrite manual work; `resetUserAdjusted()` on image transition. `getCornersInImageSpace` maps view→full-res by `originalW/displayW`, `originalH/displayH`.

**Framework APIs:** `androidx.activity` PhotoPicker contracts, ML Kit Korean recognizer (corner detection), `android.graphics.Matrix.setPolyToPoly` (perspective), `androidx.exifinterface`.

### 2.3 Quad detection (both platforms) + distortion backstop

- **iOS `detectCornersForImage:`** runs both `VNDetectDocumentSegmentationRequest` (preferred, no `minimumConfidence` knob) and `VNDetectRectanglesRequest` (`minimumConfidence=0.5`, `maximumObservations=1`, `quadratureTolerance=45`). **Critical:** build the handler with `initWithCGImage:orientation:` (explicit `CGImagePropertyOrientation` from `image.imageOrientation`), NOT `initWithCIImage:` (which ignores the orientation transform and returns landscape coords for portrait images → quad mismatch). Prefer doc-seg if `confidence >= kDetectionMinConfidence(0.1)` (floors out the ~0.004 "gap above receipt in a screenshot" false latch); else the rectangle obs (already floored at 0.5). Corners scaled by image W/H into CIImage space. If `RNQuadGeometry.isDistorted` → discard (reset confidence to 0), editor uses inset default.
- **Android `quadFromTextBlocks`** (in `CropEditorActivity`, ML Kit `KoreanTextRecognizerOptions`): collect `TextBlock.cornerPoints`; need ≥8 points (≥2 blocks). From the centroid, pick the furthest point in each of 4 angular sectors (atan2, y-down: TL/TR/BR/BL). Map bitmap→display coords, expand by `1.12`, clamp. If `QuadGeometry.isDistorted` → null → keep inset default.
- **Distortion backstop (`RNQuadGeometry` / `QuadGeometry`, identical logic):** `isDistorted` true if not 4 corners, all-zero edges, **non-convex** (cross-product sign flips across the 4 vertices), OR opposite-edge ratio `max/min > MAX_EDGE_RATIO(2.2)` on either width pair or height pair. Keep `2.2` **identical on both platforms** (PROVISIONAL). When distorted: iOS crops the axis-aligned bbox (no warp); Android `boundingBoxCrop`. `MIN_EDGE_FRACTION` was removed — do not reintroduce.

### 2.4 `cropAutoConfirm`

- **iOS gallery only** (`kCropAutoConfirmMinConfidence = 0.85`). When enabled and detection confidence ≥ 0.85, skip the editor and apply detected corners directly.
- **Android ignores `cropAutoConfirm`** entirely (platform-asymmetries §4.1) — the editor is always shown. Intended asymmetry. In Pigeon `ScanOptions.cropAutoConfirm` is present but the Android impl must not act on it.

### 2.5 Perspective correction detail

- **iOS `perspectiveCorrectedCGImage:`** — ADR-004: build `CIImage initWithCGImage:` then `imageByApplyingOrientation:` **first** (bake orientation), defensively translate extent to (0,0), then `CIPerspectiveCorrection` with the 4 CIVectors. Do NOT use `initWithImage:` straight into the filter (lazy orientation → filter sees raw landscape pixels). **Allocate a fresh `CIContext` per call** (not thread-safe under `maxPages>1`). Distorted → axis-aligned bbox crop instead.
- **Android `perspectiveCorrectedBitmap`** — `Matrix.setPolyToPoly(srcCorners, dst, 4)` where `dst` is a `outW×outH` rect (`outW=(topW+botW)/2`, `outH=(leftH+rightH)/2`), draw via `Canvas.drawBitmap(bitmap, matrix, Paint(FILTER_BITMAP_FLAG))`. Distorted → `boundingBoxCrop`.

---

## 3. Image processing: orientation, JPEG recompress, temp files

### 3.1 Orientation normalization to Up(1)

- **iOS `normalizeOrientation:`** — if `imageOrientation != Up`, redraw through `UIGraphicsImageRenderer` so pixels become upright; output always encodes `kCGImagePropertyOrientation = Up`. `processImage:` also sets TIFF `Orientation = Up` in any forwarded EXIF. **JS/Dart always sees `exif.orientation == 1`.**
- **Android `applyExifRotation`** — reads source `TAG_ORIENTATION`, applies the matching `Matrix` rotate/flip (handles ROTATE_90/180/270, FLIP_H/V, TRANSPOSE, TRANSVERSE), recycles the source. Gallery path forces `exifData.copy(orientation = ORIENTATION_NORMAL)`. Camera path forwards source EXIF orientation (GMS normally already normalized). `writeExifToFile` writes `ORIENTATION_NORMAL` to the output file.

### 3.2 JPEG recompression at `quality`

- **iOS:** `CGImageDestinationCreateWithURL` + `kCGImageDestinationLossyCompressionQuality = quality` (0.0–1.0 directly). **Use `CGImageDestination`, never `UIImageJPEGRepresentation`** (strips EXIF/TIFF dictionaries — ADR-004).
- **Android:** `Bitmap.compress(JPEG, (quality*100).toInt().coerceIn(1,100), out)`.

### 3.3 Output naming + temp lifecycle

- **iOS filename:** `receipt_<epochMillis>_<8charUUID>.jpg` in `NSCachesDirectory`. `uri = fileURL.absoluteString` (percent-encoded — never manually concat `"file://"+path`, breaks on spaces/non-ASCII usernames).
- **Android filename:** `receipt_<System.currentTimeMillis()>.jpg` in `context.cacheDir`. `uri = "file://" + file.absolutePath`. (Gallery picker copies are `receipt_pick_<ts>_<i>.jpg`.)
- **Lifecycle:** at the **start of each `scan()`** call `deletePreviousSessionFiles()` — deletes `receipt_*.jpg` in the cache dir. URIs are stable until the next `scan()` and do **not** survive app restarts (OS clears cache). Document this contract to Dart consumers unchanged.
- **Flutter note:** iOS uses `FileManager.temporaryDirectory` in the current skeleton but RN used `NSCachesDirectory`. Pick one and keep the `deletePreviousSessionFiles` prefix-sweep consistent with it. Android should use `cacheDir`.

---

## 4. EXIF extraction

### 4.1 White-list fields → `ReceiptExif`

Both platforms fill the same normalized white-list (Pigeon `ReceiptExif`): `orientation`(always 1), `colorSpace`, `lightSource`, `exifVersion`, `make`, `model`, `software`, `dateTime`, `dateTimeOriginal`, `dateTimeDigitized`, `exposureTime`(seconds), `fNumber`, `iso`(single number), `focalLength`, `flash`, `whiteBalance`, `exposureMode`, `exposureProgram`, `meteringMode`, `gps`, `raw`.

- **iOS `buildExifDict:`** reads ImageIO `CGImageSourceCopyPropertiesAtIndex` dictionaries: EXIF dict for timestamps/camera-settings, **TIFF dict for `make`/`model`/`software`** (`kCGImagePropertyTIFFSoftware` — iOS has NO `kCGImagePropertyExifSoftware`, platform-asymmetries §1.4), `dateTime` from TIFF. ISO: `kCGImagePropertyExifISOSpeedRatings` is an `NSArray` → take first element (normalize to single number, §1.3). `exifVersion` may be NSString or array of digits → coerce to string.
- **Android `readExif`** via `androidx.exifinterface.media.ExifInterface`: `TAG_*` getters; ISO from `TAG_ISO_SPEED ?: TAG_PHOTOGRAPHIC_SENSITIVITY`; numeric getters use NaN/MIN sentinels → null. `orientation` reported as the source value unless gallery (forced NORMAL); output is always upright.

### 4.2 Camera EXIF synthesis (source EXIF absent)

The document scanners re-encode and drop original EXIF, so both synthesize minimal device info **only for camera captures**:

- **iOS `buildDeviceExifDict`** (when `sourceRef==NULL`): `make="Apple"`, `model=UIDevice.model`, `orientation=1`, `dateTimeOriginal=now` (`yyyy:MM:dd HH:mm:ss`).
- **Android** (`synthesizeDeviceInfo=true`): `make ?: Build.MANUFACTURER`, `model ?: Build.MODEL`, `dateTimeOriginal ?: now`. **Gallery path passes `false`** so imports honestly report null rather than inheriting the device identity.

### 4.3 Raw passthrough (`includeRawExif`) and output-file EXIF

- **iOS `flattenRaw`** — flat map keyed by standard tag names; skips binary/dict values and a deny-set (`MakerNote`, `UserComment`, `ComponentsConfiguration`, `FileSource`, `SceneType`, `InteroperabilityIndex`). GPS keys get a `"GPS"` prefix added so both platforms agree (§1.5); GPS excluded unless `includeGpsExif`.
- **Android `buildRawExifMap`** — reflects all `ExifInterface.TAG_*` string constants; deny-set (`JPEGInterchangeFormat*`, `Thumbnail*`, `MakerNote`, `UserComment`); GPS-prefixed tags skipped unless `includeGps`. **All values are strings** (iOS keeps numeric/array). `Map<String,Object?>` accommodates both.
- **[DOC DRIFT — platform-asymmetries §1.1]** says Android does not write EXIF to the output JPEG (framed as deferred D11). **The current code DOES:** `writeExifToFile` runs in both camera and gallery paths so server-side file readers see EXIF, parity with iOS's `CGImageDestinationAddImage`. Caveat: `writeExifToFile` writes only a **subset** (`ORIENTATION_NORMAL`, make/model/software, dateTime×3, GPS lat/lng/altitude) — the on-disk file has fewer tags than the returned Pigeon `exif` object. **It MUST run after any autoRotate re-compress**, or a later compress strips the tags.

### 4.4 GPS (`includeGpsExif`)

- Only copies GPS already embedded in the source; **no `CLLocationManager` / no location permission**. `gps` = `{latitude, longitude, altitude?, timestamp?, speed?, heading?}`, lat/long signed decimals.
- **Camera-path hardcode asymmetry (faithful-port note):** iOS `handleCamera` calls `processImage:` with `includeGpsExif:NO` hardcoded, whereas Android's `handleCameraResult` passes `scanOptions.includeGpsExif` through. Output is identical (the document scanners strip source EXIF, so no GPS survives either way), but keep the difference as-is rather than "fixing" one side — it is behavior-neutral.
- **iOS:** `kCGImagePropertyGPS*`; apply S/W ref → negative; altitude ref==1 → negative; heading from `GPSImgDirection ?: GPSDestBearing`. Also copies the raw GPS dict onto the output file when `includeGpsExif`.
- **Android:** `exif.getLatLong`, `getAltitude`, `TAG_GPS_TIMESTAMP`, `TAG_GPS_SPEED`, heading `TAG_GPS_IMG_DIRECTION ?: TAG_GPS_DEST_BEARING`.

### 4.5 `orientation` is always 1

Both output pixels are orientation-normalized and both report `exif.orientation == 1`. The original value survives only in `raw.Orientation` (iOS) — Android's raw map likewise carries the source `Orientation` string when raw is enabled. Consumers must not treat `orientation` as the source value.

---

## 5. OCR (raw text + confidence)

### 5.1 iOS (`RNOcrProcessor.m`)

- `VNRecognizeTextRequest`, `recognitionLanguages = ["ko-KR","en-US"]`, `usesLanguageCorrection = NO` (prices/codes are not dictionary words). `minimumTextHeight = caller value if >0 else 1/32` (`kReceiptMinTextHeight`). **`minimumTextHeight` is iOS-only** (`ScanOptions.minimumTextHeight`); Android ignores it.
- Text = join `topCandidates(1).string` per observation with `\n`.
- `confidence` = mean of `topCandidates(1).confidence` across observations → `OcrQuality.confidence`.
- **[NOTE — current skeleton]** `ReceiptScannerApiImpl.recognizeText` sets `usesLanguageCorrection = true` and skips rotation detection. The faithful port must set it to **`false`** and route through the rotation-detecting entry (§6).

### 5.2 Android (`OcrProcessor.kt`)

- `TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())` — Korean model covers Latin too (ADR-006), so no separate Latin recognizer. **Must `close()`** the client once per scan after all pages (releases the ML Kit client).
- Text = `Text.text`. `lineCount = textBlocks.sumOf { lines.size }`.
- `confidence` = mean of `line.confidence` over all lines (NaN skipped) → `OcrQuality.confidence`. **[DOC DRIFT — platform-asymmetries §2.2]** claims Android confidence is always absent / iOS-only. **False in current code** — `meanLineConfidence` computes it from the _bundled_ Korean recognizer and `ResultBuilder` emits it; `types.ts` confirms "both platforms". Confidence is populated on **both**.
- Threading: every method blocks on `Tasks.await` → **background thread only** (the module's single-thread executor).

### 5.3 Fills

`ReceiptImage.ocrText` (present only when `ocr` and text non-empty), `OcrQuality.confidence` (both platforms). `textLength`/`lineCount` left null for Dart to derive.

---

## 6. autoRotate (OCR-confidence / geometry-based rotation)

Two **deliberately different** algorithms — do not unify. `autoRotate` only bakes pixels when `ocr==true` and a non-zero rotation was detected; when `autoRotate==false`, detection still corrects the OCR _text_ (180° reads) but pixels are not rotated.

### 6.1 iOS multi-pass count-based (`recognizeAndDetectRotationInImage:`)

**[DOC DRIFT — `ocr-orientation-correction.md` v2.0]** describes a confidence-Q formula (`Q0=mean(conf)×clamp(count/10)`, thresholds 0.80 / ×1.15). **The code does NOT use confidence for routing** — it uses **non-empty observation counts**. Implement the code:

1. Pass 1: `.accurate` at 0° → text `t0`, `c0 = nonEmptyCount`, `meanConfidence`. Default result = 0°.
2. If `c0 < kMinLinesToJudgeOrientation(3)` → return 0°.
3. Portrait fast path (`aspect<=1` && `c0 >= kUprightLineCount(8)`) → return 0°.
4. Landscape fast path (`aspect>1` && `c0>=8` && `aspect<=1.5`) → return 0°.
5. Probe rotations at `.fast`: portrait probes `[180]`; landscape probes `[90,180,270]`. Pick `bestDegrees` with the max non-empty count.
6. Commit only if `bestDegrees!=0` && `bestCount >= c0 * kRotateCommitRatio(1.3)` (biases against rotating — a false rotation is worse than a missed one). Otherwise 0°.
7. Pass 3: `.accurate` on the chosen rotation for final text; on failure fall back to the fast-probe text.

- Rotation helper `rotate:byDegrees:` is **CCW** (90→`M_PI_2`, 270→`-M_PI_2`); `cgImageByRotating:` (pixel bake) uses the **same CCW convention** → internally consistent.

### 6.2 Android single-pass aspect-mismatch (`recognizeWithRotationDetection`, spec v1.3)

Relies on ML Kit Korean being **rotation-invariant** (field-validated 16.0.0; multi-pass probes returned identical results, so probing is useless). Single Pass 0:

1. `imageAspect = w/h`. `pass0 = measureAt(bitmap, 0)` → `lineCount`, `lineAspect` (trimmed mean of per-line bbox `w/h`, 10% trim when ≥5 lines), `textLength`, `confidence`.
2. `lineCount < 3` → 0°. `lineCount < MISMATCH_MIN_LINES(5)` → 0°.
3. `imageIsLandscape = aspect>1`; `lineIsHorizontal = lineAspect > 1.5`; `lineIsVertical = lineAspect < 0.7`.
4. **`imageIsLandscape && lineIsVertical` → `ROTATED_DEFAULT_DEGREES(270)`** (user held a portrait receipt sideways). Ambiguous band (`0.7..1.5`) → 0°. Aspect-matched → 0°.

- Rotation `rotateFileInPlace` uses `Matrix.postRotate(degrees)` = **CW**.

### 6.3 rotationDegrees direction asymmetry (**#1 porting risk**)

⚠️ Same numeric `rotationDegrees=90` means **opposite directions**: iOS CCW, Android CW (platform-asymmetries §3.1). Each platform is internally consistent because detection and pixel-rotation share the convention _within_ the platform, and the output pixels are normalized so the user only sees "upright". **Keep rotation native-internal and preserve each platform's convention. Do NOT add a shared Dart rotation type or "normalize" the value** — that would break one platform. `rotationDegrees` is never exposed on the Pigeon surface.

### 6.4 Version guard (Android)

`text-recognition-korean` is pinned `16.0.1` (validated `16.0.0`) with a manual rotation-invariance regression procedure (`ml-kit-korean-rotation-invariance.md`). If the Flutter Android plugin resolves a different ML Kit version, the single-pass assumption can silently break — pin the same version and carry the guard comment.

---

## 7. imageOrigin classification

Same 4-value enum (`ImageOrigin{camera,screenshot,download,unknown}`), different signals. Camera path always `camera`.

### 7.1 iOS (gallery)

Priority: `earlyOrigin` (PHAsset) → extracted EXIF → raw source props → `unknown`.

- **PHAsset:** if `assetIdentifier` available and `mediaSubtypes & PHAssetMediaSubtypePhotoScreenshot` → `screenshot`. **No "download" subtype exists** in Photos.
- **EXIF heuristic `OriginFromExifFields(make,model,dateTime)`:** `dateTimeOriginal` present → `camera` (shutter timestamp, strongest signal); else `make && model` → `camera`; else `!make && !model` → `download` (no camera metadata at all); else (make XOR model) → nil/ambiguous → falls through to `unknown`.
- The source-ref read is gated on `exifData==nil` to avoid decoding TIFF/EXIF twice.

### 7.2 Android (gallery) `inferOrigin`

- Query `MediaStore.Images.Media.BUCKET_DISPLAY_NAME` (lowercased): `"camera"`→camera, `"screenshots"/"screenshot"`→screenshot, `"download"/"downloads"`→download.
- Fallback EXIF heuristic: `dateTimeOriginal != null` → camera; `make && model` → camera; else **`unknown`**. **Android never returns `download` from the EXIF fallback** — only an explicit bucket-name match yields `download` (§5 of platform-asymmetries). Intended asymmetry.

### 7.3 Fills `ReceiptImage.imageOrigin` (always present).

---

## 8. Platform requirements & host config

### 8.1 iOS

- **Frameworks (podspec `s.frameworks`):** `VisionKit`, `Vision`, `PhotosUI`, `ImageIO`, `CoreImage`, `CoreGraphics`, `UniformTypeIdentifiers`. Plus `Photos` (`PHAsset`) and `UIKit`.
- **Deployment target: iOS 16.0** — Korean OCR via `VNRecognizeTextRequest` requires it; there is no Latin-only fallback (ADR-006). Set in the `_ios` plugin podspec / `Package.swift`.
- **Host Info.plist (consuming app):** `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`. **No location key** — `includeGpsExif` only copies embedded EXIF GPS, no `CLLocationManager`.
- Localizable strings: `RNReceiptScanner_cropInstruction` / `_cancelButton` / `_confirmButton` (rename to a Flutter-appropriate prefix but keep the default-value fallback pattern).

### 8.2 Android

- **Gradle deps:** `com.google.android.gms:play-services-mlkit-document-scanner:16.0.0`, `com.google.mlkit:text-recognition-korean:16.0.1` (carry the rotation-invariance guard comment), `androidx.exifinterface:exifinterface:1.4.2`, `androidx.activity:activity-ktx:1.10.1` (PhotoPicker contracts). Kotlin 2.0.21.
- **SDK:** `minSdk 24`, `targetSdk 36`, `compileSdk 36`.
- **Host manifest:** only `android.permission.INTERNET`. ML Kit Document Scanner handles the camera grant via Play Services; the gallery flow uses the system photo picker (no `READ_MEDIA_IMAGES`).
- `CropEditorActivity` must be declared in the plugin's `AndroidManifest.xml` (`internal` activity). It is `ComponentActivity`, uses `androidx.core.view` window-insets.

---

## 9. Top porting risks (priority order)

1. **rotationDegrees CW/CCW is opposite per platform** (iOS `cgImageByRotating:90`=CCW; Android `postRotate(90)`=CW). Each is internally self-consistent because detection + pixel-rotation share a convention _within_ the platform. Keep rotation **native-internal, per-platform**; never introduce a shared Dart rotation type or normalize the value — doing so silently breaks one platform. It is never on the Pigeon surface.
2. **Two different OCR-rotation algorithms that must stay different.** Android's single-pass `lineAspect`-vs-`imageAspect` mismatch depends on `text-recognition-korean` being rotation-invariant (validated 16.0.0, pinned 16.0.1, manual regression gate). If the Flutter Android plugin pulls a different ML Kit version the assumption breaks with no automated signal. Do not port iOS's multi-pass to Android; pin the ML Kit version and keep the guard.
3. **Async result must survive the VC/Activity round-trip.** RN used retained delegates (iOS) and `pendingPromise` + `ActivityEventListener` (Android). The Flutter port must: iOS — hold strong refs to the camera/gallery/crop delegate objects on the plugin impl until the completion fires (skeleton already retains `apiImpl` but not per-flow delegates); Android — make the plugin `ActivityAware` + register a `PluginRegistry.ActivityResultListener`, holding the Pigeon `callback` across **both** the GMS scanner and `CropEditorActivity` results. This is the classic Flutter-plugin failure point and the biggest delta from the current stub (Android `scan()` is entirely unimplemented and not ActivityAware).
4. **ADR-004 iOS crop-editor fixes must port verbatim** (they fail only on real devices, not the simulator): `UIButton` not `UIBarButtonItem`; button bar `view.bottomAnchor -34` not `safeAreaLayoutGuide`; handles added before the button bar for hit-test z-order; `VNImageRequestHandler(cgImage:orientation:)` not `initWithCIImage:`; bake orientation (`imageByApplyingOrientation:`) before `CIPerspectiveCorrection`; fresh `CIContext` per call.
5. **autoRotate pipeline order differs and is load-bearing.** iOS OCRs the CGImage _before_ encoding and bakes rotation into pixels; Android OCRs the _encoded file_ after, then `rotateFileInPlace`, and **`writeExifToFile` must run last** (a later re-compress strips the tags). Also the iOS gallery batch **must serialize** editor presentations (`queuedItems`/`processNextQueuedItem`) — a parallel `present` for-loop makes UIKit silently drop all but the first and the Promise/completion hangs forever.

## 10. Doc-drift summary (implement code, not these docs)

- iOS OCR routing is **count-based**, not the confidence-Q formula in `ocr-orientation-correction.md` v2.0.
- Android OCR **confidence is populated** (bundled recognizer), contradicting platform-asymmetries §2.2.
- Android **does write output-file EXIF** (`writeExifToFile`), contradicting platform-asymmetries §1.1 / ADR-006 D11 "deferred" — but only a subset of tags.
