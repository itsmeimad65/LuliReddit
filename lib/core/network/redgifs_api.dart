import 'package:dio/dio.dart';

class RedgifsApi {
  RedgifsApi._();

  static final _dio = Dio(BaseOptions(baseUrl: 'https://api.redgifs.com'));

  static String? _token;
  static DateTime? _tokenExpiry;

  static Future<String> _getToken() async {
    if (_token != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _token!;
    }
    final res = await _dio.get('/v2/auth/temporary');
    _token = res.data['token'] as String;
    _tokenExpiry = DateTime.now().add(const Duration(hours: 23));
    return _token!;
  }

  static String? _extractId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (!host.contains('redgifs.com')) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    var id = segments.last;
    final dash = id.indexOf('-');
    if (dash > 0) id = id.substring(0, dash);
    return id;
  }

  static bool isRedgifsUrl(String url) => _extractId(url) != null;

  static Future<String> resolveUrl(String url) async {
    final id = _extractId(url);
    if (id == null) return url;
    final token = await _getToken();
    final res = await _dio.get(
      '/v2/gifs/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
      queryParameters: {'user-agent': 'LuliReddit/1.0'},
    );
    final gif = res.data['gif'] as Map?;
    if (gif == null) return url;
    final urls = gif['urls'] as Map?;
    if (urls == null) return url;
    final mp4 = (urls['hd'] ?? urls['sd']) as String?;
    if (mp4 == null) return url;
    return mp4.replaceAll('-silent', '');
  }
}
