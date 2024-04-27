import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

///
/// Message Session model
///
/// allows for multiple identitykey sessions and sorting
/// based on last used or created
///
/// NOTE: potential to sort messages sessions based on local createdAt timestamps
///
@JsonSerializable()
class MessageSession extends Equatable {
  final int index;
  final String serialized; // serialized session
  final int createdAt;

  const MessageSession({
    this.index = 0,
    required this.serialized,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [index, serialized, createdAt];

  Map<String, dynamic> toJson() => _$MessageSessionToJson(this);
  factory MessageSession.fromJson(Map<String, dynamic> json) => _$MessageSessionFromJson(json);
}
