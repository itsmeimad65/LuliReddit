import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/share.dart';
import '../../models/subreddit.dart';
import '../feed/post_list_view.dart';

final subredditAboutProvider =
    FutureProvider.autoDispose.family<Subreddit, String>((ref, name) {
  return ref.watch(redditRepositoryProvider).getSubredditAbout(name);
});

class SubredditScreen extends ConsumerStatefulWidget {
  const SubredditScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<SubredditScreen> createState() => _SubredditScreenState();
}

class _SubredditScreenState extends ConsumerState<SubredditScreen> {
  bool? _subOverride; // optimistic subscribe state

  @override
  Widget build(BuildContext context) {
    final about = ref.watch(subredditAboutProvider(widget.name));
    ref.listen(subredditAboutProvider(widget.name), (_, next) {
      next.whenData((s) => ref.read(subredditIconProvider.notifier).setIcon(s.name, s.iconUrl));
    });
    return Scaffold(
      appBar: AppBar(
        title: Text('r/${widget.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search?sr=${widget.name}'),
          ),
          IconButton(
            tooltip: 'About & rules',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () =>
                shareUrl(context, 'https://reddit.com/r/${widget.name}'),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: about.when(
          loading: () => const DrawerHeader(child: LinearProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (s) => _drawerContent(context, s),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/submit?sr=${widget.name}'),
        child: const Icon(Icons.edit_rounded),
      ),
      body: PostListView(
        feedKey: widget.name,
        header: about.when(
          loading: () => const SizedBox(height: 4, child: LinearProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (s) => _header(context, s),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (ctx, scroll) {
          final about =
              ref.read(subredditAboutProvider(widget.name)).valueOrNull;
          return _drawerContent(ctx, about);
        },
      ),
    );
  }

  Widget _drawerContent(BuildContext context, Subreddit? about) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (about != null) ...[
            if (about.bannerUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: about.bannerUrl!,
                  height: 90,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  backgroundImage: about.iconUrl != null
                      ? CachedNetworkImageProvider(about.iconUrl!)
                      : null,
                  child: about.iconUrl == null
                      ? Text(about.name.isNotEmpty
                          ? about.name[0].toUpperCase()
                          : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(about.namePrefixed,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${compactNumber(about.subscribers)} members',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            if (about.title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(about.title,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (about.description.isNotEmpty) ...[
              const Divider(height: 24),
              Text('About',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(about.description),
            ],
            const Divider(height: 24),
            Text('Rules',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
          ],
          FutureBuilder<List<(String, String)>>(
            future: ref
                .read(redditRepositoryProvider)
                .getSubredditRules(widget.name),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()));
              }
              final rules = snap.data ?? const [];
              if (rules.isEmpty) return const Text('No rules listed.');
              return Column(
                children: [
                  for (var i = 0; i < rules.length; i++)
                    Theme(
                      data: Theme.of(ctx)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('${i + 1}. ${rules[i].$1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        children: [
                          if (rules[i].$2.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(rules[i].$2),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Subreddit s) {
    final cs = Theme.of(context).colorScheme;
    final subscribed = _subOverride ?? s.userIsSubscriber ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.bannerUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: s.bannerUrl!,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: cs.secondaryContainer,
                          foregroundColor: cs.onSecondaryContainer,
                          backgroundImage: s.iconUrl != null
                              ? CachedNetworkImageProvider(s.iconUrl!)
                              : null,
                          child: s.iconUrl == null
                              ? Text(s.name.isNotEmpty
                                  ? s.name[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.namePrefixed,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              Text('${compactNumber(s.subscribers)} members',
                                  style:
                                      TextStyle(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _toggleSub(s, subscribed),
                          child: Text(subscribed ? 'Joined' : 'Join'),
                        ),
                      ],
                    ),
                    if (s.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(s.description,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSub(Subreddit s, bool currentlySubscribed) async {
    final next = !currentlySubscribed;
    setState(() => _subOverride = next);
    try {
      await ref.read(redditRepositoryProvider).setSubscribed(s.name, next);
    } catch (_) {
      if (mounted) setState(() => _subOverride = currentlySubscribed);
    }
  }
}
