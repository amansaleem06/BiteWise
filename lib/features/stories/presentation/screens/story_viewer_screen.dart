import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/story.dart';
import '../providers/story_providers.dart';

class StoryViewerArgs {
  const StoryViewerArgs({
    required this.rings,
    this.startIndex = 0,
  });

  final List<StoryRing> rings;
  final int startIndex;
}

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key, required this.args});

  final StoryViewerArgs args;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _authorPages;
  late AnimationController _progress;
  var _authorIndex = 0;
  var _storyIndex = 0;

  List<StoryRing> get _rings => widget.args.rings;

  StoryRing get _ring => _rings[_authorIndex];

  Story get _story => _ring.stories[_storyIndex];

  @override
  void initState() {
    super.initState();
    _authorIndex = widget.args.startIndex.clamp(0, _rings.length - 1);
    _authorPages = PageController(initialPage: _authorIndex);
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      })
      ..forward();
  }

  @override
  void dispose() {
    _authorPages.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _restart() {
    _progress
      ..reset()
      ..forward();
  }

  void _next() {
    if (_storyIndex < _ring.stories.length - 1) {
      setState(() => _storyIndex++);
      _restart();
      return;
    }
    if (_authorIndex < _rings.length - 1) {
      _authorPages.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      return;
    }
    context.pop();
  }

  void _previous() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _restart();
      return;
    }
    if (_authorIndex > 0) {
      _authorPages.previousPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      return;
    }
    _restart();
  }

  Future<void> _deleteMine() async {
    final me = ref.read(currentUserProvider)?.uid;
    if (me == null || _story.authorId != me) return;
    await ref.read(storyRepositoryProvider).delete(_story.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_rings.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final me = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final w = MediaQuery.sizeOf(context).width;
          if (d.globalPosition.dx < w * 0.28) {
            _previous();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => _progress.stop(),
        onLongPressEnd: (_) => _progress.forward(),
        child: PageView.builder(
          controller: _authorPages,
          itemCount: _rings.length,
          onPageChanged: (i) {
            setState(() {
              _authorIndex = i;
              _storyIndex = 0;
            });
            _restart();
          },
          itemBuilder: (context, i) {
            final ring = _rings[i];
            final story = i == _authorIndex
                ? _story
                : ring.stories.first;
            return Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: story.mediaUrl,
                  fit: BoxFit.cover,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x99000000), Colors.transparent],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (var s = 0; s < ring.stories.length; s++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _progress,
                                    builder: (context, _) {
                                      final value = i != _authorIndex
                                          ? 0.0
                                          : s < _storyIndex
                                              ? 1.0
                                              : s == _storyIndex
                                                  ? _progress.value
                                                  : 0.0;
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                          value: value,
                                          minHeight: 3,
                                          backgroundColor:
                                              Colors.white.withValues(
                                            alpha: 0.28,
                                          ),
                                          color: AppColors.cream,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage: ring.authorPhotoUrl != null
                                  ? CachedNetworkImageProvider(
                                      ring.authorPhotoUrl!,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ring.authorName,
                                style: GoogleFonts.sourceSans3(
                                  color: AppColors.cream,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (story.authorId == me)
                              IconButton(
                                onPressed: _deleteMine,
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.cream,
                                ),
                              ),
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.cream,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
