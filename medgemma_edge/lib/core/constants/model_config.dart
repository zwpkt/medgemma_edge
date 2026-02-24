import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show Platform;

import 'package:path/path.dart' as p;

class ModelConfig {
  // Model file names
  static const String textModelFileName = 'medgemma-4b-it-Q4_K_M.gguf'; // Q4: 4-bit quantization
  static const String mmprojFileName = 'mmproj-medgemma-4b-it-Q8_0.gguf';

  /// 1. External storage directory (target location for ADB push)
  static Future<Directory> getExternalModelDir() async {
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) throw Exception('Could not get external storage directory');
      return Directory('${externalDir.path}/MedGemma')..createSync(recursive: true);
    } else {
      return getApplicationDocumentsDirectory(); // iOS uses Documents uniformly
    }
  }

  /// 2. Internal private directory (real loading position for FFI, bypassing Android permission restrictions)
  static Future<Directory> getInternalModelDir() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory('${supportDir.path}/MedGemma')..createSync(recursive: true);
  }

  /// Get model directory (Edge AI Core: app-specific external storage, no permissions required)
  ///
  /// [isInternal]:
  ///   - true: Returns the app's internal private directory (getApplicationSupportDirectory), used for FFI engine loading, most stable.
  ///   - false: Returns the app-specific external storage (getExternalStorageDirectory), used for pushing models via ADB, easy to operate.
  static Future<Directory> getModelDir({bool isInternal = false}) async {
    Directory baseDir;

    if (Platform.isAndroid) {
      if (isInternal) {
        // Internal directory: /data/user/0/your.package.name/files (or app_support)
        // This path is most friendly for native C++ (FFI) access
        baseDir = await getApplicationSupportDirectory();
      } else {
        // External directory: /storage/emulated/0/Android/data/your.package.name/files
        // This path is convenient for developers to push files via ADB command
        final externalDir = await getExternalStorageDirectory();
        if (externalDir == null) throw Exception('Could not get external storage directory');
        baseDir = externalDir;
      }
    } else if (Platform.isIOS) {
      // iOS path is relatively simple, stored uniformly in Documents or Support
      baseDir = isInternal
          ? await getApplicationSupportDirectory()
          : await getApplicationDocumentsDirectory();
    } else {
      throw UnsupportedError('Only supports Android/iOS');
    }

    // Uniformly add the project subdirectory MedGemma
    final modelDir = Directory('${baseDir.path}/MedGemma');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// 3. Core: Prepare models and return loadable paths
  /// This method checks the internal directory, if files are missing, it copies them from the external directory
  static Future<Map<String, String>> prepareInternalModels() async {
    // Get external (source) and internal (target) directories
    final sourceDir = await getModelDir(isInternal: false);
    final targetDir = await getModelDir(isInternal: true);

    final String targetTextPath = p.join(targetDir.path, textModelFileName);
    final String targetMmprojPath = p.join(targetDir.path, mmprojFileName);

    // Perform copy check
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
      print('✅ Internal model already exists: ${p.basename(destination)}');
      return;
    }

    final sourceFile = File(source);
    if (await sourceFile.exists()) {
      print('🚚 Migrating model to internal storage: ${p.basename(source)}');
      // Use stream-based copying to avoid out-of-memory errors with large files
      await sourceFile.copy(destination);
      print('✨ Migration complete');
    } else {
      throw Exception('❌ Source file missing! Please push the model via ADB to: $source');
    }
  }





  /// Text model path
  static Future<String> get textModelPath async {
    final dir = await getModelDir(isInternal: false);
    return '${dir.path}/$textModelFileName';
  }

  /// Projector path
  static Future<String> get mmprojPath async {
    final dir = await getModelDir(isInternal: false);
    return '${dir.path}/$mmprojFileName';
  }

  /// Check if files exist
  static Future<bool> checkFilesExist() async {
    try {
      final textFile = File(await textModelPath);
      final mmprojFile = File(await mmprojPath);
      final textExists = await textFile.exists();
      final mmprojExists = await mmprojFile.exists();

      print('📁 MedGemma Edge Model Check:');
      print('   📄 Text Model: ${textExists ? '✅' : '❌'} - ${await textModelPath}');
      print('   🖼️ Projector: ${mmprojExists ? '✅' : '❌'} - ${await mmprojPath}');

      if (textExists) {
        // Try to set permissions (effective on some Android versions)
        // or re-check if the file size is 0
        final stat = await textFile.stat();
        print("Text model file size: ${stat.size}, permissions: ${stat.mode}");
      } else {
        print("Text model file does not physically exist!");
      }

      if (mmprojExists) {
        // Try to set permissions (effective on some Android versions)
        // or re-check if the file size is 0
        final stat = await mmprojFile.stat();
        print("Projector file size: ${stat.size}, permissions: ${stat.mode}");
      } else {
        print("Projector model file does not physically exist!");
      }

      return textExists && mmprojExists;
    } catch (e) {
      print('❌ File check failed: $e');
      return false;
    }
  }

  /// ADB push command (for quick deployment)
  static Future<String> getAdbPushCommand() async {
    final dir = await getModelDir();
    final packageName = 'com.example.medgemma_edge'; // Replace with your package name
    return '''
📱 Edge AI Deployment Command:
adb shell mkdir -p ${dir.path}
adb push $textModelFileName ${dir.path}/
adb push $mmprojFileName ${dir.path}/

📌 Verify Files:
adb shell ls -la ${dir.path}
''';
  }
}