import 'package:flutter/material.dart';

class ThickButton extends StatelessWidget {
  ThickButton({super.key});
  final double corner = 30;
  final int upfactor = -60;
  final Color bColor = Color(0xFF212121);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red,
              Colors.grey.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.1125),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight
          )
        ),
        width: double.infinity,
        height: double.infinity,
        child: Center(

          // Outer Box
          child: Container(
            padding: EdgeInsets.all(1.375),
            margin: EdgeInsets.symmetric(horizontal: 50, vertical: 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                colors: [
                  Color.from(alpha: .25, red: bColor.r + upfactor, blue: bColor.b + upfactor, green: bColor.g + upfactor),
                  Color.from(alpha: .175, red: bColor.r + upfactor, blue: bColor.b + upfactor, green: bColor.g + upfactor),
                ],
              ),
              borderRadius: BorderRadius.circular(corner),
            ),

            //Inner Box
            child: Container(
              padding: EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: bColor.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Take a look at the seamless neat border, even though it's not a border.",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
