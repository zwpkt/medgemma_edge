import 'package:flutter/material.dart';
import 'package:medgemma_edge/presentation/screens/LoadingScreen.dart';
import 'presentation/screens/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedGemmaEdgeApp());
}

class MedGemmaEdgeApp extends StatelessWidget {
  const MedGemmaEdgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedGemma Edge',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      // home: const ChatScreen(),
      // 将入口设为 LoadingScreen
      home: const LoadingScreen(),

    );
  }
}