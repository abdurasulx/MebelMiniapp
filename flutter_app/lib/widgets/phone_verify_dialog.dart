import 'package:flutter/material.dart';
import '../api_client.dart';

/// Google/Telegram orqali kirgan-u hali telefonini tasdiqlamagan
/// foydalanuvchi buyurtma berishga urinsa backend 403 qaytaradi (qarang
/// OrderViewSet.perform_create) — shu modal ochilib, SMS-kod bilan
/// tasdiqlangach `true` bilan yopiladi (chaqiruvchi buyurtmani qayta yuboradi).
Future<bool?> showPhoneVerifyDialog(
  BuildContext context, {
  String? initialPhone,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PhoneVerifySheet(initialPhone: initialPhone),
  );
}

class _PhoneVerifySheet extends StatefulWidget {
  final String? initialPhone;
  const _PhoneVerifySheet({this.initialPhone});

  @override
  State<_PhoneVerifySheet> createState() => _PhoneVerifySheetState();
}

class _PhoneVerifySheetState extends State<_PhoneVerifySheet> {
  late final _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _debugCode;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onTextChanged);
    _codeCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onTextChanged);
    _codeCtrl.removeListener(_onTextChanged);
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resp = await ApiClient.instance.post(
        '/users/me/phone/request-otp/',
        (j) => j as Map<String, dynamic>,
        body: {'phone': _phoneCtrl.text.trim()},
      );
      setState(() {
        _codeSent = true;
        _debugCode = resp['debug_code'] as String?;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post(
        '/users/me/phone/verify-otp/',
        (j) => j as Map<String, dynamic>,
        body: {'phone': _phoneCtrl.text.trim(), 'code': _codeCtrl.text.trim()},
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Telefon raqamini tasdiqlang',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Buyurtma berishdan oldin telefon raqamingizni SMS-kod bilan tasdiqlashingiz kerak.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF8A7357)),
          ),
          const SizedBox(height: 16),
          if (!_codeSent) ...[
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: _busy || _phoneCtrl.text.trim().isEmpty ? null : _requestCode,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Kod yuborish'),
            ),
          ] else ...[
            if (_debugCode != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Dev rejim — kod: $_debugCode',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A7357)),
                ),
              ),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'SMS-kod',
                border: OutlineInputBorder(),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _codeSent = false),
              child: const Text('Raqamni o\'zgartirish'),
            ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: _busy || _codeCtrl.text.trim().isEmpty ? null : _confirmCode,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Tasdiqlash'),
            ),
          ],
        ],
      ),
    );
  }
}
