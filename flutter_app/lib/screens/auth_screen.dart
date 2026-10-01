import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';
import '../countries.dart';
import '../locale_store.dart';
import '../theme.dart';
import '../widgets/otp_box_input.dart';
import 'profile_screen.dart';

enum _Step { phone, code, profile }

// Har bir tugma faqat O'ZI bosilganda spinner ko'rsatishi uchun — bitta
// umumiy `_busy` bo'lsa, masalan Google bosilganda "Kod yuborish" tugmasi
// ham (aslida bosilmagan bo'lsa-da) spinner'ga aylanib qolardi (barcha
// tugmalar bitta flagga qarab spinner chizardi).
enum _BusyAction { otp, verify, google, telegram, profile }

/// Faqat telefon+SMS-OTP orqali kirish (email/parol olib tashlandi — bitta,
/// oddiy oqim). Bosqichlar: davlat+raqam → 6-xonali kod (qayta yuborish
/// countdown bilan) → (agar birinchi marta kirsa) ism/familiya so'raladi.
class AuthScreen extends StatefulWidget {
  final bool isTab;
  const AuthScreen({super.key, this.isTab = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _otpLength = 6; // backend OTPRequestView: 6 xonali kod

  CountryInfo _country = cisCountries.first;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _dob;
  String? _debugCode;
  _Step _step = _Step.phone;
  _BusyAction? _busyAction;
  bool get _busy => _busyAction != null;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onTextChanged);
    _firstNameController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _phoneController.removeListener(_onTextChanged);
    _firstNameController.removeListener(_onTextChanged);
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  String get _fullPhone =>
      '${_country.dialCode}${_phoneController.text.trim()}';

  // ignore: unused_element
  bool get _phoneValid => _country.isValid(_phoneController.text.trim());

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

  Future<void> _sendCode() async {
    setState(() => _busyAction = _BusyAction.otp);
    final auth = context.read<AuthStore>();
    final result = await auth.requestOTP(_fullPhone);
    setState(() {
      _busyAction = null;
      if (result != null) {
        _debugCode = result.debugCode;
        _step = _Step.code;
        _codeController.clear();
        _startCountdown(result.resendAfter);
      }
    });
  }

  Future<void> _verify(String code) async {
    setState(() => _busyAction = _BusyAction.verify);
    final auth = context.read<AuthStore>();
    final ok = await auth.verifyOTP(_fullPhone, code);
    setState(() => _busyAction = null);
    if (!ok) return;
    if (auth.isNewUser) {
      setState(() => _step = _Step.profile);
    } else {
      if (!widget.isTab && mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _busyAction = _BusyAction.profile);
    final auth = context.read<AuthStore>();
    final ok = await auth.completeProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      dateOfBirth: _dob != null
          ? '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
          : null,
    );
    setState(() => _busyAction = null);
    if (ok && mounted && !widget.isTab) Navigator.of(context).maybePop();
  }

  // ignore: unused_element
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

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final loc = context.watch<LocaleStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTab ? loc.t('profile_title') : loc.t('auth_title')),
        automaticallyImplyLeading: !widget.isTab,
        actions: [
          IconButton(
            icon: const Icon(Icons.language_rounded, color: AppColors.deep),
            tooltip: 'Language',
            onPressed: () => pickLanguage(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == _Step.phone) _phoneStep(loc),
            if (_step == _Step.code) _codeStep(loc),
            if (_step == _Step.profile) _profileStep(loc),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF8B4B4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFC81E1E), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.t(auth.errorMessage!),
                            style: const TextStyle(
                              color: Color(0xFF9B1C1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          if (auth.errorDetails != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              auth.errorDetails!,
                              style: TextStyle(
                                color: const Color(0xFF9B1C1C).withValues(alpha: 0.75),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _phoneStep(LocaleStore loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Branded VIDA Badge / Logo
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A4237), AppColors.deep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.deep.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'V',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          loc.t('auth_welcome_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.deep,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loc.t('auth_subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.deep.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF3C4043),
                  side: const BorderSide(color: Color(0xFFDADCE0), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busyAction == _BusyAction.google
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.deep,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/icons/google_logo.png',
                              width: 20, height: 20),
                          const SizedBox(width: 12),
                          Text(
                            loc.t('auth_google'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3C4043),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : _loginWithTelegram,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2F9FD),
                  foregroundColor: const Color(0xFF26A5E4),
                  side: const BorderSide(color: Color(0xFF26A5E4), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busyAction == _BusyAction.telegram
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF26A5E4),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/icons/telegram_logo.png',
                              width: 20, height: 20),
                          const SizedBox(width: 12),
                          Text(
                            loc.t('auth_telegram'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF26A5E4),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined,
                size: 15, color: AppColors.deep.withValues(alpha: 0.45)),
            const SizedBox(width: 6),
            Text(
              loc.t('auth_secure_note'),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.deep.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        /*
        // SMS provayder ulanganda ochiladi:
        const SizedBox(height: 20),
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
          child: _busyAction == _BusyAction.otp
              ? const CircularProgressIndicator()
              : Text(loc.t('auth_send_code')),
        ),
        */
      ],
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _busyAction = _BusyAction.google);
    final auth = context.read<AuthStore>();
    final ok = await auth.loginWithGoogle();
    setState(() => _busyAction = null);
    if (!ok || !mounted) return;
    if (auth.isNewUser) {
      // Google berilgan ism/familiya bo'lsa oldindan to'ldiramiz — foydalanuvchi
      // qayta yozib o'tirmasin.
      _firstNameController.text = auth.user?.firstName ?? '';
      _lastNameController.text = auth.user?.lastName ?? '';
      setState(() => _step = _Step.profile);
    } else {
      if (!widget.isTab) {
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _loginWithTelegram() async {
    setState(() => _busyAction = _BusyAction.telegram);
    final auth = context.read<AuthStore>();
    final ok = await auth.loginWithTelegram();
    if (!mounted) return;
    setState(() => _busyAction = null);
    if (!ok) return;
    if (auth.isNewUser) {
      _firstNameController.text = auth.user?.firstName ?? '';
      _lastNameController.text = auth.user?.lastName ?? '';
      setState(() => _step = _Step.profile);
    } else {
      if (!widget.isTab) {
        Navigator.of(context).maybePop();
      }
    }
  }

  Widget _codeStep(LocaleStore loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SMS provayder hali ulanmagan — dev rejimda kod shu yerda ko'rsatiladi.
        Text(
          _debugCode != null
              ? '${loc.t('auth_sms_sent')} ($_debugCode)'
              : loc.t('auth_sms_sent'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        OtpBoxInput(
          controller: _codeController,
          length: _otpLength,
          onCompleted: (code) {
            if (!_busy) _verify(code);
          },
        ),
        const SizedBox(height: 16),
        if (_busy) const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _resendSeconds > 0 || _busy ? null : _sendCode,
            child: Text(
              _resendSeconds > 0
                  ? '${loc.t('auth_resend')} (${_resendSeconds}s)'
                  : loc.t('auth_resend'),
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _step = _Step.phone),
            child: Text(loc.t('auth_change_number')),
          ),
        ),
      ],
    );
  }

  Widget _profileStep(LocaleStore loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.t('auth_profile_title'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: loc.t('auth_first_name'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: loc.t('auth_last_name'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDob,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: loc.t('auth_dob'),
              border: const OutlineInputBorder(),
            ),
            child: Text(
              _dob != null
                  ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
                  : '',
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _busy || _firstNameController.text.trim().isEmpty
              ? null
              : _saveProfile,
          child: _busy
              ? const CircularProgressIndicator()
              : Text(loc.t('auth_save')),
        ),
      ],
    );
  }
}
