import 'dart:convert';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;
  static const String _messagesKey = 'chat_messages';

  StorageService(this._prefs);

  // 保存消息列表
  Future<void> saveMessages(List<types.Message> messages) async {
    final messagesJson = messages.map((m) => m.toJson()).toList();
    await _prefs.setString(_messagesKey, jsonEncode(messagesJson));
  }

  // 加载消息列表
  Future<List<types.Message>> loadMessages() async {
    final String? messagesString = _prefs.getString(_messagesKey);
    if (messagesString == null) return [];

    try {
      final List<dynamic> messagesJson = jsonDecode(messagesString);
      return messagesJson
          .map((json) => types.Message.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // 清空历史
  Future<void> clearMessages() async {
    await _prefs.remove(_messagesKey);
  }
}