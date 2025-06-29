// Updated main.dart
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:health_monitor/home_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Add this import for the Colors class in health_data.dart
import 'package:flutter/material.dart' show Colors;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseConfig.options,
  );
  runApp(DevicePreview(
      enabled: true,
      tools: const [
        ...DevicePreview.defaultTools,
      ],
      builder: (context) => const MyApp(),
    ),);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Health Monitor',
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF1DE9B6),
          tertiary: Color(0xFFFF6B6B),
          background: Color(0xFF0A0E14),
          surface: Color(0xFF1A1F2E),
          surfaceVariant: Color(0xFF2A2F3E),
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onBackground: Colors.white,
          onSurface: Colors.white,
          outline: Color(0xFF3A3F4E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1F2E),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Color(0xFF00E5FF)),
          titleTextStyle: TextStyle(
            color: Colors.white, 
            fontSize: 22, 
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1F2E),
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2F3E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3A3F4E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF3A3F4E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIconColor: const Color(0xFF00E5FF),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
          fontFamily: 'System',
        ).copyWith(
          headlineLarge: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          headlineMedium: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
          titleLarge: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00E5FF)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            elevation: 6,
            shadowColor: const Color(0xFF00E5FF).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF2A2F3E),
          selectedColor: const Color(0xFF00E5FF),
          labelStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF3A3F4E),
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A1F2E),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const HomePage(),
    );
  }
}