import 'package:dart_frog/dart_frog.dart';
import 'package:hmat_mi/src/repositories/telegram_repository.dart';
import 'package:hmat_mi/src/repositories/user_repository.dart';

import '../main.dart';

Handler middleware(Handler handler) {
  return handler
      .use(requestLogger())
      .use(provider<UserRepository>((_) => userRepo))
      .use(provider<TelegramRepository>((_) => telegramRepo));
  // .use(provider<GeminiRepository>((_) => geminiRepo));
}
