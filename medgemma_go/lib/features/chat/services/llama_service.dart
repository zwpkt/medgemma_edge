import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_llama/flutter_llama.dart';
import '../../../core/constants/model_config.dart';

class LlamaService {
  // ✅ 多模态专用单例
  final FlutterLlamaMultimodal _multimodal = FlutterLlamaMultimodal.instance;

  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  String? _currentTextModelPath;
  String? _currentMmprojPath;

  // ✅ 加载 SandLogicTechnologies 双文件多模态模型
  Future<void> loadMultimodalModel() async {
    if (_isModelLoaded) return;

    try {
      _currentTextModelPath = await ModelConfig.textModelPath;
      _currentMmprojPath = await ModelConfig.mmprojPath;

      debugPrint('🚀 开始加载多模态模型...');
      debugPrint('   📁 模型目录: ${await ModelConfig.getModelDirPathForAdb()}');
      debugPrint('   📄 文本模型: $_currentTextModelPath');
      debugPrint('   🖼️  mmproj: $_currentMmprojPath');

      // 2. 检查文件是否存在
      final textFile = File(_currentTextModelPath!);
      final mmprojFile = File(_currentMmprojPath!);

      if (!await textFile.exists()) {
        throw Exception('❌ 文本模型文件不存在\n'
            '请使用ADB推送文件到: ${await ModelConfig.getModelDirPathForAdb()}');
      }
      if (!await mmprojFile.exists()) {
        throw Exception('❌ 投影器文件不存在\n'
            '请使用ADB推送文件到: ${await ModelConfig.getModelDirPathForAdb()}');
      }

      // 3. 显示文件大小
      await ModelConfig.printFileSizes();

      final config = MultimodalConfig(
        textModelPath: _currentTextModelPath!,
        mmprojPath: _currentMmprojPath!,
        enableVision: true,
        useGpuForMultimodal: true,
        maxImageSize: 448,
      );

      debugPrint('⚙️ 加载配置完成，开始加载模型...');
      final success = await _multimodal.loadMultimodalModel(config);

      if (success) {
        _isModelLoaded = true;
        debugPrint('✅【多模态模型加载成功】');
      } else {
        throw Exception('loadMultimodalModel 返回 false');
      }
    } catch (e) {
      debugPrint('❌ 多模态模型加载失败: $e');
      _isModelLoaded = false;
      rethrow;
    }
  }

  // ---------- ✅【方案1】describeImage（最简洁，推荐！）----------
  Future<String> describeImage({
    required String imagePath,
    String prompt = '请详细描述这张医疗图像中的发现。',
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async {
    if (!_isModelLoaded) await loadMultimodalModel();

    try {
      debugPrint('🖼️【describeImage】开始');

      final params = GenerationParams(
        prompt: '',  // 必须传空字符串
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.95,
        topK: 40,
        repeatPenalty: 1.1,
      );

      final response = await _multimodal.describeImage(
        imagePath,
        prompt,
        params: params,
      );

      return response.text.trim();
    } catch (e) {
      debugPrint('❌ describeImage 失败: $e');
      rethrow;
    }
  }

  // ---------- ✅【方案2】generateMultimodal（通用方案）- 已修复 type 参数 ----------
  Future<String> generateWithImage({
    required String prompt,
    required String imagePath,
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async {
    if (!_isModelLoaded) await loadMultimodalModel();

    try {
      debugPrint('🖼️【generateMultimodal】开始');

      // ✅【关键修复】必须指定 type = MultimodalType.textAndImage！
      final input = MultimodalInput(
        type: MultimodalType.mixed,  // 👈 必须添加！
        text: prompt,
        imagePath: imagePath,
      );

      final params = GenerationParams(
        prompt: '',  // 必须传空字符串
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.95,
        topK: 40,
        repeatPenalty: 1.1,
      );

      final response = await _multimodal.generateMultimodal(
        input,
        params,
      );

      return response.text.trim();
    } catch (e) {
      debugPrint('❌ generateWithImage 失败: $e');
      rethrow;
    }
  }

  // ---------- ✅【方案3】流式多模态 - 已修复 type 参数 ----------
  Stream<String> generateWithImageStreaming({
    required String prompt,
    required String imagePath,
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async* {
    if (!_isModelLoaded) await loadMultimodalModel();

    try {
      debugPrint('🖼️【流式多模态】开始');

      // ✅【关键修复】流式版本同样需要 type
      final input = MultimodalInput(
        type: MultimodalType.mixed,  // 👈 必须添加！
        text: prompt,
        imagePath: imagePath,
      );

      final params = GenerationParams(
        prompt: '',  // 必须传空字符串
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.95,
        topK: 40,
        repeatPenalty: 1.1,
      );

      await for (final response in _multimodal.generateMultimodalStream(
        input,
        params,
      )) {
        yield response.text;
      }
    } catch (e) {
      debugPrint('❌ 流式多模态失败: $e');
      rethrow;
    }
  }

  // ---------- ✅ 纯文本生成（不需要 type）----------
  Future<String> generateText({
    required String prompt,
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async {
    if (!_isModelLoaded) await loadMultimodalModel();

    try {
      // ✅ 纯文本：使用不带 imagePath 的 MultimodalInput
      final input = MultimodalInput(
        type: MultimodalType.text,  // 👈 纯文本类型
        text: prompt,
      );

      final params = GenerationParams(
        prompt: prompt,  // 纯文本时必须传真实 prompt
        maxTokens: maxTokens,
        temperature: temperature,
        topP: 0.95,
        topK: 40,
        repeatPenalty: 1.1,
      );

      final response = await _multimodal.generateMultimodal(
        input,
        params,
      );

      return response.text.trim();
    } catch (e) {
      debugPrint('❌ 文本推理失败: $e');
      rethrow;
    }
  }

  // ---------- ✅ 流式纯文本 ----------
  Stream<String> generateTextStreaming({
    required String prompt,
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async* {
    if (!_isModelLoaded) await loadMultimodalModel();

    try {
      final input = MultimodalInput(
        type: MultimodalType.text,  // 👈 纯文本类型
        text: prompt,
      );

      final params = GenerationParams(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );

      await for (final response in _multimodal.generateMultimodalStream(
        input,
        params,
      )) {
        yield response.text;
      }
    } catch (e) {
      debugPrint('❌ 文本流式失败: $e');
      rethrow;
    }
  }

  // ✅ 停止生成
  Future<void> stopGeneration() async {
    if (_isModelLoaded) {
      await _multimodal.stopMultimodalGeneration();
      debugPrint('⏹️ 生成已停止');
    }
  }

  // ✅ 卸载模型
  Future<void> unloadMultimodalModel() async {
    if (_isModelLoaded) {
      await _multimodal.unloadMultimodalModel();
      _isModelLoaded = false;
      debugPrint('✅ 多模态模型已卸载');
    }
  }
}