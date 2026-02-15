import 'dart:async'; // Add this for Completer
import 'dart:io';
import 'package:hmat_mi/src/models/note_model.dart'; // Import NoteModel
import 'package:hmat_mi/src/models/user_model.dart';
import 'package:hmat_mi/src/repositories/gemini_repository.dart';
import 'package:hmat_mi/src/repositories/note_repository.dart';
import 'package:hmat_mi/src/repositories/telegram_repository.dart';
import 'package:hmat_mi/src/repositories/user_repository.dart';
import 'package:logger/logger.dart';
import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart';

class BotService {
  BotService({
    required this.telegramRepo,
    required this.userRepo,
    required this.teledart,
    required this.geminiRepo,
    required this.botName,
    required this.botToken,
    required this.logger,
    required this.noteRepo,
  });

  final TelegramRepository telegramRepo;
  final UserRepository userRepo;
  final TeleDart teledart;
  final String botName;
  final String botToken;
  final Logger logger;
  final NoteRepository noteRepo;
  final GeminiRepository geminiRepo;

  final Map<String, Future<int?>> _topicCreationLocks = {};

  void start() {
    teledart.onCommand('connect').listen(_handleConnectCommand);
    teledart.onCommand('start').listen(_handleStartCommand);
    teledart.onCommand('search').listen(_handleSearchCommand);
    teledart.onMessage(entityType: '*').listen(_handleIncomingMessage);

    logger.i('🤖 Bot Service Started and Listening...');
  }

  Future<void> _handleConnectCommand(TeleDartMessage message) async {
    if (message.chat.type == 'private') {
      await message
          .reply('⚠️ ဒီ Command ကို သင့်ရဲ့ Vault Group ထဲမှာ ရိုက်ထည့်ပေးပါ။');
      return;
    }

    final userId = message.from?.id;
    if (userId == null) return;

    var user = await userRepo.getUser(userId);
    if (user != null) {
      user = user.copyWith(vaultChannelId: message.chat.id);
      await userRepo.saveUser(user);

      logger.i('Vault Linked: ${message.chat.id} by User: $userId');
      await message.reply(
        parseMode: 'Markdown',
        '🎉 **Connection Success!**\nGroup ("${message.chat.title}") is now your Vault.',
      );
    } else {
      await message.reply('❌ Please /start in private chat first.');
    }
  }

  Future<void> _handleStartCommand(TeleDartMessage message) async {
    if (message.chat.type != 'private') return;

    final user = await userRepo.getUser(message.chat.id);
    if (user == null) {
      await message.reply(
          'မင်္ဂလာပါ! Hmat-Mi မှ ကြိုဆိုပါတယ်။\nသင့်ရဲ့ Gemini API Key ကို ပို့ပေးပါ။');
    } else {
      await message.reply('Welcome back! Data ရှိပြီးသားပါ။');
    }
  }

  Future<void> _handleIncomingMessage(TeleDartMessage message) async {
    if (message.chat.type != 'private') return;
    if (message.text?.startsWith('/') ?? false) return;

    final userId = message.chat.id;
    final user = await userRepo.getUser(userId);

    if (user == null || user.encryptedApiKey == null) {
      await _handleApiKeySetup(userId, message);
    } else if (user.vaultChannelId == null) {
      await message.reply(
          parseMode: 'Markdown',
          '⚠️ **Vault Setup မပြီးသေးပါ**\nGroup ထဲသွားပြီး **/connect** လုပ်ပေးပါ။');
    } else {
      await _handleNoteTaking(user, message);
    }
  }

  Future<void> _handleApiKeySetup(int userId, TeleDartMessage message) async {
    final text = message.text?.trim() ?? '';
    if (text.startsWith('AIza') && text.length > 20) {
      try {
        await userRepo.saveApiKey(userId, text);
        await message.reply(
            '✅ API Key Saved!\nNext: Create Group -> Add Bot as Admin -> Type /connect inside Group.');
      } catch (e) {
        await message.reply('❌ Error: $e');
      }
    } else {
      await message.reply('⚠️ Invalid API Key format. Must start with "AIza".');
    }
  }

