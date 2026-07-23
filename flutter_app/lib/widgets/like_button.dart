import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';
import '../likes_store.dart';
import '../screens/auth_screen.dart';

/// Yurakcha tugmasi — bosilganda serverga saqlanadi (iOS'dagi `LikeButton`
/// bilan bir xil vazifa). Tizimga kirilmagan bo'lsa ham har doim ko'rinadi —
/// bosilganda kirish ekraniga yo'naltiradi (avval faqat login qilinganda
/// ko'rinar edi, shu sabab foydalanuvchi uni umuman topa olmagan edi).
class LikeButton extends StatelessWidget {
  final String productId;
  final void Function(bool liked)? onToggled;
  const LikeButton({super.key, required this.productId, this.onToggled});

  @override
  Widget build(BuildContext context) {
    final likes = context.watch<LikesStore>();
    final isAuthenticated = context.watch<AuthStore>().isAuthenticated;
    final liked = likes.isLiked(productId);
    return GestureDetector(
      onTap: () async {
        if (!isAuthenticated) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
          return;
        }
        await context.read<LikesStore>().toggle(productId);
        onToggled?.call(context.read<LikesStore>().isLiked(productId));
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 16,
          color: liked ? const Color(0xFFE74C3C) : Colors.black45,
        ),
      ),
    );
  }
}
