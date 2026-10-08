import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../locale_store.dart';
import '../theme.dart';

/// Ilova ochilishida ko'rsatiladigan brend ekrani — avval bosh sahifada
/// bekorchi turgan hero matn shu yerga ko'chirildi (iOS'dagi `HomeView` hero
/// bilan bir xil matn, lekin endi faqat bir martalik "brend taassuroti").
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleStore>();
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.deep, Color(0xFF6B4130)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.t('splash_badge'),
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.t('splash_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.t('splash_desc'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
