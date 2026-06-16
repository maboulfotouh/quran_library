part of '/quran.dart';

/// خدمة تحميل كسول (lazy) وتسجيل خطوط QCF4 المضغوطة (tajweed).
///
/// الخطوط مخزّنة كملفات `.ttf.gz` في assets. عند الحاجة يتم فك ضغطها
/// وتسجيلها عبر [loadFontFromList]. تُحفظ النسخ المفكوكة على القرص
/// (على المنصات غير الويب) لتسريع التشغيلات اللاحقة.
///
/// **التحميل الكسول**: تُحمّل فقط الصفحات القريبة من الصفحة الحالية،
/// ثم تُكمَل بقية الصفحات في الخلفية تدريجيًا.
class QuranFontsService {
  QuranFontsService._();

  static const int _totalPages = 604;

  /// [iqama fork] Base URL for downloading the 604 per-page Tajweed
  /// fonts. When set, [_decompressForPage] fetches `QCF4xxx_COLOR-
  /// Regular.ttf.gz` from this URL instead of reading from the asset
  /// bundle. Host apps that bundle the fonts can leave this null and
  /// the original asset-bundle path is used.
  ///
  /// Set from the host app BEFORE calling [QuranLibrary.init]:
  ///   QuranFontsService.remoteBaseUrl =
  ///       'https://cdn.example.com/quran-fonts/qcf4';
  ///
  /// No trailing slash needed. The file name is appended internally.
  static String? remoteBaseUrl;

  /// [iqama fork] Optional consent gate. When set, called exactly
  /// once per isolate session before the very first network download
  /// (cached files don't trigger it). If the future resolves false,
  /// all subsequent download attempts in this session are aborted
  /// early — useful for warning the user about the ~67 MB cost and
  /// letting them decline.
  ///
  /// Set BEFORE calling [QuranLibrary.init]:
  ///   QuranFontsService.beforeDownloadGate = () async {
  ///     return await showMyConsentDialog();
  ///   };
  ///
  /// Pure no-op when [remoteBaseUrl] is null (no downloads happen
  /// from S3 anyway).
  static Future<bool> Function()? beforeDownloadGate;

  /// Single-flight gate evaluation. Multiple parallel page downloads
  /// share the same Future so the dialog only shows once.
  static Future<bool>? _gatePending;

  /// True once the gate has answered "no". Short-circuits future
  /// download attempts so we don't spam the user (or the network)
  /// with retries this session.
  static bool _downloadsAborted = false;

  /// [iqama fork] Called after each page transitions to ready
  /// (`_loadedPages.add(page)`), with the running count and total.
  /// Hosts use this to drive a progress UI. Pure no-op when null.
  /// Reset to null between sessions if you want a clean state.
  static void Function(int loaded, int total)? onProgress;

  /// [iqama fork] Fires once when the bulk loader's worker pool
  /// has finished walking every page — regardless of how many
  /// succeeded. Hosts use this to dismiss the progress dialog
  /// even if a stray page failed silently and we never reached
  /// 100 %. `loaded` may be less than `total` in that case.
  static void Function(int loaded, int total)? onComplete;

  /// [iqama fork] Active CancelToken for in-flight network fetches.
  /// Recreated each session; cancelled by [cancelDownloads].
  static CancelToken _downloadCancelToken = CancelToken();

  /// [iqama fork] Stop all in-flight and queued downloads for the
  /// rest of this isolate session. Cached pages stay cached — just
  /// stops the trickle. Future page-load attempts short-circuit
  /// instantly until [resumeDownloads] is called.
  ///
  /// Safe to call multiple times.
  static void cancelDownloads() {
    _downloadsAborted = true;
    if (!_downloadCancelToken.isCancelled) {
      _downloadCancelToken.cancel('user cancelled Tajweed downloads');
    }
    _backgroundLoadFuture = null;
  }

