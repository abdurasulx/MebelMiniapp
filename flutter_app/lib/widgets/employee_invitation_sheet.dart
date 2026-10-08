import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../auth_store.dart';
import '../locale_store.dart';
import '../models.dart';
import '../positions.dart';
import '../theme.dart';

/// "Ishga taklif" bildirishnomasi (in-app ro'yxat yoki push) bosilganda
/// ochiladigan oyna — kutilayotgan takliflarni ko'rsatib, shu yerning
/// o'zida qabul qilish/rad etish imkonini beradi (Profil sahifasidagi
/// "Ish takliflari" bilan bir xil API: /employee-invitations/).
Future<void> showEmployeeInvitationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _InvitationSheet(),
  );
}

class _InvitationSheet extends StatefulWidget {
  const _InvitationSheet();
  @override
  State<_InvitationSheet> createState() => _InvitationSheetState();
}

class _InvitationSheetState extends State<_InvitationSheet> {
  List<EmployeeInvitation> _pending = [];
  bool _loading = true;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ApiClient.instance.get(
        '/employee-invitations/?received=1',
        (j) => Paginated<EmployeeInvitation>.fromJson(j, EmployeeInvitation.fromJson),
        auth: true,
      );
      setState(() => _pending = page.results.where((i) => i.status == 'pending').toList());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(EmployeeInvitation inv, bool accept) async {
    setState(() => _busyId = inv.id);
    try {
      await ApiClient.instance.post(
        '/employee-invitations/${inv.id}/${accept ? 'accept' : 'decline'}/',
        (j) => j,
        auth: true,
      );
      if (!mounted) return;
      await context.read<AuthStore>().refreshUser();
      await _load();
      if (mounted && _pending.isEmpty) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.t('profile_job_offers'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  loc.t('offer_none'),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ..._pending.map(
                (inv) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          inv.positions.map((p) => positionInfo(p, loc).label).join(', '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _busyId == inv.id ? null : () => _respond(inv, true),
                                child: Text(loc.t('profile_offer_accept')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busyId == inv.id ? null : () => _respond(inv, false),
                                child: Text(loc.t('profile_offer_decline')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
          ],
        ),
      ),
    );
  }
}
