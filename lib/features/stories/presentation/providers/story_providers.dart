import '../../../safety/presentation/providers/safety_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/firestore_story_repository.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';

final storyRepositoryProvider = Provider<StoryRepository>(
  (ref) => FirestoreStoryRepository(),
);

final storyRingsProvider = StreamProvider.autoDispose<List<StoryRing>>(
  (ref) async* {
    final blocked = await ref.watch(blockedUserIdsProvider.future);
    yield* ref.watch(storyRepositoryProvider).watchRings().map(
          (rings) => rings.where((r) => !blocked.contains(r.authorId)).toList(),
        );
  },
);

final storyCommentsProvider =
    StreamProvider.autoDispose.family<List<StoryComment>, String>(
  (ref, storyId) async* {
    final blocked = await ref.watch(blockedUserIdsProvider.future);
    yield* ref.watch(storyRepositoryProvider).watchComments(storyId).map(
          (items) => items.where((c) => !blocked.contains(c.authorId)).toList(),
        );
  },
);

class StoryActions {
  StoryActions(this._repo);

  final StoryRepository _repo;

  Future<void> publish(XFile image, {bool asRestaurant = false}) =>
      _repo.publish(image, asRestaurant: asRestaurant);
}

final storyActionsProvider = Provider<StoryActions>(
  (ref) => StoryActions(ref.read(storyRepositoryProvider)),
);
