import 'package:flutter/material.dart';

class AnimatedStreamingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const AnimatedStreamingText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<AnimatedStreamingText> createState() => _AnimatedStreamingTextState();
}

class _AnimatedStreamingTextState extends State<AnimatedStreamingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _visibleText = '';
  String _newTextToAnimate = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _visibleText = widget.text;
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(AnimatedStreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text) {
      if (widget.text.startsWith(_visibleText) &&
          widget.text.length > _visibleText.length) {
        setState(() {
          if (_newTextToAnimate.isNotEmpty) {
            _visibleText += _newTextToAnimate;
          }
          _newTextToAnimate = widget.text.substring(_visibleText.length);
        });
        _controller.reset();
        _controller.forward();
      } else if (widget.text.length < _visibleText.length ||
          !widget.text.startsWith(_visibleText)) {
        setState(() {
          _visibleText = widget.text;
          _newTextToAnimate = '';
        });
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(text: _visibleText, style: widget.style),
          if (_newTextToAnimate.isNotEmpty)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(_newTextToAnimate, style: widget.style),
              ),
            ),
        ],
      ),
    );
  }
}
