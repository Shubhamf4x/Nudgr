class BitChatChannel {
  final String name;
  final String displayName;
  final DateTime createdAt;
  final int memberCount;
  final bool isJoined;
  final String? description;

  const BitChatChannel({
    required this.name,
    required this.displayName,
    required this.createdAt,
    this.memberCount = 0,
    this.isJoined = false,
    this.description,
  });

  BitChatChannel copyWith({
    String? name,
    String? displayName,
    DateTime? createdAt,
    int? memberCount,
    bool? isJoined,
    String? description,
  }) {
    return BitChatChannel(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      isJoined: isJoined ?? this.isJoined,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'displayName': displayName,
    'createdAt': createdAt.toIso8601String(),
    'memberCount': memberCount,
    'isJoined': isJoined,
    'description': description,
  };

  factory BitChatChannel.fromJson(Map<String, dynamic> json) => BitChatChannel(
    name: json['name'],
    displayName: json['displayName'],
    createdAt: DateTime.parse(json['createdAt']),
    memberCount: json['memberCount'] ?? 0,
    isJoined: json['isJoined'] ?? false,
    description: json['description'],
  );
}
