import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../countries.dart';
import '../theme.dart';
import 'otp_box_input.dart';

/// Google/Telegram orqali kirgan-u hali telefonini tasdiqlamagan
/// foydalanuvchi buyurtma berishga urinsa backend 403 qaytaradi (qarang
/// OrderViewSet.perform_create) — shu modal ochilib, SMS-kod bilan
/// tasdiqlangach `true` bilan yopiladi (chaqiruvchi buyurtmani qayta yuboradi).
///
/// OTP orqali kirish ekrani (auth_screen.dart) bilan bir xil naqsh: davlat
/// tanlagich + kod prefiksli/uzunlik-cheklangan raqam maydoni, 6-katakli
/// SMS-kod kiritish (OtpBoxInput), qayta yuborish countdown'i.
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
  static const _otpLength = 6;

  CountryInfo _country = cisCountries.first;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _debugCode;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    // Backend'dan qaytgan `phone` odatda davlat kodi bilan birga keladi
    // (masalan "+998901234567") — shuni mos davlat/mahalliy raqamga
    // ajratamiz, aks holda oddiy mahalliy raqam sifatida qoldiramiz.
    final initial = widget.initialPhone ?? '';
    for (final c in cisCountries) {
      if (initial.startsWith(c.dialCode)) {
        _country = c;
        _phoneController.text = initial.substring(c.dialCode.length);
        break;
      }
    }
    _phoneController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _phoneController.removeListener(_onTextChanged);
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _phoneValid => _country.isValid(_phoneController.text.trim());
  String get _fullPhone => '${_country.dialCode}${_phoneController.text.trim()}';

  void _startCountdown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<CountryInfo>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: cisCountries
              .map(
                (c) => ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(c.name),
                  trailing: Text(c.dialCode),
                  onTap: () => Navigator.pop(ctx, c),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      _country = selected;
      if (_phoneController.text.length > selected.phoneLength) {
        _phoneController.text = _phoneController.text.substring(0, selected.phoneLength);
      }
    });
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
        body: {'phone': _fullPhone},
      );
      setState(() {
        _codeSent = true;
        _codeController.clear();
        _debugCode = resp['debug_code'] as String?;
      });
      _startCountdown((resp['resend_after'] as int?) ?? 60);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCode(String code) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post(
        '/users/me/phone/verify-otp/',
        (j) => j as Map<String, dynamic>,
        body: {'phone': _fullPhone, 'code': code},
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
            InkWell(
              onTap: _pickCountry,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Text(_country.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${_country.name} (${_country.dialCode})')),
                    const Icon(Icons.expand_more_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_country.phoneLength),
              ],
              decoration: InputDecoration(
                labelText: 'Telefon',
                prefixText: '${_country.dialCode} ',
                border: const OutlineInputBorder(),
                helperText: '${_phoneController.text.length}/${_country.phoneLength}',
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: _busy || !_phoneValid ? null : _requestCode,
              child: _busy ? const CircularProgressIndicator() : const Text('Kod yuborish'),
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
            OtpBoxInput(
              controller: _codeController,
              length: _otpLength,
              onCompleted: (code) {
                if (!_busy) _confirmCode(code);
              },
            ),
            const SizedBox(height: 12),
            if (_busy) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => setState(() => _codeSent = false),
                  child: const Text("Raqamni o'zgartirish"),
                ),
                TextButton(
                  onPressed: _resendSeconds > 0 || _busy ? null : _requestCode,
                  child: Text(
                    _resendSeconds > 0 ? 'Qayta yuborish (${_resendSeconds}s)' : 'Qayta yuborish',
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}
