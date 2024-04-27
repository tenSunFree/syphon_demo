import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:sqlite3/open.dart';
import 'package:syphon_demo/domain/sync/service/service.dart';
import 'package:syphon_demo/global/libraries/secure-storage/secure-storage.dart';
import 'package:syphon_demo/global/print.dart';

///
/// Init Platform Dependencies
///
/// init all specific dependencies needed
/// to run Syphon on a specific platform
///
Future<void> initPlatformDependencies() async {
  // init platform overrides for compatability with dart libs
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }

  if (Platform.isLinux) {
    PathProviderLinux.registerWith();

    final appDir = File(Platform.script.toFilePath()).parent;
    final libolmDir = File(path.join(appDir.path, 'lib/libolm.so'));
    final libsqliteDir = File(path.join(appDir.path, './libsqlite3.so'));
    final libsqlcipherDir = File(path.join(appDir.path, './libsqlcipher.so'));
    final libolmExists = await libolmDir.exists();
    final libsqliteExists = await libsqliteDir.exists();
    final libsqlcipherExists = await libsqlcipherDir.exists();

    if (libolmExists) {
      DynamicLibrary.open(libolmDir.path);
    } else {
      console.error('[linux] not found libolmExists ${libolmDir.path}');
    }

    if (libsqliteExists) {
      open.overrideFor(OperatingSystem.linux, () {
        return DynamicLibrary.open(libsqliteDir.path);
      });
    } else {
      console.error('[linux] not found libsqliteExists ${libsqliteDir.path}');
    }

    if (libsqlcipherExists) {
      open.overrideFor(OperatingSystem.linux, () {
        return DynamicLibrary.open(libsqlcipherDir.path);
      });
    } else {
      console.error('[linux] not found libsqlcipherExists ${libsqlcipherDir.path}');
    }
  }

  // init window mangment for desktop builds
  if (Platform.isMacOS) {
    final directory = await getApplicationSupportDirectory();
    console.info('[macos] ${directory.path}');
    try {
      DynamicLibrary.open('libolm.3.dylib');
    } catch (error) {
      console.info('[macos] $error');
    }
  }

  // Init flutter secure storage
  if (Platform.isAndroid || Platform.isIOS) {
    SecureStorage.instance = const FlutterSecureStorage();
  }

  // init background sync for Android only
  // if (Platform.isAndroid) {
  //   final backgroundSyncStatus = await SyncService.init();
  //   console.info('[main] background service initialized $backgroundSyncStatus');
  // }
}
