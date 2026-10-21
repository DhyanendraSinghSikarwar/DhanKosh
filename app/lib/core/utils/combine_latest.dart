import 'dart:async';

/// Emits `combine(latest values)` whenever any of [sources] emits, once every
/// source has emitted at least once. Closes when all sources close; pausing
/// is not forwarded (listeners here are UI providers).
Stream<R> combineLatest<R>(
  List<Stream<Object?>> sources,
  R Function(List<Object?> values) combine,
) {
  late StreamController<R> controller;
  final subs = <StreamSubscription<Object?>>[];
  controller = StreamController<R>(
    onListen: () {
      final latest = List<Object?>.filled(sources.length, null);
      final seen = List<bool>.filled(sources.length, false);
      var open = sources.length;
      for (var i = 0; i < sources.length; i++) {
        subs.add(
          sources[i].listen(
            (v) {
              latest[i] = v;
              seen[i] = true;
              if (seen.every((s) => s)) {
                try {
                  controller.add(combine(List.of(latest)));
                } on Object catch (e, st) {
                  controller.addError(e, st);
                }
              }
            },
            onError: controller.addError,
            onDone: () {
              if (--open == 0) unawaited(controller.close());
            },
          ),
        );
      }
      if (sources.isEmpty) unawaited(controller.close());
    },
    onCancel: () => Future.wait(subs.map((s) => s.cancel())),
  );
  return controller.stream;
}
