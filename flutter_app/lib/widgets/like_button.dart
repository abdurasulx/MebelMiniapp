import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_store.dart';
import '../likes_store.dart';

/// Yurakcha tugmasi — bosilganda serverga saqlanadi (iOS'dagi `LikeButton`
/// bilan bir xil vazifa). Tizimga kirilmagan bo'lsa hech narsa qilmaydi.
class LikeButton extends StatelessWidget {
  final String productId;
  final void Function(bool liked)? onToggled;
  const LikeButton({super.key, required this.productId, this.onToggled});

  @override
  Widget build(BuildContext context) {
    final likes = context.watch<LikesStore>();
    final isAuthenticated = context.watch<AuthStore>().isAuthenticated;
    final liked = likes.isLiked(productId);
    if (!isAuthenticated) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
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
