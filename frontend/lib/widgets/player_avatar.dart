import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// The player's square in clause slots and cards: the official LALIGA picture when the sync found one
/// (`Clause.playerImageUrl`), otherwise the football placeholder. The picture is loaded asynchronously
/// through Flutter's image cache (one download per URL), and while it loads or if it fails the
/// placeholder stays, so the square is always exactly `size` and nothing ever shows an error.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.iconSize,
    this.backgroundColor = AppColors.surfaceHighest,
  });

  final String? imageUrl;
  final double size;
  final double iconSize;
  final Color backgroundColor;

  static const _radius = 8.0;

  /// Only absolute http(s) URLs are loaded; anything else shows the placeholder.
  static bool isLoadable(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(Icons.sports_soccer_rounded,
        color: AppColors.textSecondary, size: iconSize);
    final url = imageUrl;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: backgroundColor, borderRadius: BorderRadius.circular(_radius)),
      child: !isLoadable(url)
          ? placeholder
          : Image.network(
              url!.trim(),
              width: size,
              height: size,
              // LALIGA's pictures are square head-and-shoulders PNGs on a transparent background: cover the
              // square, keeping the head in view.
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
              // Placeholder until the first frame is ready, so there is never an empty square.
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                  wasSynchronouslyLoaded || frame != null ? child : placeholder,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
    );
  }
}
