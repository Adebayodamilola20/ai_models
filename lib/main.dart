import 'package:emerge_x/shared/ProviderX/provider.dart';
import 'package:emerge_x/views/pages/IntroPage.dart';
import 'package:emerge_x/views/pages/IntroScreen.dart';
import 'package:emerge_x/views/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emerge_x/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  Stripe.publishableKey = dotenv.env['Sripe Api key'] ?? "";
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase initalization Error:$e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => Userprovider())],
      child: Consumer<Userprovider>(
        builder: (context, userProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: StreamBuilder(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.data != null) {
                  return Introscreen();
                }
                return Introscreen();
              },
            ),
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.white,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Color.fromARGB(255, 0, 0, 0),
                elevation: 0,
              ),
              drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color.fromARGB(255, 0, 0, 0),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color.fromARGB(255, 0, 0, 0),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              drawerTheme: const DrawerThemeData(
                backgroundColor: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
            themeMode: userProvider.themeMode,
          );
        },
      ),
    );
  }
}

