import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/translation.dart';

/// Contract for any translation backend. New providers (Google, DeepL, ...)
/// can implement this interface without touching the UI layer.
abstract class TranslationProvider {
  Future<TranslateResult> translate(TranslateRequest request);
}

/// Talks to a LibreTranslate-compatible endpoint via the local dev proxy.
///
/// The proxy is expected to expose `POST /translate` with the same JSON
/// contract as LibreTranslate itself. See `proxy/src/index.ts`.
class LibreTranslateProvider implements TranslationProvider {
  LibreTranslateProvider({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  /// Base URL of the proxy, e.g. `http://localhost:8787`.
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  final Map<String, String> _cache = <String, String>{};

  @override
  Future<TranslateResult> translate(TranslateRequest request) async {
    final cacheKey =
        '${request.source}->${request.target}::${request.format.wireValue}::${request.text}';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return TranslateResult(
        translatedText: cached,
        source: request.source,
        target: request.target,
        originalText: request.text,
      );
    }

    final uri = Uri.parse('$baseUrl/translate');
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'q': request.text,
              'source': request.source,
              'target': request.target,
              'format': request.format.wireValue,
            }),
          )
          .timeout(timeout);
    } catch (e) {
      throw TranslationException(
        'No se pudo contactar al servicio de traducción en $baseUrl',
        cause: e,
      );
    }

    if (response.statusCode != 200) {
      throw TranslationException(
        'El servicio respondió ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['translatedText'] is! String) {
      throw const TranslationException(
        'Respuesta inválida del servicio de traducción',
      );
    }

    final translated = decoded['translatedText'] as String;
    _cache[cacheKey] = translated;

    return TranslateResult(
      translatedText: translated,
      source: request.source,
      target: request.target,
      originalText: request.text,
    );
  }

  void dispose() => _client.close();
}
