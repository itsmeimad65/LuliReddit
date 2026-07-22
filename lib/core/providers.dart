import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reddit_repository.dart';
import '../features/auth/auth_controller.dart';
import '../features/settings/settings_controller.dart';
import '../models/reddit_user.dart';
import '../models/subreddit.dart';
import 'network/rate_limit.dart';
import 'network/reddit_client.dart';

final redditClientProvider = Provider<RedditClient>((ref) {
  final client = RedditClient(
    ref.watch(secureStoreProvider),
    ref.watch(authRepositoryProvider),
    onRateLimit: (rl) => ref.read(rateLimitProvider.notifier).state = rl,
    cacheEnabled: () => ref.read(settingsControllerProvider).offlineCache,
  );
  ref.listen(authControllerProvider, (_, __) => client.invalidateAuthConfig());
  return client;
});

final redditRepositoryProvider = Provider<RedditRepository>((ref) {
  final repo = RedditRepository(ref.watch(redditClientProvider));
  void apply(Settings s) {
    repo.subsCacheEnabled = s.subsCacheEnabled;
    repo.subsCacheTtl = Duration(minutes: s.subsCacheMinutes);
  }

  apply(ref.read(settingsControllerProvider));
  ref.listen(settingsControllerProvider, (_, s) => apply(s));
  return repo;
});

final subredditIconProvider =
    NotifierProvider<SubredditIconCache, Map<String, String?>>(
  SubredditIconCache.new,
);

class SubredditIconCache extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => {};

  void setIcon(String subreddit, String? iconUrl) {
    if (iconUrl == null || iconUrl.isEmpty) return;
    if (state[subreddit] == iconUrl) return;
    state = {...state, subreddit: iconUrl};
  }

  void setAll(List<Subreddit> subs) {
    var changed = false;
    for (final s in subs) {
      if (s.iconUrl != null && s.iconUrl!.isNotEmpty && state[s.name] != s.iconUrl) {
        state = {...state, s.name: s.iconUrl};
        changed = true;
      }
    }
  }
}

final userIconProvider =
    NotifierProvider<UserIconCache, Map<String, String?>>(
  UserIconCache.new,
);

class UserIconCache extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => {};

  void setIcon(String username, String? iconUrl) {
    if (iconUrl == null || iconUrl.isEmpty) return;
    if (state[username] == iconUrl) return;
    state = {...state, username: iconUrl};
  }

  void setAll(List<RedditUser> users) {
    for (final u in users) {
      if (u.iconUrl != null && u.iconUrl!.isNotEmpty && state[u.name] != u.iconUrl) {
        state = {...state, u.name: u.iconUrl};
      }
    }
  }
}

/// Fetches the current user's profile (used to populate their avatar).
final currentUserAboutProvider = FutureProvider.autoDispose<RedditUser?>((ref) async {
  final auth = ref.watch(authControllerProvider).valueOrNull;
  if (auth == null) return null;
  final repo = ref.watch(redditRepositoryProvider);
  return repo.getUserAbout(auth.username);
});

/// Fetches & caches a subreddit's icon by name (used by feed cards).
final subredditIconAboutProvider = FutureProvider.family<Subreddit?, String>((ref, name) async {
  try {
    final repo = ref.watch(redditRepositoryProvider);
    final sub = await repo.getSubredditAbout(name);
    if (sub.iconUrl != null) {
      ref.read(subredditIconProvider.notifier).setIcon(name, sub.iconUrl);
    }
    return sub;
  } catch (_) {
    return null;
  }
});

/// Fetches & caches a user's icon by name (used by comment/search avatars).
final userAboutProvider = FutureProvider.family<RedditUser?, String>((ref, name) async {
  try {
    final repo = ref.watch(redditRepositoryProvider);
    final user = await repo.getUserAbout(name);
    if (user.iconUrl != null) {
      ref.read(userIconProvider.notifier).setIcon(name, user.iconUrl);
    }
    return user;
  } catch (_) {
    return null;
  }
});
