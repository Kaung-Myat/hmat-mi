import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:hmat_mi/src/models/user_model.dart';
import 'package:supabase/supabase.dart';

class UserRepository {
  UserRepository({
    required String secretKey,
    required this.supabase,
  }) : _encrypter = encrypt_pkg.Encrypter(
          encrypt_pkg.AES(encrypt_pkg.Key.fromUtf8(secretKey)),
        );
  final SupabaseClient supabase;
  final encrypt_pkg.Encrypter _encrypter;
  final encrypt_pkg.IV _iv = encrypt_pkg.IV.fromUtf8('hmat_mi_sec_iv16');

  Future<void> init() async {}

  Future<UserModel?> getUser(int userId) async {
    try {
      final data =
          await supabase.from('users').select().eq('id', userId).maybeSingle();

      if (data == null) return null;

      return UserModel(
        id: data['id'] as int,
        encryptedApiKey: data['encrypted_api_key'] as String?,
        vaultChannelId: data['vault_channel_id'] as int?,
        topicIds: (data['topic_ids'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v as int),
            ) ??
            {},
      );
    } catch (e) {
      print('❌ Get User Error: $e');
      return null;
    }
  }

  Future<void> saveUser(UserModel user) async {
    await supabase.from('users').upsert({
      'id': user.id,
      'encrypted_api_key': user.encryptedApiKey,
      'vault_channel_id': user.vaultChannelId,
      'topic_ids': user.topicIds,
    });
  }

  Future<void> saveApiKey(int userId, String rawApiKey) async {
    final encrypted = _encrypter.encrypt(rawApiKey, iv: _iv);

    var user = await getUser(userId) ?? UserModel(id: userId);
    user = user.copyWith(encryptedApiKey: encrypted.base64);

    await saveUser(user);
  }

  Future<String?> getDecryptedApiKey(int userId) async {
    final user = await getUser(userId);
    if (user?.encryptedApiKey == null) return null;

    try {
      return _encrypter.decrypt(
        encrypt_pkg.Encrypted.fromBase64(user!.encryptedApiKey!),
        iv: _iv,
      );
    } catch (e) {
      print('🔐 Decryption Error: $e');
      return null;
    }
  }
}