  /// [iqama fork] Reset session-level abort state so downloads can
  /// run again after a previous [cancelDownloads] or a declined
  /// gate. Call this from the host BEFORE re-entering the consent
  /// flow (e.g. when the user re-opens the Quran reader after
  /// cancelling): it clears the abort flag, recreates the Dio
  /// cancel token, and drops the cached gate-Future so the host's
  /// `beforeDownloadGate` is called fresh.
  ///
  /// Cached pages remain on disk — only in-memory session flags
  /// are touched.
  static void resumeDownloads() {
    _downloadsAborted = false;
    if (_downloadCancelToken.isCancelled) {
      _downloadCancelToken = CancelToken();
    }
    _gatePending = null;
    _backgroundLoadFuture = null;
    // Drop cached page-load futures for pages that NEVER finished
    // loading. `_loadSinglePage` swallows its own exceptions and
    // leaves a (resolved-but-incomplete) future in `_pageLoadFutures`,
    // which `putIfAbsent` would later treat as "already loaded" — so
    // a subsequent attempt skips the gate entirely and the user
    // stares at blank pages with no consent dialog. Keep entries
    // for pages already in `_loadedPages` (they really are loaded).
    _pageLoadFutures
        .removeWhere((page, _) => !_loadedPages.contains(page));
  }

  /// الصفحات المحمّلة في هذا التشغيل (1-based).
  /// "Loaded" means the PRIMARY variant (`page${N}`) is registered
  /// with Flutter. The four derived variants (`d`, `n`, `nd`, `nr`)
  /// are generated lazily — see [_ensureVariant].
  static final Set<int> _loadedPages = {};

  /// Family names already passed to [loadFontFromList]. Used by the
  /// renderer to decide whether to ask for a variant or fall back to
  /// the primary while the variant generates in the background.
  static final Set<String> _registeredFamilies = {};

  /// [iqama fork] Monotonically incremented every time a new family
  /// is registered. The rich-text-line caches its built widget per a
  /// fingerprint of inputs; including this counter in that
  /// fingerprint guarantees the cache invalidates the moment a
  /// previously-unavailable variant comes online. Without it, the
  /// very first switch from light → dark would render with the
  /// primary (black-tajweed) family forever, because the cached
  /// widget was built while the dark variant was still in flight and
  /// the fingerprint had nothing else that changed once it landed.
  static int _fontsRevision = 0;
  static int get fontsRevision => _fontsRevision;

  /// Futures لمنع تكرار تحميل نفس الصفحة عند الاستدعاء المتزامن.
  static final Map<int, Future<void>> _pageLoadFutures = {};

  /// Per-variant single-flight futures so two simultaneous frame
  /// requests for the same `page${N}d` don't double the CPAL +
  /// register cost. Keyed by family name.
  static final Map<String, Future<void>> _variantLoadFutures = {};

  /// Future واحد لتحميل الخلفية لمنع التكرار.
  static Future<void>? _backgroundLoadFuture;

  /// كاش مجلد الخطوط المفكوكة (يُهيّأ مرة واحدة).
  static Directory? _cacheDir;
  static bool _cacheDirInitialized = false;

  /// هل الصفحة المحددة جاهزة للعرض؟ (1-based)
  static bool isPageReady(int page) => _loadedPages.contains(page);

  /// عدد الصفحات المحمّلة حتى الآن.
  static int get loadedCount => _loadedPages.length;

  /// هل تم تحميل جميع الصفحات؟
  static bool get allLoaded => _loadedPages.length >= _totalPages;

