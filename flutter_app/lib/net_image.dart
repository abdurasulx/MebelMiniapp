import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// `Image.network` o'rniga: rasm DISKDA keshlanadi (qayta ochilganda internetsiz va
/// tez chiqadi), shu bilan birga `Image.network` bilan bir xil parametrlar.
Image netImage(
  String url, {
  BoxFit? fit,
  double? width,
  double? height,
  ImageLoadingBuilder? loadingBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
}) =>
    Image(
      image: CachedNetworkImageProvider(url),
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
