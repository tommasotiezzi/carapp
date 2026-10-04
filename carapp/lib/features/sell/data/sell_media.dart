import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Files and video work on the phone for the sell flow. Behind an
/// interface so tests run without the native editor.
abstract class SellMedia {
  /// The folder of one draft (created if missing).
  Future<Directory> draftDir(String draftId);

  Future<void> deleteDraftDir(String draftId);

  /// A JPEG frame of [video] at [at], written to [out].
  Future<void> thumbnail({
    required String video,
    required String out,
    required Size size,
    Duration at = const Duration(milliseconds: 800),
  });

  /// Joins [clips] in order with a short cross-dissolve into one MP4 at
  /// [out]. Returns its duration in ms. [onProgress] gets 0..1.
  Future<int> renderVideo({
    required String taskId,
    required List<String> clips,
    required String out,
    required int bitrate,
    required void Function(double progress) onProgress,
  });

  Future<void> cancel(String taskId);
}

/// Native implementation (`pro_video_editor`: Media3 on Android,
/// AVFoundation on iOS).
class NativeSellMedia implements SellMedia {
  static const transition = ClipTransition(
    type: ClipTransitionType.dissolve,
    duration: Duration(milliseconds: 600),
    curve: AnimationCurve.easeInOut,
  );

  ProVideoEditor get _editor => ProVideoEditor.instance;

  @override
  Future<Directory> draftDir(String draftId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/sell/$draftId');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<void> deleteDraftDir(String draftId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/sell/$draftId');
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  @override
  Future<void> thumbnail({
    required String video,
    required String out,
    required Size size,
    Duration at = const Duration(milliseconds: 800),
  }) async {
    final frames = await _editor.getThumbnails(ThumbnailConfigs(
      video: EditorVideo.file(File(video)),
      outputSize: size,
      timestamps: [at],
      outputFormat: ThumbnailFormat.jpeg,
      jpegQuality: 85,
    ));
    if (frames.isEmpty) throw StateError('No frame at $at in $video');
    await File(out).writeAsBytes(frames.first, flush: true);
  }

  @override
  Future<int> renderVideo({
    required String taskId,
    required List<String> clips,
    required String out,
    required int bitrate,
    required void Function(double progress) onProgress,
  }) async {
    final progress = _editor.progressStreamById(taskId).listen((p) => onProgress(p.progress));
    try {
      await _editor.renderVideoToFile(
        out,
        VideoRenderData(
          id: taskId,
          videoSegments: [
            for (var i = 0; i < clips.length; i++)
              VideoSegment(
                video: EditorVideo.file(File(clips[i])),
                // Ignored on the last clip.
                transition: transition,
              ),
          ],
          enableAudio: true,
          bitrate: bitrate,
          maxFrameRate: 30,
          // moov atom first: the feed can start playing before the end.
          shouldOptimizeForNetworkUse: true,
        ),
      );
    } finally {
      await progress.cancel();
    }
    final meta = await _editor.getMetadata(EditorVideo.file(File(out)));
    return meta.duration.inMilliseconds;
  }

  @override
  Future<void> cancel(String taskId) => _editor.cancel(taskId);
}

final sellMediaProvider = Provider<SellMedia>((ref) => NativeSellMedia());

/// Carousel photos: one from the camera or up to [limit] from the
/// gallery, long side at most [maxSide]. Paths of the picked files
/// (temporary copies); empty when cancelled.
typedef PhotoPicker = Future<List<String>> Function({
  required bool camera,
  required int limit,
  required int maxSide,
});

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ({required camera, required limit, required maxSide}) async {
    final picker = ImagePicker();
    final side = maxSide.toDouble();
    if (camera || limit < 2) {
      final file = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: side,
        maxHeight: side,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      return [?file?.path];
    }
    final files = await picker.pickMultiImage(
      maxWidth: side,
      maxHeight: side,
      imageQuality: 85,
      limit: limit,
      requestFullMetadata: false,
    );
    return [for (final f in files) f.path];
  },
);

/// Full path of a file in a draft folder: (draft id, file name).
final draftFilePathProvider = FutureProvider.autoDispose.family<String, (String, String)>((ref, key) async {
  final dir = await ref.watch(sellMediaProvider).draftDir(key.$1);
  return '${dir.path}/${key.$2}';
});
