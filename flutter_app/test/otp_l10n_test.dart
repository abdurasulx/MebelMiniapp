import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_platform_mobile/l10n/app_locale.dart';
import 'package:furniture_platform_mobile/l10n/strings.dart';

/// OTP/rate-limit/davlat-ogohlantirish matnlari barcha 9 tilda mavjud
/// va (cooldown/urinish/countdown uchun) `%d` o'rinbosari saqlangan.
void main() {
  const keys = [
    'otp_err_cooldown', 'otp_err_hourly_limit', 'otp_err_country_unsupported',
    'otp_err_unavailable', 'otp_err_send_failed', 'otp_err_busy',
    'otp_err_expired', 'otp_err_attempts', 'otp_err_wrong',
    'otp_country_note', 'otp_resend_in', 'welcome_language',
    'welcome_nearby_title', 'welcome_delivery_title', 'welcome_ar_title',
  ];
  const withNumber = ['otp_err_cooldown', 'otp_err_wrong', 'otp_resend_in'];

  for (final l in supportedLocales) {
    test('${l.code}: OTP matnlari to\'liq', () {
      for (final k in keys) {
        final v = tr(l.code, k);
        expect(v, isNot(k), reason: '${l.code} da "$k" yo\'q');
        expect(v.trim(), isNotEmpty);
      }
      for (final k in withNumber) {
        expect(tr(l.code, k), contains('%d'), reason: '${l.code}/$k da %d yo\'q');
      }
    });
  }
}
