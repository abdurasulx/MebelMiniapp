import 'package:flutter/material.dart';
import '../api_client.dart';
import '../theme.dart';

/// Server umuman javob bermaganda (internet yo'q, backend o'chiq) ko'rsatiladigan
/// to'liq ekran holati — xom `SocketException`/`TimeoutException` matni o'rniga.
/// Oddiy API xatolari (400/401 va h.k.) buni ishlatmaydi, chunki ular server
/// ishlab turganini bildiradi — faqat [NetworkException] uchun.
class OfflineView extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  const OfflineView({super.key, required this.onRetry, this.message});

  /// `error` — catch bloklarida ushlangan xato obyekti. `NetworkException`
  /// bo'lsagina true qaytaradi, aks holda oddiy inline xato ko'rsatilishi kerak.
  static bool isNetworkError(Object? error) => error is NetworkException;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.deep.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Internet aloqasi yo\'q',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message ?? 'Serverga ulanib bo\'lmadi. Internetingizni tekshirib, qayta urinib ko\'ring.',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF8A7357)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.deep),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }
}
