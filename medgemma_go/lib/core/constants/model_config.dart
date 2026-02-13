import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/src/foundation/print.dart';

import 'package:flutter/foundation.dart' show Platform;

class ModelConfig {
  // 模型文件名常量
  static const String textModelFileName = 'medgemma-4b-it_Q4_K_M.gguf';
  static const String mmprojFileName = 'mmproj-medgemma-4b-it-F16.gguf';

  /// ✅【Android】获取应用专属外部存储目录
  /// 路径: /storage/emulated/0/Android/data/<包名>/files/MedGemma/
  static Future<Directory> _getAndroidModelDir() async {
    try {
      final baseDir = await getExternalStorageDirectory();
      if (baseDir == null) {
        throw Exception('getExternalStorageDirectory() 返回 null');
      }
      final modelDir = Directory('${baseDir.path}/MedGemma');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
        debugPrint('📁 创建模型目录: ${modelDir.path}');
      }
      return modelDir;
    } catch (e) {
      debugPrint('❌ 获取Android模型目录失败: $e');
      rethrow;
    }
  }

  /// ✅【iOS降级方案】使用文档目录（外部存储在iOS不可用）
  static Future<Directory> _getIOSModelDir() async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${baseDir.path}/MedGemma');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
        debugPrint('📁 创建iOS模型目录: ${modelDir.path}');
      }
      return modelDir;
    } catch (e) {
      debugPrint('❌ 获取iOS模型目录失败: $e');
      rethrow;
    }
  }

  /// ✅【统一入口】根据平台自动选择存储位置
  static Future<Directory> getModelDir() async {
    if (Platform.isAndroid) {
      return await _getAndroidModelDir();
    } else if (Platform.isIOS) {
      return await _getIOSModelDir();
    } else {
      throw UnsupportedError('仅支持 Android 和 iOS 平台');
    }
  }

  /// ✅ 文本模型完整路径
  static Future<String> get textModelPath async {
    final dir = await getModelDir();
    return '${dir.path}/$textModelFileName';
  }

  /// ✅ 投影器完整路径
  static Future<String> get mmprojPath async {
    final dir = await getModelDir();
    return '${dir.path}/$mmprojFileName';
  }

  /// ✅ 检查模型文件是否存在
  static Future<bool> checkFilesExist() async {
    try {
      final textFile = File(await textModelPath);
      final mmprojFile = File(await mmprojPath);
      final textExists = await textFile.exists();
      final mmprojExists = await mmprojFile.exists();

      debugPrint('📁 模型文件检查:');
      debugPrint('   📄 文本模型: ${textFile.path} ${textExists ? '✅' : '❌'}');
      debugPrint('   🖼️  mmproj: ${mmprojFile.path} ${mmprojExists ? '✅' : '❌'}');

      return textExists && mmprojExists;
    } catch (e) {
      debugPrint('❌ 检查文件失败: $e');
      return false;
    }
  }

  /// ✅ 获取文件大小（调试用）
  static Future<void> printFileSizes() async {
    try {
      final textFile = File(await textModelPath);
      final mmprojFile = File(await mmprojPath);

      if (await textFile.exists()) {
        final size = await textFile.length();
        debugPrint('📊 文本模型: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      if (await mmprojFile.exists()) {
        final size = await mmprojFile.length();
        debugPrint('📊 mmproj: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
      }
    } catch (e) {
      debugPrint('❌ 获取文件大小失败: $e');
    }
  }

  /// ✅ 获取模型目录路径（用于ADB推送提示）
  static Future<String> getModelDirPathForAdb() async {
    final dir = await getModelDir();
    return dir.path;
  }
}