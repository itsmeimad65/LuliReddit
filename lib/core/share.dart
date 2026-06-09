import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet for a URL. Passing [context] lets us anchor the
/// iOS/iPad popover correctly (otherwise the sheet can silently fail to show).
Future<void> shareUrl(BuildContext context, String url, {String? subject}) async {
  Rect? origin;
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    origin = box.localToGlobal(Offset.zero) & box.size;
  }
  try {
    await Share.share(url, subject: subject, sharePositionOrigin: origin);
  } catch (_) {
    // ignore — user dismissed or platform refused
  }
}
