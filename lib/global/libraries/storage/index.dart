import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:redux/redux.dart';
import 'package:syphon_demo/context/types.dart';
import 'package:syphon_demo/domain/auth/storage.dart';
import 'package:syphon_demo/domain/crypto/sessions/storage.dart';
import 'package:syphon_demo/domain/crypto/storage.dart';
import 'package:syphon_demo/domain/events/messages/actions.dart';
import 'package:syphon_demo/domain/events/messages/model.dart';
import 'package:syphon_demo/domain/events/messages/storage.dart';
import 'package:syphon_demo/domain/events/reactions/actions.dart';
import 'package:syphon_demo/domain/events/reactions/model.dart';
import 'package:syphon_demo/domain/events/reactions/storage.dart';
import 'package:syphon_demo/domain/events/receipts/actions.dart';
import 'package:syphon_demo/domain/events/receipts/model.dart';
import 'package:syphon_demo/domain/events/receipts/storage.dart';
import 'package:syphon_demo/domain/index.dart';
import 'package:syphon_demo/domain/media/actions.dart';
import 'package:syphon_demo/domain/media/storage.dart';
import 'package:syphon_demo/domain/rooms/room/model.dart';
import 'package:syphon_demo/domain/rooms/storage.dart';
import 'package:syphon_demo/domain/settings/storage.dart';
import 'package:syphon_demo/domain/user/storage.dart';
import 'package:syphon_demo/global/libraries/storage/constants.dart';
import 'package:syphon_demo/global/libraries/storage/database.dart';
import 'package:syphon_demo/global/print.dart';
import 'package:syphon_demo/global/values.dart';

class Storage {
  // cache key identifiers
  static const keyLocation = '${Values.appLabel}@storageKey';

  // storage identifiers
  static const sqliteLocation = '${Values.appLabel}-cold-storage.db';

  // cold storage references
  static ColdStorageDatabase? database;
}

Future<ColdStorageDatabase> initStorage({AppContext context = const AppContext(), String pin = ''}) async {
  final database = openDatabaseThreaded(context, pin: pin);
  Storage.database = database;
  return database;
}

Future<void> closeStorage(ColdStorageDatabase? storage) async {
  if (storage != null) {
    storage.close();
  }
}

Future deleteStorage({AppContext context = const AppContext()}) async {
  try {
    final contextId = context.id;
    var storageLocation = Storage.sqliteLocation;

    if (contextId.isNotEmpty) {
      storageLocation = '$contextId-$storageLocation';
    }

    storageLocation = DEBUG_MODE ? 'debug-$storageLocation' : storageLocation;

    final appDir = await getApplicationSupportDirectory();
    final file = File(path.join(appDir.path, storageLocation));
    await file.delete();
  } catch (error) {
    console.error('[deleteColdStorage] $error');
  }
}

///
/// Load Storage
///
/// bulk loads cold storage objects to RAM, this can
/// be much more specific and performant
///
/// for example, only load users that are known to be
/// involved in stored messages/events
///
Future<Map<String, dynamic>> loadStorage(ColdStorageDatabase storage) async {
  try {
    final userIds = <String>[];
    final messages = <String, List<Message>>{};
    final decrypted = <String, List<Message>>{};
    final reactions = <String, List<Reaction>>{};

    final auth = await loadAuth(storage: storage);
    final crypto = await loadCrypto(storage: storage);
    // final settings = await loadSettings(storage: storage);
    final rooms = await loadRooms(storage: storage);

    for (final Room room in rooms.values) {
      messages[room.id] = await loadMessagesRoom(
        room.id,
        storage: storage,
      );

      decrypted[room.id] = await loadDecryptedRoom(
        room.id,
        storage: storage,
      );

      final currentUserIds = (messages[room.id] ?? []).map((message) => message.sender ?? '').toList();

      userIds.addAll(currentUserIds);
    }

    final users = await loadUsers(storage: storage, ids: userIds);

    final media = await loadMediaRelative(
      storage: storage,
      users: users.values.toList(),
      rooms: rooms.values.toList(),
    );

    final messageSessions = await loadMessageSessionsInbound(
      roomIds: rooms.keys.toList(),
      storage: storage,
    );

    return {
      StorageKeys.AUTH: auth,
      StorageKeys.CRYPTO: crypto,
      // StorageKeys.SETTINGS: settings,
      StorageKeys.ROOMS: rooms,
      StorageKeys.USERS: users,
      StorageKeys.MEDIA: media,
      StorageKeys.MESSAGES: messages,
      StorageKeys.REACTIONS: reactions,
      StorageKeys.DECRYPTED: decrypted,
      StorageKeys.MESSAGE_SESSIONS: messageSessions,
    };
  } catch (error) {
    console.error('[loadStorage] $error');
    return {};
  }
}

//
// Load Storage (Async)
//
// finishes loading cold storage objects to RAM, this can
// be much more specific and performant
//
loadStorageAsync(ColdStorageDatabase storage, Store<AppState> store) {
  try {
    final rooms = store.state.roomStore.roomList;
    final messages = store.state.eventStore.messages;
    final decrypted = store.state.eventStore.messagesDecrypted;

    final medias = <String, Uint8List>{};
    final reactions = <String, List<Reaction>>{};
    final receipts = <String, Map<String, Receipt>>{};

    loadAsync() async {
      for (final Room room in rooms) {
        final currentMessages = messages[room.id] ?? [];
        final currentDecrypted = decrypted[room.id] ?? [];
        final currentMessagesIds = currentMessages.map((e) => e.id ?? '').toList();

        reactions.addAll(await loadReactionsMapped(
          roomId: room.id,
          eventIds: currentMessagesIds,
          storage: storage,
        ));

        receipts[room.id] = await loadReceipts(
          currentMessagesIds,
          storage: storage,
        );

        medias.addAll(await loadMediaRelative(
          messages: currentMessages + currentDecrypted,
          storage: storage,
        ));
      }

      store.dispatch(LoadMedia(mediaMap: medias));
      store.dispatch(LoadReceipts(receiptsMap: receipts));
      // store.dispatch(LoadReactions(reactionsMap: reactions));

      // mutate messages
      // store.dispatch(mutateMessagesAll());
    }

    loadAsync();
  } catch (error) {
    console.error('[loadStorageAsync] $error');
  }
}
