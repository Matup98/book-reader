import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/translation.dart';
import 'screens/home_screen.dart';
import 'services/translation_service.dart';

/// Storage keys for persisted translation preferences.
const String _prefsKeyTranslationMode = 'translation_mode';
const String _prefsKeyTranslationEngine = 'translation_engine';

class BookReaderApp extends StatefulWidget {
  const BookReaderApp({super.key});

  @override
  State<BookReaderApp> createState() => _BookReaderAppState();
}

class _BookReaderAppState extends State<BookReaderApp> {
  late final ProxyTranslationProvider _translationProvider;
  TranslationMode _translationMode = TranslationMode.context;
  TranslationEngine _translationEngine = TranslationEngine.libretranslate;

  @override
  void initState() {
    super.initState();
    _translationProvider = ProxyTranslationProvider(baseUrl: _resolveBaseUrl());
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final mode =
        TranslationMode.fromWireValue(prefs.getString(_prefsKeyTranslationMode));
    final engine = TranslationEngine.fromWireValue(
      prefs.getString(_prefsKeyTranslationEngine),
    );
    if (!mounted) return;
    setState(() {
      _translationMode = mode;
      _translationEngine = engine;
    });
  }

  Future<void> _setTranslationMode(TranslationMode mode) async {
    if (mode == _translationMode) return;
    setState(() => _translationMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyTranslationMode, mode.wireValue);
  }

  Future<void> _setTranslationEngine(TranslationEngine engine) async {
    if (engine == _translationEngine) return;
    setState(() => _translationEngine = engine);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyTranslationEngine, engine.wireValue);
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
      home: HomeScreen(
        translationProvider: _translationProvider,
        translationMode: _translationMode,
        onTranslationModeChanged: _setTranslationMode,
        translationEngine: _translationEngine,
        onTranslationEngineChanged: _setTranslationEngine,
      ),
    );
  }
}
