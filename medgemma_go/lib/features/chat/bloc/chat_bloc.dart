import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/llama_service.dart';
import '../services/storage_service.dart';

// -------------------- Events --------------------
abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// 发送单条消息（非流式）
class SendMessageEvent extends ChatEvent {
  final String text;
  final File? imageFile;

  const SendMessageEvent({required this.text, this.imageFile});

  @override
  List<Object?> get props => [text, imageFile];
}

/// 流式发送消息（打字机效果）
class StreamMessageEvent extends ChatEvent {
  final String text;
  final File? imageFile;

  const StreamMessageEvent({required this.text, this.imageFile});

  @override
  List<Object?> get props => [text, imageFile];
}

/// 加载历史记录
class LoadHistoryEvent extends ChatEvent {}

/// 清空对话
class ClearChatEvent extends ChatEvent {}

/// 停止生成
class StopGenerationEvent extends ChatEvent {}

// -------------------- States --------------------
abstract class ChatUIState extends Equatable {
  const ChatUIState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatUIState {}

class ChatLoading extends ChatUIState {}

class ChatLoaded extends ChatUIState {
  final List<types.Message> messages;
  final bool isTyping;
  final String? currentResponseId; // 当前正在流式生成的消息ID

  const ChatLoaded({
    required this.messages,
    this.isTyping = false,
    this.currentResponseId,
  });

  @override
  List<Object?> get props => [messages, isTyping, currentResponseId];

  ChatLoaded copyWith({
    List<types.Message>? messages,
    bool? isTyping,
    String? currentResponseId,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      currentResponseId: currentResponseId ?? this.currentResponseId,
    );
  }
}

class ChatError extends ChatUIState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

// -------------------- BLoC --------------------
class ChatBloc extends Bloc<ChatEvent, ChatUIState> {
  final LlamaService _llamaService;
  final StorageService _storageService;
  final _uuid = const Uuid();

  static const int _maxMessages = 50;

  ChatBloc({
    required LlamaService llamaService,
    required StorageService storageService,
  }) : _llamaService = llamaService,
        _storageService = storageService,
        super(ChatInitial()) {
    // 注册事件处理
    on<LoadHistoryEvent>(_onLoadHistory);
    on<SendMessageEvent>(_onSendMessage);
    on<StreamMessageEvent>(_onStreamMessage);
    on<ClearChatEvent>(_onClearChat);
    on<StopGenerationEvent>(_onStopGeneration);
  }

  // ---------- 加载历史记录 ----------
  Future<void> _onLoadHistory(
      LoadHistoryEvent event,
      Emitter<ChatUIState> emit,
      ) async {
    try {
      final messages = await _storageService.loadMessages();
      emit(ChatLoaded(messages: messages));
    } catch (e) {
      emit(ChatError('加载历史记录失败: $e'));
      emit(const ChatLoaded(messages: []));
    }
  }

  // ---------- 非流式发送（简单模式）----------
  Future<void> _onSendMessage(
      SendMessageEvent event,
      Emitter<ChatUIState> emit,
      ) async {
    if (state is! ChatLoaded) return;

    final currentState = state as ChatLoaded;
    final List<types.Message> updatedMessages = [...currentState.messages];

    try {
      // 1. 添加用户消息（文本+图片）
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 如果有图片，创建图片消息
      if (event.imageFile != null) {
        final imageMessage = types.ImageMessage(
          author: ChatMessage.userAuthor,
          createdAt: timestamp,
          id: _uuid.v4(),
          name: event.imageFile!.path.split('/').last,
          size: await event.imageFile!.length(),
          uri: event.imageFile!.path,
          height: 512,
          width: 512,
        );
        updatedMessages.insert(0, imageMessage);
      }

      // 如果有文本，创建文本消息
      if (event.text.isNotEmpty) {
        final textMessage = types.TextMessage(
          author: ChatMessage.userAuthor,
          createdAt: timestamp,
          id: _uuid.v4(),
          text: event.text,
        );
        updatedMessages.insert(0, textMessage);
      }

      emit(currentState.copyWith(
        messages: updatedMessages,
        isTyping: true,
      ));

      // 2. 调用 MedGemma 模型（自动判断多模态或纯文本）
      late final String response;

      if (event.imageFile != null) {
        // ✅ 多模态：有图像输入（flutter_llama 1.1.2 支持）
        response = await _llamaService.generateWithImage(
          prompt: event.text.isEmpty
              ? '请详细描述这张医疗图像中的发现，包括异常区域、可能的诊断建议。'
              : event.text,
          imagePath: event.imageFile!.path,
        );
      } else {
        // 纯文本
        response = await _llamaService.generateText(
          prompt: event.text,
        );
      }

      // 3. 移除输入状态，添加AI回复
      final aiMessage = types.TextMessage(
        author: ChatMessage.assistantAuthor,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: _uuid.v4(),
        text: response,
      );

      updatedMessages.insert(0, aiMessage);

      // 4. 保存到本地存储
      final messagesToSave = updatedMessages.take(_maxMessages).toList();
      await _storageService.saveMessages(messagesToSave);

      emit(currentState.copyWith(
        messages: updatedMessages,
        isTyping: false,
      ));

    } catch (e) {
      emit(currentState.copyWith(isTyping: false));
      emit(ChatError('模型推理失败: $e'));
    }
  }

