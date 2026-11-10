import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initializes sqflite FFI for Windows/Linux desktop platforms.
Future<void> initDesktopDatabase() async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

