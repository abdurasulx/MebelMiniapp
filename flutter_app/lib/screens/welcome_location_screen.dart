import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../locale_store.dart';
import '../location_store.dart';
import '../theme.dart';
import '../viloyat.dart';

/// Birinchi ishga tushirish: joylashuvdan foydalanish YOKI viloyatni qo'lda
/// tanlash. Joylashuv ixtiyoriy — foydalanuvchi har doim viloyat tanlab davom
/// etishi mumkin (iOS `WelcomeLocationView` bilan bir xil oqim).
class WelcomeLocationScreen extends StatefulWidget {
  const WelcomeLocationScreen({super.key});

  @override
  State<WelcomeLocationScreen> createState() => _WelcomeLocationScreenState();
}

class _WelcomeLocationScreenState extends State<WelcomeLocationScreen> {
  bool _region = false;
  bool _busy = false;

  Future<void> _useLocation(LocationStore location) async {
    setState(() => _busy = true);
    await location.detectFromGps();
    if (!mounted) return;
    setState(() => _busy = false);
    if (location.hasFix) {
      await location.completeOnboarding();
    } else {
      // Ruxsat berilmadi / GPS yo'q — viloyat tanlashga o'tamiz.
      setState(() => _region = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    final location = context.watch<LocationStore>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
          child:
              _region ? _regionList(loc, location) : _welcome(loc, location)),
    );
  }

  Widget _welcome(LocaleStore loc, LocationStore location) {
    Widget benefit(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.brand, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5))),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.chair_rounded, color: AppColors.onBrand),
          ),
          const SizedBox(height: 24),
          Text(loc.t('welcome_title'),
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 10),
          Text(loc.t('welcome_subtitle'),
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          benefit(Icons.location_on_rounded, loc.t('welcome_privacy')),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _useLocation(location),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
              label: Text(loc.t('welcome_use_location')),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: _busy ? null : () => setState(() => _region = true),
              child: Text(loc.t('welcome_choose_region')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _regionList(LocaleStore loc, LocationStore location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _region = false),
            ),
            Text(loc.t('welcome_region_title'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.public_rounded),
                title: Text(loc.t('home_all')),
                onTap: () async {
                  await location.setViloyat(null);
                  await location.completeOnboarding();
                },
              ),
              for (final v in viloyatlar)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(v.label),
                  onTap: () async {
                    await location.setViloyat(v.code);
                    await location.completeOnboarding();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
