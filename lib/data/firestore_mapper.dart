/// Converts the typed wire format of the Firestore REST API to plain JSON.
Object? decodeFirestoreValue(Map<String, dynamic> value) {
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('integerValue'))
    return int.parse(value['integerValue'] as String);
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('arrayValue')) {
    return ((value['arrayValue'] as Map)['values'] as List? ?? [])
        .map((v) => decodeFirestoreValue(Map<String, dynamic>.from(v as Map)))
        .toList();
  }
  if (value.containsKey('mapValue')) {
    return decodeFirestoreFields(
      Map<String, dynamic>.from(
        (value['mapValue'] as Map)['fields'] as Map? ?? {},
      ),
    );
  }
  throw const FormatException('Unsupported Firestore value');
}

Map<String, dynamic> decodeFirestoreFields(Map<String, dynamic> fields) =>
    fields.map(
      (key, value) => MapEntry(
        key,
        decodeFirestoreValue(Map<String, dynamic>.from(value as Map)),
      ),
    );
