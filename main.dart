import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dotenv/dotenv.dart';
import 'package:hmat_mi/src/repositories/gemini_repository.dart';
import 'package:hmat_mi/src/repositories/note_repository.dart';
import 'package:hmat_mi/src/repositories/telegram_repository.dart';
import 'package:hmat_mi/src/repositories/user_repository.dart';
import 'package:hmat_mi/src/services/bot_service.dart';
import 'package:hmat_mi/src/services/webhook_fetcher.dart';
import 'package:logger/logger.dart';
import 'package:supabase/supabase.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

late final TelegramRepository telegramRepo;
late final UserRepository userRepo;
late final NoteRepository noteRepo;
late final GeminiRepository geminiRepo;
late final SupabaseClient supabase;
late final Logger logger;

late final DartFrogWebhookFetcher webhookFetcher;

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5),
  );
  final env = DotEnv(includePlatformEnvironment: true);

  if (File('.env').existsSync()) {
    env.load();
  }

  final botToken = env['BOT_TOKEN'];
  final secretKey = env['SECRET_KEY'];
  final supabaseUrl = env['SUPABASE_URL'];
  final supabaseKey = env['SUPABASE_KEY'];

  if (botToken == null ||
      secretKey == null ||
      supabaseUrl == null ||
      supabaseKey == null) {
    logger.f('''
❌ Missing Environment Variables! Please set BOT_TOKEN, SECRET_KEY, SUPABASE_URL, and SUPABASE_KEY.''');
    exit(1);
  }

  if (secretKey.length != 32) {
    logger.f('❌ SECRET_KEY must be exactly 32 characters long!');
    exit(1);
  }

  logger.i('🚀 Initializing Hmat-Mi Bot...');

  supabase = SupabaseClient(supabaseUrl, supabaseKey);
  userRepo = UserRepository(
    secretKey: secretKey,
    supabase: supabase,
  );
  await userRepo.init();

  noteRepo = NoteRepository(
    supabase: supabase,
  );
  await noteRepo.init();

  geminiRepo = GeminiRepository();

  final telegram = Telegram(botToken);
  final botUser = await telegram.getMe();
  final username = botUser.username!;

  webhookFetcher = DartFrogWebhookFetcher(telegram: telegram);

  final teledart = TeleDart(
    botToken,
    Event(username),
    fetcher: webhookFetcher,
  )..start();

  telegramRepo = TelegramRepository(teledart, botToken);

  const globeUrl = 'https://hmat-mi.globeapp.dev';
  const webhookUrl = '$globeUrl/webhook';

  await telegram.setWebhook(webhookUrl);
  logger
    ..i('🔗 Webhook set to: $webhookUrl')
    ..d('✅ Database & Telegram initialized');

  BotService(
    telegramRepo: telegramRepo,
    userRepo: userRepo,
    noteRepo: noteRepo,
    geminiRepo: geminiRepo,
    teledart: teledart,
    botName: username,
    botToken: botToken,
    logger: logger,
  ).start();

  logger.i('🌍 Server listening on $ip:$port');
  return serve(handler, ip, port);
}
