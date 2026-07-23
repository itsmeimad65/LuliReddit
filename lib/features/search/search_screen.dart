import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../settings/settings_controller.dart';
import '../../models/post.dart';
import '../../models/reddit_user.dart';
import '../../models/subreddit.dart';
import '../feed/post_card.dart';
import 'recent_visits_store.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialSubreddit, this.initialQuery});
  final String? initialSubreddit;
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  bool _loadingMore = false;
  String _query = '';
  String _sort = 'relevance';
  String _time = 'all';
  String? _after;
  String? _scopeSubreddit;
  List<Post> _posts = [];
  List<Subreddit> _subs = [];
  List<RedditUser> _users = [];
  List<String> _recent = [];
  List<Subreddit> _autocomplete = [];
  Timer? _autoTimer;

  static const _sorts = {
    'relevance': 'Relevance',
    'hot': 'Hot',
    'top': 'Top',
    'new': 'New',
    'comments': 'Comments',
  };
  static const _times = {
    'hour': 'Hour',
    'day': 'Day',
    'week': 'Week',
    'month': 'Month',
    'year': 'Year',
    'all': 'All time',
  };
  static const _recentKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    _recent = ref.read(sharedPrefsProvider).getStringList(_recentKey) ?? [];
    if (widget.initialSubreddit != null) {
      _scopeSubreddit = widget.initialSubreddit;
    }
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _controller.text = q;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _search(q));
    }
  }

  void _onSearchChanged(String q) {
    _autoTimer?.cancel();
    if (q.trim().isEmpty || q.trim().length < 2) {
      if (_autocomplete.isNotEmpty) setState(() => _autocomplete = []);
      return;
    }
    _autoTimer =
        Timer(const Duration(milliseconds: 300), () => _fetchAutocomplete(q.trim()));
  }

  Future<void> _fetchAutocomplete(String q) async {
    try {
      final results =
          await ref.read(redditRepositoryProvider).subredditAutocomplete(q);
      if (mounted) setState(() => _autocomplete = results);
    } catch (_) {}
  }

  void _saveRecent(String q) {
    final list = [q, ..._recent.where((e) => e != q)].take(12).toList();
    ref.read(sharedPrefsProvider).setStringList(_recentKey, list);
    setState(() => _recent = list);
  }

  void _removeRecent(String q) {
    final list = _recent.where((e) => e != q).toList();
    ref.read(sharedPrefsProvider).setStringList(_recentKey, list);
    setState(() => _recent = list);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _autoTimer?.cancel();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _query = '';
      _posts = [];
      _subs = [];
      _users = [];
    });
  }

  Future<void> _search(String q, {bool saveRecent = true}) async {
    q = q.trim();
    if (q.isEmpty) return;
    if (_controller.text != q) _controller.text = q;
    FocusScope.of(context).unfocus();
    setState(() => _autocomplete = []);
    if (saveRecent) _saveRecent(q);
    setState(() {
      _loading = true;
      _query = q;
      _after = null;
      _posts = [];
      _subs = [];
      _users = [];
    });
    final repo = ref.read(redditRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.searchPosts(q,
            subreddit: _scopeSubreddit, sort: _sort, time: _time),
        if (_scopeSubreddit == null)
          repo.searchSubreddits(q)
        else
          Future.value(<Subreddit>[]),
        if (_scopeSubreddit == null)
          repo.searchUsers(q)
        else
          Future.value(<RedditUser>[]),
      ]);
      if (!mounted) return;
      final listing = results[0] as dynamic;
      ref.read(subredditIconProvider.notifier).setAll(results[1] as List<Subreddit>);
      ref.read(userIconProvider.notifier).setAll(results[2] as List<RedditUser>);
      setState(() {
        _posts = listing.items as List<Post>;
        _after = listing.after as String?;
        _subs = results[1] as List<Subreddit>;
        _users = results[2] as List<RedditUser>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || _after == null) return;
    setState(() => _loadingMore = true);
    try {
      final listing = await ref.read(redditRepositoryProvider).searchPosts(
        _query,
        subreddit: _scopeSubreddit,
        sort: _sort,
        time: _time,
        after: _after,
      );
      if (!mounted) return;
      setState(() {
        _posts.addAll(listing.items as List<Post>);
        _after = listing.after as String?;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final restricted = _scopeSubreddit != null;
    return DefaultTabController(
      length: restricted ? 1 : 3,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          title: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: (widget.initialQuery?.trim().isEmpty ?? true),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (q) {
              setState(() {});
              _onSearchChanged(q);
            },
            decoration: InputDecoration(
              hintText: restricted
                  ? 'Search in r/$_scopeSubreddit'
                  : 'Search Reddit',
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: _clear,
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            if (_query.isNotEmpty)
              IconButton(
                icon: Icon(
                  ref.watch(savedSearchesProvider).contains(_query)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
                tooltip: ref.watch(savedSearchesProvider).contains(_query)
                    ? 'Unsave search'
                    : 'Save search',
                onPressed: () =>
                    ref.read(savedSearchesProvider.notifier).toggle(_query),
              ),
          ],
          bottom: restricted
              ? null
              : const TabBar(tabs: [
                  Tab(text: 'Posts'),
                  Tab(text: 'Subreddits'),
                  Tab(text: 'Users'),
                ]),
        ),
        body: Stack(
          children: [
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _query.isEmpty
                    ? _empty(cs)
                    : TabBarView(
                        children: [
                          _postsTab(),
                          if (!restricted) _subsTab(),
                          if (!restricted) _usersTab(),
                        ],
                      ),
            // Autocomplete overlay
            if (_autocomplete.isNotEmpty && _focusNode.hasFocus)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 4,
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _autocomplete.length,
                      itemBuilder: (_, i) {
                        final s = _autocomplete[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: cs.secondaryContainer,
                            backgroundImage: s.iconUrl != null
                                ? CachedNetworkImageProvider(s.iconUrl!)
                                : null,
                            child: s.iconUrl == null
                                ? Text(s.name[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 13))
                                : null,
                          ),
                          title: Text(s.namePrefixed),
                          subtitle: Text(
                              '${compactNumber(s.subscribers)} members'),
                          onTap: () {
                            _scopeSubreddit = s.name;
                            ref.read(subredditIconProvider.notifier)
                                .setIcon(s.name, s.iconUrl);
                            _controller.text = '';
                            _autocomplete = [];
                            _focusNode.unfocus();
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty(ColorScheme cs) {
    final recentSubs = ref.watch(recentSubredditsProvider);
    final recentUsers = ref.watch(recentUsersProvider);
    final savedSearches = ref.watch(savedSearchesProvider);
    final hasRecent = recentSubs.isNotEmpty || recentUsers.isNotEmpty || _recent.isNotEmpty || savedSearches.isNotEmpty;
    if (!hasRecent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Search posts, subreddits and users',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 130),
      children: [
        if (recentSubs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 2),
            child: Row(
              children: [
                Text('Recent subreddits',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      ref.read(recentSubredditsProvider.notifier).clear(),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recentSubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _RecentSubredditChip(name: recentSubs[i]),
            ),
          ),
        ],
        if (recentUsers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 2),
            child: Row(
              children: [
                Text('Recent users',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      ref.read(recentUsersProvider.notifier).clear(),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recentUsers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _RecentUserChip(name: recentUsers[i]),
            ),
          ),
        ],
        if (savedSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Icon(Icons.bookmark_rounded, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Saved searches',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          for (final q in savedSearches)
            ListTile(
              leading: const Icon(Icons.bookmark_rounded),
              title: Text(q),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.north_west_rounded, size: 18),
                    tooltip: 'Search',
                    onPressed: () {
                      _controller.text = q;
                      _search(q, saveRecent: false);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_remove_rounded, size: 18),
                    tooltip: 'Unsave',
                    onPressed: () =>
                        ref.read(savedSearchesProvider.notifier).unsave(q),
                  ),
                ],
              ),
              onTap: () => _search(q),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Text('Recent',
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(sharedPrefsProvider).remove(_recentKey);
                  setState(() => _recent = []);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        for (final q in _recent)
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(q),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.north_west_rounded, size: 18),
                  tooltip: 'Search',
                  onPressed: () {
                    _controller.text = q;
                    _search(q, saveRecent: false);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Remove',
                  onPressed: () => _removeRecent(q),
                ),
              ],
            ),
            onTap: () => _search(q),
          ),
      ],
    );
  }

  Widget _filterBar() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
      child: Row(
        children: [
          // Scope picker
          ActionChip(
            avatar: Icon(_scopeSubreddit != null
                ? Icons.lock_rounded
                : Icons.public_rounded, size: 16),
            label: Text(_scopeSubreddit != null
                ? 'r/$_scopeSubreddit'
                : 'All'),
            onPressed: () => _pickScope(),
          ),
          const SizedBox(width: 8),
          for (final e in _sorts.entries) ...[
            ChoiceChip(
              label: Text(e.value),
              selected: _sort == e.key,
              onSelected: (_) {
                setState(() => _sort = e.key);
                _search(_query, saveRecent: false);
              },
            ),
            const SizedBox(width: 6),
          ],
          if (_sort == 'top') ...[
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              initialValue: _time,
              onSelected: (v) {
                setState(() => _time = v);
                _search(_query, saveRecent: false);
              },
              itemBuilder: (_) => [
                for (final t in _times.entries)
                  PopupMenuItem(value: t.key, child: Text(t.value)),
              ],
              child: Chip(
                avatar: const Icon(Icons.schedule_rounded, size: 16),
                label: Text(_times[_time] ?? 'All time'),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _pickScope() {
    final qCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search subreddit…',
                        isDense: true,
                      ),
                      onSubmitted: (q) async {
                        if (q.trim().isEmpty) return;
                        final subs =
                            await ref.read(redditRepositoryProvider).searchSubreddits(q.trim());
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        _pickSubreddit(subs);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _scopeSubreddit = null);
                },
                child: const Text('All subreddits'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickSubreddit(List<Subreddit> subs) {
    if (subs.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pick a subreddit'),
        children: [
          for (final s in subs.take(20))
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _scopeSubreddit = s.name);
                ref.read(subredditIconProvider.notifier).setIcon(s.name, s.iconUrl);
                if (_query.isNotEmpty) _search(_query, saveRecent: false);
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: s.iconUrl != null
                        ? CachedNetworkImageProvider(s.iconUrl!)
                        : null,
                    child: s.iconUrl == null
                        ? Text(s.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 11))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(s.namePrefixed),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _postsTab() => Column(
        children: [
          _filterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _search(_query, saveRecent: false),
              child: _posts.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No posts found')),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 130),
                      itemCount: _posts.length + (_after != null ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i >= _posts.length) {
                          _loadMorePosts();
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2))),
                          );
                        }
                        final p = _posts[i];
                        return PostCard(post: p);
                      },
                    ),
            ),
          ),
        ],
      );

  Widget _subsTab() {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => _search(_query, saveRecent: false),
      child: _subs.isEmpty
        ? ListView(children: const [
            SizedBox(height: 120),
            Center(child: Text('No subreddits found')),
          ])
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 130),
            itemCount: _subs.length,
            itemBuilder: (_, i) {
              final s = _subs[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  backgroundImage: s.iconUrl != null
                      ? CachedNetworkImageProvider(s.iconUrl!)
                      : null,
                  child: s.iconUrl == null
                      ? Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?')
                      : null,
                ),
                title: Text(s.namePrefixed),
                subtitle: Text('${compactNumber(s.subscribers)} members'),
                onTap: () => context.push('/r/${s.name}'),
              );
            },
          ),
    );
  }

  Widget _usersTab() {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => _search(_query, saveRecent: false),
      child: _users.isEmpty
        ? ListView(children: const [
            SizedBox(height: 120),
            Center(child: Text('No users found')),
          ])
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 130),
            itemCount: _users.length,
            itemBuilder: (_, i) {
              final u = _users[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  backgroundImage: u.iconUrl != null
                      ? CachedNetworkImageProvider(u.iconUrl!)
                      : null,
                  child: u.iconUrl == null
                      ? Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?')
                      : null,
                ),
                title: Text('u/${u.name}'),
                subtitle: Text('${compactNumber(u.linkKarma + u.commentKarma)} karma'),
                onTap: () => context.push('/u/${u.name}'),
              );
            },
          ),
     );
  }
}

