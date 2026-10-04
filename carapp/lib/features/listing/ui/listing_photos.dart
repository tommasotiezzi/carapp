import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_url.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/tokens.dart';
import '../data/listing_detail.dart';

/// Horizontal strip of photos; tap opens them full screen.
class ListingPhotoStrip extends ConsumerWidget {
  const ListingPhotoStrip({super.key, required this.photos});

  final List<ListingPhoto> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(supabaseProvider);
    final urls = [for (final p in photos) MediaUrl.resolve(client, p.storagePath)!];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => _PhotoViewer(urls: urls, initialIndex: i),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.m),
            child: CachedNetworkImage(
              imageUrl: urls[i],
              width: 104,
              height: 132,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: AppColors.placeholder),
              errorWidget: (_, _, _) => const ColoredBox(color: AppColors.placeholder),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(imageUrl: widget.urls[i], fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.l),
                  child: Text(
                    '${_index + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
