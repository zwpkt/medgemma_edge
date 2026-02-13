import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class ChatMessage {
  static const userAuthor = types.User(
    id: 'user',
    firstName: '我',
  );

  static const assistantAuthor = types.User(
    id: 'assistant',
    firstName: 'MedGemma',
  );
}