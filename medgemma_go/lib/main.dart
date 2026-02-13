import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:medgemma_go/core/di/injection.dart';
import 'package:medgemma_go/features/chat/bloc/chat_bloc.dart';
import 'package:medgemma_go/features/chat/screens/chat_screen.dart';
import 'package:medgemma_go/features/chat/services/llama_service.dart';
import 'package:medgemma_go/features/chat/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化依赖注入
  await setupInjection();

  runApp(const MedGemmaApp());
}

class MedGemmaApp extends StatelessWidget {
  const MedGemmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedGemma 医疗助手',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      home: BlocProvider(
        create: (context) => ChatBloc(
          llamaService: GetIt.I<LlamaService>(),
          storageService: GetIt.I<StorageService>(),
        ),
        child: const ChatScreen(),
      ),
    );
  }
}