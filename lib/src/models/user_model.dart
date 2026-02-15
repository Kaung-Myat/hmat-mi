class UserModel {
  UserModel({
    required this.id,
    this.encryptedApiKey,
    this.vaultChannelId,
    this.doneMessageIds = const [],
    this.topicIds = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      encryptedApiKey: json['encryptedApiKey'] as String?,
      vaultChannelId: json['vaultChannelId'] as int?,
      doneMessageIds: (json['doneMessageIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      topicIds: (json['topicIds'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v as int),
          ) ??
          {},
    );
  }
  final int id; // Telegram User ID
  final String? encryptedApiKey; // Gemini API Key (Encrypted)
  final int? vaultChannelId; // User's Private Channel ID
  final List<int> doneMessageIds;
  final Map<String, int> topicIds;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'encryptedApiKey': encryptedApiKey,
      'vaultChannelId': vaultChannelId,
      'doneMessageIds': doneMessageIds,
      'topicIds': topicIds,
    };
  }

  UserModel copyWith({
    String? encryptedApiKey,
    int? vaultChannelId,
    List<int>? doneMessageIds,
    Map<String, int>? topicIds,
  }) {
    return UserModel(
      id: id,
      encryptedApiKey: encryptedApiKey ?? this.encryptedApiKey,
      vaultChannelId: vaultChannelId ?? this.vaultChannelId,
      doneMessageIds: doneMessageIds ?? this.doneMessageIds,
      topicIds: topicIds ?? this.topicIds,
    );
  }
}
