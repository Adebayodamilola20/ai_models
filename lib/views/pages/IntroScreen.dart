import 'package:emerge_x/views/pages/IntroPage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../shared/ProviderX/provider.dart';

class Introscreen extends StatefulWidget {
  const Introscreen({super.key});

  @override
  State<Introscreen> createState() => _IntroscreenState();
}

class _IntroscreenState extends State<Introscreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), 
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Spacer(flex: 1),
              Text(
                'Welcome',
                style: GoogleFonts.inter(
                color:  Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  
                ),
              ),
              Text(
                'to EmergeX',
                style: GoogleFonts.inter(
                color:  Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'EmergeX is a free AI assistant that can help you with a wide variety of tasks.',
                style: GoogleFonts.inter(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 1),

              // Feature 1
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 Icon(LucideIcons.flag, 
                  color:  Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                   size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Responses can be inaccurate',
                          style: GoogleFonts.inter(
                            color:  Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EmergeX may provide inaccurate information about people, places, or facts.',
                          style: GoogleFonts.inter(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Feature 2
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.lock, 
                  color:  Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                   size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Don't share sensitive info",
                          style: GoogleFonts.inter(
                            color:  Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            text:
                                'Chats may be reviewed and used for training. ',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: 'Learn more about your choices',
                                style: GoogleFonts.inter(
                                 color:  Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return Intropage();
                        },
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Footer
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: 'By continuing, you agree to our ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color:  Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: ' and have\nread our ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                         color:  Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
    
  )
    );
}
}
