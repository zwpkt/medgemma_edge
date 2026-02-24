import 'package:flutter/material.dart';
import '../../core/constants/model_config.dart';
import 'chat_screen.dart'; // Import your chat page

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _statusMessage = 'Initializing system...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startSetup();
  }

  Future<void> _startSetup() async {
    try {
      // 1. Move models (external -> internal)
      setState(() => _statusMessage = 'Optimizing medical model resources...\n(First run may take about 30 seconds)');
      // This will return the internal path, but we first ensure the move is complete
      // Use the path of getExternalStorageDirectory(), not the internal path and not copying
      // ModelConfig.prepareInternalModels();

      // 2. After completion, navigate to ChatScreen
      // Note: ChatScreen's initState will call _llamaService.loadModel()
      // and loadModel should use the path returned by ModelConfig.prepareInternalModels()
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '❌ Initialization Failed\nPlease ensure model files are pushed via ADB\nError: $e';
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
              // You can put your MedGemma Logo here
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
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}