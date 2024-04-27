import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:syphon_demo/domain/events/reactions/model.dart';
import 'package:syphon_demo/domain/events/redaction/model.dart';
import 'package:syphon_demo/global/libraries/storage/database.dart';
import 'package:syphon_demo/global/print.dart';

///
/// Reaction Queries - unencrypted (Cold Storage)
///
/// In storage, reactions are indexed by eventId
/// In redux, they're indexed by RoomID and placed in a list
///
extension ReactionQueries on ColdStorageDatabase {
  Future<void> insertReactionsBatched(List<Reaction> reactions) {
    // HACK: temporary to account for sqlite versions without UPSERT
    if (Platform.isLinux) {
      return batch(
        (batch) => batch.insertAll(
          this.reactions,
          reactions,
          mode: InsertMode.insertOrReplace,
        ),
      );
    }
    return batch(
      (batch) => batch.insertAllOnConflictUpdate(
        this.reactions,
        reactions,
      ),
    );
  }

  ///
  /// Select Reactions (Ids)
  ///
  /// Query every message known in a room
  ///
  Future<List<Reaction>> selectReactionsById(List<String> reactionIds) {
    return (select(reactions)..where((tbl) => tbl.body.isNotNull() & tbl.id.isIn(reactionIds))).get();
  }

  ///
  /// Select Reactions (All)
  ///
  /// Query every message known in a room
  ///
  Future<List<Reaction>> selectReactionsPerEvent(String roomId, List<String>? eventIds) {
    return (select(reactions)
          ..where((tbl) =>
              tbl.body.isNotNull() & tbl.roomId.equals(roomId) & tbl.relEventId.isIn(eventIds ?? [])))
        .get();
  }
}

Future<void> saveReactions(
  List<Reaction> reactions, {
  required ColdStorageDatabase storage,
}) async {
  await storage.insertReactionsBatched(reactions);
}

Future<void> saveReactionsRedacted(
  List<Redaction> redactions, {
  required ColdStorageDatabase storage,
}) async {
  final reactionIds = redactions.map((redaction) => redaction.redactId ?? '').toList();
  final reactions = await storage.selectReactionsById(reactionIds);

  final reactionsUpdated = reactions.map((reaction) => reaction.copyWith(body: null)).toList();
  await storage.insertReactionsBatched(reactionsUpdated);
}

///
/// Load Reactions
///
///
Future<List<Reaction>> loadReactions({
  required ColdStorageDatabase storage,
  required String roomId,
  List<String> eventIds = const [],
}) async {
  try {
    return storage.selectReactionsPerEvent(roomId, eventIds);
  } catch (error) {
    console.error(error.toString(), title: 'loadReactions');
    return [];
  }
}

///
/// Load Reactions Mapped
///
///
Future<Map<String, List<Reaction>>> loadReactionsMapped({
  required ColdStorageDatabase storage,
  required String roomId,
  List<String> eventIds = const [],
}) async {
  try {
    final reactions = await storage.selectReactionsPerEvent(roomId, eventIds);

    return Map<String, List<Reaction>>.fromIterable(
      reactions,
      key: (reaction) => reaction.relEventId,
      value: (reaction) => reactions
          .where(
            (r) => r.relEventId == reaction.relEventId,
          )
          .toList(),
    );
  } catch (error) {
    console.error(error.toString(), title: 'loadReactions');
    return {};
  }
}
