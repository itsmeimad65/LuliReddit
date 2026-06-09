import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

/// True when the platform should use the iOS 26 "Liquid Glass" treatment.
bool get useLiquidGlass => Platform.isIOS;

/// A translucent, blurred "liquid glass" surface for chrome (nav bar, search
/// pill, sheets) on iOS. On other platforms it renders a solid Material using
/// [fallbackColor] so the Material 3 "Bloom" look is preserved.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.fallbackColor,
    this.blur = 24,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color? fallbackColor;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (!useLiquidGlass) {
      return Material(
        color: fallbackColor ?? cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // Translucent tint so blurred content shows through (the "glass").
            color: cs.surface.withValues(alpha: dark ? 0.44 : 0.6),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? 0.14 : 0.55),
              width: 1,
            ),
            // Soft specular sheen from the top — the "liquid" highlight.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: dark ? 0.10 : 0.22),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
          // InkWell children need a Material ancestor for ripples.
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}