  // ---------- 流式发送（打字机效果，推荐）----------
  Future<void> _onStreamMessage(
      StreamMessageEvent event,
      Emitter<ChatUIState> emit,
      ) async {
    if (state is! ChatLoaded) return;

    final currentState = state as ChatLoaded;
    final List<types.Message> updatedMessages = [...currentState.messages];

    try {
      // 1. 添加用户消息（文本+图片）
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 图片消息
      if (event.imageFile != null) {
        final imageMessage = types.ImageMessage(
          author: ChatMessage.userAuthor,
          createdAt: timestamp,
          id: _uuid.v4(),
          name: event.imageFile!.path.split('/').last,
          size: await event.imageFile!.length(),
          uri: event.imageFile!.path,
          height: 512,
          width: 512,
        );
        updatedMessages.insert(0, imageMessage);
      }

      // 文本消息
      if (event.text.isNotEmpty) {
        final textMessage = types.TextMessage(
          author: ChatMessage.userAuthor,
          createdAt: timestamp,
          id: _uuid.v4(),
          text: event.text,
        );
        updatedMessages.insert(0, textMessage);
      }

      // 2. 创建空白AI消息占位符
      final responseId = _uuid.v4();
      final aiMessage = types.TextMessage(
        author: ChatMessage.assistantAuthor,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: responseId,
        text: '', // 初始为空
      );

      updatedMessages.insert(0, aiMessage);

      emit(currentState.copyWith(
        messages: updatedMessages,
        isTyping: true,
        currentResponseId: responseId,
      ));

      // 3. 流式生成（根据是否有图像选择不同方法）
      String accumulatedResponse = '';

      if (event.imageFile != null) {
        // ✅ 多模态流式生成（flutter_llama 1.1.2 支持）
        await for (final token in _llamaService.generateWithImageStreaming(
          prompt: event.text.isEmpty
              ? '请详细描述这张医疗图像中的发现。'
              : event.text,
          imagePath: event.imageFile!.path,
        )) {
          accumulatedResponse += token;

          // 实时更新消息
          final index = updatedMessages.indexWhere((m) => m.id == responseId);
          if (index != -1) {
            updatedMessages[index] = types.TextMessage(
              author: ChatMessage.assistantAuthor,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: responseId,
              text: accumulatedResponse,
            );

            // 每收到一个 token 就更新 UI（打字机效果）
            emit(currentState.copyWith(
              messages: updatedMessages,
              isTyping: true,
              currentResponseId: responseId,
            ));
          }
        }
      } else {
        // 纯文本流式生成
        await for (final token in _llamaService.generateTextStreaming(
          prompt: event.text,
        )) {
          accumulatedResponse += token;

          final index = updatedMessages.indexWhere((m) => m.id == responseId);
          if (index != -1) {
            updatedMessages[index] = types.TextMessage(
              author: ChatMessage.assistantAuthor,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: responseId,
              text: accumulatedResponse,
            );

            emit(currentState.copyWith(
              messages: updatedMessages,
              isTyping: true,
              currentResponseId: responseId,
            ));
          }
        }
      }

      // 4. 生成完成，保存到本地存储
      final messagesToSave = updatedMessages.take(_maxMessages).toList();
      await _storageService.saveMessages(messagesToSave);

      emit(currentState.copyWith(
        messages: updatedMessages,
        isTyping: false,
        currentResponseId: null,
      ));

    } catch (e) {
      // 出错时更新当前消息为错误状态
      if (currentState.currentResponseId != null) {
        final index = updatedMessages.indexWhere(
                (m) => m.id == currentState.currentResponseId
        );
        if (index != -1) {
          updatedMessages[index] = types.TextMessage(
            author: ChatMessage.assistantAuthor,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: currentState.currentResponseId!,
            text: '【生成失败】$e',
          );
        }
      }

      emit(currentState.copyWith(
        messages: updatedMessages,
        isTyping: false,
        currentResponseId: null,
      ));

      emit(ChatError('流式生成失败: $e'));
    }
  }

  // ---------- 停止生成 ----------
  Future<void> _onStopGeneration(
      StopGenerationEvent event,
      Emitter<ChatUIState> emit,
      ) async {
    await _llamaService.stopGeneration();

    if (state is ChatLoaded) {
      final currentState = state as ChatLoaded;
      emit(currentState.copyWith(
        isTyping: false,
        currentResponseId: null,
      ));
    }
  }

  // ---------- 清空对话 ----------
  Future<void> _onClearChat(
      ClearChatEvent event,
      Emitter<ChatUIState> emit,
      ) async {
    await _storageService.clearMessages();
    emit(const ChatLoaded(messages: []));
  }

  @override
  Future<void> close() {
    _llamaService.unloadMultimodalModel();
    return super.close();
  }
}