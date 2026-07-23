import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'models.dart';

/// Sevimlilar holati — serverda saqlanadi, qaysi qurilmadan kirsa ham bir xil
/// (iOS'dagi `LikesStore` bilan bir xil naqsh).
class LikesStore extends ChangeNotifier {
  final Set<String> _likedIds = {};

  bool isLiked(String productId) => _likedIds.contains(productId);

  void sync(List<Product> products) {
    for (final p in products) {
      if (p.isLiked) _likedIds.add(p.id);
    }
  }

  void clear() {
    _likedIds.clear();
    notifyListeners();
  }

  Future<void> toggle(String productId) async {
    try {
      final res = await ApiClient.instance.post(
        '/likes/toggle/',
        (j) => j as Map<String, dynamic>,
        body: {'product': productId},
        auth: true,
      );
      if (res['liked'] == true) {
        _likedIds.add(productId);
      } else {
        _likedIds.remove(productId);
      }
      notifyListeners();
    } catch (_) {
      // jim turamiz — UI holati o'zgarmaydi
    }
  }
}
