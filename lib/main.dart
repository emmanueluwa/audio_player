import 'package:audio_player/HomePage.dart';
import 'package:audio_player/screens/login_screen.dart';
import 'package:audio_player/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "audio app",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.grey, useMaterial3: true),
      initialRoute: "/login",
      routes: {
        "/login": (context) => LoginScreen(),
        "/register": (context) => RegisterScreen(),
        "/home": (context) => HomePage(),
      },
    );
  }
}
