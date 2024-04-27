import 'package:flutter/foundation.dart';
import 'package:redux_persist/redux_persist.dart';
import 'package:sembast/sembast.dart';
import 'package:syphon_demo/domain/auth/state.dart';
import 'package:syphon_demo/domain/crypto/state.dart';
import 'package:syphon_demo/domain/rooms/state.dart';
import 'package:syphon_demo/domain/sync/state.dart';
import 'package:syphon_demo/global/libraries/cache/index.dart';
import 'package:syphon_demo/global/libraries/cache/threadables.dart';
import 'package:syphon_demo/global/print.dart';

class CacheStorage implements StorageEngine {
  final Database? cache;

  CacheStorage({this.cache});

  @override
  Future<Uint8List> load() async {
    final List<Object> stores = [
      const AuthStore(),
      const SyncStore(),
      const CryptoStore(),
      const RoomStore(),
    ];

    await Future.wait(stores.map((store) async {
      final type = store.runtimeType.toString();
      try {
        // Fetch from database
        final table = StoreRef<String, String>.main();
        final record = table.record(store.runtimeType.toString());
        final jsonEncrypted = await record.get(cache!);

        // Decrypt from database
        final jsonDecoded = await compute(
          decryptJsonBackground,
          {
            'type': type,
            'json': jsonEncrypted,
            'cacheKey': Cache.cacheKey,
          },
          debugLabel: 'decryptJsonBackground',
        );

        // Load for CacheSerializer to use later
        Cache.cacheStores[type] = jsonDecoded;
      } catch (error) {
        console.error(error.toString(), title: 'CacheStorage|$type');
      }
    }));

    // unlock redux_persist after cache loaded from sqflite
    return Uint8List(0);
  }

  @override
  Future<void> save(Uint8List? data) {
    return Future.value();
  }
}
