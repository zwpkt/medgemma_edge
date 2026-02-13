import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import '../bloc/chat_bloc.dart';
import '../models/chat_message.dart';
import '../widgets/custom_input.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('assets/icons/medgemma_icon.png'),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MedGemma 医疗助手'),
                SizedBox(height: 2),
                Text(
                  '基于多模态医疗大模型',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearConfirmDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: BlocConsumer<ChatBloc, ChatUIState>(
        listener: (context, state) {
          if (state is ChatError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ChatInitial) {
            context.read<ChatBloc>().add(LoadHistoryEvent());
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ChatLoaded) {
            return Column(
              children: [
                Expanded(
                  child: Chat(
                    messages: state.messages,
                    onSendPressed: (p0) => _handleSendPressed(context, p0),
                    user: ChatMessage.userAuthor,
                    showUserAvatars: true,
                    showUserNames: true,
                    onMessageTap: (_, message) => _handleImagePreview(context, message),
                    theme: DefaultChatTheme(
                      primaryColor: Theme.of(context).primaryColor,
                      secondaryColor: Colors.grey.shade100,
                      inputBackgroundColor: Colors.white,
                      sentMessageBodyTextStyle: const TextStyle(color: Colors.white),
                      receivedMessageBodyTextStyle: TextStyle(color: Colors.grey.shade900),
                    ),
                  ),
                ),
                if (state.isTyping)
                  Container(
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('MedGemma 正在分析...'),
                      ],
                    ),
                  ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _handleSendPressed(BuildContext context, types.PartialText message) {
    final chatBloc = context.read<ChatBloc>();

    // 触发发送事件（图片由 CustomInput 通过状态管理传递）
    // 实际项目中，你需要维护一个全局的待发送图片状态
    // 这里简化处理，假设用户通过 CustomInput 选择了图片
    chatBloc.add(SendMessageEvent(
      text: message.text,
      // 你需要从某个地方获取图片文件，比如通过 BLoC 状态或全局变量
    ));
  }

  void _handleImagePreview(BuildContext context, types.Message message) {
    if (message is types.ImageMessage) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.7,
                child: PhotoView(
                  imageProvider: FileImage(File(message.uri)),
                  backgroundDecoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空对话'),
        content: const Text('确定要清空所有聊天记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatBloc>().add(ClearChatEvent());
              Navigator.pop(context);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于 MedGemma'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MedGemma-4B 是基于 Google Gemma-3 的医疗多模态模型，支持：'),
            SizedBox(height: 12),
            Text('• 医疗影像分析（X光、CT、病理切片等）'),
            Text('• 症状问答与诊断建议'),
            Text('• 医学知识查询'),
            Text('• 病历摘要生成'),
            SizedBox(height: 16),
            Text('当前版本：4bit 量化，2.3GB'),
            Text('推荐使用 GPU 加速以获得最佳体验'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}