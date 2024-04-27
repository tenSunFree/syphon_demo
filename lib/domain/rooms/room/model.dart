// ignore_for_file: unnecessary_this

import 'package:drift/drift.dart' as drift;
import 'package:json_annotation/json_annotation.dart';
import 'package:syphon_demo/domain/events/messages/model.dart';
import 'package:syphon_demo/domain/user/model.dart';
import 'package:syphon_demo/global/libraries/storage/database.dart';

part 'model.g.dart';

class Photo {
  final int albumId;
  final int id;
  final String title;
  final String url;
  final String thumbnailUrl;

  Photo({
    required this.albumId,
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      albumId: json['albumId'],
      id: json['id'],
      title: json['title'],
      url: json['url'],
      thumbnailUrl: json['thumbnailUrl'],
    );
  }

  @override
  String toString() {
    return 'Photo{albumId: $albumId, id: $id, title: $title, url: $url, thumbnailUrl: $thumbnailUrl}';
  }
}

class RoomPresets {
  static const public = 'public_chat';
  static const private = 'private_chat';
  static const privateTrusted = 'trusted_private_chat';
}

@JsonSerializable()
class Room implements drift.Insertable<Room> {
  final String id;
  final String? name;
  final String? alias;
  final String? homeserver;
  final String? avatarUri;
  final String? topic;
  final String? joinRule; // "public", "knock", "invite", "private"

  final bool drafting;
  final bool direct;
  final bool sending;
  final bool invite;
  final bool guestEnabled;
  final bool encryptionEnabled;
  final bool worldReadable;
  final bool hidden;
  final bool archived;

  // oldest batch in timeline
  final String? lastBatch; // oldest batch in timeline
  // most recent batch from the last /sync
  final String? prevBatch;
  // next batch - or lastSince - in the timeline
  final String? nextBatch;

  final int lastRead;
  final int lastUpdate;
  final int totalJoinedUsers;
  final int namePriority;

  // Event lists and handlers
  final Message? draft;
  final Message? reply;

  // Associated user ids
  // TODO: remove by adding pivot table in cold storage
  final List<String> userIds;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool userTyping;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<String> usersTyping;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool limited;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool syncing;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get type {
    if (invite) {
      return 'invite';
    }

    if (joinRule == 'public' || worldReadable) {
      return 'public';
    }

    if (direct) {
      return 'direct';
    }

    return 'group';
  }

  const Room({
    required this.id,
    this.name = 'Empty Chat',
    this.alias = '',
    this.homeserver,
    this.avatarUri,
    this.topic = '',
    this.joinRule = 'private',
    this.drafting = false,
    this.invite = false,
    this.direct = false,
    this.syncing = false,
    this.sending = false,
    this.limited = false,
    this.hidden = false,
    this.archived = false,
    this.draft,
    this.reply,
    this.userIds = const [],
    this.lastRead = 0,
    this.lastUpdate = 0,
    this.namePriority = 4,
    this.totalJoinedUsers = 0,
    this.guestEnabled = false,
    this.encryptionEnabled = false,
    this.worldReadable = false,
    this.userTyping = false,
    this.usersTyping = const [],
    this.lastBatch,
    this.nextBatch,
    this.prevBatch,
  });

  Room copyWith({
    String? id,
    String? name,
    String? homeserver,
    String? avatarUri,
    String? topic,
    bool? invite,
    bool? direct,
    bool? limited,
    bool? syncing,
    bool? sending,
    bool? drafting,
    bool? hidden,
    bool? archived,
    joinRule,
    int? lastRead,
    int? lastUpdate,
    int? namePriority,
    int? totalJoinedUsers,
    guestEnabled,
    encryptionEnabled,
    bool? userTyping,
    List<String>? usersTyping,
    draft,
    reply,
    List<String>? userIds,
    Map<String, User>? usersTEMP,
    String? lastBatch,
    String? prevBatch,
    String? nextBatch,
  }) =>
      Room(
        id: id ?? this.id,
        name: name ?? this.name,
        alias: alias ?? alias,
        topic: topic ?? this.topic,
        joinRule: joinRule ?? this.joinRule,
        avatarUri: avatarUri ?? this.avatarUri,
        homeserver: homeserver ?? this.homeserver,
        drafting: drafting ?? this.drafting,
        invite: invite ?? this.invite,
        direct: direct ?? this.direct,
        hidden: hidden ?? this.hidden,
        archived: archived ?? this.archived,
        sending: sending ?? this.sending,
        syncing: syncing ?? this.syncing,
        limited: limited ?? this.limited,
        lastRead: lastRead ?? this.lastRead,
        lastUpdate: lastUpdate ?? this.lastUpdate,
        namePriority: namePriority ?? this.namePriority,
        totalJoinedUsers: totalJoinedUsers ?? this.totalJoinedUsers,
        guestEnabled: guestEnabled ?? this.guestEnabled,
        encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
        userTyping: userTyping ?? this.userTyping,
        usersTyping: usersTyping ?? this.usersTyping,
        draft: draft ?? this.draft,
        reply: reply == Null ? null : reply ?? this.reply,
        userIds: userIds ?? this.userIds,
        lastBatch: lastBatch ?? this.lastBatch,
        prevBatch: prevBatch ?? this.prevBatch,
        nextBatch: nextBatch ?? this.nextBatch,
      );

  Map<String, dynamic> toJson() => _$RoomToJson(this);
  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
  factory Room.fromMatrix(Map<String, dynamic> json) {
    try {
      return Room(
        id: json['room_id'],
        name: json['name'],
        alias: json['canonical_alias'],
        homeserver: (json['room_id'] as String).split(':')[1],
        topic: json['topic'],
        avatarUri: json['avatar_url'],
        totalJoinedUsers: json['num_joined_members'] ?? 0,
        guestEnabled: json['guest_can_join'],
        worldReadable: json['world_readable'],
        syncing: false,
      );
    } catch (error) {
      return Room(id: json['room_id']);
    }
  }

  // allows converting to message companion type for saving through drift
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    return RoomsCompanion(
      id: drift.Value(id),
      name: drift.Value(name),
      alias: drift.Value(alias),
      homeserver: drift.Value(homeserver),
      avatarUri: drift.Value(avatarUri),
      topic: drift.Value(topic),
      joinRule: drift.Value(joinRule),
      drafting: drift.Value(drafting),
      direct: drift.Value(direct),
      sending: drift.Value(sending),
      invite: drift.Value(invite),
      guestEnabled: drift.Value(guestEnabled),
      encryptionEnabled: drift.Value(encryptionEnabled),
      worldReadable: drift.Value(worldReadable),
      hidden: drift.Value(hidden),
      archived: drift.Value(archived),
      lastBatch: drift.Value(lastBatch),
      prevBatch: drift.Value(prevBatch),
      nextBatch: drift.Value(nextBatch),
      lastRead: drift.Value(lastRead),
      lastUpdate: drift.Value(lastUpdate),
      totalJoinedUsers: drift.Value(totalJoinedUsers),
      namePriority: drift.Value(namePriority),
      draft: drift.Value(draft),
      reply: drift.Value(reply),
      userIds: drift.Value(userIds),
    ).toColumns(nullToAbsent);
  }
}

typedef Chat = Room;
