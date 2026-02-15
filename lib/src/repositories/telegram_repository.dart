// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart';

class TelegramRepository {
  TelegramRepository(
    this._teledart,
    this._botToken,
  );
  final TeleDart _teledart;
  final String _botToken;

  Future<User> getMe() async {
    return _teledart.getMe();
  }

  Future<void> sendMessage(
    dynamic chatId,
    String text, {
    int? replyToMessageId,
  }) async {
    await _teledart.sendMessage(chatId, text,
        replyToMessageId: replyToMessageId);
  }

  Future<int?> createTopic(dynamic chatId, String name) async {
    try {
      final url =
          Uri.parse('https://api.telegram.org/bot$_botToken/createForumTopic');

      final request = await HttpClient().postUrl(url);
      request.headers.contentType = ContentType.json;

      // Request Body
      final body = jsonEncode({
        'chat_id': chatId,
        'name': name,
      });
      request.write(body);

      // Response Handling
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (json['ok'] == true) {
        final result = json['result'] as Map<String, dynamic>;
        return result['message_thread_id'] as int?;
      } else {
        print('⚠️ Telegram Error: ${json['description']}');
        return null;
      }
    } catch (e) {
      print('❌ Native HTTP Error: $e');
      return null;
    }
  }

  Future<void> sendMessageToTopic(
    dynamic chatId,
    int topicId,
    String text,
  ) async {
    await _teledart.sendMessage(chatId, text, messageThreadId: topicId);
  }

  // 3. Forward Message to Topic
  Future<Message> forwardToTopic(
      dynamic chatId, int fromChatId, int messageId, int topicId) async {
    return _teledart.forwardMessage(
      chatId,
      fromChatId,
      messageId,
      messageThreadId: topicId,
    );
  }

  Future<Message> forwardToGeneral(
    dynamic chatId,
    int fromChatId,
    int messageId,
  ) async {
    return _teledart.forwardMessage(chatId, fromChatId, messageId);
  }

  Future<void> editMessageCaption(dynamic chatId, int messageId,
      {required String caption}) async {
    await _teledart.editMessageCaption(
      caption: caption,
      chatId: chatId,
      messageId: messageId,
    );
  }

  Stream<TeleDartMessage> get onMessage => _teledart.onMessage();

  Stream<TeleDartMessage> onCommand(String command) =>
      _teledart.onCommand(command);
}
