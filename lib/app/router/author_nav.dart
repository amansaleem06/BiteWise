import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/feed/domain/entities/post.dart';
import 'routes.dart';

/// Opens the public identity behind a post — the restaurant page when
/// the plate was published as the business, otherwise the author's profile.
void openPostAuthor(BuildContext context, Post post) {
  final pageId = post.pageId;
  if (pageId != null) {
    context.push(Routes.restaurantPath(pageId));
  } else {
    context.push(Routes.userPath(post.authorId));
  }
}
