import 'dart:async';

/// Switches immediately when the outer stream changes; stale inner events
/// cannot leak across sign-out/account changes.
Stream<R> switchLatest<T, R>(Stream<T> source, Stream<R> Function(T) project) {
  late StreamController<R> controller;
  StreamSubscription<T>? outer;
  StreamSubscription<R>? inner;
  var generation = 0;
  var cancelled = false;
  var outerDone = false;
  var switching = false;
  controller = StreamController<R>(
    onListen: () {
      outer = source.listen(
        (value) async {
          final current = ++generation;
          switching = true;
          final previous = inner;
          inner = null;
          await previous?.cancel();
          if (cancelled || current != generation) return;
          switching = false;
          try {
            inner = project(value).listen(
              (event) {
                if (!cancelled && current == generation) controller.add(event);
              },
              onError: (Object e, StackTrace st) {
                if (!cancelled && current == generation)
                  controller.addError(e, st);
              },
              onDone: () {
                if (current == generation) {
                  inner = null;
                  if (outerDone && !cancelled) controller.close();
                }
              },
            );
          } catch (e, st) {
            if (!cancelled && current == generation) controller.addError(e, st);
            if (outerDone && !cancelled) controller.close();
          }
        },
        onError: controller.addError,
        onDone: () {
          outerDone = true;
          if (inner == null && !switching && !cancelled) controller.close();
        },
      );
    },
    onCancel: () async {
      cancelled = true;
      generation++;
      await outer?.cancel();
      await inner?.cancel();
    },
  );
  return controller.stream;
}
