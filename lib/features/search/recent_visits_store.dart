import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import '../history/interest_store.dart' show userScopedPrefsKey;

class RecentSubredditsStore extends Notifier<List<String>> {
  static const _base = 'recent_subs';
  static const _cap = 10;
  late String _key;

  @override
  List<String> build() {
    _key = userScopedPrefsKey(ref, _base);
    return ref.read(sharedPrefsProvider).getStringList(_key) ?? [];
  }

  void visit(String name) {
    final list = [name, ...state.where((e) => e != name)].take(_cap).toList();
    state = list;
    _persist();
  }

  void remove(String name) {
    state = state.where((e) => e != name).toList();
    _persist();
  }

  void clear() {
    state = [];
    _persist();
  }

  void _persist() {
    ref.read(sharedPrefsProvider).setStringList(_key, state);
  }
}

final recentSubredditsProvider =
    NotifierProvider<RecentSubredditsStore, List<String>>(
        RecentSubredditsStore.new);

class RecentUsersStore extends Notifier<List<String>> {
  static const _base = 'recent_users';
  static const _cap = 10;
  late String _key;

  @override
  List<String> build() {
    _key = userScopedPrefsKey(ref, _base);
    return ref.read(sharedPrefsProvider).getStringList(_key) ?? [];
  }

  void visit(String name) {
    final list = [name, ...state.where((e) => e != name)].take(_cap).toList();
    state = list;
    _persist();
  }

  void remove(String name) {
    state = state.where((e) => e != name).toList();
    _persist();
  }

  void clear() {
    state = [];
    _persist();
  }

  void _persist() {
    ref.read(sharedPrefsProvider).setStringList(_key, state);
  }
}

final recentUsersProvider =
    NotifierProvider<RecentUsersStore, List<String>>(
        RecentUsersStore.new);
