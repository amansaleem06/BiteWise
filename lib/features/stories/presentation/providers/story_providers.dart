import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/firestore_story_repository.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';

final storyRepositoryProvider = Provider<StoryRepository>(
  (ref) => FirestoreStoryRepository(),
);

final storyRingsProvider = StreamProvider.autoDispose<List<StoryRing>>(
  (ref) => ref.watch(storyRepositoryProvider).watchRings(),
);

final storyCommentsProvider =
    StreamProvider.autoDispose.family<List<StoryComment>, String>(
  (ref, storyId) => ref.watch(storyRepositoryProvider).watchComments(storyId),
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
