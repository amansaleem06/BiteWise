import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/app_user.dart';

/// A user profile as seen by the current viewer.
class UserProfile extends Equatable {
  const UserProfile({required this.user, this.isFollowedByMe = false});

  final AppUser user;
  final bool isFollowedByMe;

  UserProfile copyWith({AppUser? user, bool? isFollowedByMe}) => UserProfile(
        user: user ?? this.user,
        isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      );

  @override
  List<Object?> get props => [user, isFollowedByMe];
}
