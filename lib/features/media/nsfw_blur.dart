import 'dart:ui';

import 'package:flutter/material.dart';

/// Wraps media with a frosted blur + label until tapped to reveal.
/// When [blur] is false it renders [child] unchanged.
class NsfwBlur extends StatefulWidget {
  const NsfwBlur({
    super.key,
    required this.blur,
    required this.child,
    this.isSpoiler = false,
  });
  final bool blur;
  final bool isSpoiler;
  final Widget child;

  @override
  State<NsfwBlur> createState() => _NsfwBlurState();
}

class _NsfwBlurState extends State<NsfwBlur> {
  bool _revealed = false;

  @override
  void didUpdateWidget(covariant NsfwBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blur != widget.blur) _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.blur || _revealed) return widget.child;
    final label = widget.isSpoiler ? 'Spoiler · tap to view' : 'NSFW · tap to view';
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Material(
                color: Colors.black.withValues(alpha: 0.25),
                child: InkWell(
                  onTap: () => setState(() => _revealed = true),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_off_rounded,
                            color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
