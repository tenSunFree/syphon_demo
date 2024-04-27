import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:syphon_demo/domain/user/model.dart';
import 'package:syphon_demo/global/libraries/storage/database.dart';
import 'package:syphon_demo/global/print.dart';

///
/// Room Queries
///
extension UserQueries on ColdStorageDatabase {
  Future<void> insertUsers(List<User> users) {
    // HACK: temporary to account for sqlite versions without UPSERT
    if (Platform.isLinux) {
      return batch(
        (batch) => batch.insertAll(
          this.users,
          users,
          mode: InsertMode.insertOrReplace,
        ),
      );
    }
    return batch(
      (batch) => batch.insertAllOnConflictUpdate(this.users, users),
    );
  }

  Future<List<User>> selectUsers(List<String> ids, {int offset = 0, int limit = 0}) {
    return (select(users)..where((tbl) => tbl.userId.isIn(ids))).get();
  }

  Future<List<User>> selectUsersAll() {
    return select(users).get();
  }
}

Future<void> saveUsers(
  Map<String, User> users, {
  required ColdStorageDatabase storage,
}) async {
  return storage.insertUsers(users.values.toList());
}

///
/// Load Users (Cold Storage)
///
Future<Map<String, User>> loadUsers({
  required ColdStorageDatabase storage,
  List<String> ids = const [],
}) async {
  final Map<String, User> users = {};

  try {
    final users = await storage.selectUsers(ids);

    console.info('[users] loaded ${users.length}');

    return Map.fromIterable(
      users,
      key: (user) => user.userId,
      value: (user) => user,
    );
  } catch (error) {
    console.error(error.toString(), title: 'loadUsers');
    return users;
  }
}

///
/// Load Users All (Cold Storage)
///
Future<Map<String, User>> loadUsersAll({
  required ColdStorageDatabase storage,
}) async {
  final Map<String, User> users = {};

  try {
    final users = await storage.selectUsersAll();

    console.info('[users ALL] loaded ${users.length}');

    return Map.fromIterable(
      users,
      key: (user) => user.userId,
      value: (user) => user,
    );
  } catch (error) {
    console.error(error.toString(), title: 'loadUsers');
    return users;
  }
}
