import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend `GET /app/version/` (va 426 `APP_UPDATE_REQUIRED`) javobi.
/// Qoidalar (qaysi versiya bloklanishi) FAQAT backend'da — bu yerda
/// hech narsa qattiq yozilmaydi.
class AppVersionPolicy {
  final String platform;
  final String currentVersion;
  final String latestVersion;
  final String minimumSupportedVersion;
  final String status; // ACTIVE | UPDATE_REQUIRED | BLOCKED
  final bool updateAvailable;
  final bool forceUpdate;
  final String storeUrl;
  final String message;

  const AppVersionPolicy({
    this.platform = '',
    this.currentVersion = '',
    this.latestVersion = '',
    this.minimumSupportedVersion = '',
    this.status = 'ACTIVE',
    this.updateAvailable = false,
    this.forceUpdate = false,
    this.storeUrl = '',
    this.message = '',
  });

  /// Noto'g'ri (Map bo'lmagan) kirishda `FormatException` tashlaydi.
  factory AppVersionPolicy.fromJson(dynamic j) {
    if (j is! Map) throw const FormatException('Versiya javobi JSON obyekt emas');
    String s(String k) => (j[k] ?? '').toString();
    bool b(String k) => j[k] == true;
    return AppVersionPolicy(
      platform: s('platform'),
      currentVersion: s('current_version'),
      latestVersion: s('latest_version'),
      minimumSupportedVersion: s('minimum_supported_version'),
      status: s('status').isEmpty ? 'ACTIVE' : s('status'),
      updateAvailable: b('update_available'),
      forceUpdate: b('force_update'),
      storeUrl: s('store_url'),
      message: s('message'),
    );
  }

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'current_version': currentVersion,
        'latest_version': latestVersion,
        'minimum_supported_version': minimumSupportedVersion,
        'status': status,
        'update_available': updateAvailable,
        'force_update': forceUpdate,
        'store_url': storeUrl,
        'message': message,
      };

  /// Majburiy yangilash: BLOCKED, yoki UPDATE_REQUIRED + force_update.
  bool get isForced =>
      status == 'BLOCKED' || (status == 'UPDATE_REQUIRED' && forceUpdate);
}

enum UpdateAction { proceed, optional, forced }

/// Sof (UI'siz) qaror: server siyosati -> nima qilish kerak.
UpdateAction decideAction(AppVersionPolicy p) {
  if (p.isForced) return UpdateAction.forced;
  if (p.updateAvailable || p.status == 'UPDATE_REQUIRED') {
    return UpdateAction.optional;
  }
  return UpdateAction.proceed;
}

/// `2.4.0`, `2.4.0+24`, `v2.4` -> (2,4,0); noto'g'ri -> null.
/// Satr emas, butun sonlar bo'yicha (`2.10.0 > 2.9.0`).
List<int>? parseVersion(String raw) {
  final text = raw.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
  if (!RegExp(r'^\d+(\.\d+){0,2}$').hasMatch(text)) return null;
  final parts = text.split('.').map(int.parse).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}

/// -1 / 0 / 1; format noto'g'ri bo'lsa null.
int? compareVersions(String a, String b) {
  final pa = parseVersion(a), pb = parseVersion(b);
  if (pa == null || pb == null) return null;
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i] < pb[i] ? -1 : 1;
  }
  return 0;
}

/// Tarmoq/5xx/JSON bo'lmagan xatoda: keshlangan siyosat MAJBURIY blok
/// bo'lgan va u hali ham shu (yoki undan eski) o'rnatilgan versiyaga tegishli
/// bo'lsa — blok saqlanadi; aks holda ruxsat (hech qachon keraksiz bloklamaymiz).
UpdateAction decideFromCache(AppVersionPolicy? cached, String runningVersion) {
  if (cached == null || !cached.isForced) return UpdateAction.proceed;
  final vsBlocked = compareVersions(runningVersion, cached.currentVersion);
  final vsMin = cached.minimumSupportedVersion.isEmpty
      ? null
      : compareVersions(runningVersion, cached.minimumSupportedVersion);
  if ((vsBlocked != null && vsBlocked <= 0) || (vsMin != null && vsMin < 0)) {
    return UpdateAction.forced;
  }
  return UpdateAction.proceed;
}

typedef PolicyFetcher = Future<AppVersionPolicy> Function();

/// Ilova versiyasi holati. `ApiClient.updateRequired` (426) va
/// [checkOnStartup] natijalari shu yerda birlashadi; UI faqat shuni tinglaydi.
class AppVersionStore extends ChangeNotifier {
  static const _prefKey = 'fp.app_version_policy';

  final PolicyFetcher _fetcher;
  final String Function() _runningVersion;
  final ValueListenable<AppVersionPolicy?>? _forcedSource;

  AppVersionStore({
    required PolicyFetcher fetcher,
    required String Function() runningVersion,
    ValueListenable<AppVersionPolicy?>? forcedSource,
  })  : _fetcher = fetcher,
        _runningVersion = runningVersion,
        _forcedSource = forcedSource {
    _forcedSource?.addListener(_onForcedPublished);
  }

  UpdateAction _action = UpdateAction.proceed;
  AppVersionPolicy? _policy;
  bool _checking = false;
  bool _optionalHandled = false;

  UpdateAction get action => _action;
  AppVersionPolicy? get policy => _policy;
  bool get checking => _checking;
  bool get isForced => _action == UpdateAction.forced;

  /// Ixtiyoriy yangilanish dialogi hali ko'rsatilmagan (sessiya davomida
  /// bir marta) bo'lsa true.
  bool get shouldShowOptional =>
      _action == UpdateAction.optional && !_optionalHandled;

  void markOptionalHandled() {
    _optionalHandled = true;
  }

  void _onForcedPublished() {
    final p = _forcedSource?.value;
    if (p == null) return;
    _apply(p);
    _save(p);
  }

  void _apply(AppVersionPolicy p) {
    _policy = p;
    _action = decideAction(p);
    notifyListeners();
  }

  /// Splash paytida chaqiriladi. Hech qachon istisno tashlamaydi.
  Future<void> checkOnStartup() => recheck();

  /// Majburiy ekrandagi "Qayta tekshirish" ham shu. `true` — server
  /// javob berdi; `false` — tarmoq/5xx (kesh asosida qaror qilindi).
  Future<bool> recheck() async {
    _checking = true;
    notifyListeners();
    var reached = false;
    try {
      final p = await _fetcher();
      reached = true;
      _apply(p);
      await _save(p);
    } catch (_) {
      final cached = await _load();
      final act = decideFromCache(cached, _runningVersion());
      _policy = cached;
      _action = act;
    }
    _checking = false;
    notifyListeners();
    return reached;
  }

  Future<void> _save(AppVersionPolicy p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(p.toJson()));
    } catch (_) {}
  }

  Future<AppVersionPolicy?> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return null;
      return AppVersionPolicy.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _forcedSource?.removeListener(_onForcedPublished);
    super.dispose();
  }
}
