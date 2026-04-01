import 'package:flutter/material.dart';

class CustomLoader extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const CustomLoader({
    super.key,
    this.width = 50,
    this.height = 50,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Image.asset(
          'assets/images/#design.gif',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if the asset is missing
            return CircularProgressIndicator(
              color: color ?? Colors.blue,
            );
          },
        ),
      ),
    );
  }
}
