import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:syphon_demo/domain/sync/state.dart';
import 'package:syphon_demo/global/libraries/storage/constants.dart';
import 'package:syphon_demo/global/libraries/storage/database.dart';
import 'package:syphon_demo/global/print.dart';

///
/// Auth Quesies - unencrypted (Cold Storage)
///
/// In storage, messages are indexed by eventId
/// In redux, they're indexed by RoomID and placed in a list
///
extension SyncQueries on ColdStorageDatabase {
  Future<int> insertSyncStore(SyncStore store) async {
    final storeJson = json.decode(json.encode(store));

    // HACK: temporary to account for sqlite versions without UPSERT
    if (Platform.isLinux) {
      return into(syncs).insert(
        SyncsCompanion(
          id: const Value(StorageKeys.SYNC),
          store: Value(storeJson),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }

    return into(syncs).insertOnConflictUpdate(
      SyncsCompanion(
        id: const Value(StorageKeys.SYNC),
        store: Value(storeJson),
      ),
    );
  }

  Future<SyncStore?> selectSyncStore() async {
    final row = await (select(syncs)..where((tbl) => tbl.id.isNotNull())).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return SyncStore.fromJson(row.store ?? {});
  }
}

Future<int> saveSync(
  SyncStore store, {
  required ColdStorageDatabase storage,
}) async {
  return storage.insertSyncStore(store);
}

///
/// Load Auth Store (Cold Storage)
///
Future<SyncStore?> loadSync({required ColdStorageDatabase storage}) async {
  try {
    return storage.selectSyncStore();
  } catch (error) {
    console.error(error.toString(), title: 'loadAuth');
    return null;
  }
}
