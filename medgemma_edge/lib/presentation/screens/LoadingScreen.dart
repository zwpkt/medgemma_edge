import 'package:flutter/material.dart';
import '../../core/constants/model_config.dart';
import 'chat_screen.dart'; // 导入你的聊天页面

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _statusMessage = '正在初始化系统...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startSetup();
  }

  Future<void> _startSetup() async {
    try {
      // 1. 搬运模型 (外部 -> 内部)
      setState(() => _statusMessage = '正在优化医疗模型资源...\n(首次运行约需 30 秒)');
      // 这里会返回内部路径，但我们先确保搬运完成
      await ModelConfig.prepareInternalModels();

      // 2. 检查完成后，跳转到 ChatScreen
      // 注意：ChatScreen 内部的 initState 会调用 _llamaService.loadModel()
      // 而 loadModel 内部应该使用 ModelConfig.prepareInternalModels() 返回的路径
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '❌ 初始化失败\n请确保已通过 ADB 推送模型文件\n错误: $e';
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 可以放一个你的 MedGemma Logo
              const Icon(Icons.health_and_safety, size: 80, color: Colors.teal),
              const SizedBox(height: 40),
              if (!_hasError)
                const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              if (_hasError)
                TextButton(
                  onPressed: () => _startSetup(),
                  child: const Text('重试'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}