  Future<void> _handleSearchCommand(TeleDartMessage message) async {
    final query = message.text?.replaceFirst('/search ', '').trim() ?? '';
    if (query.isEmpty) {
      await message
          .reply('🔍 ဘာရှာချင်တာလဲ? ရိုက်ထည့်ပါ (Example: /search flutter)');
      return;
    }

    final results = await noteRepo.search(query);

    if (results.isEmpty) {
      await message.reply('❌ "$query" နဲ့ပတ်သက်ပြီး ဘာမှ မမှတ်ထားပါဘူး။');
    } else {
      var response = '🔍 **Found ${results.length} results:**\n\n';

      for (final note in results.take(10)) {
        final icon = _getIcon(note.type);
        // ignore: use_string_buffers
        response +=
            '$icon [${note.topic}] ${note.content.length > 30 ? "${note.content.substring(0, 30)}..." : note.content}\n🔗 ${note.messageLink}\n\n';
      }

      await message.reply(response, parseMode: 'Markdown');
    }
  }

  String _getIcon(String type) {
    if (type == 'image') return '🖼️';
    if (type == 'video') return '🎥';
    return '📝';
  }

  Future<void> _handleNoteTaking(
    UserModel user,
    TeleDartMessage message,
  ) async {
    final vaultId = user.vaultChannelId!;
    final targetTopic = _determineTopic(message);
    final topicId = await _getSafeTopicId(user, targetTopic, vaultId);

    try {
      if (topicId != null) {
        final forwardedMsg = await telegramRepo.forwardToTopic(
          vaultId,
          user.id,
          message.messageId,
          topicId,
        );

        logger.i('Note saved to $targetTopic (ID: $topicId)');

        final linkId = vaultId.toString().replaceAll('-100', '');
        final messageLink = 'https://t.me/c/$linkId/${forwardedMsg.messageId}';

        final note = NoteModel(
          messageId: forwardedMsg.messageId,
          content: message.caption ?? message.text ?? 'Media File',
          topic: targetTopic,
          type: message.photo != null ? 'image' : 'text',
          createdAt: DateTime.now(),
          messageLink: messageLink,
        );
        await noteRepo.indexNote(note);
        logger.i('✅ Note indexed: ${note.messageId}');
        if (message.photo != null && message.photo!.isNotEmpty) {
          // Run in background (don't await to keep bot fast)
          _processOCR(user, forwardedMsg, message.photo!.last, note);
        }
      } else {
        await telegramRepo.forwardToGeneral(
            vaultId, user.id, message.messageId);
        logger.w('Failed to get Topic ID, saved to General');
      }

      await telegramRepo.sendMessage(user.id, '✅ Saved');
    } catch (e) {
      if (e.toString().contains('message thread not found') ||
          e.toString().contains('Bad Request')) {
        logger.w('⚠️ Topic deleted manually! Re-creating: $targetTopic');

        final cleanTopics = Map<String, int>.from(user.topicIds)
          ..remove(targetTopic);
        // ignore: parameter_assignments
        user = user.copyWith(topicIds: cleanTopics);
        await userRepo.saveUser(user);

        final newTopicId =
            await _createAndSaveTopic(user, targetTopic, vaultId);
        if (newTopicId != null) {
          // Retry forwarding
          final forwardedMsg = await telegramRepo.forwardToTopic(
              vaultId, user.id, message.messageId, newTopicId);

          // Retry Indexing
          final linkId = vaultId.toString().replaceAll('-100', '');
          final messageLink =
              'https://t.me/c/$linkId/${forwardedMsg.messageId}';

          final note = NoteModel(
            messageId: forwardedMsg.messageId,
            content: message.caption ?? message.text ?? 'Media File',
            topic: targetTopic,
            type: message.photo != null ? 'image' : 'text',
            createdAt: DateTime.now(),
            messageLink: messageLink,
          );
          await noteRepo.indexNote(note);

          logger.i('♻️ Recovered and saved to new topic');
        }
      } else {
        logger.e('Failed to forward', error: e);
      }
    }
  }

