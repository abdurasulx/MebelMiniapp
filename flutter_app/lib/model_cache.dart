import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 3D (.glb) modellarni qurilma xotirasida (diskda) keshlash menejeri.
///
/// Bir marta yuklab olingach, keyingi barcha ochilishlarda internetdan qayta
/// tortilmasdan, lokal fayldan (`file://...`) bir zumda ochiladi.
class Model3DCacheManager {
  Model3DCacheManager._();
  static final Model3DCacheManager instance = Model3DCacheManager._();

  Directory? _cacheDir;
  final Map<String, Future<File>> _activeDownloads = {};

  Future<Directory> _getDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final baseDir = await getApplicationSupportDirectory();
    final dir = Directory('${baseDir.path}/models_3d');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  String _fileNameForUrl(String url) {
    final hash = md5.convert(utf8.encode(url)).toString();
    return 'model_$hash.glb';
  }

  /// URL uchun keshdagi fayl mavjud bo'lsa uni qaytaradi, aks holda null
  Future<File?> getCachedFile(String url) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${_fileNameForUrl(url)}');
      if (await file.exists() && (await file.length()) > 0) {
        return file;
      }
    } catch (e) {
      debugPrint('Model3DCache getCachedFile error: $e');
    }
    return null;
  }

  /// Modelni keshdan oladi yoki yuklab olib keshlaydi.
  /// Bir vaqtda bir xil URL uchun ikkita download so'rovi ketmasligi uchun
  /// `_activeDownloads` orqali deduplicate qilinadi.
  Future<File> getOrDownload(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    // 1. Keshda allaqachon bormi?
    final cached = await getCachedFile(url);
    if (cached != null) {
      onProgress?.call(1.0);
      return cached;
    }

    // 2. Ayni paytda yuklanayotgan bo'lsa, o'sha Future'ni qaytaramiz
    if (_activeDownloads.containsKey(url)) {
      return _activeDownloads[url]!;
    }

    final downloadFuture = _download(url, onProgress: onProgress);
    _activeDownloads[url] = downloadFuture;

    try {
      final file = await downloadFuture;
      return file;
    } finally {
      _activeDownloads.remove(url);
    }
  }

  Future<File> _download(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _getDir();
    final targetPath = '${dir.path}/${_fileNameForUrl(url)}';
    final targetFile = File(targetPath);
    final tempFile = File('$targetPath.tmp_${DateTime.now().millisecondsSinceEpoch}');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw HttpException(
          'Failed to download 3D model (status: ${streamedResponse.statusCode})',
        );
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = tempFile.openWrite();
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          final p = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(p);
        }
      }
      await sink.flush();
      await sink.close();

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetPath);
      onProgress?.call(1.0);
      return targetFile;
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Mahsulot sahifasi ochilganda orqa fonda oldindan yuklab qo'yish (prefetch)
  void prefetch(String? url) {
    if (url == null || url.isEmpty) return;
    getCachedFile(url).then((cached) {
      if (cached == null) {
        getOrDownload(url).catchError((e) {
          debugPrint('Prefetch 3D model failed: $e');
          return File('');
        });
      }
    });
  }
}
