import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:syphon_demo/context/storage.dart';
import 'package:syphon_demo/global/platform.dart';
import 'package:syphon_demo/global/values.dart';
import 'package:syphon_demo/views/prelock.dart';

// ignore: avoid_void_async
void main() async {
  debugPrint('main');
  WidgetsFlutterBinding.ensureInitialized();

  // init platform specific code
  await initPlatformDependencies();

  // pull current context / nullable
  final context = await loadContextCurrent();

  if (SHOW_BORDERS && DEBUG_MODE) {
    debugPaintSizeEnabled = SHOW_BORDERS;
  }

  // init app
  runApp(Prelock(
    appContext: context,
    enabled: context.id.isNotEmpty && context.pinHash.isNotEmpty,
  ));
}
