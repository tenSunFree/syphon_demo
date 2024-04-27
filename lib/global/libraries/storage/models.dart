import 'dart:isolate';

import 'package:syphon_demo/global/values.dart';

class DatabaseInfo {
  final String key;
  final String path;
  final SendPort? port;

  const DatabaseInfo({
    this.key = Values.empty,
    this.path = Values.empty,
    this.port,
  });
}