  /// [iqama fork] True iff every primary page TTF is sitting in the
  /// on-disk cache. Hosts use this to skip a progress dialog on
  /// re-entry when the previous session already finished downloading
  /// — `allLoaded` returns false on a cold start (the in-memory set
  /// is empty) even when all 604 files are still on disk from a
  /// previous run, so this is the correct probe for "is there any
  /// network work left to do?".
  static Future<bool> isFullyCachedOnDisk() async {
    if (kIsWeb) return false;
    if (allLoaded) return true;
    final dir = await _ensureCacheDir();
    if (dir == null) return false;
    try {
      // One directory listing instead of 604 existsSync() probes.
      // Variants (page${N}d.ttf, page${N}n.ttf, …) live in the same
      // dir but are generated on-demand from the primary; only the
      // primary TTF matters here.
      final primary = RegExp(r'^page\d+\.ttf$');
      var count = 0;
      for (final entry in dir.listSync(followLinks: false)) {
        if (entry is File &&
            primary.hasMatch(entry.uri.pathSegments.last)) {
          count++;
          if (count >= _totalPages) return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// اسم عائلة الخط للصفحة المحددة (page1 .. page604).
  static String getFontFamily(int pageIndex) => 'page${pageIndex + 1}';

  /// اسم عائلة الخط الداكن للصفحة المحددة (page1d .. page604d).
  static String getDarkFontFamily(int pageIndex) => 'page${pageIndex + 1}d';

  /// اسم عائلة الخط بدون تجويد فاتح (page1n .. page604n).
  static String getNoTajweedFontFamily(int pageIndex) =>
      'page${pageIndex + 1}n';

  /// اسم عائلة الخط بدون تجويد داكن (page1nd .. page604nd).
  static String getNoTajweedDarkFontFamily(int pageIndex) =>
      'page${pageIndex + 1}nd';

  /// اسم عائلة الخط الأحمر للخلاف (page1nr .. page604nr).
  static String getRedFontFamily(int pageIndex) => 'page${pageIndex + 1}nr';

  /// مسار الـ asset المضغوط للصفحة (1-based).
  static String _assetPath(int page) {
    final padded = page.toString().padLeft(3, '0');
    return 'packages/quran_library/assets/fonts/quran_fonts_qfc4/'
        'QCF4${padded}_COLOR-Regular.ttf.gz';
  }

  // ---------------------------------------------------------------------------
  // تهيئة مجلد الكاش
  // ---------------------------------------------------------------------------

  static Future<Directory?> _ensureCacheDir() async {
    if (_cacheDirInitialized) return _cacheDir;
    _cacheDirInitialized = true;
    if (kIsWeb) return null;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/quran_fonts_cache');
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
    } catch (e) {
      log('QuranFontsService: failed to create cache dir: $e',
          name: 'QuranFontsService');
      _cacheDir = null;
    }
    return _cacheDir;
  }

  // ---------------------------------------------------------------------------
  // التحميل الكسول: تحميل صفحات قريبة فقط
  // ---------------------------------------------------------------------------

  /// تحميل الصفحات القريبة من [centerPage] (1-based) بنصف قطر [radius].
  ///
  /// مثال: `ensurePagesLoaded(100, radius: 10)` يحمّل الصفحات 90–110.
  /// يتم تخطّي الصفحات المحمّلة مسبقًا. يُنتظر حتى انتهاء التحميل.
  static Future<void> ensurePagesLoaded(
    int centerPage, {
    int radius = 10,
  }) async {
    final cacheDir = await _ensureCacheDir();
    final start = (centerPage - radius).clamp(1, _totalPages);
    final end = (centerPage + radius).clamp(1, _totalPages);

    final futures = <Future<void>>[];
    for (int p = start; p <= end; p++) {
      if (!_loadedPages.contains(p)) {
        futures.add(_loadSinglePage(p, cacheDir));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// تحميل بقية الصفحات في الخلفية بترتيب يبدأ من [startNearPage].
  ///
  /// تُحدّث [progress] (0.0–1.0) و[ready] عند الانتهاء الكامل.
  /// لا تُنتظر — تعمل بشكل غير متزامن.
  static Future<void> loadRemainingInBackground({
    required int startNearPage,
    required RxDouble progress,
    required RxBool ready,
  }) {
    if (allLoaded) {
      progress.value = 1.0;
      ready.value = true;
      return Future.value();
    }
    // منع التكرار
    _backgroundLoadFuture ??= _doLoadRemaining(
      startNearPage: startNearPage,
      progress: progress,
      ready: ready,
    );
    return _backgroundLoadFuture!;
  }

  /// [iqama fork] Host-friendly variant of [loadRemainingInBackground].
  /// Doesn't need the package's `RxDouble`/`RxBool` plumbing — the host
  /// observes progress via [onProgress]. Idempotent / single-flighted:
  /// safe to call from the consent flow without worrying about an
  /// in-flight background loop already running from the package side.
  static Future<void> startBulkDownload({int startNearPage = 1}) {
    if (allLoaded) return Future.value();
    _backgroundLoadFuture ??= _doLoadRemaining(
      startNearPage: startNearPage,
      progress: RxDouble(0.0),
      ready: RxBool(false),
    );
    return _backgroundLoadFuture!;
  }

  /// [iqama fork] Max concurrent page downloads. Each page hits S3
  /// once for the .gz then does CPU work to make 5 CPAL variants.
  /// Going above ~8 saturates the UI isolate and the dialog appears
  /// to freeze even though pages are loading.
  static const int _backgroundConcurrency = 8;

  static Future<void> _doLoadRemaining({
    required int startNearPage,
    required RxDouble progress,
    required RxBool ready,
  }) async {
    final cacheDir = await _ensureCacheDir();
    final loadOrder = _buildLoadOrder(startNearPage);

    // [iqama fork] Parallelized with a fixed-size worker pool so the
    // background loop doesn't stall the dialog for 5–20 minutes on a
    // sequential 604-page network walk. Workers pull from a shared
    // cursor. Each page gets up to 2 retry attempts before being
    // counted as failed — covers transient S3 hiccups (the most
    // common reason for a page sticking at "loaded but not added"
    // and the dialog freezing one short of 604).
    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        if (_downloadsAborted) return;
        if (cursor >= loadOrder.length) return;
        final page = loadOrder[cursor++];
        if (_loadedPages.contains(page)) continue;

        const maxAttempts = 3;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          if (_downloadsAborted) return;
          try {
            // Drop the poisoned future first so a previous failure
            // doesn't short-circuit `putIfAbsent` to the resolved-
            // but-incomplete entry.
            if (attempt > 1) _pageLoadFutures.remove(page);
            await _loadSinglePage(page, cacheDir);
          } catch (_) {/* swallow — retry decision below */}
          if (_loadedPages.contains(page)) break;
          if (attempt < maxAttempts) {
            // Brief backoff: 300 ms then 800 ms.
            await Future.delayed(
              Duration(milliseconds: attempt == 1 ? 300 : 800),
            );
          }
        }
        progress.value = _loadedPages.length / _totalPages;
      }
    }

    await Future.wait(List.generate(_backgroundConcurrency, (_) => worker()));

    if (!_downloadsAborted) {
      progress.value = 1.0;
      ready.value = true;
    }

    // [iqama fork] One last completion signal. The host's progress
    // dialog only auto-dismisses on `loaded >= total`, which never
    // happens if a page genuinely failed all retries. `onComplete`
    // lets the dialog dismiss with whatever final count we got and
    // surface a softer warning if loaded < total.
    final loaded = _loadedPages.length;
    onProgress?.call(loaded, _totalPages);
    onComplete?.call(loaded, _totalPages);
  }

  /// بناء ترتيب التحميل: يبدأ من [startPage] ويتوسع للخارج.
  ///
  /// مثلاً لو startPage=100: 100، 101، 99، 102، 98، 103، 97 ...
  static List<int> _buildLoadOrder(int startPage) {
    final order = <int>[];
    final start = startPage.clamp(1, _totalPages);
    order.add(start);

    for (int delta = 1; delta < _totalPages; delta++) {
      final after = start + delta;
      final before = start - delta;
      if (after <= _totalPages) order.add(after);
      if (before >= 1) order.add(before);
    }

    return order;
  }

  // ---------------------------------------------------------------------------
  // تحميل صفحة واحدة مع كل المتغيرات (4 خطوط)
  // ---------------------------------------------------------------------------

  /// تحميل صفحة واحدة (1-based) مع متغيراتها الأربعة.
  ///
  /// - `page{N}` — فاتح مع تجويد
  /// - `page{N}d` — داكن مع تجويد (CPAL: أسود→أبيض)
  /// - `page{N}n` — فاتح بدون تجويد (CPAL: كل الألوان→أسود)
  /// - `page{N}nd` — داكن بدون تجويد (CPAL: كل الألوان→أبيض)
  /// [iqama fork] Loads ONLY the primary variant (`page${N}`) for
  /// the bulk path. The dark / no-tajweed / red variants used to be
  /// generated eagerly here — that meant 5×604 = 3,020
  /// `loadFontFromList` calls during a fresh download, each of
  /// which serializes on Flutter's platform thread for Skia font
  /// registration. The non-primary variants are now generated
  /// on-demand via [ensureVariant], called by the renderer when it
  /// actually needs that mode.
  static Future<void> _loadSinglePage(int page, Directory? cacheDir) {
    return _pageLoadFutures.putIfAbsent(page, () async {
      try {
        final familyName = 'page$page';
        final fontBytes = await _readPrimaryBytes(page, cacheDir);
        await _registerFamily(familyName, fontBytes);
        _loadedPages.add(page);
        onProgress?.call(_loadedPages.length, _totalPages);
      } catch (e, st) {
        log('QuranFontsService: failed to load font page $page: $e',
            name: 'QuranFontsService', stackTrace: st);
      }
    });
  }

  /// [iqama fork] Reads the raw decompressed TTF bytes for the
  /// primary variant of [page] — disk cache first, network fetch
  /// + decode otherwise. Used by both the bulk loader and the
  /// on-demand variant generator below.
  static Future<Uint8List> _readPrimaryBytes(int page, Directory? cacheDir) async {
    if (cacheDir != null) {
      final cachedFile = File('${cacheDir.path}/page$page.ttf');
      if (cachedFile.existsSync()) {
        return Uint8List.fromList(await cachedFile.readAsBytes());
      }
      final bytes = await _decompressForPage(page, cacheDir);
      try {
        await cachedFile.writeAsBytes(bytes, flush: true);
      } catch (e) {
        log('QuranFontsService: primary cache write failed for page $page: $e',
            name: 'QuranFontsService');
      }
      return bytes;
    }
    return _decompressForPage(page, cacheDir);
  }

  static Future<void> _registerFamily(String family, Uint8List bytes) async {
    await loadFontFromList(bytes, fontFamily: family);
    final wasNew = _registeredFamilies.add(family);
    if (wasNew) _fontsRevision++;
  }

  /// [iqama fork] Ensures the [variant] for [page] is registered
  /// with Flutter and ready to render. Cheap fast-path when the
  /// family is already loaded; otherwise reads the variant TTF
  /// from disk if cached (b), or generates it via CPAL surgery
  /// from the primary bytes and caches the result.
  ///
  /// Renderer / mode-switch handlers call this; the future
  /// completes once the variant is usable.
  static Future<void> ensureVariant(int page, FontVariant variant) {
    final family = variant.familyFor(page);
    if (_registeredFamilies.contains(family)) return Future.value();
    return _variantLoadFutures.putIfAbsent(family, () async {
      try {
        final cacheDir = await _ensureCacheDir();
        // (b) Try the on-disk variant cache first.
        if (cacheDir != null) {
          final variantFile = File('${cacheDir.path}/$family.ttf');
          if (variantFile.existsSync()) {
            final bytes = Uint8List.fromList(await variantFile.readAsBytes());
            await _registerFamily(family, bytes);
            return;
          }
        }

        // Cache miss → mutate from the primary bytes.
        final primary = await _readPrimaryBytes(page, cacheDir);
        final mutated = variant.mutate(primary);
        await _registerFamily(family, mutated);
        if (cacheDir != null) {
          try {
            await File('${cacheDir.path}/$family.ttf')
                .writeAsBytes(mutated, flush: true);
          } catch (e) {
            log('QuranFontsService: variant cache write failed $family: $e',
                name: 'QuranFontsService');
          }
        }
      } catch (e, st) {
        log('QuranFontsService: ensureVariant $family failed: $e',
            name: 'QuranFontsService', stackTrace: st);
        // Drop the failed future so the next call retries instead
        // of hitting an already-resolved-but-incomplete entry.
        _variantLoadFutures.remove(family);
      }
    });
  }

  /// [iqama fork] True iff the family the renderer wants is already
  /// registered. Used as a sync check before falling back to the
  /// primary while the variant generates in the background.
  static bool isFamilyReady(String family) => _registeredFamilies.contains(family);

  /// [iqama fork] Pre-warm every font variant (dark + noTajweed +
  /// noTajweedDark + red) for the user's landing page and its
  /// [radius] neighbours. Slashes the first-toggle stall users
  /// hit when they flip tajweed off, or when the reader's theme
  /// switches from light to dark, since the variant generation
  /// (a heavy CPAL byte mutation) happens in the background well
  /// before the renderer asks for the family.
  ///
  /// **Layered.** Page [pageIndex] is warmed first, then ±1,
  /// then ±2. So even if pre-warming the whole window takes a
  /// few hundred ms, the user's immediate view is ready early.
  ///
  /// **Idempotent.** Internally calls [ensureVariant], which
  /// guards via `_registeredFamilies` and `_variantLoadFutures`
  /// — repeated calls to this method are cheap once the data is
  /// already in memory.
  ///
  /// **Serial, not parallel.** Each `ensureVariant` that has to do
  /// real work calls `loadFontFromList`, which briefly blocks the
  /// platform thread while it installs the font. The original
  /// `Future.wait([…])` fanned out ~20 of those in flight at once
  /// during a single page-change — enough to starve Flutter's
  /// compositor for half a second and produce the mid-swipe stall
  /// users reported on tablets. The serial loop, combined with a
  /// `Future.delayed(Duration.zero)` yield after each variant, lets
  /// the platform thread service a compositor frame between every
  /// font registration. Total wall-clock is slightly longer, but
  /// the swipe animation no longer drops to 0 fps mid-gesture.
  ///
  /// Optional [cancelToken] is polled between variants; returning
  /// `true` aborts the rest of the work. The caller (the debounced
  /// scheduler in `QuranCtrl.schedulePrewarmDebounced`) bumps its
  /// generation token on every new page-change so a prewarm that
  /// is still walking the window when the user starts swiping
  /// again bails on the very next yield instead of fighting the
  /// new gesture.
  static Future<void> prewarmPageNeighbourhood(
    int pageIndex, {
    int radius = 2,
    bool Function()? cancelToken,
  }) async {
    for (int offset = 0; offset <= radius; offset++) {
      if (cancelToken != null && cancelToken()) return;
      final pages = offset == 0
          ? [pageIndex]
          : [pageIndex - offset, pageIndex + offset];
      for (final p in pages) {
        if (p < 0 || p > 603) continue;
        for (final v in FontVariant.values) {
          if (cancelToken != null && cancelToken()) return;
          await ensureVariant(p + 1, v);
          // Yield so the platform thread can paint a compositor
          // frame between every registered font. Without this the
          // swipe animation flatlines while ~20 loadFontFromList
          // calls chew the platform thread back-to-back.
          await Future<void>.delayed(Duration.zero);
        }
      }
    }
  }

  /// فك ضغط ملف `.ttf.gz` من الـ assets.
  static Future<Uint8List> _decompressFromAsset(int page) async {
    final data = await rootBundle.load(_assetPath(page));
    final gzBytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final decompressed = const GZipDecoder().decodeBytes(gzBytes);
    return Uint8List.fromList(decompressed);
  }

  /// [iqama fork] Returns the decompressed TTF bytes for [page]. If
  /// [remoteBaseUrl] is set, the `.gz` is fetched from the network
  /// the first time and cached on disk; subsequent calls in the same
  /// session use the in-memory decompression of the on-disk bytes.
  /// Falls back to [_decompressFromAsset] when [remoteBaseUrl] is null
  /// (e.g. a host app that bundles the fonts).
  static Future<Uint8List> _decompressForPage(
      int page, Directory? cacheDir) async {
    if (remoteBaseUrl == null) {
      return _decompressFromAsset(page);
    }
    final gzBytes = await _fetchPageGzip(page, cacheDir);
    final decompressed = const GZipDecoder().decodeBytes(gzBytes);
    return Uint8List.fromList(decompressed);
  }

  /// [iqama fork] Downloads `QCF4{padded}_COLOR-Regular.ttf.gz` from
  /// [remoteBaseUrl] and stores it under `<cacheDir>/gz/` so a re-launch
  /// doesn't re-download. Returns the raw .gz bytes — decompression is
  /// handled by the caller.
  static Future<Uint8List> _fetchPageGzip(
      int page, Directory? cacheDir) async {
    // [iqama fork] Recreate the cancel token if it was used. Lets
    // the host re-enter Tajweed mode within the same session after
    // a previous cancellation cleared _downloadsAborted (in tests /
    // hot reload / explicit reset).
    if (_downloadCancelToken.isCancelled && !_downloadsAborted) {
      _downloadCancelToken = CancelToken();
    }
    final padded = page.toString().padLeft(3, '0');
    final fileName = 'QCF4${padded}_COLOR-Regular.ttf.gz';

    // gz disk cache lives alongside the decompressed TTF cache; keep
    // them in a sibling dir so cleanup is one rmdir.
    File? gzCachedFile;
    if (cacheDir != null) {
      final gzDir = Directory('${cacheDir.path}/gz');
      if (!gzDir.existsSync()) {
        try {
          await gzDir.create(recursive: true);
        } catch (_) {/* fallthrough to memory-only */}
      }
      gzCachedFile = File('${gzDir.path}/$fileName');
      if (gzCachedFile.existsSync()) {
        try {
          return Uint8List.fromList(await gzCachedFile.readAsBytes());
        } catch (e) {
          log('QuranFontsService: gz cache read failed for page $page: $e',
              name: 'QuranFontsService');
        }
      }
    }

    // [iqama fork] Consent gate. Only runs when we're about to hit
    // the network (cache hits above already returned). The gate is
    // single-flighted across parallel page downloads so the host's
    // dialog only shows once.
    if (_downloadsAborted) {
      throw _FontDownloadDeclinedException();
    }
    if (beforeDownloadGate != null) {
      _gatePending ??= beforeDownloadGate!();
      final ok = await _gatePending!;
      if (!ok) {
        // Don't set _downloadsAborted here — that's only for an
        // explicit cancelDownloads() mid-flight. Instead, clear the
        // gate Future so a subsequent re-entry (e.g. user reopens
        // the Quran reader after declining) can ask again.
        _gatePending = null;
        throw _FontDownloadDeclinedException();
      }
    }

    final url = '${remoteBaseUrl!}/$fileName';
    // Use a fresh Dio so the host app's Dio-wide interceptors (auth
    // headers etc) don't accidentally apply to a public CDN fetch.
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.bytes,
    ));
    try {
      final resp = await dio.get<List<int>>(
        url,
        cancelToken: _downloadCancelToken,
      );
      if (resp.statusCode != 200 || resp.data == null) {
        throw Exception('HTTP ${resp.statusCode} for $url');
      }
      final bytes = Uint8List.fromList(resp.data!);
      // Cache the .gz for next launch. Best-effort: failure to cache
      // does not break this session.
      if (gzCachedFile != null) {
        try {
          await gzCachedFile.writeAsBytes(bytes, flush: true);
        } catch (e) {
          log('QuranFontsService: gz cache write failed for page $page: $e',
              name: 'QuranFontsService');
        }
      }
      return bytes;
    } finally {
      dio.close(force: false);
    }
  }

  // ---------------------------------------------------------------------------
  // تعديل جدول CPAL في ملف TTF/OTF
  // ---------------------------------------------------------------------------

  /// يبحث عن جدول `CPAL` في بيانات الخط ويستبدل اللون الأسود الأساسي
  /// (الطبقة الأساسية لنص القرآن) بـ [newBaseColor].
  ///
  /// ألوان التجويد (أحمر، أخضر، أزرق، إلخ) تبقى كما هي تماماً.
  /// إذا لم يُعثر على جدول CPAL، تُرجع البيانات بدون تعديل.
  static Uint8List _modifyCpalBaseColor(
      Uint8List fontBytes, Color newBaseColor) {
    final bd = ByteData.view(
        fontBytes.buffer, fontBytes.offsetInBytes, fontBytes.lengthInBytes);

    if (fontBytes.length < 12) return fontBytes;
    final numTables = bd.getUint16(4);

    int? cpalOffset;
    int? cpalLength;
    const cpalTag = 0x4350414C; // 'CPAL' in ASCII
    for (int t = 0; t < numTables; t++) {
      final recordOffset = 12 + t * 16;
      if (recordOffset + 16 > fontBytes.length) break;
      final tag = bd.getUint32(recordOffset);
      if (tag == cpalTag) {
        cpalOffset = bd.getUint32(recordOffset + 8);
        cpalLength = bd.getUint32(recordOffset + 12);
        break;
      }
    }

    if (cpalOffset == null || cpalLength == null) return fontBytes;
    if (cpalOffset + cpalLength > fontBytes.length) return fontBytes;

    if (cpalOffset + 12 > fontBytes.length) return fontBytes;
    final numColorRecords = bd.getUint16(cpalOffset + 6);
    final colorRecordsArrayOffset = bd.getUint32(cpalOffset + 8);

    final absColorRecordsOffset = cpalOffset + colorRecordsArrayOffset;

    final newR = (newBaseColor.r * 255).round();
    final newG = (newBaseColor.g * 255).round();
    final newB = (newBaseColor.b * 255).round();
    final newA = (newBaseColor.a * 255).round();

    for (int c = 0; c < numColorRecords; c++) {
      final colorOffset = absColorRecordsOffset + c * 4;
      if (colorOffset + 4 > fontBytes.length) break;

      final b = fontBytes[colorOffset];
      final g = fontBytes[colorOffset + 1];
      final r = fontBytes[colorOffset + 2];
      final a = fontBytes[colorOffset + 3];

      // اكتشاف اللون الأسود: RGB ≤ 30 و Alpha ≥ 200
      if (r <= 30 && g <= 30 && b <= 30 && a >= 200) {
        fontBytes[colorOffset] = newB;
        fontBytes[colorOffset + 1] = newG;
        fontBytes[colorOffset + 2] = newR;
        fontBytes[colorOffset + 3] = newA;
      }
    }

    return fontBytes;
  }

  /// يستبدل **جميع** ألوان CPAL بلون واحد موحّد.
  ///
  /// يُستخدم لإنشاء نسخة "بدون تجويد" حيث يُرسم كل شيء بلون واحد.
  static Uint8List _modifyCpalAllColors(Uint8List fontBytes, Color color) {
    final bd = ByteData.view(
        fontBytes.buffer, fontBytes.offsetInBytes, fontBytes.lengthInBytes);

    if (fontBytes.length < 12) return fontBytes;
    final numTables = bd.getUint16(4);

    int? cpalOffset;
    int? cpalLength;
    const cpalTag = 0x4350414C;
    for (int t = 0; t < numTables; t++) {
      final recordOffset = 12 + t * 16;
      if (recordOffset + 16 > fontBytes.length) break;
      final tag = bd.getUint32(recordOffset);
      if (tag == cpalTag) {
        cpalOffset = bd.getUint32(recordOffset + 8);
        cpalLength = bd.getUint32(recordOffset + 12);
        break;
      }
    }

    if (cpalOffset == null || cpalLength == null) return fontBytes;
    if (cpalOffset + cpalLength > fontBytes.length) return fontBytes;
    if (cpalOffset + 12 > fontBytes.length) return fontBytes;

    final numColorRecords = bd.getUint16(cpalOffset + 6);
    final colorRecordsArrayOffset = bd.getUint32(cpalOffset + 8);
    final absColorRecordsOffset = cpalOffset + colorRecordsArrayOffset;

    final newR = (color.r * 255).round();
    final newG = (color.g * 255).round();
    final newB = (color.b * 255).round();
    final newA = (color.a * 255).round();

    for (int c = 0; c < numColorRecords; c++) {
      final colorOffset = absColorRecordsOffset + c * 4;
      if (colorOffset + 4 > fontBytes.length) break;
      fontBytes[colorOffset] = newB;
      fontBytes[colorOffset + 1] = newG;
      fontBytes[colorOffset + 2] = newR;
      fontBytes[colorOffset + 3] = newA;
    }

    return fontBytes;
  }

  /// حذف كاش الخطوط من القرص.
  static Future<void> clearCache() async {
    if (kIsWeb) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/quran_fonts_cache');
      if (cacheDir.existsSync()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      log('QuranFontsService: clearCache failed: $e',
          name: 'QuranFontsService');
    }
    _loadedPages.clear();
    _registeredFamilies.clear();
    _pageLoadFutures.clear();
    _variantLoadFutures.clear();
    _backgroundLoadFuture = null;
    _cacheDir = null;
    _cacheDirInitialized = false;
  }
}

/// [iqama fork] Sentinel thrown when the consent gate returns false.
/// Caught by `_loadSinglePage`'s outer catch and logged silently.
class _FontDownloadDeclinedException implements Exception {
  @override
  String toString() => 'Tajweed font download declined by user';
}

/// [iqama fork] The four derived font variants the renderer can ask
/// for. The primary (`page${N}`) loads eagerly during bulk download;
/// these get generated on-demand via [QuranFontsService.ensureVariant]
/// so a 604-page fresh install doesn't pay 5× the platform-thread
/// registration cost up-front.
enum FontVariant {
  /// Dark mode with tajweed — CPAL base color (black) → white.
  /// `page${N}d`.
  dark,

