import 'package:flutter/material.dart';

const _seedColor = Colors.indigo;

ThemeData get lightTheme => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      useMaterial3: true,
    );

ThemeData get darkTheme => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
