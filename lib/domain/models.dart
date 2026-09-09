class Entry {
  final int id;
  final String title, body, label;
  const Entry({
    required this.id,
    required this.title,
    required this.body,
    required this.label,
  });
  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
    id: json['id'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
    label: json['label'] as String,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'label': label,
  };
}

class Feed {
  final List<Entry> items;
  final bool cached;
  final DateTime savedAt;
  const Feed(this.items, this.cached, this.savedAt);
}

class AppFailure implements Exception {
  final String message;
  const AppFailure(this.message);
  @override
  String toString() => message;
}

abstract interface class ContentRepository {
  Future<Feed> fetch(String category);
}

abstract interface class SessionStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> session);
  Future<void> clear();
}

abstract interface class FeedCache {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
  Future<void> clear();
}

abstract interface class AuthenticationRepository {
  Future<Map<String, dynamic>?> restore();
  Future<Map<String, dynamic>> authenticate({
    required String email,
    required String password,
    String? name,
  });
  Future<bool> logout();
}
