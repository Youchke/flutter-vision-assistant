import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:app_ai_traiter/login.dart';
import 'package:app_ai_traiter/contact.dart';
import 'package:app_ai_traiter/edit_profile.dart';
import 'package:app_ai_traiter/about_developpeur.dart';
import 'package:app_ai_traiter/assistant_virtual.dart';
import 'package:app_ai_traiter/traitemant_objets.dart';
import 'package:app_ai_traiter/welcome.dart';
import 'package:app_ai_traiter/detection_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
    print('Caméras trouvées: ${cameras.length}');
  } catch (e) {
    cameras = [];
    print('Erreur lors de l\'initialisation des caméras: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Traiter App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 141, 72, 191),
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 205, 166, 233),
            foregroundColor: const Color.fromARGB(255, 5, 15, 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 141, 72, 191),
              width: 2,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 141, 72, 191),
          ),
        ),
      ),
      home: Login(),
 // Plus besoin de title
      routes: {
        '/login': (context) => Login(),
        '/assistant': (context) => AssistantVirtuel(),
        '/editprofile': (context) => EditProfile(),
        '/contact': (context) => ContactUs(), 
        '/about_developpeur': (context) => AboutDeveloperPage(),
        '/image-generation': (context) => ImageGeneratorPage(),
        '/object-processing': (context) => ObjectDetectionScreen(),
       
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => WelcomePage(),
        );
      },
    );
  }
}
