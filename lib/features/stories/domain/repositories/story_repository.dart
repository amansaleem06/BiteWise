import 'package:image_picker/image_picker.dart';

import '../entities/story.dart';

abstract interface class StoryRepository {
  Stream<List<StoryRing>> watchRings();

  Future<void> publish(XFile image);

  Future<void> delete(String storyId);
}