class _RecentSubredditChip extends ConsumerWidget {
  const _RecentSubredditChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final iconUrl = ref.watch(subredditIconProvider)[name];
    if (iconUrl == null) ref.watch(subredditIconAboutProvider(name));
    return ActionChip(
      avatar: CircleAvatar(
        radius: 12,
        backgroundColor: cs.secondaryContainer,
        backgroundImage: iconUrl != null
            ? CachedNetworkImageProvider(iconUrl)
            : null,
        child: iconUrl == null
            ? Text(name[0].toUpperCase(),
                style: TextStyle(
                    color: cs.onSecondaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.bold))
            : null,
      ),
      label: Text('r/$name', style: const TextStyle(fontSize: 13)),
      onPressed: () => context.push('/r/$name'),
    );
  }
}

class _RecentUserChip extends ConsumerWidget {
  const _RecentUserChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final iconUrl = ref.watch(userIconProvider)[name];
    if (iconUrl == null) ref.watch(userAboutProvider(name));
    return ActionChip(
      avatar: CircleAvatar(
        radius: 12,
        backgroundColor: cs.tertiaryContainer,
        backgroundImage: iconUrl != null
            ? CachedNetworkImageProvider(iconUrl)
            : null,
        child: iconUrl == null
            ? Text(name[0].toUpperCase(),
                style: TextStyle(
                    color: cs.onTertiaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.bold))
            : null,
      ),
      label: Text('u/$name', style: const TextStyle(fontSize: 13)),
      onPressed: () => context.push('/u/$name'),
    );
  }
}
