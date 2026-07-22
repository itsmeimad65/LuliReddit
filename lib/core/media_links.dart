// Detection of media URLs embedded in comment/post markdown, so we can render
// them natively (image/video viewers) instead of kicking out to a browser.

/// Path (ignoring the query string), lowercased — reddit appends `?width=…&s=…`.
String _path(Uri u) => u.path.toLowerCase();

bool isImageUrl(Uri u) {
  final p = _path(u);
  if (p.endsWith('.jpg') ||
      p.endsWith('.jpeg') ||
      p.endsWith('.png') ||
      p.endsWith('.webp') ||
      p.endsWith('.gif')) {
    return true;
  }
  final host = u.host.toLowerCase();
  return host == 'i.redd.it' ||
      host == 'preview.redd.it' ||
      host == 'i.imgur.com';
}

bool isVideoUrl(Uri u) {
  final p = _path(u);
  if (p.endsWith('.mp4') || p.endsWith('.gifv')) return true;
  final host = u.host.toLowerCase();
  return host == 'v.redd.it' ||
      host == 'redgifs.com' ||
      host == 'www.redgifs.com';
}

bool isMediaUrl(Uri u) => isVideoUrl(u) || isImageUrl(u);

/// True when the URL points at an animated GIF (rendered as an image, but we
/// keep it distinct so callers can badge it).
bool isGifUrl(Uri u) => _path(u).endsWith('.gif');

final _urlRe = RegExp(r'https?://[^\s<>\)\]"]+');

/// Media URLs referenced anywhere in [markdown] (bare links or `![](url)`),
/// de-duplicated and in order of appearance.
List<Uri> extractMediaLinks(String markdown) {
  final out = <Uri>[];
  final seen = <String>{};
  for (final m in _urlRe.allMatches(markdown)) {
    // Trim trailing markdown/sentence punctuation the regex may have caught.
    var raw = m.group(0)!;
    while (raw.isNotEmpty && '.,;:!*_'.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !isMediaUrl(uri)) continue;
    if (seen.add(raw)) out.add(uri);
  }
  return out;
}
