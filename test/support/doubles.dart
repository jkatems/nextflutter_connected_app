import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:carnet/domain/models.dart';

class MemoryCache implements FeedCache {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = value;
  }

  @override
  Future<void> clear() async => values.clear();
}

class MemorySession implements SessionStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  Adapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
final item = {
  'id': 1,
  'title': 'Article',
  'body': 'Contenu réel',
  'label': 'TEST',
};
final session = {
  'accessToken': 'old',
  'refreshToken': 'refresh',
  'user': {'id': 7, 'name': 'Alice'},
};
