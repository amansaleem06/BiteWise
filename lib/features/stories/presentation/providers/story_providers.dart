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

class StoryActions {
  StoryActions(this._repo);

  final StoryRepository _repo;

  Future<void> publish(XFile image) => _repo.publish(image);
}

final storyActionsProvider = Provider<StoryActions>(
  (ref) => StoryActions(ref.read(storyRepositoryProvider)),
);
