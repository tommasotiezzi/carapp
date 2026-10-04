import 'package:carapp/core/media/shared_video.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the player lives until the last holder releases it (feed -> listing handoff)', () {
    final video = SharedVideo('https://cdn.example/v.mp4'); // the feed's hold
    final lent = video.retain(); // lent while the listing page is open
    final header = lent.retain(); // the listing header's hold

    video.release(); // the feed scrolled away meanwhile
    expect(video.isDisposed, isFalse, reason: 'the listing still plays it');
    header.release(); // listing closed
    expect(video.isDisposed, isFalse);
    lent.release(); // the feed's lend ends
    expect(video.isDisposed, isTrue);

    lent.release(); // extra releases are ignored
    expect(video.isDisposed, isTrue);
  });
}
