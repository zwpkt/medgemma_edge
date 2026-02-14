import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class ModelConfig {
  // 模型文件名常量
  // static const String textModelFileName = 'medgemma-4b-it_Q4_K_M.gguf';
  // static const String mmprojFileName = 'mmproj-medgemma-4b-it-F16.gguf';
  static const String textModelFileName = 'medgemma-4b-it-Q8_0.gguf';
  static const String mmprojFileName = 'mmproj-medgemma-4b-it-Q8_0.gguf';


  static const String modelSubDir = 'MedGemma'; // 模型子目录名

  /// ✅【Android】获取应用专属外部存储目录
  /// 路径: /storage/emulated/0/Android/data/<包名>/files/MedGemma/
  static Future<Directory> _getAndroidModelDir() async {
    try {
      final baseDir = await getExternalStorageDirectory();
      if (baseDir == null) {
        throw Exception('获取应用专属目录失败 (getExternalStorageDirectory() 返回 null)');
      }
      // 在专属目录下创建模型子目录
      final modelDir = Directory('${baseDir.path}/$modelSubDir');
      
      // 关键：如果目录不存在，就创建它
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
        debugPrint('📁 成功创建模型目录: ${modelDir.path}');
      }
      return modelDir;
    } catch (e) {
      debugPrint('❌ 获取或创建Android模型目录失败: $e');
      rethrow;
    }
  }

  /// ✅【iOS】使用应用文档目录
  static Future<Directory> _getIOSModelDir() async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${baseDir.path}/$modelSubDir');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
        debugPrint('📁 成功创建iOS模型目录: ${modelDir.path}');
      }
      return modelDir;
    } catch (e) {
      debugPrint('❌ 获取或创建iOS模型目录失败: $e');
      rethrow;
    }
  }

  /// ✅【统一入口】根据平台自动获取模型目录
  static Future<Directory> getModelDir() async {
    if (Platform.isAndroid) {
      return await _getAndroidModelDir();
    } else if (Platform.isIOS) {
      return await _getIOSModelDir();
    } else {
      throw UnsupportedError('当前平台不受支持');
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

  // ... (其他辅助方法，如 checkFilesExist, printFileSizes 等可以保留不变)
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



  static Future<String> getModelDirPathForAdb() async {
    final dir = await getModelDir();
    return dir.path;
  }
}
