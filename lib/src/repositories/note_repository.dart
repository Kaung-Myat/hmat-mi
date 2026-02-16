import 'package:hmat_mi/src/models/note_model.dart';
import 'package:hmat_mi/src/repositories/gemini_repository.dart';
import 'package:supabase/supabase.dart';

class NoteRepository {
  NoteRepository({
    required this.supabase,
    required this.geminiRepo,
  });

  final SupabaseClient supabase;
  final GeminiRepository geminiRepo;

  Future<void> init() async {}

  Future<void> indexNote({
    required NoteModel note,
    required String apiKey,
    required String userId,
  }) async {
    final embedding = await geminiRepo.generateEmbedding(
      text: note.content,
      apiKey: apiKey,
    );

    await supabase.from('notes').insert({
      'user_id': int.parse(userId), // Convert string back to int for database
      'message_id': note.messageId,
      'content': note.content,
      'topic': note.topic,
      'type': note.type,
      'message_link': note.messageLink,
      'embedding': embedding,
      'created_at': note.createdAt, // Pass DateTime object directly
    });
  }

  /// Semantic Search
  Future<List<NoteModel>> search({
    required String query,
    required String apiKey,
    required String userId,
  }) async {
    try {
      // 1. User ရှာလိုက်တဲ့ စာ (Query) ကို Vector ပြောင်းမယ်
      final queryEmbedding = await geminiRepo.generateEmbedding(
        text: query,
        apiKey: apiKey,
      );

      // 2. Supabase RPC (Remote Procedure Call) ကို ခေါ်ပြီး ရှာမယ်
      // (match_notes ဆိုတဲ့ function ကို SQL မှာ ဆောက်ခဲ့ပြီး ဖြစ်ရပါမယ်)
      // ignore: omit_local_variable_types
      final List<dynamic> data = await supabase.rpc(
        'match_notes',
        params: {
          'query_embedding': queryEmbedding,
          'match_threshold': 0.5, // 0.5 = 50% တူမှ ပြမယ် (စိတ်ကြိုက်ပြင်နိုင်)
          'match_count': 10, // Result ၁၀ ခု ယူမယ်
          'filter_user_id': int.parse(userId), // ဒီ User ပိုင်တာပဲ ရှာပေးမယ်
        },
      );

      // 3. Result ကို NoteModel ပြန်ပြောင်းမယ်
      return data.map((json) {
        final messageId = json['message_id'] as int?;
        final content = json['content'] as String?;
        final topic = json['topic'] as String?;
        final type = json['type'] as String?;
        final createdAtStr = json['created_at'] as String?;
        final messageLink = json['message_link'] as String?;

        if (messageId == null || content == null || topic == null || type == null || 
            createdAtStr == null || messageLink == null) {
          print('⚠️ Skipping invalid search result: $json');
          // Skip invalid records
          return null;
        }

        return NoteModel(
          messageId: messageId,
          content: content,
          topic: topic,
          type: type,
          createdAt: DateTime.parse(createdAtStr),
          messageLink: messageLink,
        );
      }).where((note) => note != null).cast<NoteModel>().toList();
    } catch (e) {
      print('❌ Semantic Search Error: $e');
      return [];
    }
  }
}
