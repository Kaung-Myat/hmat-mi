import 'dart:async';

import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart' as teledart_pkg;

class DartFrogWebhookFetcher extends teledart_pkg.Event {
  DartFrogWebhookFetcher() : super('');
  final StreamController<Update> _controller = StreamController.broadcast();

  Stream<Update> get onUpdate => _controller.stream;

  Future<void> start() async {}

  Future<void> stop() async {
    await _controller.close();
  }

  void addUpdate(Update update) {
    _controller.add(update);
  }
}
