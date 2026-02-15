import 'dart:async';

import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

class DartFrogWebhookFetcher extends LongPolling {
  DartFrogWebhookFetcher({required Telegram telegram}) : super(telegram);

  final StreamController<Update> _controller = StreamController.broadcast();

  @override
  Stream<Update> onUpdate() {
    return _controller.stream;
  }

  @override
  Future<void> start() async {
    // Webhook မို့လို့ Polling ကို ပိတ်ထားတာ မှန်ပါတယ်
  }

  @override
  Future<void> stop() async {
    await _controller.close();
  }

  void addUpdate(Update update) {
    _controller.add(update);
  }
}
