import 'dart:async';

import 'game_event.dart';

class EventBus {
  final _controller = StreamController<GameEvent>.broadcast(sync: true);

  Stream<T> on<T extends GameEvent>() =>
      _controller.stream.where((e) => e is T).cast<T>();

  void fire(GameEvent event) => _controller.add(event);

  void dispose() => _controller.close();
}
