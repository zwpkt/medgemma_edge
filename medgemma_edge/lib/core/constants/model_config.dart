import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show Platform;

import 'package:path/path.dart' as p;

class ModelConfig {
  // 模型文件名（Q8,命令行验证可用）
  // static const String textModelFileName = 'medgemma-4b-it-Q8_0.gguf';
  // static const String mmprojFileName = 'mmproj-medgemma-4b-it-Q8_0.gguf';

  //Q4：4bit量化
  //static const String textModelFileName = 'medgemma-4b-it-Q4_K_M.gguf';
  static const String textModelFileName = 'm.gguf';
  static const String mmprojFileName = 'mmproj-medgemma-4b-it-F16.gguf';

  /// 1. 外部存储目录 (ADB推送的目标位置)
  static Future<Directory> getExternalModelDir() async {
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) throw Exception('无法获取外部存储目录');
      return Directory('${externalDir.path}/MedGemma')..createSync(recursive: true);
    } else {
      return getApplicationDocumentsDirectory(); // iOS 统一使用 Documents
    }
  }

  /// 2. 内部私有目录 (FFI 加载的真实位置，绕过 Android 权限限制)
  static Future<Directory> getInternalModelDir() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory('${supportDir.path}/MedGemma')..createSync(recursive: true);
  }

  /// 获取模型目录（Edge AI 核心：应用专属外部存储，无需权限）
  /// 获取模型存放目录
  ///
  /// [isInternal]:
  ///   - true: 返回应用内部私有目录 (getApplicationSupportDirectory)，用于 FFI 引擎加载，权限最高，最稳定。
  ///   - false: 返回应用专属外部存储 (getExternalStorageDirectory)，用于 ADB 推送模型，方便操作。
  static Future<Directory> getModelDir({bool isInternal = false}) async {
    Directory baseDir;

    if (Platform.isAndroid) {
      if (isInternal) {
        // 内部目录：/data/user/0/top.beecloud.medgemma_edge/files (或 app_support)
        // 这里的路径对原生 C++ (FFI) 访问最友好
        baseDir = await getApplicationSupportDirectory();
      } else {
        // 外部目录：/storage/emulated/0/Android/data/top.beecloud.medgemma_edge/files
        // 这里的路径方便开发者通过 ADB 命令推送文件
        final externalDir = await getExternalStorageDirectory();
        if (externalDir == null) throw Exception('无法获取外部存储目录');
        baseDir = externalDir;
      }
    } else if (Platform.isIOS) {
      // iOS 路径相对简单，统一存放在 Documents 或 Support
      baseDir = isInternal
          ? await getApplicationSupportDirectory()
          : await getApplicationDocumentsDirectory();
    } else {
      throw UnsupportedError('仅支持 Android/iOS');
    }

    // 统一加上项目子目录 MedGemma
    final modelDir = Directory('${baseDir.path}/MedGemma');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// 3. 核心：准备模型并返回可加载的路径
  /// 这个方法会检查内部目录，如果没文件，就从外部目录搬运过去
  static Future<Map<String, String>> prepareInternalModels() async {
    // 获取外部（源）和 内部（目标）目录
    final sourceDir = await getModelDir(isInternal: false);
    final targetDir = await getModelDir(isInternal: true);

    final String targetTextPath = p.join(targetDir.path, textModelFileName);
    final String targetMmprojPath = p.join(targetDir.path, mmprojFileName);

    // 执行搬运检查
    await _copyIfMissing(
      source: p.join(sourceDir.path, textModelFileName),
      destination: targetTextPath,
    );

    await _copyIfMissing(
      source: p.join(sourceDir.path, mmprojFileName),
      destination: targetMmprojPath,
    );

    return {
      'textModel': targetTextPath,
      'mmproj': targetMmprojPath,
    };
  }
  static Future<void> _copyIfMissing({required String source, required String destination}) async {
    final destFile = File(destination);
    if (await destFile.exists()) {
      print('✅ 内部模型已存在: ${p.basename(destination)}');
      return;
    }

    final sourceFile = File(source);
    if (await sourceFile.exists()) {
      print('🚚 正在迁移模型至内部存储: ${p.basename(source)}');
      // 使用流式复制，避免大文件内存溢出
      await sourceFile.copy(destination);
      print('✨ 迁移完成');
    } else {
      throw Exception('❌ 缺失源文件！请先用 ADB 将模型推送至: $source');
    }
  }





  /// 文本模型路径
  static Future<String> get textModelPath async {
    final dir = await getModelDir(isInternal: true);
    return '${dir.path}/$textModelFileName';
  }

  /// 投影器路径
  static Future<String> get mmprojPath async {
    final dir = await getModelDir(isInternal: true);
    return '${dir.path}/$mmprojFileName';
  }

  /// 检查文件是否存在
  static Future<bool> checkFilesExist() async {
    try {
      final textFile = File(await textModelPath);
      final mmprojFile = File(await mmprojPath);
      final textExists = await textFile.exists();
      final mmprojExists = await mmprojFile.exists();

      print('📁 MedGemma Edge 模型检查:');
      print('   📄 文本模型: ${textExists ? '✅' : '❌'} - ${await textModelPath}');
      print('   🖼️ 投影器: ${mmprojExists ? '✅' : '❌'} - ${await mmprojPath}');

      if (textExists) {
        // 尝试设置权限（部分安卓版本生效）
        // 或者重新检查文件大小是否为 0
        final stat = await textFile.stat();
        print("文本模型文件大小: ${stat.size}, 权限: ${stat.mode}");
      } else {
        print("文本模型文件物理上不存在！");
      }

      if (mmprojExists) {
        // 尝试设置权限（部分安卓版本生效）
        // 或者重新检查文件大小是否为 0
        final stat = await mmprojFile.stat();
        print("投影文件大小: ${stat.size}, 权限: ${stat.mode}");
      } else {
        print("投影模型文件物理上不存在！");
      }

      return textExists && mmprojExists;
    } catch (e) {
      print('❌ 检查文件失败: $e');
      return false;
    }
  }

  /// ADB 推送命令（用于快速部署）
  static Future<String> getAdbPushCommand() async {
    final dir = await getModelDir();
    final packageName = 'com.example.medgemma_edge'; // 替换为您的包名
    return '''
📱 Edge AI 部署命令:
adb shell mkdir -p ${dir.path}
adb push $textModelFileName ${dir.path}/
adb push $mmprojFileName ${dir.path}/

📌 验证文件:
adb shell ls -la ${dir.path}
''';
  }
}