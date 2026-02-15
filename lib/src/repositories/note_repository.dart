import 'package:hmat_mi/src/models/note_model.dart';
import 'package:supabase/supabase.dart';

class NoteRepository {
  NoteRepository({required this.supabase});

  final SupabaseClient supabase;

  Future<void> init() async {}

  Future<void> indexNote(NoteModel note) async {
    await supabase.from('notes').insert({
      'message_id': note.messageId,
      'content': note.content,
      'topic': note.topic,
      'type': note.type,
      'message_link': note.messageLink,
      'created_at': note.createdAt.toIso8601String(),
    });
  }

  Future<List<NoteModel>> search(String query) async {
    try {
      final List<dynamic> data = await supabase
          .from('notes')
          .select()
          .ilike('content', '%$query%')
          .limit(10);

      return data.map((json) {
        return NoteModel(
          messageId: json['message_id'] as int,
          content: json['content'] as String,
          topic: json['topic'] as String,
          type: json['type'] as String,
          createdAt: DateTime.parse(json['created_at'] as String),
          messageLink: json['message_link'] as String,
        );
      }).toList();
    } catch (e) {
      print('❌ Search Error: $e');
      return [];
    }
  }
}
