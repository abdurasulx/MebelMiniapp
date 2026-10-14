import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_platform_mobile/api_client.dart';
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
    'err_bad_request', 'err_login_required', 'err_forbidden', 'err_not_found',
    'err_conflict', 'err_too_many', 'err_server', 'err_unknown', 'err_offline',
    'err_decoding', 'welcome_nearby_title', 'welcome_delivery_title', 'welcome_ar_title',
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

  test('xom xato matnlari foydalanuvchiga ko\'rsatilmaydi', () {
    for (final raw in [
      'Not found.', 'cancelled', 'Xatolik yuz berdi (404)', '404',
      'SocketException: Failed host lookup', "type 'Null' is not a subtype",
      'Ошибка 500',
    ]) {
      expect(isRawErrorText(raw), isTrue, reason: raw);
    }
    for (final ok in ["Kod noto'g'ri. 3 ta urinish qoldi", "Ma'lumot topilmadi"]) {
      expect(isRawErrorText(ok), isFalse, reason: ok);
    }
    ApiClient.localeCode = 'en';
    expect(friendlyError(ApiException('Not found.', statusCode: 404)),
        'Something went wrong. Please try again');
    expect(friendlyError(const FormatException('bad')), "Couldn't read the data. Please try again");
    ApiClient.localeCode = 'uz';
  });
}
