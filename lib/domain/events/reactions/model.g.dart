// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Reaction _$ReactionFromJson(Map<String, dynamic> json) => Reaction(
      id: json['id'] as String?,
      userId: json['userId'] as String?,
      roomId: json['roomId'] as String?,
      type: json['type'] as String?,
      sender: json['sender'] as String?,
      stateKey: json['stateKey'] as String?,
      batch: json['batch'] as String?,
      prevBatch: json['prevBatch'] as String?,
      timestamp: json['timestamp'] as int? ?? 0,
      body: json['body'] as String?,
      relType: json['relType'] as String?,
      relEventId: json['relEventId'] as String?,
    );

Map<String, dynamic> _$ReactionToJson(Reaction instance) => <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'roomId': instance.roomId,
      'type': instance.type,
      'sender': instance.sender,
      'stateKey': instance.stateKey,
      'batch': instance.batch,
      'prevBatch': instance.prevBatch,
      'timestamp': instance.timestamp,
      'body': instance.body,
      'relType': instance.relType,
      'relEventId': instance.relEventId,
    };
