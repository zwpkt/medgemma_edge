import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import '../../core/constants/model_config.dart';


/// MedGemma Edge 核心推理服务
/// 基于 llama_cpp_dart 实现，支持多模态和离线推理
class LlamaEdgeService {
  static final LlamaEdgeService _instance = LlamaEdgeService._internal();
  factory LlamaEdgeService() => _instance;
  LlamaEdgeService._internal();

  // ✅ 核心：Managed Isolate (Flutter友好，非阻塞)
  LlamaParent? _llamaParent;
  LlamaScope? _currentScope;  // ✅ 保存当前请求的 scope

  // 状态
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isModelLoaded => _llamaParent != null;

  // 流式响应
  final _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  // 加载进度
  final _loadingController = StreamController<double>.broadcast();
  Stream<double> get loadingStream => _loadingController.stream;

  // 错误信息
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  /// 加载多模态模型（Edge AI 核心）
  Future<bool> loadModel() async {
    try {


      _checkMemory();

      _loadingController.add(0.1);

      // 1. 先加载系统库
      _preloadSystemLibs();
      print("🚀 原生系统依赖链加载完成");

      // 2. 再加载你自己编译的依赖库 (顺序很重要)
      _preloadYourCustomLibs();

      print("🚀 原生自编译依赖链加载完成");
      _loadingController.add(0.2);

      // 1. 检查模型文件
      print('🔍 [MedGemma Edge] 检查模型文件...');
      final filesExist = await ModelConfig.checkFilesExist();
      if (!filesExist) {
        final adbCmd = await ModelConfig.getAdbPushCommand();
        _errorController.add('模型文件不存在\n$adbCmd');
        _loadingController.add(-1);
        return false;
      }

      _loadingController.add(0.3);

      // 2. 获取模型路径
      final textPath = await ModelConfig.textModelPath;
      final mmprojPath = await ModelConfig.mmprojPath;

      print('📦 [MedGemma Edge] 加载配置:');
      print('   - 文本模型: $textPath； size：${File(textPath).lengthSync()}');
      print('   - 投影器: $mmprojPath； size：${File(mmprojPath).lengthSync()}');


      // 3. 配置模型参数（Edge AI 优化）
      final loadCommand = LlamaLoad(
        path: textPath,
        modelParams: ModelParams()
          ..nGpuLayers = 0              // 99: 尽可能使用 GPU; 0: CPU
          ..mainGpu = -1  // 明确告诉系统不使用任何 GPU
          ..useMemorymap = true          // ✅ 原 useMmap → useMemorymap, true->false
          ..useMemoryLock = false        // ✅ 原 useMlock → useMemoryLock
          ..checkTensors = false
          ..useExtraBufts = false
          ..noHost = false,
        contextParams: ContextParams()
          ..nCtx = 512    //2048
          ..nBatch = 512
          ..nThreads = 4
          ..nSeqMax = 1,
        samplingParams: SamplerParams()  // ✅ 类名正确
          ..temp = 0.7                  // ✅ 参数名正确
          ..topK = 40
          ..topP = 0.95
          ..penaltyRepeat = 1.1,        // ✅ 参数名正确
        mmprojPath: mmprojPath,  // ✅ 多模态：传入投影器路径！
        verbose: true,
      );

      _loadingController.add(0.6);

      // 关键修改：在创建 LlamaParent 之前，先设置静态变量； 先设置主 Isolate 的 libraryPath
      Llama.libraryPath = 'libllama.so';
      print('📌 [主Isolate] libraryPath 已设置为: libllama.so');

      // try {
      //   print('🔍 开始详细诊断...');
      //
      //   // 1. 先设置 libraryPath
      //   Llama.libraryPath = 'libllama.so';
      //
      //   // 2. 手动加载库
      //   final handle = DynamicLibrary.open('libllama.so');
      //   print('✅ 成功打开 libllama.so');
      //
      //   // 3. 检查关键符号是否存在
      //   final symbols = [
      //     'llama_model_default_params',
      //     'llama_context_default_params',
      //     'llama_init_from_file',
      //     'llama_new_context_with_model',
      //     'llama_n_ctx',
      //     'llama_n_batch',
      //     'llama_decode',
      //     'llama_free',
      //     'llama_backend_init',
      //     'llama_load_session_file',
      //     'llama_save_session_file',
      //     'llama_get_state_size',
      //     'llama_copy_state_data',
      //     'llama_set_state_data'
      //   ];
      //
      //   for (final symbol in symbols) {
      //     try {
      //       handle.lookup(symbol);
      //       print('  ✅ 符号 $symbol 存在');
      //     } catch (e) {
      //       print('  ❌ 符号 $symbol 缺失: $e');
      //     }
      //   }
      //
      // } catch (e) {
      //   print('❌ 库加载诊断失败: $e');
      // }

      // 4. 初始化 LlamaParent
      print('🚀 [MedGemma Edge] 初始化推理引擎...');
      _llamaParent = LlamaParent(loadCommand);
      print('🚀 [MedGemma Edge] 正在加载模型...');
      if (_llamaParent != null){
        //todo
      }

      print(" Llama.libraryPath${ Llama.libraryPath}");
      await _llamaParent!.init();
      print("after init");

      print('🚀 [MedGemma Edge] 模型加载完成');

      _loadingController.add(0.9);

      // 5. 设置流式监听
      _llamaParent!.stream.listen(
            (response) {
          if (kDebugMode) print('📝 [推理] $response');
          _responseController.add(response);
        },
        onError: (error) {
          print('❌ [推理错误] $error');
          _errorController.add('推理错误: $error');
        },
        onDone: () {
          print('✅ [推理完成]');
        },
      );

      _isInitialized = true;
      _loadingController.add(1.0);

      print('✅ [MedGemma Edge] 模型加载成功！');
      print('   - 设备: ${Platform.operatingSystem}');
      print('   - 模式: 完全离线 | GPU加速 | 边缘计算');

      return true;
    } catch (e, s) {
      print('❌ [MedGemma Edge] 加载失败: $e\n$s');
      _errorController.add('加载失败: $e');
      _loadingController.add(-1);
      return false;
    }
  }


