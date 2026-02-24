import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../domain/services/llama_service.dart';
import '../../core/constants/model_config.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  File? _selectedImage;

  bool _isLoading = false;
  bool _isModelReady = false;
  String _modelStatus = '🔄 Initializing...';
  double _loadProgress = 0.0;

  late final LlamaEdgeService _llamaService;

  @override
  void initState() {
    super.initState();
    _llamaService = LlamaEdgeService();
    _setupListeners();
    _initializeModel();
  }

  void _setupListeners() {
    // Stream response
    _llamaService.responseStream.listen((token) {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && !_messages.last.isUser) {
            _messages.last.content += token;
          } else {
            _messages.add(ChatMessage(content: token, isUser: false));
          }
        });
      }
    }, onDone: () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    // Loading progress
    _llamaService.loadingStream.listen((progress) {
      if (mounted) {
        setState(() {
          _loadProgress = progress;
          if (progress == 1.0) {
            _modelStatus = '✅ Model Ready';
            _isModelReady = true;
          } else if (progress < 0) {
            _modelStatus = '❌ Load Failed';
          } else {
            _modelStatus = '🔄 Loading Model ${(progress * 100).toInt()}%';
          }
        });
      }
    });

    // Error messages
    _llamaService.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _modelStatus = '❌ $error';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    });
  }

  Future<void> _initializeModel() async {
    final success = await _llamaService.loadModel();
    if (mounted && success) {
      setState(() {
        _isModelReady = true;
        _modelStatus = '✅ MedGemma Edge is ready';
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        content: text,
        isUser: true,
        imagePath: _selectedImage?.path,
      ));
      _textController.clear();
      _isLoading = true;
    });

    // Call model
    if (_selectedImage != null) {
      await _llamaService.generateWithImage(
        prompt: text.isEmpty ? 'Describe the findings in this medical image in detail.' : text,
        imageFile: _selectedImage!,
      );
      setState(() => _selectedImage = null);
    } else {
      _llamaService.generateText(text);
    }
  }

  void _stopMessage() {
    _llamaService.stopGeneration();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MedGemma Edge'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _modelStatus.contains('✅')
                ? Colors.green[50]
                : _modelStatus.contains('❌')
                ? Colors.red[50]
                : Colors.blue[50],
            child: Row(
              children: [
                if (_loadProgress > 0 && _loadProgress < 1)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: _loadProgress,
                    ),
                  )
                else if (_modelStatus.contains('✅'))
                  const Icon(Icons.check_circle, color: Colors.green, size: 20)
                else if (_modelStatus.contains('❌'))
                    const Icon(Icons.error, color: Colors.red, size: 20)
                  else
                    const Icon(Icons.sync, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_modelStatus)),
              ],
            ),
          ),

          // Message list
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages.reversed.toList()[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Image preview
          if (_selectedImage != null)
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
            ),
            child: Row(
              children: [
                // Image button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add_photo_alternate),
                  onSelected: (value) {
                    if (value == 'gallery') _pickImage();
                    else if (value == 'camera') _takePhoto();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'gallery',
                      child: Row(children: [Icon(Icons.photo_library), Text('From Gallery')]),
                    ),
                    const PopupMenuItem(
                      value: 'camera',
                      child: Row(children: [Icon(Icons.camera_alt), Text('Take Photo')]),
                    ),
                  ],
                ),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: _selectedImage != null ? 'Enter question or description...' : 'Enter message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _isModelReady && !_isLoading ? _sendMessage() : null,
                  ),
                ),

                // Send/Stop button
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isModelReady
                      ? (_isLoading ? Colors.red : Colors.teal)
                      : Colors.grey,
                  child: IconButton(
                    icon: _isLoading
                        ? const Icon(Icons.stop, color: Colors.white)
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isModelReady
                        ? (_isLoading ? _stopMessage : _sendMessage)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final messageContent = SelectableRegion(
      focusNode: FocusNode(),
      selectionControls: materialTextSelectionControls,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.imagePath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(message.imagePath!),
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          message.isUser
              ? SelectableText(
                  message.content,
                  style: const TextStyle(color: Colors.white),
                )
              : MarkdownBody(
                  data: message.content,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                  ),
                ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser)
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal,
              child: Text('ME', style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.teal : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: messageContent,
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
          if (message.isUser)
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MedGemma Edge'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edge AI Medical Assistant based on MedGemma', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Model: medgemma-4b-it-Q8_0 (4.13GB)'),
            Text('Projector: mmproj-F16 (851MB)'),
            Text('Inference Engine: llama_cpp_dart v0.2.3'),
            SizedBox(height: 8),
            Text('🔋 Edge AI Features:'),
            Text('  • Runs completely offline'),
            Text('  • On-device GPU acceleration'),
            Text('  • Privacy-protected, no internet required'),
            Text('  • Supports medical image analysis'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _llamaService.dispose();
    super.dispose();
  }
}

class ChatMessage {
  String content;
  final bool isUser;
  final String? imagePath;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.imagePath,
  });
}
