import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:syphon_demo/domain/user/model.dart';

part 'state.g.dart';

@JsonSerializable()
class UserStore extends Equatable {
  // user.id's
  final List<String> blocked;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final Map<String, User> users;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool loading;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<User> invites;

  const UserStore({
    this.users = const {},
    this.invites = const [],
    this.blocked = const [],
    this.loading = false,
  });

  @override
  List<Object> get props => [
        users,
        invites,
        loading,
        blocked,
      ];

  UserStore copyWith({
    bool? loading,
    List<User>? invites,
    Map<String, User>? users,
    List<String>? blocked,
  }) =>
      UserStore(
        users: users ?? this.users,
        invites: invites ?? this.invites,
        loading: loading ?? this.loading,
        blocked: blocked ?? this.blocked,
      );
  Map<String, dynamic> toJson() => _$UserStoreToJson(this);

  factory UserStore.fromJson(Map<String, dynamic> json) => _$UserStoreFromJson(json);
}