  Future<void> _processOCR(
    UserModel user,
    Message forwardedMsg,
    PhotoSize photo,
    NoteModel note,
  ) async {
    try {
      final apiKey = await userRepo.getDecryptedApiKey(user.id);
      if (apiKey == null) return;

      logger.d('🖼️ Downloading image for OCR...');

      // Get File Path from Telegram
      final file = await teledart.getFile(photo.fileId);
      final filePath = file.filePath;
      if (filePath == null) return;

      // Download Image Bytes
      final downloadUrl =
          'https://api.telegram.org/file/bot$botToken/$filePath';
      final request = await HttpClient().getUrl(Uri.parse(downloadUrl));
      final response = await request.close();
      final imageBytes = await response.expand((element) => element).toList();

      // Send to Gemini
      logger.d('🤖 Gemini analyzing text...');
      final extractedText = await geminiRepo.extractTextFromImage(
          apiKey: apiKey, imageBytes: imageBytes);

      if (extractedText != null && extractedText.isNotEmpty) {
        final newContent = '${note.content}\n[OCR]: $extractedText';

        final updatedNote = NoteModel(
          messageId: note.messageId,
          content: newContent,
          topic: note.topic,
          type: note.type,
          createdAt: note.createdAt,
          messageLink: note.messageLink,
        );
        await noteRepo.indexNote(updatedNote);
        logger.i('✅ OCR Text indexed for Search');

        try {
          final replyText = '📝 **OCR Detected:**\n$extractedText';

          await telegramRepo.sendMessage(
            forwardedMsg.chat.id,
            replyText,
            replyToMessageId: forwardedMsg.messageId,
          );
        } catch (e) {
          logger.w('Could not send OCR reply: $e');
        }
      }
    } catch (e) {
      logger.e('OCR Processing Failed', error: e);
    }
  }

  Future<int?> _getSafeTopicId(
      UserModel user, String topicName, int vaultId) async {
    if (user.topicIds.containsKey(topicName)) {
      return user.topicIds[topicName];
    }

    if (_topicCreationLocks.containsKey(topicName)) {
      logger.d('⏳ Waiting for topic creation: $topicName');
      return await _topicCreationLocks[topicName];
    }

    logger.i('📂 Starting topic creation: $topicName');

    final completer = _createAndSaveTopic(user, topicName, vaultId);
    _topicCreationLocks[topicName] = completer;

    try {
      final resultId = await completer;
      return resultId;
    } finally {
      _topicCreationLocks.remove(topicName);
    }
  }

  Future<int?> _createAndSaveTopic(
      UserModel user, String topicName, int vaultId) async {
    final freshUser = await userRepo.getUser(user.id);
    if (freshUser != null && freshUser.topicIds.containsKey(topicName)) {
      return freshUser.topicIds[topicName];
    }

    final topicId = await telegramRepo.createTopic(vaultId, topicName);

    if (topicId != null) {
      final currentUser = await userRepo.getUser(user.id);
      if (currentUser != null) {
        final newTopics = Map<String, int>.from(currentUser.topicIds);
        newTopics[topicName] = topicId;

        await userRepo.saveUser(currentUser.copyWith(topicIds: newTopics));
        logger.i('✅ Topic created and saved: $topicName -> $topicId');
      }
      return topicId;
    }

    return null;
  }

  String _determineTopic(TeleDartMessage message) {
    final text = message.caption ?? message.text ?? '';

    final hashtagRegex = RegExp(r'#(\w+)');
    final match = hashtagRegex.firstMatch(text);
    if (match != null) {
      return match.group(1)!;
    }

    if (message.video != null) return 'Videos';
    if (message.photo != null) return 'Images';
    if (message.document != null) return 'Files';
    if (message.voice != null || message.audio != null) return 'Audio';

    if (text.contains('http://') || text.contains('https://')) {
      if (text.contains('youtube.com') || text.contains('youtu.be')) {
        return 'YouTube';
      }
      return 'Links';
    }

    return 'General';
  }
}
