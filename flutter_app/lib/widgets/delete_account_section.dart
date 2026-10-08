import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../locale_store.dart';

/// Profildagi "Hisobni o'chirish" bo'limi — veb'dagi `DeleteAccountSection`
/// (Profile.jsx) bilan bir xil oqim: sabab bilan so'rov yuboriladi
/// (`/users/me/deletion-request/`), administrator ko'rib chiqib tasdiqlaydi.
/// Google Play va App Store talabi: o'chirishni ilovaning ichidan boshlash.
class DeleteAccountSection extends StatefulWidget {
  const DeleteAccountSection({super.key});

  @override
  State<DeleteAccountSection> createState() => _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends State<DeleteAccountSection> {
  bool? _pending; // null = hali yuklanmoqda

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.instance.get(
        '/users/me/deletion-request/',
        (j) => j,
        auth: true,
      );
      if (mounted) setState(() => _pending = data != null);
    } catch (_) {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _openForm() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DeleteAccountForm(),
    );
    if (submitted == true && mounted) setState(() => _pending = true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    if (_pending == null) return const SizedBox.shrink();
    if (_pending == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          loc.t('profile_delete_account_pending'),
          style: const TextStyle(color: Color(0xFF8A7357), fontSize: 13),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton.icon(
        onPressed: _openForm,
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        icon: const Icon(Icons.delete_outline, size: 18),
        label: Text(loc.t('profile_delete_account_title')),
      ),
    );
  }
}

class _DeleteAccountForm extends StatefulWidget {
  const _DeleteAccountForm();

  @override
  State<_DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends State<_DeleteAccountForm> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post(
        '/users/me/deletion-request/',
        (j) => j,
        body: {'reason': reason},
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.t('profile_delete_account_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
          ),
          const SizedBox(height: 8),
          Text(
            loc.t('profile_delete_account_desc'),
            style: const TextStyle(color: Color(0xFF8A7357), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: loc.t('profile_delete_account_reason_placeholder'),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy || _reason.text.trim().isEmpty ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(loc.t('profile_delete_account_submit')),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                child: Text(loc.t('profile_delete_account_cancel')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
