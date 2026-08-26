import 'package:image_picker/image_picker.dart';

import '../entities/story.dart';

abstract interface class StoryRepository {
  Stream<List<StoryRing>> watchRings();

  Future<void> publish(XFile image, {bool asRestaurant = false});

  Future<void> delete(String storyId);

  Future<bool> isLiked(String storyId);

  Future<void> setLiked(String storyId, {required bool liked});

  Stream<List<StoryComment>> watchComments(String storyId);

  Future<void> addComment(String storyId, String text);
}
