import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
// 将这个组件集成到你的 ChatScreen 中

class CustomChatInput extends StatefulWidget {
  final Function(String text, File? image) onSend;

  const CustomChatInput({
    super.key,
    required this.onSend,
  });

  @override
  State<CustomChatInput> createState() => _CustomChatInputState();
}

class _CustomChatInputState extends State<CustomChatInput> {
  final TextEditingController _controller = TextEditingController();
  File? _pendingImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图片预览区
          if (_pendingImage != null)
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _pendingImage!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _pendingImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 输入行
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 图片选择按钮
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _pickImage,
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: _takePhoto,
              ),

              // 文本输入框
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: '输入医疗问题或上传影像...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // 发送按钮
              Container(
                margin: const EdgeInsets.only(left: 4),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _handleSend,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 从相册选择图片
  Future<void> _pickImage() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要存储权限才能选择图片')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pendingImage = File(result.files.single.path!);
      });
    }
  }

  // 拍照
  Future<void> _takePhoto() async {
    // 实现相机拍照逻辑
    // 这里简化处理，实际应使用 image_picker
  }

  // 发送消息
  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImage == null) return;

    widget.onSend(text, _pendingImage);

    _controller.clear();
    setState(() => _pendingImage = null);
  }
}