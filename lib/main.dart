import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';

Future<void> main() async {
  await pdfrxFlutterInitialize();
  runApp(const BookReaderApp());
}
