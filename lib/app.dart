import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/translation_service.dart';

class BookReaderApp extends StatefulWidget {
  const BookReaderApp({super.key});

  @override
  State<BookReaderApp> createState() => _BookReaderAppState();
}

class _BookReaderAppState extends State<BookReaderApp> {
  late final LibreTranslateProvider _translationProvider;

  @override
  void initState() {
    super.initState();
    _translationProvider = LibreTranslateProvider(baseUrl: _resolveBaseUrl());
  }

  /// Reads `TRANSLATE_API_URL` from `--dart-define`, falling back to the local
  /// proxy on `localhost:8787`.
  String _resolveBaseUrl() {
    const configured = String.fromEnvironment('TRANSLATE_API_URL');
    if (configured.isNotEmpty) return configured;
    return 'http://localhost:8787';
  }

  @override
  void dispose() {
    _translationProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Reader',
      debugShowCheckedModeBanner: kDebugMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: HomeScreen(translationProvider: _translationProvider),
    );
  }
}
