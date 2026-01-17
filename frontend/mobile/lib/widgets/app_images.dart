import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_client.dart';

class AppNetImage extends StatelessWidget {
  final ApiClient? apiClient;
  final String? pathOrUrl;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  final String? fallbackLetter;
  final IconData fallbackIcon;

  /// Helps speed: decode smaller in memory
  final int? memCacheWidth;
  final int? memCacheHeight;

  const AppNetImage({
    super.key,
    required this.pathOrUrl,
    this.apiClient,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackLetter,
    this.fallbackIcon = Icons.image_not_supported,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  String? _resolve() {
    final p = pathOrUrl?.trim();
    if (p == null || p.isEmpty) return null;
    if (apiClient != null) return apiClient!.resolveImageUrl(p);
    // if no apiClient, accept only absolute URLs
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return null;
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: (fallbackLetter != null && fallbackLetter!.trim().isNotEmpty)
          ? Text(
              fallbackLetter!.trim(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            )
          : Icon(fallbackIcon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolve();
    if (url == null) {
      final w = _fallback();
      return borderRadius == null
          ? w
          : ClipRRect(borderRadius: borderRadius!, child: w);
    }

    final img = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => _fallback(),
    );

    return borderRadius == null
        ? img
        : ClipRRect(borderRadius: borderRadius!, child: img);
  }
}

class AppNetAvatar extends StatelessWidget {
  final ApiClient apiClient;
  final String? pathOrUrl;
  final double radius;

  final String fallbackLetter;
  final IconData fallbackIcon;

  const AppNetAvatar({
    super.key,
    required this.apiClient,
    required this.pathOrUrl,
    this.radius = 18,
    this.fallbackLetter = '?',
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    final url = apiClient.resolveImageUrl(pathOrUrl);
    final size = radius * 2;

    if (url == null || url.isEmpty) {
      return CircleAvatar(radius: radius, child: Text(fallbackLetter));
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        memCacheHeight: (size * 3).round(),
        placeholder: (_, __) => SizedBox(
          width: size,
          height: size,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => CircleAvatar(
          radius: radius,
          child: Text(fallbackLetter.isEmpty ? '?' : fallbackLetter),
        ),
      ),
    );
  }
}