  // 在调用 _initializeLlama 前添加内存检查
  Future<bool> _checkMemory() async {
    try {
      final file = File('/proc/meminfo');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        int memAvailable = 0;
        int memTotal = 0;

        for (final line in lines) {
          if (line.startsWith('MemAvailable:')) {
            memAvailable = int.parse(line.split(RegExp(r'\s+'))[1]) ~/ 1024; // 转 MB
            print('📊 系统可用内存: $memAvailable MB');
          } else if (line.startsWith('MemTotal:')) {
            memTotal = int.parse(line.split(RegExp(r'\s+'))[1]) ~/ 1024;
            print('📊 系统总内存: $memTotal MB');
          }
        }

        // 模型需要约 3GB 空闲
        if (memAvailable < 3000) {
          print('⚠️ 警告：可用内存不足 3GB，模型加载可能失败');
          return false;
        }
      }

      // 进程内存
      final rss = ProcessInfo.currentRss ~/ (1024 * 1024);
      print('📊 进程当前 RSS: $rss MB');

      return true;
    } catch (e) {
      print('⚠️ 无法获取内存信息: $e');
      return true; // 继续尝试
    }
  }


  void _preloadSystemLibs() {
    if (Platform.isAndroid) {
      DynamicLibrary.open('liblog.so');
      DynamicLibrary.open('libm.so');
      DynamicLibrary.open('libdl.so');
    }
  }

  void _preloadYourCustomLibs() {
    // 按依赖顺序手动点火
    DynamicLibrary.open('libc++_shared.so');
    DynamicLibrary.open('libomp.so');
    DynamicLibrary.open('libggml.so');
    DynamicLibrary.open('libggml-base.so');
    DynamicLibrary.open('libggml-cpu.so');
    // 注意：libllama.so 通常由插件内部加载，但手动加载一次可以提前暴露符号错误
    DynamicLibrary.open('libmtmd.so');
    DynamicLibrary.open('libllama.so');

  }

  /// 纯文本生成
  void generateText(String prompt) {
    if (!_isInitialized || _llamaParent == null) {
      _errorController.add('模型未初始化');
      return;
    }

    print('📝 [用户] $prompt');
    // 保存返回的 scope，用于后续停止
    Future<String>? _currentPromptId;  // 保存当前请求的 promptId
    _currentPromptId= _llamaParent!.sendPrompt(prompt);



    // 通过 scope 监听响应
    // _currentScope!.stream.listen(
    //       (response) {
    //     _responseController.add(response);
    //   },
    //   onError: (error) {
    //     _errorController.add('生成错误: $error');
    //   },
    //   onDone: () {
    //     _currentScope = null;  // 生成完成，清理 scope
    //   },
    // );
  }

  /// 多模态生成（文本 + 图像）- Edge AI 核心功能
  Future<void> generateWithImage({
    required String prompt,
    required File imageFile,
  }) async {
    if (!_isInitialized || _llamaParent == null) {
      _errorController.add('模型未初始化');
      return;
    }

    try {
      print('🖼️ [MedGemma Edge] 多模态推理开始');
      print('   - 提示词: $prompt');
      print('   - 图像: ${imageFile.path} (${await imageFile.length()} bytes)');

      // 读取图像文件
      final imageBytes = await imageFile.readAsBytes();

      // 构建多模态输入
      // 注意：llama_cpp_dart 通过特殊格式支持图像
      // 格式: <image>base64编码的图像数据</image>\n文本提示词
      final base64Image = imageBytes.isNotEmpty ?
      'data:image/jpeg;base64,${base64Encode(imageBytes)}' : '';

      final multimodalPrompt = '''
<image>
$base64Image
</image>
$prompt
''';

      _llamaParent!.sendPrompt(multimodalPrompt);

    } catch (e) {
      print('❌ [多模态错误] $e');
      _errorController.add('图像处理失败: $e');
    }
  }

  /// ✅【核心】停止生成
  void stopGeneration() {
    _currentScope = _llamaParent!.getScope();
    if (_currentScope != null) {
      _currentScope!.stop();  // 通过 scope 停止
      _currentScope = null;
      print('⏹️ [生成已停止]');
    } else {
      print('⚠️ [没有正在进行的生成任务]');
    }
  }

  /// 卸载模型（释放内存）
  Future<void> unloadModel() async {
    if (_llamaParent != null) {
      await _llamaParent!.dispose();
      _llamaParent = null;
      _isInitialized = false;
      print('✅ [MedGemma Edge] 模型已卸载');
    }
  }

  /// 释放资源
  void dispose() {
    unloadModel();
    _responseController.close();
    _loadingController.close();
    _errorController.close();
  }

  /// 辅助：base64编码
  String base64Encode(List<int> bytes) {
    return String.fromCharCodes(bytes);
  }
}