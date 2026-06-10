import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] holding everything sensitive:
/// the user's Reddit API credentials (entered at login) and OAuth tokens.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  // Keys
  static const _kClientId = 'client_id';
  static const _kRedirectUri = 'redirect_uri';
  static const _kGiphyKey = 'giphy_api_key';
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kTokenExpiry = 'token_expiry'; // millis since epoch
  static const _kUsername = 'username';

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> _write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);

  // --- API credentials ---
  Future<String?> get clientId => read(_kClientId);
  Future<String?> get redirectUri => read(_kRedirectUri);
  Future<String?> get giphyKey => read(_kGiphyKey);

  Future<void> saveCredentials({
    required String clientId,
    required String redirectUri,
    String? giphyKey,
  }) async {
    await _write(_kClientId, clientId);
    await _write(_kRedirectUri, redirectUri);
    await _write(_kGiphyKey, (giphyKey != null && giphyKey.isEmpty) ? null : giphyKey);
  }

  // --- Tokens ---
  Future<String?> get accessToken => read(_kAccessToken);
  Future<String?> get refreshToken => read(_kRefreshToken);
  Future<String?> get username => read(_kUsername);

  Future<DateTime?> get tokenExpiry async {
    final raw = await read(_kTokenExpiry);
    if (raw == null) return null;
    final millis = int.tryParse(raw);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    required DateTime expiry,
  }) async {
    await _write(_kAccessToken, accessToken);
    if (refreshToken != null) await _write(_kRefreshToken, refreshToken);
    await _write(_kTokenExpiry, expiry.millisecondsSinceEpoch.toString());
  }

  Future<void> saveUsername(String? username) => _write(_kUsername, username);

  // --- Multi-account ---
  // We persist a map of {username: refreshToken}. The "active slot" keys above
  // (access/refresh/expiry/username) mirror whichever account is current; the
  // access token is ephemeral and re-derived from the refresh token on demand.
  static const _kAccounts = 'accounts_json';

  Future<Map<String, String>> _accountsMap() async {
    final raw = await read(_kAccounts);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map;
      return m.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<List<String>> get accounts async => (await _accountsMap()).keys.toList();

  Future<void> upsertAccount(String username, String refreshToken) async {
    final m = await _accountsMap();
    m[username] = refreshToken;
    await _write(_kAccounts, jsonEncode(m));
  }

  Future<void> removeAccountEntry(String username) async {
    final m = await _accountsMap();
    m.remove(username);
    await _write(_kAccounts, jsonEncode(m));
  }

  Future<void> clearAccounts() => _storage.delete(key: _kAccounts);

  /// Loads [username]'s stored refresh token into the active slot and clears the
  /// (other account's) access token so the next API call refreshes for the new
  /// account. Returns false if the account isn't stored.
  Future<bool> activateAccount(String username) async {
    final rt = (await _accountsMap())[username];
    if (rt == null) return false;
    await _write(_kRefreshToken, rt);
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kTokenExpiry);
    await _write(_kUsername, username);
    return true;
  }

  /// Clears tokens + username but keeps API credentials (so re-login is quick).
  Future<void> clearSession() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kTokenExpiry);
    await _storage.delete(key: _kUsername);
  }

  /// Full wipe — credentials and session.
  Future<void> clearAll() => _storage.deleteAll();
}