  /// Light mode without tajweed — every CPAL color → black.
  /// `page${N}n`.
  noTajweed,

  /// Dark mode without tajweed — every CPAL color → white.
  /// `page${N}nd`.
  noTajweedDark,

  /// Red overlay for ten-readings disagreement words — every CPAL
  /// color → red. `page${N}nr`.
  red,
}

extension FontVariantExt on FontVariant {
  String familyFor(int page) {
    switch (this) {
      case FontVariant.dark:          return 'page${page}d';
      case FontVariant.noTajweed:     return 'page${page}n';
      case FontVariant.noTajweedDark: return 'page${page}nd';
      case FontVariant.red:           return 'page${page}nr';
    }
  }

  Uint8List mutate(Uint8List primary) {
    switch (this) {
      case FontVariant.dark:
        return QuranFontsService._modifyCpalBaseColor(
          Uint8List.fromList(primary),
          const Color(0xFFFFFFFF),
        );
      case FontVariant.noTajweed:
        return QuranFontsService._modifyCpalAllColors(
          Uint8List.fromList(primary),
          const Color(0xFF000000),
        );
      case FontVariant.noTajweedDark:
        return QuranFontsService._modifyCpalAllColors(
          Uint8List.fromList(primary),
          const Color(0xFFFFFFFF),
        );
      case FontVariant.red:
        return QuranFontsService._modifyCpalAllColors(
          Uint8List.fromList(primary),
          const Color(0xFFFF0000),
        );
    }
  }
}
