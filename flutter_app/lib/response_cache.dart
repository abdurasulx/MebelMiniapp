import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// GET javoblarining diskdagi + xotiradagi keshi (stale-while-revalidate).
///
/// `ApiClient.get(..., cache: true)` shu keshdan ishlaydi: avval saqlangan
/// javob DARHOL qaytariladi, fonda server so'raladi; javob o'zgargan bo'lsa
/// kesh yangilanadi va ekran `onRefresh` orqali yangilanadi.
class ResponseCache {
  ResponseCache._();
  static final ResponseCache instance = ResponseCache._();

  static const int _maxBodyBytes = 2 * 1024 * 1024;
  final Map<String, String> _mem = {};
  Directory? _dir;

  Future<Directory?> _ensureDir() async {
    if (_dir != null) return _dir;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}/resp_cache');
      if (!await d.exists()) await d.create(recursive: true);
      return _dir = d;
    } catch (_) {
      return null; // diskka yozib bo'lmasa — faqat xotira keshi
    }
  }

  // FNV-1a (64 bit) — fayl nomi uchun barqaror xesh (Object.hash ishga tushirishlar
  // orasida o'zgaradi).
  static String _fileName(String key) {
    var h = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final b in utf8.encode(key)) {
      h = ((h ^ BigInt.from(b)) * prime) & mask;
    }
    return '${h.toRadixString(16).padLeft(16, '0')}.json';
  }

  Future<String?> read(String key) async {
    final m = _mem[key];
    if (m != null) return m;
    final dir = await _ensureDir();
    if (dir == null) return null;
    try {
      final f = File('${dir.path}/${_fileName(key)}');
      if (!await f.exists()) return null;
      final body = await f.readAsString();
      _mem[key] = body;
      return body;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String body) async {
    if (body.length > _maxBodyBytes) return;
    _mem[key] = body;
    final dir = await _ensureDir();
    if (dir == null) return;
    try {
      await File('${dir.path}/${_fileName(key)}')
          .writeAsString(body, flush: true);
    } catch (_) {/* kesh ixtiyoriy */}
  }

  /// Chiqishda (logout) barcha keshni tozalaydi.
  Future<void> clear() async {
    _mem.clear();
    final dir = await _ensureDir();
    if (dir == null) return;
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (_) {}
  }
}
