import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';
import '../countries.dart';
import '../locale_store.dart';
import '../theme.dart';

/// Faqat telefon+SMS-OTP orqali kirish (email/parol olib tashlandi — bitta,
/// oddiy oqim). Raqam kiritishdan oldin davlat (MDH) tanlanadi, tanlangan
/// kod raqamga avtomatik qo'shiladi.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _otpLength = 6; // backend OTPRequestView: 6 xonali kod

  CountryInfo _country = cisCountries.first;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _debugCode;
  bool _codeStep = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Tugmalar matn holatiga qarab yoqiladi (bo'sh bo'lmasa) — controller
    // o'zgarishi build()ni avtomatik qayta chaqirmagani uchun qo'lda tinglaymiz.
    _phoneController.addListener(_onTextChanged);
    _codeController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _phoneController.removeListener(_onTextChanged);
    _codeController.removeListener(_onTextChanged);
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _fullPhone =>
      '${_country.dialCode}${_phoneController.text.trim()}';

  bool get _phoneValid => _country.isValid(_phoneController.text.trim());

  Future<void> _sendCode() async {
    setState(() => _busy = true);
    final auth = context.read<AuthStore>();
    final code = await auth.requestOTP(_fullPhone);
    setState(() {
      _busy = false;
      if (auth.errorMessage == null) {
        _debugCode = code;
        _codeStep = true;
      }
    });
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final auth = context.read<AuthStore>();
    await auth.verifyOTP(_fullPhone, _codeController.text.trim());
    setState(() => _busy = false);
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
        _phoneController.text = _phoneController.text.substring(
          0,
          selected.phoneLength,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final loc = context.watch<LocaleStore>();
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('auth_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_codeStep) ...[
              Text(
                loc.t('auth_select_country'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF8A7357),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickCountry,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Text(_country.flag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${_country.name} (${_country.dialCode})'),
                      ),
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
                  labelText: loc.t('auth_phone_hint'),
                  prefixText: '${_country.dialCode} ',
                  border: const OutlineInputBorder(),
                  helperText:
                      '${_phoneController.text.length}/${_country.phoneLength}',
                  errorText: _phoneController.text.isNotEmpty && !_phoneValid
                      ? loc.t('auth_phone_invalid')
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy || !_phoneValid ? null : _sendCode,
                child: _busy
                    ? const CircularProgressIndicator()
                    : Text(loc.t('auth_send_code')),
              ),
            ] else ...[
              // SMS provayder hali ulanmagan — dev rejimda kod shu yerda ko'rsatiladi.
              Text(
                _debugCode != null
                    ? '${loc.t('auth_sms_sent')} ($_debugCode)'
                    : loc.t('auth_sms_sent'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 10),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_otpLength),
                ],
                decoration: InputDecoration(
                  labelText: loc.t('auth_code_hint'),
                  border: const OutlineInputBorder(),
                  helperText: '${_codeController.text.length}/$_otpLength',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy || _codeController.text.length != _otpLength
                    ? null
                    : _verify,
                child: _busy
                    ? const CircularProgressIndicator()
                    : Text(loc.t('auth_verify')),
              ),
              TextButton(
                onPressed: () => setState(() => _codeStep = false),
                child: Text(loc.t('auth_change_number')),
              ),
            ],
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
