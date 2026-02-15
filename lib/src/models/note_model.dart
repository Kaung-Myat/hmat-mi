// Hive imports တွေကို ဖယ်လိုက်ပါ
class NoteModel {
  NoteModel({
    required this.messageId,
    required this.content,
    required this.topic,
    required this.type,
    required this.createdAt,
    required this.messageLink,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      messageId: json['message_id'] as int,
      content: json['content'] as String,
      topic: json['topic'] as String,
      type: json['type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      messageLink: json['message_link'] as String,
    );
  }
  final int messageId;
  final String content;
  final String topic;
  final String type;
  final DateTime createdAt;
  final String messageLink;
}
