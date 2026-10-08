import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../attendance_store.dart';
import '../../locale_store.dart';
import '../../theme.dart';

/// Xodim uchun "Ishga keldim"/"Ishni tugatdim" — geolokatsiya orqali
/// backendga yuboriladi, YAKUNIY qarorni (tasdiqlangan/rad etilgan/shubhali)
/// backend beradi (docs "Xodimlar ish haqi va davomat tizimi" §13-14).
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _store = AttendanceStore();
  bool _busy = false;
  AttendanceResult? _lastResult;
  String? _error;

  Future<void> _run(Future<AttendanceResult> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _lastResult = null;
    });
    try {
      final result = await action();
      setState(() => _lastResult = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('attendance_title'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.access_time_filled, size: 64, color: Colors.brown.shade700),
            const SizedBox(height: 24),
            if (_busy) const CircularProgressIndicator(),
            if (_error != null)
              Card(
                color: AppColors.errorSurface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                ),
              ),
            if (_lastResult != null) _ResultBanner(result: _lastResult!, loc: loc),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _run(_store.checkIn),
                icon: const Icon(Icons.login),
                label: Text(loc.t('attendance_check_in')),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(_store.checkOut),
                icon: const Icon(Icons.logout),
                label: Text(loc.t('attendance_check_out')),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final AttendanceResult result;
  final LocaleStore loc;
  const _ResultBanner({required this.result, required this.loc});

  @override
  Widget build(BuildContext context) {
    final approved = result.isApproved;
    return Card(
      color: approved ? AppColors.success : AppColors.errorSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              approved ? Icons.check_circle : Icons.cancel,
              color: approved ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                approved
                    ? (result.action == 'check_in'
                        ? loc.t('attendance_check_in_approved')
                        : loc.t('attendance_check_out_approved'))
                    : (result.reason.isNotEmpty
                        ? result.reason
                        : (result.action == 'check_in'
                            ? loc.t('attendance_check_in_rejected')
                            : loc.t('attendance_check_out_rejected'))),
                style: TextStyle(color: approved ? AppColors.success : AppColors.errorDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
