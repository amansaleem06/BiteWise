import 'dart:async';
import 'package:bitewise/core/utils/switch_latest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign-out replaces an infinite profile stream and ignores old events',
      () async {
    final auth = StreamController<String?>();
    final oldProfile = StreamController<String>();
    final events = <String?>[];
    final subscription = switchLatest<String?, String?>(
      auth.stream,
      (uid) => uid == null ? Stream.value(null) : oldProfile.stream,
    ).listen(events.add);
    auth.add('first');
    await Future<void>.delayed(Duration.zero);
    oldProfile.add('first profile');
    await Future<void>.delayed(Duration.zero);
    auth.add(null);
    await Future<void>.delayed(Duration.zero);
    oldProfile.add('stale profile');
    await Future<void>.delayed(Duration.zero);
    expect(events, ['first profile', null]);
    await subscription.cancel();
    await auth.close();
    await oldProfile.close();
  });
  test('rapid account changes only emit the latest profile', () async {
    final auth = StreamController<String>();
    final events = <String>[];
    final subscription =
        switchLatest(auth.stream, (String uid) => Stream.value(uid))
            .listen(events.add);
    auth.add('one');
    auth.add('two');
    auth.add('three');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(events.last, 'three');
    await subscription.cancel();
    await auth.close();
  });
}
