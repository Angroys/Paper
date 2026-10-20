import 'dart:async';

/// A stream that emits [current]() on listen, then every event of
/// [changes]. Subscribes to [changes] synchronously on listen, so no event
/// fired right after `listen` is lost (unlike an `async*` generator).
Stream<T> currentThenChanges<T>(T Function() current, Stream<T> changes) {
  late StreamController<T> controller;
  StreamSubscription<T>? sub;
  controller = StreamController<T>(
    onListen: () {
      controller.add(current());
      sub = changes.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}
