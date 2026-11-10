import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web implementation - sets databaseFactory to web IndexedDB factory
Future<void> initDesktopDatabase() async {
  databaseFactory = databaseFactoryFfiWeb;
}
