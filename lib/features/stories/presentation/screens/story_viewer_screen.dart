import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_snackbar.dart';
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
  var _liked = false;
  var _likeCount = 0;
  var _pauseCount = 0;

  List<StoryRing> get _rings => widget.args.rings;

  StoryRing get _ring => _rings[_authorIndex];

  Story get _story => _ring.stories[_storyIndex];

  @override
  void initState() {
    super.initState();
    _authorIndex = _rings.isEmpty
        ? 0
        : widget.args.startIndex.clamp(0, _rings.length - 1);
    _authorPages = PageController(initialPage: _authorIndex);
    _likeCount = _rings.isEmpty ? 0 : _story.likeCount;
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      })
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLike());
  }

  @override
  void dispose() {
    _authorPages.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _pause() {
    _pauseCount++;
    _progress.stop();
  }

  void _resume() {
    if (_pauseCount > 0) _pauseCount--;
    if (_pauseCount == 0) _progress.forward();
  }

  void _restart() {
    _likeCount = _story.likeCount;
    _liked = false;
    _progress
      ..reset()
      ..forward();
    _loadLike();
  }

  Future<void> _loadLike() async {
    if (_rings.isEmpty) return;
    final id = _story.id;
    try {
      final liked = await ref.read(storyRepositoryProvider).isLiked(id);
      if (mounted && _story.id == id) {
        setState(() => _liked = liked);
      }
    } catch (_) {}
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

  Future<void> _toggleLike() async {
    final next = !_liked;
    setState(() {
      _liked = next;
      _likeCount += next ? 1 : -1;
    });
    try {
      await ref.read(storyRepositoryProvider).setLiked(
            _story.id,
            liked: next,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = !next;
        _likeCount += next ? -1 : 1;
      });
      AppSnackbar.error(context, userMessageFrom(e));
    }
  }

  Future<void> _openComments() async {
    _pause();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      builder: (ctx) => _StoryCommentsSheet(storyId: _story.id),
    );
    if (mounted) _resume();
  }

  String _remainingLabel(DateTime? expiresAt) {
    if (expiresAt == null) return '';
    final left = expiresAt.difference(DateTime.now());
    if (left.isNegative) return 'expired';
    if (left.inHours >= 1) return '${left.inHours}h left';
    if (left.inMinutes >= 1) return '${left.inMinutes}m left';
    return 'moments left';
  }

  @override
  Widget build(BuildContext context) {
    if (_rings.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final me = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
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
          final story = i == _authorIndex ? _story : ring.stories.first;
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
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0x99000000), Colors.transparent],
                  ),
                ),
              ),
              Positioned.fill(
                top: 88,
                bottom: 88,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final w = MediaQuery.sizeOf(context).width;
                    if (d.globalPosition.dx < w * 0.28) {
                      _previous();
                    } else {
                      _next();
                    }
                  },
                  onLongPressStart: (_) => _pause(),
                  onLongPressEnd: (_) => _resume(),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.cream,
                            ),
                          ),
                          Expanded(
                            child: Row(
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
                                            borderRadius:
                                                BorderRadius.circular(99),
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
                          ),
                          if (story.authorId == me)
                            IconButton(
                              onPressed: _deleteMine,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.cream,
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: Row(
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ring.authorName,
                                    style: GoogleFonts.sourceSans3(
                                      color: AppColors.cream,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    [
                                      Formatters.relativeTime(story.createdAt),
                                      _remainingLabel(story.expiresAt),
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                    style: GoogleFonts.sourceSans3(
                                      color: AppColors.cream
                                          .withValues(alpha: 0.78),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (ring.postedAsRestaurant)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cream.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  'Page',
                                  style: GoogleFonts.sourceSans3(
                                    color: AppColors.cream,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _toggleLike,
                              icon: Icon(
                                _liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: _liked
                                    ? const Color(0xFFE85D4C)
                                    : AppColors.cream,
                              ),
                            ),
                            if (_likeCount > 0)
                              Text(
                                Formatters.compactCount(_likeCount),
                                style: GoogleFonts.sourceSans3(
                                  color: AppColors.cream,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            IconButton(
                              onPressed: _openComments,
                              icon: const Icon(
                                Icons.mode_comment_outlined,
                                color: AppColors.cream,
                              ),
                            ),
                            if (story.commentCount > 0)
                              Text(
                                Formatters.compactCount(story.commentCount),
                                style: GoogleFonts.sourceSans3(
                                  color: AppColors.cream,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoryCommentsSheet extends ConsumerStatefulWidget {
  const _StoryCommentsSheet({required this.storyId});

  final String storyId;

  @override
  ConsumerState<_StoryCommentsSheet> createState() =>
      _StoryCommentsSheetState();
}

class _StoryCommentsSheetState extends ConsumerState<_StoryCommentsSheet> {
  final _controller = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(storyRepositoryProvider).addComment(widget.storyId, text);
      _controller.clear();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, userMessageFrom(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(storyCommentsProvider(widget.storyId));
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineLight,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Comments',
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            Expanded(
              child: comments.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(userMessageFrom(e))),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'Be the first to reply',
                        style: GoogleFonts.sourceSans3(
                          color: AppColors.charcoal.withValues(alpha: 0.55),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final c = items[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: c.authorPhotoUrl != null
                              ? CachedNetworkImageProvider(c.authorPhotoUrl!)
                              : null,
                        ),
                        title: Text(
                          c.authorName,
                          style: GoogleFonts.sourceSans3(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(c.text),
                        trailing: Text(
                          Formatters.relativeTime(c.createdAt),
                          style: GoogleFonts.sourceSans3(fontSize: 11),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      maxLength: 280,
                      decoration: const InputDecoration(
                        hintText: 'Reply…',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
