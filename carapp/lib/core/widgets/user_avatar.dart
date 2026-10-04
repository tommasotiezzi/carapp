import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/media_url.dart';
import '../supabase/supabase_client.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// A profile picture (`avatars` bucket), or the initials of [name].
/// Dealers without a picture get the blue background.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.path,
    required this.name,
    this.radius = 24,
    this.dealer = false,
    this.dark = false,
  });

  final String? path;
  final String name;
  final double radius;
  final bool dealer;

  /// Over the video (feed): dark grey instead of the light placeholder.
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No picture: no client needed (initials only).
    final url = (path ?? '').isEmpty ? null : MediaUrl.avatar(ref.read(supabaseProvider), path);
    final background = dealer ? AppColors.primary : (dark ? const Color(0xFF2C333C) : AppColors.placeholder);
    final initials = Text(
      Formatters.initials(name),
      style: TextStyle(
        color: dealer || dark ? Colors.white : AppColors.inkSecondary,
        fontWeight: FontWeight.w700,
        fontSize: radius * 0.6,
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: url == null
          ? initials
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth: (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round(),
                errorWidget: (_, _, _) => Center(child: initials),
              ),
            ),
    );
  }
}
