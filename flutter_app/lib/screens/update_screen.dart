import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_version.dart';
import '../locale_store.dart';
import '../theme.dart';

typedef StoreLauncher = Future<bool> Function(Uri url);

Future<bool> _defaultLauncher(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Majburiy yangilash ekrani — yopib/o'tkazib bo'lmaydi (orqaga qaytish,
/// "keyinroq" yo'q). Matn va do'kon havolasi to'liq backend'dan.
class UpdateScreen extends StatefulWidget {
  final StoreLauncher launcher;
  const UpdateScreen({super.key, this.launcher = _defaultLauncher});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  String? _error;

  Future<void> _openStore(AppVersionPolicy? policy, LocaleStore loc) async {
    final raw = policy?.storeUrl.trim() ?? '';
    final uri = raw.isEmpty ? null : Uri.tryParse(raw);
    var ok = false;
    if (uri != null && uri.hasScheme) {
      try {
        ok = await widget.launcher(uri);
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _error = ok ? null : loc.t('update_open_failed'));
    }
  }

  Future<void> _recheck(AppVersionStore store, LocaleStore loc) async {
    final reached = await store.recheck();
    if (!mounted) return;
    // Hali ham majburiy bo'lsa (yoki server javob bermasa) shu ekranda
    // qolamiz; yangilangan bo'lsa Gate o'zi ekranni almashtiradi.
    setState(() => _error = reached ? null : loc.t('update_check_failed'));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    final store = context.watch<AppVersionStore>();
    final policy = store.policy;
    final message = (policy?.message.isNotEmpty ?? false)
        ? policy!.message
        : loc.t('update_forced_message');
    final latest = policy?.latestVersion ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.system_update_alt_rounded,
                          size: 44, color: AppColors.deep),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      loc.t('update_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                    if (latest.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${loc.t('update_latest_label')}: $latest',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13.5),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('update_button'),
                        onPressed: () => _openStore(policy, loc),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(loc.t('update_button')),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('update_retry'),
                      onPressed:
                          store.checking ? null : () => _recheck(store, loc),
                      child: store.checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : Text(loc.t('update_retry')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ixtiyoriy yangilanish dialogi ([Keyinroq] / [Yangilash]).
Future<void> showOptionalUpdateDialog(
  BuildContext context,
  AppVersionPolicy policy,
  LocaleStore loc, {
  StoreLauncher launcher = _defaultLauncher,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(loc.t('update_available_title')),
      content: Text(
        policy.latestVersion.isEmpty
            ? loc.t('update_available_title')
            : '${loc.t('update_available_title')}: ${policy.latestVersion}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(loc.t('update_later')),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final uri = Uri.tryParse(policy.storeUrl.trim());
            if (uri != null && uri.hasScheme) {
              try {
                await launcher(uri);
              } catch (_) {}
            }
          },
          child: Text(loc.t('update_button')),
        ),
      ],
    ),
  );
}
