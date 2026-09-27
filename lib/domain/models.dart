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

enum FailureKind {
  network,
  unauthorized,
  forbidden,
  invalidData,
  storage,
  unknown,
}

class AppFailure implements Exception {
  final String message;
  final FailureKind kind;
  const AppFailure(this.message, {this.kind = FailureKind.unknown});
  @override
  String toString() => message;
}

/// Validate an API session before saving credentials or accepting a refresh.
Map<String, dynamic> parseSession(Object? value) {
  if (value is! Map<String, dynamic> ||
      value['accessToken'] is! String ||
      (value['accessToken'] as String).isEmpty ||
      value['refreshToken'] is! String ||
      (value['refreshToken'] as String).isEmpty ||
      value['user'] is! Map ||
      value['user']['id'] is! int ||
      value['user']['name'] is! String) {
    throw const AppFailure(
      'La session reçue du serveur est invalide.',
      kind: FailureKind.invalidData,
    );
  }
  return value;
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
